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
        ubs[lt_bound.cvi] = min(ubs[lt_bound.cvi], lt_bound.s.upper)
    end
    for gt_bound in node.gt_bounds
        lbs[gt_bound.cvi] = max(lbs[gt_bound.cvi], gt_bound.s.lower)
    end

    proven_active = Bool[]
    not_inactive = Bool[]
    ϵ_int = config.int_tol
    for cvi in cvis
        l = lbs[cvi]
        u = ubs[cvi]
        # Approximate version of: l == 1 == u
        push!(proven_active, (abs(l - 1) ≤ ϵ_int) & (abs(u - 1) ≤ ϵ_int))
        # Approximate version of: l <= 1 <= u
        push!(not_inactive, (l ≤ 1 + ϵ_int) & (1 <= u + ϵ_int))
    end
    return proven_active, not_inactive
end
