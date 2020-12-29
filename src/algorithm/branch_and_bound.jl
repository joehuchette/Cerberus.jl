function optimize!(
    form::DMIPFormulation,
    config::AlgorithmConfig,
    primal_bound::Float64 = Inf,
)::Result
    result = Result()
    # TODO: Model presolve. Must happen before initial state is built.
    # Initialize search tree with LP relaxation
    state = CurrentState(primal_bound)
    if config.log_output
        _log_preamble(form, primal_bound)
    end
    while !isempty(state.tree)
        node = pop_node!(state.tree)
        process_node!(state, form, node, config)
        update_state!(state, form, node, config)
        # TODO: Don't do this every iteration
        update_dual_bound!(state)
        if config.log_output
            _log_node_update(state)
        end
        if state.total_node_count >= config.node_limit
            break
        end
    end
    return Result(state, config)
end

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
    empty!(state.node_result)
    simplex_iters = MOI.get(model, MOI.SimplexIterations())
    state.node_result.simplex_iters = simplex_iters
    state.node_result.depth = length(node.branchings)
    term_status = MOI.get(model, MOI.TerminationStatus())
    if term_status == MOI.OPTIMAL
        state.node_result.cost = MOI.get(model, MOI.ObjectiveValue())
        _fill_solution!(state.node_result.x, model)
        state.node_result.int_infeas =
            _num_int_infeasible(form, state.node_result.x, config)
        if config.warm_start
            _fill_basis!(state.node_result.basis, model)
        end
        if config.hot_start
            state.node_result.model = model
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
    x::Dict{VI,Float64},
    config::AlgorithmConfig,
)::Int
    cnt = 0
    for i in 1:num_variables(form)
        v_set = form.integrality[i]
        if v_set === nothing
            continue
        end
        vi = VI(i)
        xi = x[vi]
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
)
    favorite_child.parent_info =
        ParentInfo(result.cost, result.basis, result.model)
    # TODO: This only maintains hot start model on dives. Is this the right call?
    other_child.parent_info = ParentInfo(result.cost, result.basis, nothing)
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
        _attach_parent_info!(favorite_child, other_child, result)
        push_node!(state.tree, other_child)
        push_node!(state.tree, favorite_child)
    end
    state.total_elapsed_time_sec = time() - state.starting_time
    return nothing
end
