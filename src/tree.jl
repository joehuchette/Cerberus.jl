const Basis = Dict{Any,MOI.BasisStatusCode}

struct ParentInfo
    dual_bound::Float64
    basis::Union{Nothing,Basis}
    hot_start_model::Union{Nothing,MOI.AbstractOptimizer}
end
ParentInfo() = ParentInfo(-Inf, nothing, nothing)

mutable struct Node
    vars_branched_to_zero::Vector{MOI.VariableIndex}
    vars_branched_to_one::Vector{MOI.VariableIndex}
    parent_info::ParentInfo
    # TODO: Check that branching sets do not overlap
end
Node() = Node([], [], ParentInfo())
function Node(zero_set::Vector{MOI.VariableIndex}, one_set::Vector{MOI.VariableIndex})
    return Node(zero_set, one_set, ParentInfo())
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

