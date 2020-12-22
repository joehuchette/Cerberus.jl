mutable struct NodeResult
    cost::Float64
    simplex_iters::Int
    x::Union{Nothing,Vector{Float64}}
    basis::Union{Nothing,Basis}
    model::Union{Nothing,Gurobi.Optimizer}

    # Wall time should be tracked by CurrentState

    function NodeResult(cost::Real, simplex_iters::Real, x::Union{Nothing,Vector{Float64}}=nothing, basis::Union{Nothing,Basis}=nothing, model::Union{Nothing,Gurobi.Optimizer}=nothing)
        @assert simplex_iters >= 0
        return new(cost, simplex_iters, x, basis, model)
    end
end

mutable struct CurrentState
    gurobi_env::Gurobi.Env
    tree::Tree
    enumerated_node_count::Int
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Vector{Float64}
    total_simplex_iters::Int

    function CurrentState(form::DMIPFormulation, primal_bound::Real=Inf)
        return new(
            Gurobi.Env(),
            Tree(),
            0,
            primal_bound,
            -Inf,
            fill(NaN, num_variables(form)),
            0,
        )
    end
end

function update_dual_bound!(state::CurrentState)
    state.dual_bound = minimum(node.parent_info.dual_bound for node in state.tree.open_nodes)
    return nothing
end

ip_feasible(form::DMIPFormulation, x::Nothing, config::AlgorithmConfig) = false
function ip_feasible(form::DMIPFormulation, x::Vector{Float64}, config::AlgorithmConfig)::Bool
    for vi in form.integrality
        if !(abs(x[vi.value]) <= config.int_tol || abs(1 - x[vi.value]) <= config.int_tol)
            return false
        end
    end
    return true
end

function update_state!(state::CurrentState, form::DMIPFormulation, node::Node, result::NodeResult, config::AlgorithmConfig)
    state.enumerated_node_count += 1
    state.total_simplex_iters += result.simplex_iters
    # 1. Prune by infeasibility
    if result.cost == Inf
        # Do nothing
    # 2. Prune by bound
    elseif result.cost > state.primal_bound
        # Do nothing
    # 3. Prune by integrality
    elseif result.x !== nothing && ip_feasible(form, result.x, config)
        # Have <= to handle case where we seed the optimal cost but
        # not the optimal solution
        if result.cost <= state.primal_bound
            # TODO: Add a tolerance here (maybe?), plus way to handle MAX
            state.primal_bound = result.cost
            state.best_solution .= result.x
        end
    # 4. Branch!
    else
        favorite_child, other_child = branch(form, config.branching_rule, node, result, config)
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
        push_node!(state.tree, other_child)
        push_node!(state.tree, favorite_child)
    end
    return nothing
end
