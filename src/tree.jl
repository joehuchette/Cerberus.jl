const BoundDiff = Dict{CVI,Int}

mutable struct Node
    lb_diff::BoundDiff
    ub_diff::BoundDiff
    lt_constrs::Vector{AffineConstraint{LT}}
    gt_constrs::Vector{AffineConstraint{GT}}
    depth::Int
    dual_bound::Float64

    function Node(
        lb_diff::BoundDiff,
        ub_diff::BoundDiff,
        lt_constrs::Vector{AffineConstraint{LT}},
        gt_constrs::Vector{AffineConstraint{GT}},
        depth::Int,
        dual_bound::Float64 = -Inf,
    )
        if depth < length(lb_diff) + length(ub_diff)
            throw(
                ArgumentError(
                    "Depth is too small for the number of branches made.",
                ),
            )
        end
        return new(lb_diff, ub_diff, lt_constrs, gt_constrs, depth, dual_bound)
    end
end
function Node()
    return Node(
        BoundDiff(),
        BoundDiff(),
        AffineConstraint{LT}[],
        AffineConstraint{GT}[],
        0,
        -Inf,
    )
end
function Node(
    lb_diff::BoundDiff,
    ub_diff::BoundDiff,
    depth::Int,
    dual_bound::Float64 = -Inf,
)
    return Node(
        lb_diff,
        ub_diff,
        AffineConstraint{LT}[],
        AffineConstraint{GT}[],
        depth,
        dual_bound,
    )
end

function Base.copy(node::Node)
    return Node(
        copy(node.lb_diff),
        copy(node.ub_diff),
        copy(node.lt_constrs),
        copy(node.gt_constrs),
        node.depth,
        node.dual_bound,
    )
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
