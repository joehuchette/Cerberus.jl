mutable struct NodeResult
    cost::Float64
    simplex_iters::Int
    x::Dict{MOI.VariableIndex,Float64}
    basis::Union{Nothing,Basis}
    model::Union{Nothing,Gurobi.Optimizer}

    # Wall time should be tracked by CurrentState

    function NodeResult(cost::Real, simplex_iters::Real, x::Dict{MOI.VariableIndex,Float64}=Dict{MOI.VariableIndex,Float64}(), basis::Union{Nothing,Basis}=nothing, model::Union{Nothing,Gurobi.Optimizer}=nothing)
        @assert simplex_iters >= 0
        return new(cost, simplex_iters, x, basis, model)
    end
end

function NodeResult(cost::Real, simplex_iters::Real, x::Vector{Float64}, basis::Union{Nothing,Basis}=nothing, model::Union{Nothing,Gurobi.Optimizer}=nothing)
    @warn "Slow path, only use for testing."
    return NodeResult(
        cost,
        simplex_iters,
        Dict(MOI.VariableIndex(i) => x[i] for i in 1:length(x)),
        basis,
        model,
    )
end

mutable struct CurrentState
    gurobi_env::Gurobi.Env
    tree::Tree
    enumerated_node_count::Int
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Dict{MOI.VariableIndex,Float64}
    total_simplex_iters::Int

    function CurrentState(primal_bound::Real=Inf)
        return new(
            Gurobi.Env(),
            Tree(),
            0,
            primal_bound,
            -Inf,
            Dict{MOI.VariableIndex,Float64}(),
            0,
        )
    end
end

function update_dual_bound!(state::CurrentState)
    state.dual_bound = minimum(node.parent_info.dual_bound for node in state.tree.open_nodes)
    return nothing
end
