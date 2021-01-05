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
    state =
        CurrentState(num_variables(form), config, primal_bound = primal_bound)
    if config.log_output
        _log_preamble(form, primal_bound)
    end
    while !isempty(state.tree)
        node = pop_node!(state.tree)
        process_node!(state, form, node, config)
        update_state!(state, form, node, config)
        _log_if_necessary(state, config)
        if _is_time_to_terminate(state, config)
            break
        end
    end
    return Result(state, config)
end

# TODO: Store config in CurrentState, remove as argument here.
function process_node!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
    config::AlgorithmConfig,
)::Nothing
    # 1. Build model
    model = build_base_model(
        form,
        state,
        node,
        config,
        node.parent_info.hot_start_model,
    )
    # Update bounds on binary variables at the current node
    update_node_bounds!(model, node)
    set_basis_if_available!(model, node.parent_info.basis)

    # 2. Solve model
    MOI.optimize!(model)

    # 3. Grab solution data and bundle it into a NodeResult
    reset!(state.node_result)
    state.node_result.simplex_iters = MOI.get(model, MOI.SimplexIterations())
    state.node_result.depth = length(node.branchings)
    term_status = MOI.get(model, MOI.TerminationStatus())
    if term_status == MOI.OPTIMAL
        state.node_result.cost = MOI.get(model, MOI.ObjectiveValue())
        _fill_solution!(state.node_result.x, model)
        state.node_result.int_infeas =
            _num_int_infeasible(form, state.node_result.x, config)
        if config.incrementalism == WARM_START
            update_basis!(state.node_result, model)
        elseif config.incrementalism == HOT_START
            update_basis!(state.node_result, model)
            set_model!(state.node_result, model)
        end
    elseif term_status == MOI.INFEASIBLE
        state.node_result.cost = Inf
    elseif term_status == MOI.DUAL_INFEASIBLE
        state.node_result.cost = -Inf
    else
        error("Unexpected termination status $term_status at node LP.")
    end
    return nothing
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

function _attach_parent_info!(
    favorite_child::Node,
    other_child::Node,
    result::NodeResult,
    config::AlgorithmConfig,
)
    cost = result.cost
    if config.incrementalism == NO_INCREMENTALISM
        favorite_child.parent_info = ParentInfo(cost, nothing, nothing)
        other_child.parent_info = ParentInfo(cost, nothing, nothing)
    elseif config.incrementalism == WARM_START
        favorite_child.parent_info =
            ParentInfo(cost, get_basis(result), nothing)
        other_child.parent_info =
            ParentInfo(cost, copy(get_basis(result)), nothing)
    else
        @assert config.incrementalism == HOT_START
        favorite_child.parent_info =
            ParentInfo(cost, nothing, get_model(result))
        other_child.parent_info = ParentInfo(cost, get_basis(result), nothing)
    end
    return nothing
end

function update_state!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
    config::AlgorithmConfig,
)
    result = state.node_result
    state.total_node_count += 1
    state.total_simplex_iters += result.simplex_iters
    state.polling_state.period_node_count += 1
    state.polling_state.period_simplex_iters += result.simplex_iters
    # 1. Prune by infeasibility
    if result.cost == Inf
        # Do nothing
    elseif result.cost > state.primal_bound
        # 2. Prune by bound
        # Do nothing
    elseif result.cost == -Inf
        # 3. LP is unbounded.
        #  Implies MIP is infeasible or unbounded. Should only happen at root.
        @assert isempty(node.branchings)
        state.primal_bound = result.cost
    elseif result.int_infeas == 0
        # 4. Prune by integrality
        # Have <= to handle case where we seed the optimal cost but
        # not the optimal solution
        if result.cost <= state.primal_bound
            state.primal_bound = result.cost
            # TODO: Make this more efficient, keys should not change.
            copy!(state.best_solution, result.x)
        end
    else
        # 5. Branch!
        favorite_child, other_child =
            branch(form, config.branching_rule, node, result, config)
        _attach_parent_info!(favorite_child, other_child, result, config)
        push_node!(state.tree, other_child)
        push_node!(state.tree, favorite_child)
        # TODO: Add a check in this branch to ensure we don't have a "funny" return
        #       status. This is a little kludgy since we don't necessarily store the
        #       MOI model in result. Maybe need to add termination status as a field...
    end
    state.total_elapsed_time_sec = time() - state.starting_time
    return nothing
end
