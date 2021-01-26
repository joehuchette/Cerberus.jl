struct BranchingDecision{F<:Union{SV,SAF},S<:Union{LT,GT}}
    f::F
    s::S
end

function apply_branching!(node::Node, bd::BranchingDecision{SV,LT})
    node.depth += 1
    vi = bd.f.variable
    diff = node.ub_diff
    if haskey(diff, vi)
        diff[vi] = min(diff[vi], bd.s.upper)
    else
        diff[vi] = bd.s.upper
    end
    return nothing
end

function apply_branching!(node::Node, bd::BranchingDecision{SV,GT})
    node.depth += 1
    vi = bd.f.variable
    diff = node.lb_diff
    if haskey(diff, vi)
        diff[vi] = max(diff[vi], bd.s.lower)
    else
        diff[vi] = bd.s.lower
    end
    return nothing
end

function apply_branching!(node::Node, bd::BranchingDecision{SAF,LT})
    node.depth += 1
    # NOTE: Can potentially modify bd in-place; would need to note this in the
    # contract, though.
    f, s = MOIU.normalize_constant(bd.f, bd.s)
    push!(node.lt_constrs, AffineConstraint(f, s))
    return nothing
end

function apply_branching!(node::Node, bd::BranchingDecision{SAF,GT})
    node.depth += 1
    # NOTE: Can potentially modify bd in-place; would need to note this in the
    # contract, though.
    f, s = MOIU.normalize_constant(bd.f, bd.s)
    push!(node.gt_constrs, AffineConstraint(f, s))
    return nothing
end

function down_branch(node::Node, branch_vi::VI, val::Float64)
    return _branch(node, branch_vi, LT(floor(Int, val)))
end

function up_branch(node::Node, branch_vi::VI, val::Float64)
    return _branch(node, branch_vi, GT(ceil(Int, val)))
end

function _branch(node::Node, branch_vi::VI, set::S) where {S<:Union{LT,GT}}
    # TODO: Can likely reuse this memory instead of copying
    new_node = copy(node)
    apply_branching!(new_node, BranchingDecision(SV(branch_vi), set))
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
        var_set = form.variable_kind[i]
        # continuous variable, don't branch on it
        if var_set === nothing
            continue
        end
        @assert typeof(var_set) <: Union{ZO,GI}
        vi = VI(i)
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
    vt = VI(t)
    xt = parent_result.x[t]
    down_node = down_branch(parent_node, vt, xt)
    up_node = up_branch(parent_node, vt, xt)
    @debug "Branching on $vt, whose current LP value is $xt."
    # TODO: This dives on child that is closest to integrality. Is this right?
    if xt - floor(xt) > ceil(xt) - xt
        return (up_node, down_node)
    else
        return (down_node, up_node)
    end
end
