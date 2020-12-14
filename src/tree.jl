struct Basis
    v_basis::Vector{Int}
    c_basis::Vector{Int}
end

struct Node
    vars_branched_to_zero::Set{Int}
    vars_branched_to_one::Set{Int}
    basis::Union{Nothing,Basis}
    parent_dual_bound::Float64
    # TODO: Way to hot start model on dives
end
Node() = Node(Set{Int}(), Set{Int}(), nothing, -Inf)

mutable struct Tree
    open_nodes::DataStructures.Stack{Node}
end

isempty(tree::Tree) = isempty(tree.open_nodes)
pop_next_node!(tree::Tree) = pop!(tree.open_nodes)
