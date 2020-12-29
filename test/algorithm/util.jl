function _is_root_node(node::Cerberus.Node)
    isempty(node.branchings) || return false
    node.parent_info.dual_bound == -Inf || return false
    node.parent_info.basis === nothing || return false
    node.parent_info.hot_start_model === nothing || return false
    return true
end

function _NodeResult(
    cost::Real,
    simplex_iters::Real,
    x::Vector{Float64},
    basis::Union{Nothing,Cerberus.Basis} = nothing,
    model::Union{Nothing,Gurobi.Optimizer} = nothing,
)
    return NodeResult(
        cost,
        simplex_iters,
        Dict(_VI(i) => x[i] for i in 1:length(x)),
        basis,
        model,
    )
end

function _CurrentState()
    state = Cerberus.CurrentState()
    state.gurobi_env = GRB_ENV
    return state
end

function _CurrentState(primal_bound)
    state = Cerberus.CurrentState(primal_bound)
    state.gurobi_env = GRB_ENV
    return state
end

_vec_to_dict(x::Vector) = Dict(_VI(i) => x[i] for i in 1:length(x))
