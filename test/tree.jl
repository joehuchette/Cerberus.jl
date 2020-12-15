@testset "Basis" begin
    v_basis = [1, 3, 5]
    c_basis = [2, 4]
    basis = @inferred Cerberus.Basis(v_basis, c_basis)
    @test basis.v_basis == v_basis
    @test basis.c_basis == c_basis
end

@testset "Node" begin
    br_zero = Set{Int}([1, 3, 5])
    br_one = Set{Int}([2, 6])
    basis = Cerberus.Basis([1, 2], [3])
    parent_dual_bound = 3.2

    n1 = @inferred Cerberus.Node()
    n2 = @inferred Cerberus.Node(br_zero, br_one)
    n3 = @inferred Cerberus.Node(br_zero, br_one, parent_dual_bound)
    n4 = @inferred Cerberus.Node(br_zero, br_one, parent_dual_bound, basis)

    @test isempty(n1.vars_branched_to_zero)
    @test n2.vars_branched_to_zero == br_zero
    @test n3.vars_branched_to_zero == br_zero
    @test n4.vars_branched_to_zero == br_zero

    @test isempty(n1.vars_branched_to_one)
    @test n2.vars_branched_to_one == br_one
    @test n3.vars_branched_to_one == br_one
    @test n4.vars_branched_to_one == br_one

    @test n1.parent_dual_bound == -Inf
    @test n2.parent_dual_bound == -Inf
    @test n3.parent_dual_bound == parent_dual_bound
    @test n4.parent_dual_bound == parent_dual_bound

    @test n1.basis === nothing
    @test n2.basis === nothing
    @test n3.basis === nothing
    @test n4.basis == basis

    # Violates nonnegativity of variable indices
    br_zero_bad = Set{Int}([0, 1])
    # Violates nonempty intersection of branches up and down
    br_one_bad = Set{Int}([2, 3, 6])
    # Violates nonnegativity of variable indices
    br_one_bad_2 = Set{Int}([-1, 2, 6])
    @test_throws AssertionError Cerberus.Node(br_zero_bad, br_one)
    @test_throws AssertionError Cerberus.Node(br_zero, br_one_bad)
    @test_throws AssertionError Cerberus.Node(br_zero, br_one_bad_2)
end

@testset "Tree" begin
    # BFS, branching first on 1 and then on 2
    n1 = Cerberus.Node()
    n2 = Cerberus.Node(Set{Int}([1]), Set{Int}([ ]))
    n3 = Cerberus.Node(Set{Int}([ ]), Set{Int}([1]))
    n4 = Cerberus.Node(Set{Int}([2]), Set{Int}([1]))
    n5 = Cerberus.Node(Set{Int}([ ]), Set{Int}([1,2]))
    tree = @inferred Cerberus.Tree()
    @inferred Cerberus.push_node!(tree, n5)
    @inferred Cerberus.push_node!(tree, n4)
    @inferred Cerberus.push_node!(tree, n3)
    @inferred Cerberus.push_node!(tree, n2)
    @inferred Cerberus.push_node!(tree, n1)

    @test !isempty(tree)
    @test Cerberus.num_open_nodes(tree) == 5
    @test Cerberus.pop_node!(tree) == n1

    @test !isempty(tree)
    @test Cerberus.num_open_nodes(tree) == 4
    @test Cerberus.pop_node!(tree) == n2

    @test !isempty(tree)
    @test Cerberus.num_open_nodes(tree) == 3
    @test Cerberus.pop_node!(tree) == n3

    @test !isempty(tree)
    @test Cerberus.num_open_nodes(tree) == 2
    @test Cerberus.pop_node!(tree) == n4

    @test !isempty(tree)
    @test Cerberus.num_open_nodes(tree) == 1
    @test Cerberus.pop_node!(tree) == n5

    @test isempty(tree)
end
