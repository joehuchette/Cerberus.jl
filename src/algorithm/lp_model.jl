# TODO: When adding hot starting, can dispatch on previous_model stored in
# node to elide reconstruction.
function build_base_model(form::DMIPFormulation, state::CurrentState, node::Node, config::AlgorithmConfig)
    env = state.gurobi_env
    model = Gurobi.Optimizer(env)
    MOI.add_constrained_variables(model, form.bounds)
    for (f, s) in form.feasible_region.aff_constrs
        MOI.add_constraint(model, f, s)
    end
    MOI.set(model, MOI.ObjectiveFunction{ScalarAffineFunction}(), form.obj)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    return model
end

function update_bounds!(model::MOI.AbstractOptimizer, node::Node)
    for index in node.vars_branched_to_zero
        ci = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval}(index)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        @assert interval.lower == 0.0
        interval.upper = 0.0
        MOI.set(model, MOI.ConstraintSet(), ci, interval)
    end
    for index in node.vars_branched_to_one
        ci = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval}(index)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        interval.lower = 1.0
        @assert interval.upper == 1.0
        MOI.set(model, MOI.ConstraintSet(), ci, interval)
    end
    return nothing
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
