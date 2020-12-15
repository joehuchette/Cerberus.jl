function down_branch(node::Node, result::NodeResult, branch_idx::Int)
    return _branch(node, result, branch_idx, true)
end

function up_branch(node::Node, result::NodeResult, branch_idx::Int)
    return _branch(node, result, branch_idx, false)
end

function _branch(node::Node, result::NodeResult, branch_idx::Int, branch_down::Bool)
    vars_branched_to_zero = copy(node.vars_branched_to_zero)
    vars_branched_to_one = copy(node.vars_branched_to_one)
    if branch_down
        push!(vars_branched_to_zero, branch_idx)
    else
        push!(vars_branched_to_one, branch_idx)
    end
    @assert result.cost > node.parent_dual_bound
    return Node(
        vars_branched_to_zero,
        vars_branched_to_one,
        result.cost,
        result.basis,
    )
end

function branch(problem::Problem, ::MostInfeasible, state::CurrentState, parent_node::Node, result::NodeResult)::Tuple{Node,Node}
    most_frac_idx = 0
    most_frac_val = 1.0
    for i in integral_indices(problem.base_form)
        @assert 0 <= result.x[i] <= 1
        frac_val = abs(result.x[i] - 0.5)
        if frac_val < most_frac_val
            most_frac_idx = i
            most_frac_val = frac_val
        end
    end
    @assert most_frac_idx > 0
    down_node = down_branch(parent_node, result, most_frac_idx)
    up_node = up_branch(parent_node, result, most_frac_idx)
    if result.x[most_frac_idx] > 0.5
        return (up_node, down_node)
    else
        return (down_node, up_node)
    end
end
