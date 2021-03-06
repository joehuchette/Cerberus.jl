"""
Ensures that the LP model in `state.gurobi_model` is up-to-date for the current
`node`. Depending on how things are configured, this could require us doing
some or all of: rebuilding the model from scratch, applying new branchings,
and reformulating disjunctions.
"""
function populate_lp_model!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
    config::AlgorithmConfig,
)
    if state.rebuild_model
        create_base_model!(state, form, node, config)
        apply_branchings!(state, node)
        formulate_disjunctions!(state, form, node, config)
    else
        # If this case we would like to reuse the same model and not rebuild
        # from scratch...
        if !state.on_a_dive
            # ...however, upon backtracking we need to reset bounds and reapply
            # (or reset) disjunctive formulations.
            remove_branchings!(state, form)
        end
        apply_branchings!(state, node)
        if config.formulation_tightening_strategy == TIGHTEN_AT_EACH_NODE
            error(
                "Cerberus does not currently support tightening formulations via problem modification; you must rebuild from scratch.",
            )
        end
        return nothing
    end
    return nothing
end

# NOTE: At all times, the first `num_variables(form)` variables in the model
# will correspond to those registered with `form`. The disjunctive formulaters
# may add additional continuous variables, but they must come after this chunk.
# This means that these variables will present, in the same order, in every
# node LP.
function create_base_model!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
    config::AlgorithmConfig,
)
    reset_formulation_state!(state)
    model = config.lp_solver_factory(state, config)::Gurobi.Optimizer
    state.gurobi_model = model
    for cvi in all_variables(form)
        l, u = get_bounds(form, cvi)
        # Cache the above updates in formulation. Even better,
        # batch add variables.
        vi, ci = MOI.add_constrained_variable(model, IN(l, u))
        attach_index!(state, vi)
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
    MOI.set(model, MOI.ObjectiveFunction{SAF}(), instantiate(form.obj, state))
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    state.rebuild_model = false
    state.total_model_builds += 1
    return nothing
end

function formulate_disjunctions!(
    state::CurrentState,
    form::DMIPFormulation,
    node::Node,
    config::AlgorithmConfig,
)
    for (formulater, cvis) in form.disjunction_formulaters
        formulate!(
            state,
            form,
            formulater,
            # If we use a static formulation, it must be valid at the root. In
            # a bit of a hack, in this case we will just pass in an empty Node.
            if config.formulation_tightening_strategy == STATIC_FORMULATION
                Node()
            else
                node
            end,
            config,
        )
    end
    return nothing
end

function _unattached_bounds(cs::ConstraintState, node::Node, ::Type{LT})
    return view(
        node.lt_bounds,
        Colon()(cs.branch_state.num_lt_branches + 1, length(node.lt_bounds)),
    )
end
function _unattached_bounds(cs::ConstraintState, node::Node, ::Type{GT})
    return view(
        node.gt_bounds,
        Colon()(cs.branch_state.num_gt_branches + 1, length(node.gt_bounds)),
    )
end
function _unattached_constraints(cs::ConstraintState, node::Node, ::Type{LT})
    return view(
        node.lt_general_constrs,
        Colon()(
            length(cs.branch_state.lt_general_constrs) + 1,
            length(node.lt_general_constrs),
        ),
    )
end
function _unattached_constraints(cs::ConstraintState, node::Node, ::Type{GT})
    return view(
        node.gt_general_constrs,
        Colon()(
            length(cs.branch_state.gt_general_constrs) + 1,
            length(node.gt_general_constrs),
        ),
    )
end

function remove_branchings!(state::CurrentState, form::DMIPFormulation)
    model = state.gurobi_model
    cs = state.constraint_state
    for cvi in all_variables(form)
        l, u = get_bounds(form, cvi)
        ci = cs.base_state.var_constrs[index(cvi)]
        MOI.set(model, MOI.ConstraintSet(), ci, IN(l, u))
    end
    # TODO: Can potentially be smarter about not deleting all of these
    # constraints on a backtrack.
    MOI.delete(model, cs.branch_state.lt_general_constrs)
    MOI.delete(model, cs.branch_state.gt_general_constrs)
    empty!(cs.branch_state)
    return nothing
end

# We skip any bounds or constraints that are already added to the model. Note
# that we do this a bit dangerously--we merely count the number of
# bounds/constraints attached (as recorded in constraint_state). Therefore,
# this will only work on dives.
function apply_branchings!(state::CurrentState, node::Node)
    model = state.gurobi_model
    cs = state.constraint_state
    for lt_bound in _unattached_bounds(cs, node, LT)
        cvi = lt_bound.cvi
        vi = instantiate(cvi, state)
        ci = cs.base_state.var_constrs[index(cvi)]
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        new_interval = IN(interval.lower, min(lt_bound.s.upper, interval.upper))
        MOI.set(model, MOI.ConstraintSet(), ci, new_interval)
        cs.branch_state.num_lt_branches += 1
    end
    for gt_bound in _unattached_bounds(cs, node, GT)
        cvi = gt_bound.cvi
        vi = instantiate(cvi, state)
        ci = cs.base_state.var_constrs[index(cvi)]
        interval = MOI.get(model, MOI.ConstraintSet(), ci)
        new_interval = IN(max(gt_bound.s.lower, interval.lower), interval.upper)
        MOI.set(model, MOI.ConstraintSet(), ci, new_interval)
        cs.branch_state.num_gt_branches += 1
    end
    for ac in _unattached_constraints(cs, node, LT)
        # Invariant: constraint was normalized via MOIU.normalize_constant.
        ci = MOI.add_constraint(model, instantiate(ac.f, state), ac.s)
        push!(cs.branch_state.lt_general_constrs, ci)
    end
    for ac in _unattached_constraints(cs, node, GT)
        # Invariant: constraint was normalized via MOIU.normalize_constant.
        ci = MOI.add_constraint(model, instantiate(ac.f, state), ac.s)
        push!(cs.branch_state.gt_general_constrs, ci)
    end
    return nothing
end

# TODO: Unit test
function _update_lp_solution!(state::CurrentState, form::DMIPFormulation)
    # NOTE: I believe that the following is costless if the size is correct.
    resize!(state.current_solution, num_variables(form))
    for cvi in all_variables(form)
        state.current_solution[index(cvi)] = MOI.get(
            state.gurobi_model,
            MOI.VariablePrimal(),
            instantiate(cvi, state),
        )
    end
    return nothing
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
