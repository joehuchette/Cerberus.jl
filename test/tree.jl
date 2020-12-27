@testset "Node" begin
    branchings = [
        Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH),
        Cerberus.BranchingDecision(_VI(2), 1, Cerberus.UP_BRANCH),
        Cerberus.BranchingDecision(_VI(3), 0, Cerberus.DOWN_BRANCH),
        Cerberus.BranchingDecision(_VI(5), 0, Cerberus.DOWN_BRANCH),
        Cerberus.BranchingDecision(_VI(6), 1, Cerberus.UP_BRANCH),
    ]
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
    n2 = @inferred Cerberus.Node(branchings)
    n3 = @inferred Cerberus.Node(branchings, parent_info)

    @test isempty(n1.branchings)
    @test n2.branchings == branchings
    @test n3.branchings == branchings

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
    n2 = Cerberus.Node([Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH)])
    n3 = Cerberus.Node([Cerberus.BranchingDecision(_VI(1), 1, Cerberus.UP_BRANCH)])
    n4 = Cerberus.Node([
        Cerberus.BranchingDecision(_VI(1), 1, Cerberus.UP_BRANCH),
        Cerberus.BranchingDecision(_VI(2), 0, Cerberus.DOWN_BRANCH),
    ])
    n5 = Cerberus.Node([
        Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH),
        Cerberus.BranchingDecision(_VI(2), 1, Cerberus.UP_BRANCH),
    ])
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
