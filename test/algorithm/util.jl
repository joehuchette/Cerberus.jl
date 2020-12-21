function _silent_gurobi_factory(state::Cerberus.CurrentState)
    model = Gurobi.Optimizer(state.gurobi_env)
    MOI.set(model, MOI.Silent(), true)
    return model
end
