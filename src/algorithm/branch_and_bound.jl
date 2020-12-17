function optimize!(problem::Problem, config::AlgorithmConfig, primal_bound::Float64=Inf)::Result
    result = Result()
    to = result.timings
    # TODO: Model presolve. Must happen before initial state is built.
    # Initialize search tree with LP relaxation
    state = _initial_state(problem, primal_bound)
    TimerOutputs.@timeit to "Tree search" begin
        while !isempty(state.tree)
            node = pop_next_node!(tree)
            TimerOutputs.@timeit to "Node processing" begin
                result = process_node(problem, state, node, config)
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

function process_node(problem::Problem, state::CurrentState, node::Node, config::AlgorithmConfig)::NodeResult
    # 1. Build model
    model = build_lp_model(problem, state, node, config)
    set_basis_if_available!(model, node.basis)

    # 2. Solve model
    MOI.optimize!(model)

    # 3. Grab solution data and bundle it into a NodeResult
    x = nothing
    cost = MOI.get(model, MOI.ObjectiveValue())
    basis = nothing
    term_status = MOI.get(model, MOI.TerminationStatus())
    if term_status == MOI.OPTIMAL
        x = MOI.get(model, MOI.VariablePrimal(), MOI.ListOfVariableIndices())
        basis = get_basis(model)
    elseif term_status == MOI.INFEASIBLE
        @assert cost == Inf
    else
        error("Unexpected termination status $term_status at node LP.")
    end
    return NodeResult(x, cost, basis, MOI.get(model, MOI.SimplexIterations())
)
end
