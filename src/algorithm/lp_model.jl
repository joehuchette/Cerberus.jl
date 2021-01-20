function populate_base_model!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
    config::AlgorithmConfig,
)
    if !state.model_invalidated
        return nothing
    end
    model = config.lp_solver_factory(state, config)::Gurobi.Optimizer
    for i in 1:num_variables(form)
        bound = form.feasible_region.bounds[i]
        l, u = bound.lower, bound.upper
        if form.integrality[i] isa ZO
            l = max(0, l)
            u = min(1, u)
        end
        # Cache the above updates in formulation. Even better,
        # batch add variables.
        vi, ci = MOI.add_constrained_variable(model, IN(l, u))
        state.constraint_state.var_constrs[i] = ci
    end
    for (i, lt_constr) in enumerate(form.feasible_region.lt_constrs)
        ci = MOI.add_constraint(model, lt_constr.f, lt_constr.s)
        state.constraint_state.lt_constrs[i] = ci
    end
    for (i, gt_constr) in enumerate(form.feasible_region.gt_constrs)
        ci = MOI.add_constraint(model, gt_constr.f, gt_constr.s)
        state.constraint_state.gt_constrs[i] = ci
    end
    for (i, et_constr) in enumerate(form.feasible_region.et_constrs)
        ci = MOI.add_constraint(model, et_constr.f, et_constr.s)
        state.constraint_state.et_constrs[i] = ci
    end
    # TODO: Test this once it does something...
    for formulater in form.disjunction_formulaters
        apply!(model, formulator, node)
    end
    MOI.set(model, MOI.ObjectiveFunction{SAF}(), form.obj)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    state.gurobi_model = model
    state.model_invalidated = false
    state.total_model_builds += 1
    return nothing
end

function update_node_bounds!(model::MOI.AbstractOptimizer, node::Node)
    for (vi, lb) in node.lb_diff
        ci = CI{SV,IN}(vi.value)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        # @assert lb >= interval.upper
        new_interval = IN(lb, interval.upper)
        MOI.set(model, MOI.ConstraintSet(), ci, new_interval)
    end
    for (vi, ub) in node.ub_diff
        ci = CI{SV,IN}(vi.value)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        # @assert ub <= interval.upper
        new_interval = IN(interval.lower, ub)
        MOI.set(model, MOI.ConstraintSet(), ci, new_interval)
    end
    return nothing
end

function _get_lp_solution!(model::MOI.AbstractOptimizer)
    nvars = MOI.get(model, MOI.NumberOfVariables())
    x = Vector{Float64}(undef, nvars)
    for v in MOI.get(model, MOI.ListOfVariableIndices())
        x[v.value] = MOI.get(model, MOI.VariablePrimal(), v)
    end
    return x
end

function get_basis(state::CurrentState)::Basis
    basis = Basis()
    for ci in state.constraint_state.lt_constrs
        basis.lt_constrs[ci] =
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci)
    end
    for ci in state.constraint_state.gt_constrs
        basis.gt_constrs[ci] =
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci)
    end
    for ci in state.constraint_state.et_constrs
        basis.et_constrs[ci] =
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci)
    end
    for ci in state.constraint_state.var_constrs
        basis.var_constrs[ci] =
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci)
    end
    return basis
end

function set_basis_if_available!(
    model::MOI.AbstractOptimizer,
    state::CurrentState,
    node::Node,
)
    if haskey(state.warm_starts, node)
        _set_basis!(model, state.warm_starts[node])
        state.total_warm_starts += 1
    end
    return nothing
end

function _set_basis!(model::MOI.AbstractOptimizer, basis::Basis)::Nothing
    # TODO: Check that basis is, in fact, a basis after modification
    @debug "Basis is being set ($(length(basis)) elements)"
    if isempty(basis.lt_constrs) &&
       isempty(basis.gt_constrs) &&
       isempty(basis.et_constrs) &&
       isempty(basis.var_constrs)
        throw(ArgumentError("You are attempting to set an empty basis."))
    end
    for (k, v) in basis.lt_constrs
        MOI.set(model, MOI.ConstraintBasisStatus(), k, v)
    end
    for (k, v) in basis.gt_constrs
        MOI.set(model, MOI.ConstraintBasisStatus(), k, v)
    end
    for (k, v) in basis.et_constrs
        MOI.set(model, MOI.ConstraintBasisStatus(), k, v)
    end
    for (k, v) in basis.var_constrs
        MOI.set(model, MOI.ConstraintBasisStatus(), k, v)
    end
    return nothing
end
