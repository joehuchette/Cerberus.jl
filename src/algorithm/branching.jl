function down_branch(node::Node, branch_vi::MOI.VariableIndex)
    return _branch(node, branch_vi, true)
end

function up_branch(node::Node, branch_vi::MOI.VariableIndex)
    return _branch(node, branch_vi, false)
end

function _branch(node::Node, branch_vi::MOI.VariableIndex, branch_down::Bool)
    # TODO: Can likely reuse this memory instead of copying
    vars_branched_to_zero = copy(node.vars_branched_to_zero)
    vars_branched_to_one = copy(node.vars_branched_to_one)
    if branch_down
        push!(vars_branched_to_zero, branch_vi)
    else
        push!(vars_branched_to_one, branch_vi)
    end
    return Node(
        vars_branched_to_zero,
        vars_branched_to_one,
    )
end

function branch(form::DMIPFormulation, ::MostInfeasible, parent_node::Node, parent_result::NodeResult, config::AlgorithmConfig)::Tuple{Node,Node}
    most_frac_idx = 0
    most_frac_val = 1.0
    for vi in form.integrality
        i = vi.value
        xi = parent_result.x[i]
        @assert 0 <= xi <= 1
        if abs(xi - 0) <= config.int_tol || abs(xi - 1) <= config.int_tol
            continue
        end
        frac_val = abs(xi - 0.5)
        if frac_val >= 0.5 - config.int_tol
            continue
        end
        if frac_val < most_frac_val
            most_frac_idx = i
            most_frac_val = frac_val
        end
    end
    @assert most_frac_idx > 0
    vi = MOI.VariableIndex(most_frac_idx)
    down_node = down_branch(parent_node, vi)
    up_node = up_branch(parent_node, vi)
    if parent_result.x[most_frac_idx] > 0.5
        return (up_node, down_node)
    else
        return (down_node, up_node)
    end
end
