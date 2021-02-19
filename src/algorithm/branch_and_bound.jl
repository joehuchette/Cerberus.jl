# TODO: Unit test
function _is_time_to_terminate(state::CurrentState, config::AlgorithmConfig)
    if state.total_node_count >= config.node_limit ||
       state.total_elapsed_time_sec >= config.time_limit_sec
        return true
    else
        return false
    end
end

function optimize!(
    form::DMIPFormulation,
    config::AlgorithmConfig,
    primal_bound::Float64 = Inf,
)::Result
    result = Result()
    # TODO: Model presolve. Must happen before initial state is built.
    # Initialize search tree with LP relaxation
    state = CurrentState(primal_bound = primal_bound)
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
NodeResult() = NodeResult(NaN, Float64[], 0, -1, 0)

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
    formulate_disjunctions!(state, form, node, config)
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
        _update_lp_solution!(state, form)
        node_result.x = state.current_solution
        node_result.int_infeas = _num_int_infeasible(state, form, config)
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
    state::CurrentState,
    form::DMIPFormulation,
    config::AlgorithmConfig,
)::Int
    cnt = 0
    for cvi in all_variables(form)
        v_set = get_variable_kind(form, cvi)
        if v_set === nothing
            continue
        end
        xi = state.current_solution[index(cvi)]
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
        @assert _is_root_node(node)
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
        children = branch(state, form, node, node_result, config)
        _store_basis_if_desired!(state, children, config)
        for child in children
            child.dual_bound = node_result.cost
            push_node!(state.tree, child)
        end
        # TODO: Can be even more clever with this and reuse the same model
        # throughout the tree. However, we currently update bounds based on a
        # diff with the root. So, after backtracking we will need to reset all
        # bounds, but can otherwise reuse the same model.
        state.backtracking = false
        # TODO: Add a check in this branch to ensure we don't have a "funny"
        # return status. This is a little kludgy since we don't necessarily
        # store the MOI model in node_result. Maybe need to add termination
        # status as a field...
    end
    state.rebuild_model = if state.backtracking
        (config.model_reuse_strategy != USE_SINGLE_MODEL)
    else
        (config.model_reuse_strategy == NO_MODEL_REUSE)
    end
    state.total_elapsed_time_sec = time() - state.starting_time
    delete!(state.warm_starts, node)
    return nothing
end

function _store_basis_if_desired!(
    state::CurrentState,
    children::NTuple{N,Node},
    config::AlgorithmConfig,
) where {N}
    @assert N == length(children) >= 2
    if config.warm_start_strategy == NO_WARM_STARTS
        # Do nothing
    else
        basis = get_basis(state)
        state.warm_starts[children[1]] = basis
        ending_index = (
            if config.warm_start_strategy == WARM_START_WHEN_BACKTRACKING
                N - 1
            else
                @assert config.warm_start_strategy == WARM_START_WHENEVER_POSSIBLE
                N
            end
        )
        for i in 2:ending_index
            state.warm_starts[children[i]] = copy(basis)
        end
    end
    return nothing
end
