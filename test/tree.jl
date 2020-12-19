# @testset "Basis" begin
#     basis = Dict(
#         _VI(1) => MOI.BASIC,
#         _VI(2) => MOI.NONBASIC,
#         _VI(3) => MOI.BASIC,
#         _VI(4) => MOI.NONBASIC_AT_LOWER,
#         _VI(5) => MOI.BASIC,
#         _CI(1) => MOI.NONBASIC,
#         _CI(2) => MOI.BASIC,
#         _CI(3) => MOI.NONBASIC,
#         _CI(4) => MOI.BASIC,
#     )
#     basis = @inferred Cerberus.Basis(basis, c_basis)
#     @test basis.v_basis == v_basis
#     @test basis.c_basis == c_basis
# end

@testset "Node" begin
    br_zero = [_VI(1), _VI(3), _VI(5)]
    br_one = [_VI(2), _VI(6)]
    basis = Dict(
        _VI(1) => MOI.BASIC,
        _VI(2) => MOI.NONBASIC,
        _VI(3) => MOI.BASIC,
        _VI(4) => MOI.NONBASIC_AT_LOWER,
        _VI(5) => MOI.BASIC,
        _CI(1) => MOI.NONBASIC,
        _CI(2) => MOI.BASIC,
        _CI(3) => MOI.NONBASIC,
        _CI(4) => MOI.BASIC,
    )
    dual_bound = 3.2
    parent_info = Cerberus.ParentInfo(dual_bound, basis, nothing)

    n1 = @inferred Cerberus.Node()
    n2 = @inferred Cerberus.Node(br_zero, br_one)
    n3 = @inferred Cerberus.Node(br_zero, br_one, parent_info)

    @test isempty(n1.vars_branched_to_zero)
    @test n2.vars_branched_to_zero == br_zero
    @test n3.vars_branched_to_zero == br_zero

    @test isempty(n1.vars_branched_to_one)
    @test n2.vars_branched_to_one == br_one
    @test n3.vars_branched_to_one == br_one

    @test n1.parent_info.dual_bound == -Inf
    @test n2.parent_info.dual_bound == -Inf
    @test n3.parent_info.dual_bound == dual_bound

    @test n1.parent_info.basis === nothing
    @test n2.parent_info.basis === nothing
    @test n3.parent_info.basis == basis
end

@testset "Tree" begin
    # BFS, branching first on 1 and then on 2
    n1 = Cerberus.Node()
    n2 = Cerberus.Node([_VI(1)], _VI[])
    n3 = Cerberus.Node(_VI[], [_VI(1)])
    n4 = Cerberus.Node([_VI(2)], [_VI(1)])
    n5 = Cerberus.Node(_VI[], [_VI(1), _VI(2)])
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
