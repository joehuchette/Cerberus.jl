function reset_formulation_upon_backtracking!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
)
    model = state.gurobi_model
    cs = state.constraint_state
    for i in 1:num_variables(form)
        cvi = CVI(i)
        l, u = get_bounds(form, cvi)
        ci = cs.base_state.var_constrs[index(cvi)]
        MOI.set(model, MOI.ConstraintSet(), ci, IN(l, u))
    end
    # TODO: Can potentially be smarter about not deleting all of these
    # constraints on a backtrack.
    MOI.delete(model, cs.branch_state.lt_general_constrs)
    MOI.delete(model, cs.branch_state.gt_general_constrs)
    empty!(cs.branch_state)
    apply_branchings!(state, node)
    return nothing
end

function populate_base_model!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
    config::AlgorithmConfig,
)
    if !state.rebuild_model
        # If the above check passed, we would like to reuse the same model and
        # not rebuild from scratch...
        if state.backtracking
            # ...however, upon backtracking we need to reset bounds and reapply
            # (or reset) disjunctive formulations.
            reset_formulation_upon_backtracking!(state, form, node)
        end
        return nothing
    end
    empty!(state.constraint_state)
    model = config.lp_solver_factory(state, config)::Gurobi.Optimizer
    for i in 1:num_variables(form)
        l, u = get_bounds(form, CVI(i))
        # Cache the above updates in formulation. Even better,
        # batch add variables.
        vi, ci = MOI.add_constrained_variable(model, IN(l, u))
        push!(state.variable_indices, vi)
        push!(state.constraint_state.base_state.var_constrs, ci)
    end
    for lt_constr in get_constraints(form, CCI{LT})
        # Invariant: constraint was normalized via MOIU.normalize_constant.
        ci = MOI.add_constraint(
            model,
            instantiate(lt_constr.f, state),
            lt_constr.s,
        )
        push!(state.constraint_state.base_state.lt_constrs, ci)
    end
    for gt_constr in get_constraints(form, CCI{GT})
        # Invariant: constraint was normalized via MOIU.normalize_constant.
        ci = MOI.add_constraint(
            model,
            instantiate(gt_constr.f, state),
            gt_constr.s,
        )
        push!(state.constraint_state.base_state.gt_constrs, ci)
    end
    for et_constr in get_constraints(form, CCI{ET})
        # Invariant: constraint was normalized via MOIU.normalize_constant.
        ci = MOI.add_constraint(
            model,
            instantiate(et_constr.f, state),
            et_constr.s,
        )
        push!(state.constraint_state.base_state.et_constrs, ci)
    end
    # TODO: Test this once it does something...
    for formulater in form.disjunction_formulaters
        apply!(model, formulator, node)
    end
    MOI.set(model, MOI.ObjectiveFunction{SAF}(), instantiate(form.obj, state))
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    state.gurobi_model = model
    state.rebuild_model = false
    state.total_model_builds += 1
    return nothing
end

