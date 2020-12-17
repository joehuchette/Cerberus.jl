function build_lp_model(problem::Problem, state::CurrentState, node::Node, config::AlgorithmConfig)
    env = state.gurobi_env
    model = Gurobi.Optimizer(env)

end

function get_basis(model::MOI.AbstractOptimizer)::Basis
    # @assert MOI.get(model, MOI.ListOfConstraints()) == [()]
     v_basis = Dict(
        v => MOI.get(model, MOI.ListOfVariableIndices(), v) for v in MOI.get(model, MOI.ListOfVariableIndices())
    )
    c_basis = Dict(
        (f, s) => MOI.get(model, MOI.ConstraintBasisStatus(), (f, s))
    )
    c_basis = Dict{MOI.ConstraintIndex,MOI.ConstraintBasisStatus}()
    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        for index in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
            c = MOI.ConstraintIndex{F,S}(index)
            c_basis[c] = MOI.get(model, MOI.ConstraintBasisStatus(), c)
        end
    end
    return Basis(v_basis, c_basis)
end

set_basis_if_available!(model::MOI.AbstractOptimizer, ::Nothing) = nothing
function set_basis_if_available!(model::MOI.AbstractOptimizer, basis::Basis)::Nothing
    # TODO: Actually set the basis. But, need to implement this in MOI first.
    return nothing
end
