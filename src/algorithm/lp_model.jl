# TODO: When adding hot starting, can dispatch on previous_model stored in
# node to elide reconstruction.
function build_base_model(
    form::DMIPFormulation,
    state::CurrentState,
    node::Node,
    config::AlgorithmConfig,
)
    model = config.lp_solver_factory(state, config)::Gurobi.Optimizer
    for i in 1:num_variables(form)
        bound = form.base_form.feasible_region.bounds[i]
        l, u = bound.lower, bound.upper
        # TODO: Make this update more efficient, and unit test it.
        if form.integrality[i] isa ZO
            l = max(0, l)
            u = min(1, u)
        end
        MOI.add_constrained_variable(model, IN(l, u))
    end
    for aff_constr in form.base_form.feasible_region.aff_constrs
        MOI.add_constraint(model, aff_constr.f, aff_constr.s)
    end
    # TODO: Test this once it does something...
    for formulater in form.disjunction_formulaters
        apply!(model, formulator, node)
    end
    MOI.set(model, MOI.ObjectiveFunction{SAF}(), form.base_form.obj)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    return model
end

function update_node_bounds!(model::MOI.AbstractOptimizer, node::Node)
    for bd in node.branchings
        ci = CI{SV,IN}(bd.vi.value)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        new_interval = (
            if bd.direction == DOWN_BRANCH
                IN(interval.lower, bd.value)
            else
                IN(bd.value, interval.upper)
            end
        )
        MOI.set(model, MOI.ConstraintSet(), ci, new_interval)
    end
    return nothing
end

function _fill_solution!(x::Dict{VI,Float64}, model::MOI.AbstractOptimizer)
    for v in MOI.get(model, MOI.ListOfVariableIndices())
        x[v] = MOI.get(model, MOI.VariablePrimal(), v)
    end
    return nothing
end

function _fill_basis!(
    basis::Dict{Any,MOI.BasisStatusCode},
    model::MOI.AbstractOptimizer,
)
    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
            basis[ci] = MOI.get(model, MOI.ConstraintBasisStatus(), ci)
        end
    end
    return nothing
end

# TODO: Do we still need this function?
function get_basis(model::MOI.AbstractOptimizer)::Basis
    basis = Dict{Any,MOI.BasisStatusCode}()
    _fill_basis!(basis, model)
    return basis
end

set_basis_if_available!(model::MOI.AbstractOptimizer, ::Nothing) = nothing
function set_basis_if_available!(
    model::MOI.AbstractOptimizer,
    basis::Basis,
)::Nothing
    # TODO: Check that basis is, in fact, a basis after modification
    for (key, val) in basis
        MOI.set(model, MOI.ConstraintBasisStatus(), key, val)
    end
    return nothing
end
