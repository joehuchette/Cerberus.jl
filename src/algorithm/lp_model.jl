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
    @show node
    for index in node.vars_branched_to_zero
        ci = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(index.value)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        @assert interval.lower == 0.0
        interval.upper = 0.0
        @show interval
        MOI.set(model, MOI.ConstraintSet(), ci, interval)
    end
    for index in node.vars_branched_to_one
        ci = MOI.ConstraintIndex{MOI.SingleVariable,MOI.Interval{Float64}}(index.value)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        interval.lower = 1.0
        @assert interval.upper == 1.0
        @show interval
        MOI.set(model, MOI.ConstraintSet(), ci, interval)
    end
    return nothing
end

function get_basis(model::MOI.AbstractOptimizer)::Basis
    # @assert MOI.get(model, MOI.ListOfConstraints()) == [()]
     basis = Dict{Any,MOI.BasisStatusCode}(
        v => MOI.get(model, MOI.ListOfVariableIndices(), v) for v in MOI.get(model, MOI.ListOfVariableIndices())
    )
    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        for index in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
            c = MOI.ConstraintIndex{F,S}(index)
            basis[c] = MOI.get(model, MOI.ConstraintBasisStatus(), c)
        end
    end
    return basis
end

set_basis_if_available!(model::MOI.AbstractOptimizer, ::Nothing) = nothing
function set_basis_if_available!(model::MOI.AbstractOptimizer, basis::Basis)::Nothing
    # TODO: Actually set the basis. But, need to implement this in MOI first.
    return nothing
end
