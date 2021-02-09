function _is_root_node(node::Cerberus.Node)
    return isempty(node.lt_bounds) &&
           isempty(node.gt_bounds) &&
           isempty(node.lt_general_constrs) &&
           isempty(node.gt_general_constrs) &&
           node.depth == 0
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

function _CurrentState(
    fm::Cerberus.DMIPFormulation,
    config::Cerberus.AlgorithmConfig;
    primal_bound = Inf,
)
    state = Cerberus.CurrentState(fm, config, primal_bound = primal_bound)
    state.gurobi_env = GRB_ENV
    return state
end
