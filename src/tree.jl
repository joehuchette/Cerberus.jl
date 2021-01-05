# const Basis = Dict{Union{CI{SV,IN},CI{SAF,<:_C_SETS}},MOI.BasisStatusCode}
const Basis = Dict{Any,MOI.BasisStatusCode}

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

mutable struct Node
    branchings::Vector{BranchingDecision}
    parent_info::ParentInfo
end
Node() = Node([], ParentInfo())
Node(branchings::Vector{BranchingDecision}) = Node(branchings, ParentInfo())

mutable struct Tree
    open_nodes::DataStructures.Stack{Node}

    Tree() = new(DataStructures.Stack{Node}())
end

Base.isempty(tree::Tree) = Base.isempty(tree.open_nodes)
Base.length(tree::Tree) = Base.length(tree.open_nodes)
push_node!(tree::Tree, node::Node) = push!(tree.open_nodes, node)
pop_node!(tree::Tree) = pop!(tree.open_nodes)
num_open_nodes(tree::Tree) = length(tree.open_nodes)
