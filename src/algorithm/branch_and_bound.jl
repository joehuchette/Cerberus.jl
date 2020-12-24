function optimize!(
    form::DMIPFormulation,
    config::AlgorithmConfig,
    primal_bound::Float64 = Inf,
)::Result
    result = Result()
    to = result.timings
    # TODO: Model presolve. Must happen before initial state is built.
    # Initialize search tree with LP relaxation
    state = CurrentState(primal_bound)
    TimerOutputs.@timeit to "Tree search" begin
        while !isempty(state.tree)
            node = pop_node!(state.tree)
            TimerOutputs.@timeit to "Node processing" begin
                process_node!(state, form, node, config)
            end
            update_state!(state, form, node, config)
            # TODO: Don't do this every iteration
            update_dual_bound!(state)
            state.node_result
            if state.total_node_count >= config.node_limit
                break
            end
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
    model = build_base_model(form, state, node, config)
    # Update bounds on binary variables at the current node
    update_node_bounds!(model, node)
    set_basis_if_available!(model, node.parent_info.basis)

    # 2. Solve model
    MOI.optimize!(model)

    # 3. Grab solution data and bundle it into a NodeResult
    simplex_iters = MOI.get(model, MOI.SimplexIterations())
    state.node_result.simplex_iters = simplex_iters
    term_status = MOI.get(model, MOI.TerminationStatus())
    empty!(state.node_result)
    if term_status == MOI.OPTIMAL
        state.node_result.cost = MOI.get(model, MOI.ObjectiveValue())
        _fill_solution!(state.node_result.x, model)
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

function _ip_feasible(
    form::DMIPFormulation,
    x::Dict{MOI.VariableIndex,Float64},
    config::AlgorithmConfig,
)::Bool
    for vi in form.integrality
        if !(abs(x[vi]) <= config.int_tol || abs(1 - x[vi]) <= config.int_tol)
            return false
        end
    end
    return true
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
        # 2. Prune by bound
    elseif result.cost > state.primal_bound
        # Do nothing
        # 3. LP is unbounded.
        #  Implies MIP is infeasible or unbounded. Should only happen at root.
    elseif result.cost == -Inf
        # Assert that we're at the root node
        @assert isempty(node.vars_branched_to_zero)
        @assert isempty(node.vars_branched_to_one)
        state.primal_bound = result.cost
        # 4. Prune by integrality
    elseif _ip_feasible(form, result.x, config)
        # Have <= to handle case where we seed the optimal cost but
        # not the optimal solution
        if result.cost <= state.primal_bound
            state.primal_bound = result.cost
            # TODO: Make this more efficient, keys should not change.
            copy!(state.best_solution, result.x)
        end
        # 5. Branch!
    else
        favorite_child, other_child =
            branch(form, config.branching_rule, node, result, config)
        _attach_parent_info!(favorite_child, other_child, result)
        push_node!(state.tree, other_child)
        push_node!(state.tree, favorite_child)
    end
    return nothing
end
