mutable struct NodeResult
    x::Union{Nothing,Vector{Float64}}
    cost::Float64
    basis::Union{Nothing,Basis}
    simplex_iters::Int
    # Wall time should be tracked by CurrentState

    function NodeResult(x::Union{Nothing,Vector{Float64}}, cost::Real, basis::Union{Nothing,Basis}, simplex_iters::Real)
        @assert simplex_iters >= 0
        return new(x, cost, basis, simplex_iters)
    end
end

mutable struct CurrentState
    tree::Tree
    enumerated_node_count::Int
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Vector{Float64}
    total_simplex_iters::Int

    function CurrentState(problem::Problem, primal_bound::Real=Inf)
        return new(
            Tree(),
            0,
            primal_bound,
            -Inf,
            fill(NaN, num_variables(problem)),
            0,
        )
    end
end

function update_dual_bound!(state::CurrentState)
    state.dual_bound = minimum(node.parent_dual_bound for node in state.tree.open_nodes)
    return nothing
end

ip_feasible(problem::Problem, x::Nothing, config::AlgorithmConfig) = false
function ip_feasible(problem::Problem, x::Vector{Float64}, config::AlgorithmConfig)::Bool
    for i in integral_indices(problem.base_form)
        if !(abs(x[i]) <= config.int_tol || abs(1 - x[i]) <= config.int_tol)
            return false
        end
    end
    return true
end

function update!(state::CurrentState, problem::Problem, node::Node, result::NodeResult, config::AlgorithmConfig)
    state.enumerated_node_count += 1
    state.total_simplex_iters += result.simplex_iters
    # 1. Prune by infeasibility
    if result.cost == Inf
        # Do nothing
    # 2. Prune by bound
    elseif result.cost > state.primal_bound
        # Do nothing
    # 3. Prune by integrality
    elseif result.x !== nothing && ip_feasible(problem, result.x, config)
        # Have <= to handle case where we seed the optimal cost but
        # not the optimal solution
        if result.cost <= state.primal_bound
            # TODO: Add a tolerance here (maybe?), plus way to handle MAX
            state.primal_bound = result.cost
            state.best_solution .= result.x
        end
    # 4. Branch!
    else
        favorite_child, other_child = branch(problem, config.branching_rule, state, node, result)
        push_node!(state.tree, other_child)
        push_node!(state.tree, favorite_child)
    end
    return nothing
end
