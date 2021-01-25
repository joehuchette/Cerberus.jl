# TODO: Unit test
function _is_time_to_terminate(state::CurrentState, config::AlgorithmConfig)
    if state.total_node_count >= config.node_limit ||
       state.total_elapsed_time_sec >= config.time_limit_sec
        return true
    else
        return false
    end
end

# NOTE: Almost all of the time inside this functions is spent in process_node!.
# Roughly 1/3 is in build_base_model, 1/3 in optimize!(::Gurobi.Optimizer), and
# 1/5 in _update_basis!. Some ideas of how to improve performance in the future:
#   1. Use only one model throughout the algorithm, even on backtracks. This
#      means that either we keep all the cuts we (will eventually) add, or
#      purge them somehow.
#   2. Roughly 1/5 of the time in build_base_model is spent individually
#      setting the variable bounds. We could try to back this or, even better,
#      pass the bounds upon creating the variable via GRBaddvar. Maybe the
#      cleverest way to do this would be to add to Gurobi.jl a method
#      MOI.add_constrained_variable(::Gurobi.Optimizer, set).
#   3. I think that Gurobi.VariableInfo introduces typestability issues in,
#      e.g. Gurobi._update_if_necessary. An "easy" fix is to have a fastpath
#      in that method that skips over updating the entries in the case where
#      no columns are deleted. But it's likely worth addressing the type
#      instability directly.
function optimize!(
    form::DMIPFormulation,
    config::AlgorithmConfig,
    primal_bound::Float64 = Inf,
)::Result
    result = Result()
    # TODO: Model presolve. Must happen before initial state is built.
    # Initialize search tree with LP relaxation
    state = CurrentState(form, config, primal_bound = primal_bound)
    _log_preamble(form, primal_bound, config)
    while !isempty(state.tree)
        node = pop_node!(state.tree)
        node_result = process_node!(state, form, node, config)
        update_state!(state, form, node, node_result, config)
        _log_if_necessary(state, node_result, config)
        if _is_time_to_terminate(state, config)
            break
        end
    end
    result = Result(state, config)
    _log_postamble(result, config)
    return result
end

mutable struct NodeResult
    cost::Float64
    x::Vector{Float64}
    simplex_iters::Int
    depth::Int
    int_infeas::Int
end

function NodeResult()
    return NodeResult(NaN, Float64[], 0, 0, 0)
end

# TODO: Store config in CurrentState, remove as argument here.
function process_node!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
    config::AlgorithmConfig,
)::NodeResult
    # 1. Build model
    populate_base_model!(state, form, node, config)
    # Update bounds on binary variables at the current node
    apply_branchings!(state, node)
    set_basis_if_available!(state, node)

    # 2. Solve model
    model = state.gurobi_model
    MOI.optimize!(model)

    # 3. Grab solution data and bundle it into a NodeResult
    node_result = NodeResult()
    node_result.simplex_iters = MOI.get(model, MOI.SimplexIterations())
    node_result.depth = node.depth
    term_status = MOI.get(model, MOI.TerminationStatus())
    if term_status == MOI.OPTIMAL
        node_result.cost = MOI.get(model, MOI.ObjectiveValue())
        node_result.x = _get_lp_solution!(model)
        node_result.int_infeas =
            _num_int_infeasible(form, node_result.x, config)
    elseif term_status == MOI.INFEASIBLE
        node_result.cost = Inf
    elseif term_status == MOI.DUAL_INFEASIBLE
        node_result.cost = -Inf
    else
        error("Unexpected termination status $term_status at node LP.")
    end
    return node_result
end

# Only checks feasibility w.r.t. integrality constraints!
function _num_int_infeasible(
    form::DMIPFormulation,
    x::Vector{Float64},
    config::AlgorithmConfig,
)::Int
    cnt = 0
    for i in 1:num_variables(form)
        v_set = form.integrality[i]
        if v_set === nothing
            continue
        end
        vi = VI(i)
        xi = x[i]
        ϵ = config.int_tol
        xi_f = _approx_floor(xi, ϵ)
        xi_c = _approx_ceil(xi, ϵ)
        if v_set isa ZO
            # Should have explicitly imposed 0/1 bounds in the formulation...
            # but assert just to be safe.
            @assert -ϵ <= xi <= 1 + ϵ
        end
        if min(abs(xi - xi_f), abs(xi_c - xi)) > ϵ
            # The variable value is more than ϵ away from both its floor and
            # ceiling, so it's fractional up to our tolerance.
            cnt += 1
        end
    end
    return cnt
end

function update_state!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
    node_result::NodeResult,
    config::AlgorithmConfig,
)
    state.total_node_count += 1
    state.total_simplex_iters += node_result.simplex_iters
    state.polling_state.period_node_count += 1
    state.polling_state.period_simplex_iters += node_result.simplex_iters
    state.backtracking = true
    # 1. Prune by infeasibility
    if node_result.cost == Inf
        # Do nothing
    elseif node_result.cost > state.primal_bound
        # 2. Prune by bound
        # Do nothing
    elseif node_result.cost == -Inf
        # 3. LP is unbounded.
        #  Implies MIP is infeasible or unbounded. Should only happen at root.
        @assert isempty(node.lb_diff) && isempty(node.ub_diff)
        state.primal_bound = node_result.cost
    elseif node_result.int_infeas == 0
        # 4. Prune by integrality
        # Have <= to handle case where we seed the optimal cost but
        # not the optimal solution
        if node_result.cost <= state.primal_bound
            state.primal_bound = node_result.cost
            # TODO: Make this more efficient, keys should not change.
            copy!(state.best_solution, node_result.x)
        end
    else
        # 5. Branch!
        favorite_child, other_child =
            branch(form, config.branching_rule, node, node_result, config)
        favorite_child.dual_bound = node_result.cost
        other_child.dual_bound = node_result.cost
        push_node!(state.tree, other_child)
        push_node!(state.tree, favorite_child)
        _store_basis_if_desired!(state, favorite_child, other_child, config)
        # TODO: Can be even more clever with this and reuse the same model
        # throughout the tree. However, we currently update bounds based on a
        # diff with the root. So, after backtracking we will need to reset all
        # bounds, but can otherwise reuse the same model.
        state.backtracking = false
        # TODO: Add a check in this branch to ensure we don't have a "funny" return
        #       status. This is a little kludgy since we don't necessarily store the
        #       MOI model in node_result. Maybe need to add termination status as a field...
    end
    state.rebuild_model = if state.backtracking
        (config.model_reuse_strategy != USE_SINGLE_MODEL)
    else
        (config.model_reuse_strategy == NO_REUSE)
    end
    state.total_elapsed_time_sec = time() - state.starting_time
    delete!(state.warm_starts, node)
    return nothing
end

function _store_basis_if_desired!(
    state::CurrentState,
    favorite_child::Node,
    other_child::Node,
    config::AlgorithmConfig,
)
    if config.warm_start_strategy == NO_WARM_STARTS
        # Do nothing
    else
        basis = get_basis(state)
        if config.warm_start_strategy == WHEN_BACKTRACKING
            state.warm_starts[other_child] = basis
        else
            @assert config.warm_start_strategy == WHENEVER_POSSIBLE
            state.warm_starts[favorite_child] = copy(basis)
            state.warm_starts[other_child] = basis
        end
    end
    return nothing
end
