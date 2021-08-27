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
    bound_update::BoundUpdate
    fractional_value::Float64

    function Node()
        node = new()
        node.lt_bounds = BoundUpdate{LT}[]
        node.gt_bounds = BoundUpdate{GT}[]
        node.lt_general_constrs = AffineConstraint{LT}[]
        node.gt_general_constrs = AffineConstraint{LT}[]
        node.depth = 0
        node.dual_bound = -Inf
        # bound_update & fractional_value are left unitialized.
        return node
    end
end

function Node(
    lt_bounds::Vector{BoundUpdate{LT}},
    gt_bounds::Vector{BoundUpdate{GT}},
    depth::Int,
    dual_bound::Float64 = -Inf,
)
    node = Node()
    node.lt_bounds = lt_bounds
    node.gt_bounds = gt_bounds
    node.lt_general_constrs = []
    node.gt_general_constrs = []
    node.depth = depth
    node.dual_bound = dual_bound
    return node
end

function Node(
    lt_bounds::Vector{BoundUpdate{LT}},
    gt_bounds::Vector{BoundUpdate{GT}},
    lt_general_constrs::Vector{AffineConstraint{LT}},
    gt_general_constrs::Vector{AffineConstraint{GT}},
    depth::Int,
)
    node = Node()
    node.lt_bounds = lt_bounds
    node.gt_bounds = gt_bounds
    node.lt_general_constrs = lt_general_constrs
    node.gt_general_constrs = gt_general_constrs
    node.depth = depth
    node.dual_bound = -Inf
    return node
end

function Base.copy(node::Node)
    new_node =  Node(
        copy(node.lt_bounds),
        copy(node.gt_bounds),
        copy(node.lt_general_constrs),
        copy(node.gt_general_constrs),
        node.depth)
        new_node.dual_bound = node.dual_bound
        return new_node
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
