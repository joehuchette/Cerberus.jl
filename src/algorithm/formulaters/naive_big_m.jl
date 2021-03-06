function new_variables_to_attach(
    formulater::DisjunctiveFormulater{DisjunctiveConstraints.NaiveBigM},
)
    return fill(
        ZO(),
        DisjunctiveConstraints.num_alternatives(formulater.disjunction.s),
    )
end

# NOTE: This will ignore any general constraints in `node`.
function compute_disjunction_activity(
    form::DMIPFormulation,
    formulater::DisjunctiveFormulater{DisjunctiveConstraints.NaiveBigM},
    node::Node,
    config::AlgorithmConfig,
)
    cvis = form.disjunction_formulaters[formulater]
    @assert length(cvis) ==
            DisjunctiveConstraints.num_alternatives(formulater.disjunction.s)
    lbs = Dict{CVI,Float64}()
    ubs = Dict{CVI,Float64}()
    for cvi in cvis
        @assert !haskey(lbs, cvi)
        @assert !haskey(ubs, cvi)
        l, u = get_bounds(form, cvi)
        lbs[cvi] = l
        ubs[cvi] = u
    end
    for lt_bound in node.lt_bounds
        cvi = lt_bound.cvi
        if haskey(ubs, cvi)
            ubs[cvi] = min(ubs[cvi], lt_bound.s.upper)
        end
    end
    for gt_bound in node.gt_bounds
        cvi = gt_bound.cvi
        if haskey(lbs, cvi)
            lbs[cvi] = max(lbs[cvi], gt_bound.s.lower)
        end
    end

    activity = Bool[]
    proven_active = Int[]
    ϵ_int = config.int_tol
    for (i, cvi) in enumerate(cvis)
        l = lbs[cvi]
        u = ubs[cvi]
        # Approximate version of: l == 1 == u
        if (abs(l - 1) ≤ ϵ_int) && (abs(u - 1) ≤ ϵ_int)
            push!(proven_active, i)
        end
        # Approximate version of: l <= 1 <= u
        push!(activity, (l ≤ 1 + ϵ_int) & (1 <= u + ϵ_int))
    end
    if length(proven_active) == 1
        # We have proven one alternative must be active; therefore, we can
        # infer that all others must be inactive.
        fill!(activity, false)
        activity[proven_active[1]] = true
    elseif length(proven_active) > 1
        # We have proven that two alternatives must be active. This is not
        # possible; therefore, the problem must be infeasible.
        fill!(activity, false)
    end
    return activity
end

function delete_all_constraints!(
    model::Gurobi.Optimizer,
    disjunction_state::DisjunctiveConstraints.NaiveBigMState,
)
    for lt_ci in disjunction_state.lt_cis
        if lt_ci !== nothing
            MOI.delete(model, lt_ci)
        end
    end
    for gt_ci in disjunction_state.gt_cis
        if gt_ci !== nothing
            MOI.delete(model, gt_ci)
        end
    end
    return nothing
end
