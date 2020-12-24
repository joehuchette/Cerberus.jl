mutable struct NodeResult
    cost::Float64
    simplex_iters::Int
    x::Dict{MOI.VariableIndex,Float64}
    basis::Basis
    model::Union{Nothing,Gurobi.Optimizer}
    # Wall time should be tracked by CurrentState
end

function NodeResult()
    return NodeResult(
        NaN,
        0,
        Dict{MOI.VariableIndex,Float64}(),
        Dict{Any,MOI.BasisStatusCode}(),
        nothing,
    )
end

function Base.empty!(result::NodeResult)
    result.cost = NaN
    result.simplex_iters = 0
    # Save sizes of x and basis; keys should not change throughout tree anyway
    x_sz = length(result.x)
    # TODO: Potentially more efficient, but messier, is to fill all entries with NaNs.
    empty!(result.x)
    x_sz > 0 && sizehint!(result.x, x_sz)
    basis_sz = length(result.basis)
    empty!(result.basis)
    basis_sz > 0 && sizehint!(result.basis, basis_sz)
    result.model = nothing
    return nothing
end

mutable struct CurrentState
    gurobi_env::Gurobi.Env
    tree::Tree
    node_result::NodeResult
    primal_bound::Float64
    dual_bound::Float64
    best_solution::Dict{MOI.VariableIndex,Float64}
    total_node_count::Int
    total_simplex_iters::Int

    function CurrentState(primal_bound::Real = Inf)
        state = new(
            Gurobi.Env(),
            Tree(),
            NodeResult(),
            primal_bound,
            -Inf,
            Dict{MOI.VariableIndex,Float64}(),
            0,
            0,
        )
        push_node!(state.tree, Node())
        return state
    end
end

function update_dual_bound!(state::CurrentState)
    if isempty(state.tree)
        # Tree is exhausted, so have proven optimality of best found solution.
        state.dual_bound = state.primal_bound
    else
        state.dual_bound = minimum(
            node.parent_info.dual_bound for node in state.tree.open_nodes
        )
    end
    return nothing
end
