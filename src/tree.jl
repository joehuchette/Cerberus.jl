struct Basis
    lt_constrs::Dict{CI{SAF,LT},MOI.BasisStatusCode}
    gt_constrs::Dict{CI{SAF,GT},MOI.BasisStatusCode}
    et_constrs::Dict{CI{SAF,ET},MOI.BasisStatusCode}
    var_constrs::Dict{CI{SV,IN},MOI.BasisStatusCode}
end
Basis() = Basis(Dict(), Dict(), Dict(), Dict())

# TODO: Unit test
function Base.copy(src::Basis)
    dest = Basis()
    for (k,v) in src.lt_constrs
        dest.lt_constrs[k] = v
    end
    for (k,v) in src.gt_constrs
        dest.gt_constrs[k] = v
    end
    for (k,v) in src.et_constrs
        dest.et_constrs[k] = v
    end
    for (k,v) in src.var_constrs
        dest.var_constrs[k] = v
    end
    return dest
end

struct ParentInfo
    dual_bound::Float64
    basis::Union{Nothing,Basis}
    hot_start_model::Union{Nothing,MOI.AbstractOptimizer}
end
ParentInfo() = ParentInfo(-Inf, nothing, nothing)

@enum BranchingDirection DOWN_BRANCH UP_BRANCH

struct BranchingDecision
    vi::VI
    value::Int
    direction::BranchingDirection
end

const BoundDiff = Dict{VI,Int}

mutable struct Node
    lb_diff::BoundDiff
    ub_diff::BoundDiff
    depth::Int
    parent_info::ParentInfo

    function Node(
        lb_diff::BoundDiff,
        ub_diff::BoundDiff,
        depth::Int,
        parent_info::ParentInfo = ParentInfo(),
    )
        if depth < length(lb_diff) + length(ub_diff)
            throw(ArgumentError("Depth is too small for the number of branches made."))
        end
        return new(lb_diff, ub_diff, depth, parent_info)
    end
end
Node() = Node(BoundDiff(), BoundDiff(), 0, ParentInfo())

function copy_without_pi(node::Node)
    return Node(
        copy(node.lb_diff),
        copy(node.ub_diff),
        node.depth,
        ParentInfo(),
    )
end

function apply_branching!(node::Node, bd::BranchingDecision)
    node.depth += 1
    vi = bd.vi
    if bd.direction == DOWN_BRANCH
        diff = node.ub_diff
        if haskey(diff, vi)
            diff[vi] = min(diff[vi], bd.value)
        else
            diff[vi] = bd.value
        end
    else
        @assert bd.direction == UP_BRANCH
        diff = node.lb_diff
        if haskey(diff, vi)
            diff[vi] = max(diff[vi], bd.value)
        else
            diff[vi] = bd.value
        end
    end
    return nothing
end

mutable struct Tree
    open_nodes::DataStructures.Stack{Node}

    Tree() = new(DataStructures.Stack{Node}())
end

Base.isempty(tree::Tree) = Base.isempty(tree.open_nodes)
Base.length(tree::Tree) = Base.length(tree.open_nodes)
push_node!(tree::Tree, node::Node) = push!(tree.open_nodes, node)
pop_node!(tree::Tree) = pop!(tree.open_nodes)
num_open_nodes(tree::Tree) = length(tree.open_nodes)
