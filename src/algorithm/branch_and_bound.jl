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
                result = process_node(node, state, config)
            end
            update_state!(state, result)
            if node_count >= config.node_limit
                state.dual_bound = minimum(node.parent_dual_bound for node in tree.open_nodes)
                break
            end
        end
    end
    return Result(state)
end

function apply!(formulation::Formulation, tightener::FormulationUpdater, node::Node)
    return nothing
end

function process_node(node::Node, state::CurrentState, config::AlgorithmConfig)::NodeResult
    # 1. Build model

    # 2. Solve model

    # 3a. Prune by infeasibility

    # 3b. Prune by integrality

    # 3c. Prune by bound

    # 4c. Branch

end
