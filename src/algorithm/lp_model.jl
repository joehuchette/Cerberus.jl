# TODO: When adding hot starting, can dispatch on previous_model stored in
# node to elide reconstruction.
function build_base_model(form::DMIPFormulation, state::CurrentState, node::Node, config::AlgorithmConfig)
    # env = state.gurobi_env
    # model = Gurobi.Optimizer(env)
    model = Gurobi.Optimizer()
    MOI.add_constrained_variables(model, form.base_form.feasible_region.bounds)
    for aff_constr in form.base_form.feasible_region.aff_constrs
        MOI.add_constraint(model, aff_constr.f, aff_constr.s)
    end
    for formulater in form.disjunction_formulaters
        apply!(model, formulator, node)
    end
    MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), form.base_form.obj)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    return model
end

function update_node_bounds!(model::MOI.AbstractOptimizer, node::Node)
    for index in node.vars_branched_to_zero
        ci = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(index.value)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        @assert interval.lower >= 0.0
        MOI.set(model, MOI.ConstraintSet(), ci, MOI.Interval(interval.lower, 0.0))
    end
    for index in node.vars_branched_to_one
        ci = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(index.value)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        @assert interval.upper <= 1.0
        MOI.set(model, MOI.ConstraintSet(), ci, MOI.Interval(1.0, interval.upper))
    end
    return nothing
end

function get_basis(model::MOI.AbstractOptimizer)::Basis
    # @assert MOI.get(model, MOI.ListOfConstraints()) == [()]
    basis = Dict{Any,MOI.BasisStatusCode}()
    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
            basis[ci] = MOI.get(model, MOI.ConstraintBasisStatus(), ci)
        end
    end
    return basis
end

set_basis_if_available!(model::MOI.AbstractOptimizer, ::Nothing) = nothing
function set_basis_if_available!(model::MOI.AbstractOptimizer, basis::Basis)::Nothing
    # TODO: Actually set the basis. But, need to implement this in MOI first.
    return nothing
end
