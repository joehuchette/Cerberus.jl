struct Basis
    v_basis::Vector{Int}
    c_basis::Vector{Int}
end

struct Node
    vars_branched_to_zero::Set{Int}
    vars_branched_to_one::Set{Int}
    parent_dual_bound::Float64
    basis::Union{Nothing,Basis}
    # TODO: Way to hot start model on dives

    function Node(vars_branched_to_zero::Set{Int}, vars_branched_to_one::Set{Int}, parent_dual_bound::Float64=-Inf, basis::Union{Nothing,Basis}=nothing)
        # TODO: Make this check more efficient
        @assert Base.isempty(intersect(vars_branched_to_one, vars_branched_to_zero))
        @assert all(t -> t > 0, vars_branched_to_zero)
        @assert all(t -> t > 0, vars_branched_to_one)
        return new(vars_branched_to_zero, vars_branched_to_one, parent_dual_bound, basis)
    end
end
Node() = Node(Set{Int}(), Set{Int}(), -Inf, nothing)

function Base.copy(node::Node)
    return Node(
        copy(node.vars_branched_to_zero),
        copy(node.vars_branched_to_one),
        node.parent_dual_bound,
        node.basis,
    )
end

mutable struct Tree
    open_nodes::DataStructures.Stack{Node}

    Tree() = new(DataStructures.Stack{Node}())
end

Base.isempty(tree::Tree) = Base.isempty(tree.open_nodes)
push_node!(tree::Tree, node::Node) = push!(tree.open_nodes, node)
pop_node!(tree::Tree) = pop!(tree.open_nodes)
num_open_nodes(tree::Tree) = length(tree.open_nodes)

