function down_branch(node::Node, branch_vi::VI, val::Float64)
    return _branch(node, branch_vi, floor(Int, val), DOWN_BRANCH)
end

function up_branch(node::Node, branch_vi::VI, val::Float64)
    return _branch(node, branch_vi, ceil(Int, val), UP_BRANCH)
end

function _branch(node::Node, branch_vi::VI, rounded_val::Int, direction::BranchingDirection)
    # TODO: Can likely reuse this memory instead of copying
    branchings = copy(node.branchings)
    push!(branchings, BranchingDecision(branch_vi, rounded_val, direction))
    return Node(branchings)
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
        var_set = form.integrality[i]
        # continuous variable, don't branch on it
        if var_set === nothing
            continue
        end
        vi = VI(i)
        xi = parent_result.x[vi]
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
    xt = parent_result.x[vt]
    down_node = down_branch(parent_node, vt, xt)
    up_node = up_branch(parent_node, vt, xt)
    # TODO: This dives on child that is closest to integrality. Is this right?
    if xt - floor(xt) > ceil(xt) - xt
        return (up_node, down_node)
    else
        return (down_node, up_node)
    end
end
