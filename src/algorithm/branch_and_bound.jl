function optimize!(form::DMIPFormulation, config::AlgorithmConfig, primal_bound::Float64=Inf)::Result
    result = Result()
    to = result.timings
    # TODO: Model presolve. Must happen before initial state is built.
    # Initialize search tree with LP relaxation
    state = CurrentState(primal_bound)
    TimerOutputs.@timeit to "Tree search" begin
        while !isempty(state.tree)
            node = pop_node!(state.tree)
            TimerOutputs.@timeit to "Node processing" begin
                result = process_node(form, state, node, config)
            end
            update_state!(state, form, node, result, config)
            # TODO: Don't do this every iteration
            update_dual_bound!(state)
            if state.total_node_count >= config.node_limit
                break
            end
        end
    end
    return Result(state, config)
end

function process_node(form::DMIPFormulation, state::CurrentState, node::Node, config::AlgorithmConfig)::NodeResult
    # 1. Build model
    model = build_base_model(form, state, node, config)
    # Update bounds on binary variables at the current node
    update_node_bounds!(model, node)
    set_basis_if_available!(model, node.parent_info.basis)

    # 2. Solve model
    MOI.optimize!(model)

    # 3. Grab solution data and bundle it into a NodeResult
    simplex_iters = MOI.get(model, MOI.SimplexIterations())
    term_status = MOI.get(model, MOI.TerminationStatus())
    vs = MOI.get(model, MOI.ListOfVariableIndices())
    if term_status == MOI.OPTIMAL
        return NodeResult(
            MOI.get(model, MOI.ObjectiveValue()),
            simplex_iters,
            # TODO: Do this lazily via stored model object
            Dict(v => MOI.get(model, MOI.VariablePrimal(), v) for v in vs),
            config.warm_start ? get_basis(model) : nothing,
            config.hot_start ? model : nothing
        )
    elseif term_status == MOI.INFEASIBLE
        return NodeResult(
            Inf,
            simplex_iters,
        )
    else
        error("Unexpected termination status $term_status at node LP.")
    end
end


function _ip_feasible(form::DMIPFormulation, x::Dict{MOI.VariableIndex,Float64}, config::AlgorithmConfig)::Bool
    for vi in form.integrality
        if !(abs(x[vi]) <= config.int_tol || abs(1 - x[vi]) <= config.int_tol)
            return false
        end
    end
    return true
end

function _attach_parent_info!(favorite_child::Node, other_child::Node, result::NodeResult)
    favorite_child.parent_info = ParentInfo(
        result.cost,
        result.basis,
        result.model,
    )
    # TODO: This only maintains hot start model on dives. Is this the right call?
    other_child.parent_info = ParentInfo(
        result.cost,
        result.basis,
        nothing,
    )
    return nothing
end

function update_state!(state::CurrentState, form::DMIPFormulation, node::Node, result::NodeResult, config::AlgorithmConfig)
    state.total_node_count += 1
    state.total_simplex_iters += result.simplex_iters
    # 1. Prune by infeasibility
    if result.cost == Inf
        # Do nothing
    # 2. Prune by bound
    elseif result.cost > state.primal_bound
        # Do nothing
    # 3. Prune by integrality
    elseif result.cost < Inf && _ip_feasible(form, result.x, config)
        # Have <= to handle case where we seed the optimal cost but
        # not the optimal solution
        if result.cost <= state.primal_bound
            # TODO: Add a tolerance here (maybe?), plus way to handle MAX
            state.primal_bound = result.cost
            state.best_solution = result.x
        end
    # 4. Branch!
    else
        favorite_child, other_child = branch(form, config.branching_rule, node, result, config)
        _attach_parent_info!(favorite_child, other_child, result)
        push_node!(state.tree, other_child)
        push_node!(state.tree, favorite_child)
    end
    return nothing
end