function apply_branchings!(state::CurrentState, node::Node)
    model = state.gurobi_model
    cs = state.constraint_state
    num_existing_lt_bounds = cs.branch_state.num_lt_branches
    total_lt_bounds = length(node.lt_bounds)
    for i in (num_existing_lt_bounds+1):total_lt_bounds
        lt_bound = node.lt_bounds[i]
        vi = state.variable_indices[index(lt_bound.cvi)]
        ci = CI{SV,IN}(vi.value)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        new_interval = IN(interval.lower, min(lt_bound.s.upper, interval.upper))
        MOI.set(model, MOI.ConstraintSet(), ci, new_interval)
        cs.branch_state.num_lt_branches += 1
    end
    num_existing_gt_bounds = cs.branch_state.num_gt_branches
    total_gt_bounds = length(node.gt_bounds)
    for i in (num_existing_gt_bounds+1):total_gt_bounds
        gt_bound = node.gt_bounds[i]
        vi = state.variable_indices[index(gt_bound.cvi)]
        ci = CI{SV,IN}(vi.value)
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        new_interval = IN(max(gt_bound.s.lower, interval.lower), interval.upper)
        MOI.set(model, MOI.ConstraintSet(), ci, new_interval)
        cs.branch_state.num_gt_branches += 1
    end
    num_existing_lt_general_constrs = length(cs.branch_state.lt_general_constrs)
    total_lt_general_constrs = length(node.lt_general_constrs)
    for i in (num_existing_lt_general_constrs+1):total_lt_general_constrs
        ac = node.lt_general_constrs[i]
        # Invariant: The constraints are added in order. If we're adding
        # constraint i attached at this node, and length of branch_lt_constrs
        #  is no less than i, then we've already added it, so can skip.
        # Invariant: constraint was normalized via MOIU.normalize_constant.
        ci = MOI.add_constraint(model, instantiate(ac.f, state), ac.s)
        push!(cs.branch_state.lt_general_constrs, ci)
    end
    num_existing_gt_general_constrs = length(cs.branch_state.gt_general_constrs)
    total_gt_general_constrs = length(node.gt_general_constrs)
    for i in (num_existing_gt_general_constrs+1):total_gt_general_constrs
        ac = node.gt_general_constrs[i]
        # Invariant: The constraints are added in order. If we're adding
        # constraint i attached at this node, and length of branch_lt_constrs
        #  is no less than i, then we've already added it, so can skip.
        # Invariant: constraint was normalized via MOIU.normalize_constant.
        ci = MOI.add_constraint(model, instantiate(ac.f, state), ac.s)
        push!(cs.branch_state.gt_general_constrs, ci)
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
    cs = state.constraint_state
    for ci in cs.base_state.var_constrs
        push!(
            basis.base_var_constrs,
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci),
        )
    end
    for ci in cs.base_state.lt_constrs
        push!(
            basis.base_lt_constrs,
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci),
        )
    end
    for ci in cs.base_state.gt_constrs
        push!(
            basis.base_gt_constrs,
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci),
        )
    end
    for ci in cs.base_state.et_constrs
        push!(
            basis.base_et_constrs,
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci),
        )
    end
    for ci in cs.branch_state.lt_general_constrs
        push!(
            basis.branch_lt_constrs,
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci),
        )
    end
    for ci in cs.branch_state.gt_general_constrs
        push!(
            basis.branch_gt_constrs,
            MOI.get(state.gurobi_model, MOI.ConstraintBasisStatus(), ci),
        )
    end
    return basis
end

function set_basis_if_available!(state::CurrentState, node::Node)
    if haskey(state.warm_starts, node)
        _set_basis!(
            state.gurobi_model,
            state.constraint_state,
            state.warm_starts[node],
        )
        state.total_warm_starts += 1
    end
    return nothing
end

function _set_basis!(
    model::MOI.AbstractOptimizer,
    cs::ConstraintState,
    basis::Basis,
)::Nothing
    # TODO: Check that basis is, in fact, a basis after modification
    @debug "Basis is being set ($(length(basis)) elements)"
    if isempty(basis.base_var_constrs) &&
       isempty(basis.base_lt_constrs) &&
       isempty(basis.base_gt_constrs) &&
       isempty(basis.base_et_constrs) &&
       isempty(basis.branch_lt_constrs) &&
       isempty(basis.branch_gt_constrs)
        throw(ArgumentError("You are attempting to set an empty basis."))
    end
    for (i, bs) in enumerate(basis.base_var_constrs)
        ci = cs.base_state.var_constrs[i]
        MOI.set(model, MOI.ConstraintBasisStatus(), ci, bs)
    end
    for (i, bs) in enumerate(basis.base_lt_constrs)
        ci = cs.base_state.lt_constrs[i]
        MOI.set(model, MOI.ConstraintBasisStatus(), ci, bs)
    end
    for (i, bs) in enumerate(basis.base_gt_constrs)
        ci = cs.base_state.gt_constrs[i]
        MOI.set(model, MOI.ConstraintBasisStatus(), ci, bs)
    end
    for (i, bs) in enumerate(basis.base_et_constrs)
        ci = cs.base_state.et_constrs[i]
        MOI.set(model, MOI.ConstraintBasisStatus(), ci, bs)
    end
    for (i, bs) in enumerate(basis.branch_lt_constrs)
        ci = cs.branch_state.lt_general_constrs[i]
        MOI.set(model, MOI.ConstraintBasisStatus(), ci, bs)
    end
    for (i, bs) in enumerate(basis.branch_gt_constrs)
        ci = cs.branch_state.gt_general_constrs[i]
        MOI.set(model, MOI.ConstraintBasisStatus(), ci, bs)
    end
    return nothing
end
