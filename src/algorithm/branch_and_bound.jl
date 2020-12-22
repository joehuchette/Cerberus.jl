function optimize!(form::DMIPFormulation, config::AlgorithmConfig, primal_bound::Float64=Inf)::Result
    result = Result()
    to = result.timings
    # TODO: Model presolve. Must happen before initial state is built.
    # Initialize search tree with LP relaxation
    state = _initial_state(form, primal_bound)
    TimerOutputs.@timeit to "Tree search" begin
        while !isempty(state.tree)
            node = pop_next_node!(tree)
            TimerOutputs.@timeit to "Node processing" begin
                result = process_node(form, state, node, config)
            end
            update_state!(state, result)
            if node_count >= config.node_limit
                update_dual_bound!(cs)
                break
            end
        end
    end
    return Result(state)
end

function process_node(form::DMIPFormulation, state::CurrentState, node::Node, config::AlgorithmConfig)::NodeResult
    # 1. Build model
    model = build_base_model(form, state, node, config)
    # Update bounds on binary variables at the current node
    update_node_bounds!(model, node)
    set_basis_if_available!(model, node.basis)

    # 2. Solve model
    MOI.optimize!(model)

    # 3. Grab solution data and bundle it into a NodeResult
    cost = MOI.get(model, MOI.ObjectiveValue())
    simplex_iters = MOI.get(model, MOI.SimplexIterations())
    term_status = MOI.get(model, MOI.TerminationStatus())
    if term_status == MOI.OPTIMAL
        return NodeResult(
            cost,
            simplex_iters,
            MOI.get(model, MOI.VariablePrimal(), MOI.ListOfVariableIndices()),
            config.warm_start ? get_basis(model) : nothing,
            config.hot_start ? model : nothing
        )
    elseif term_status == MOI.INFEASIBLE
        @assert cost == Inf
        return NodeResult(
            cost,
            simplex_iters,
        )
    else
        error("Unexpected termination status $term_status at node LP.")
    end
end
