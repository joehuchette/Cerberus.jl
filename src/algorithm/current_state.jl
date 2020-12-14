struct CurrentState
    tree::Tree
    enumerated_node_count::Int
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Vector{Float64}
end

function _initial_state(problem::Problem, primal_bound::Float64=Inf)
    return CurrentState(
        Tree(DataStructures.Stack(Node())),
        0,
        primal_bound,
        -Inf,
        fill(NaN, num_variables(problem)),
    )
end

# Includes both pruning by bound and infeasibility
function update!(state::CurrentState, result::NodeResult)
    state.enumerated_node_count += 1
    return nothing
end

function update!(state::CurrentState, result::PruneByIntegrality)
    state.enumerated_node_count += 1
    # TODO: Add a tolerance here (maybe?), plus way to handle MAX
    if result.objective_value <= state.primal_bound
        state.primal_bound = result.objective_value
        state.best_solution .= result.solution
    end
    return nothing
end

function update!(state::CurrentState, result::Branching)
    state.enumerated_node_count += 1
    push!(state.tree, result.other_child)
    push!(state.tree, result.favorite_child)
    return nothing
end
