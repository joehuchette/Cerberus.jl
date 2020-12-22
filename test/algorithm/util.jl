function _silent_gurobi_factory(state::Cerberus.CurrentState)
    model = Gurobi.Optimizer(state.gurobi_env)
    MOI.set(model, MOI.Silent(), true)
    return model
end

function _is_root_node(node::Cerberus.Node)
    isempty(node.vars_branched_to_zero) || return false
    isempty(node.vars_branched_to_one) || return false
    node.parent_info.dual_bound == -Inf || return false
    node.parent_info.basis === nothing || return false
    node.parent_info.hot_start_model === nothing || return false
    return true
end
