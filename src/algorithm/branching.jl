function apply_branching!(node::Node, bu::BoundUpdate{LT})
    node.depth += 1
    push!(node.lt_bounds, bu)
    return nothing
end

function apply_branching!(node::Node, bu::BoundUpdate{GT})
    node.depth += 1
    push!(node.gt_bounds, bu)
    return nothing
end

function apply_branching!(node::Node, ac::AffineConstraint{LT})
    node.depth += 1
    # NOTE: Can potentially modify bd in-place; would need to note this in the
    # contract, though.
    f = CSAF(ac.f.coeffs, ac.f.indices, 0.0)
    s = LT(ac.s.upper - ac.f.constant)
    push!(node.lt_general_constrs, AffineConstraint(f, s))
    return nothing
end

function apply_branching!(node::Node, ac::AffineConstraint{GT})
    node.depth += 1
    # NOTE: Can potentially modify bd in-place; would need to note this in the
    # contract, though.
    f = CSAF(ac.f.coeffs, ac.f.indices, 0.0)
    s = GT(ac.s.lower - ac.f.constant)
    push!(node.gt_general_constrs, AffineConstraint(f, s))
    return nothing
end

function down_branch(node::Node, branch_cvi::CVI, val::Float64)
    return _branch(node, branch_cvi, LT(floor(Int, val)))
end

function up_branch(node::Node, branch_cvi::CVI, val::Float64)
    return _branch(node, branch_cvi, GT(ceil(Int, val)))
end

function _branch(node::Node, branch_cvi::CVI, set::S) where {S<:Union{LT,GT}}
    # TODO: Can likely reuse this memory instead of copying
    new_node = copy(node)
    apply_branching!(new_node, BoundUpdate(branch_cvi, set))
    return new_node
end

function branch(
    form::DMIPFormulation,
    ::MostInfeasible,
    parent_node::Node,
    parent_result::NodeResult,
    config::AlgorithmConfig,
)::Tuple{Node,Node}
    t = 0
    most_frac_val = 0.0
    for i in 1:num_variables(form)
        var_set = get_variable_kind(form, CVI(i))
        # continuous variable, don't branch on it
        if var_set === nothing
            continue
        end
        @assert typeof(var_set) <: Union{ZO,GI}
        xi = parent_result.x[i]
        xi_f = _approx_floor(xi, config.int_tol)
        xi_c = _approx_ceil(xi, config.int_tol)
        frac_val = min(xi - xi_f, xi_c - xi)
        # We're integral up to tolerance, don't branch.
        if frac_val <= config.int_tol
            continue
        end
        if frac_val > most_frac_val
            t = i
            most_frac_val = frac_val
        end
    end
    @assert t > 0
    cvi = CVI(t)
    xt = parent_result.x[t]
    down_node = down_branch(parent_node, cvi, xt)
    up_node = up_branch(parent_node, cvi, xt)
    @debug "Branching on $cvi, whose current LP value is $xt."
    # TODO: This dives on child that is closest to integrality. Is this right?
    if xt - floor(xt) > ceil(xt) - xt
        return (up_node, down_node)
    else
        return (down_node, up_node)
    end
end
