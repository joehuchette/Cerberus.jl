struct BoundUpdate{S<:Union{LT,GT}}
    cvi::CVI
    s::S
end

mutable struct Node
    lt_bounds::Vector{BoundUpdate{LT}}
    gt_bounds::Vector{BoundUpdate{GT}}
    lt_general_constrs::Vector{AffineConstraint{LT}}
    gt_general_constrs::Vector{AffineConstraint{GT}}
    depth::Int
    dual_bound::Float64
    branching_variable::BoundUpdate
    branch_var_fractional::Float64
end

function Node()
    return Node(
        BoundUpdate{LT}[],
        BoundUpdate{GT}[],
        AffineConstraint{LT}[],
        AffineConstraint{GT}[],
        0,
        -Inf,
        NaN,
        NaN,
    )
end

function Node(
    lt_bounds::Vector{BoundUpdate{LT}},
    gt_bounds::Vector{BoundUpdate{GT}},
    depth::Int,
    dual_bound::Float64 = -Inf,
)
    return Node(lt_bounds, gt_bounds, [], [], depth, dual_bound, NaN, NaN)
end

function Node(
    lt_bounds::Vector{BoundUpdate{LT}},
    gt_bounds::Vector{BoundUpdate{GT}},
    lt_general_constrs::Vector{AffineConstraint{LT}},
    gt_general_constrs::Vector{AffineConstraint{GT}},
    depth::Int,
)
    return Node(
        lt_bounds,
        gt_bounds,
        lt_general_constrs,
        gt_general_constrs,
        depth,
        -Inf,
        NaN,
        NaN,
    )
end

function Base.copy(node::Node)
    return Node(
        copy(node.lt_bounds),
        copy(node.gt_bounds),
        copy(node.lt_general_constrs),
        copy(node.gt_general_constrs),
        node.depth,
        node.dual_bound,
        node.branching_variable,
        node.branch_var_fractional,
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
