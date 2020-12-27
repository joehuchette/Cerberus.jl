@testset "upbranch and downbranch" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    let db = @inferred Cerberus.down_branch(node, _VI(1), 0.5)
        @test db.branchings == [Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH)]
    end

    let ub = @inferred Cerberus.up_branch(node, _VI(2), 0.5)
        @test ub.branchings == [Cerberus.BranchingDecision(_VI(2), 1, Cerberus.UP_BRANCH)]
    end
end

@testset "MostInfeasible" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    x = [0.6, 0.7, 0.1]
    cost = 1.2
    config = Cerberus.AlgorithmConfig()
    result = Cerberus.NodeResult(
        cost,
        12,
        _vec_to_dict(x),
        Cerberus.Basis(),
        nothing,
    )
    n1, n2 = @inferred Cerberus.branch(
        fm,
        Cerberus.MostInfeasible(),
        node,
        result,
        config,
    )
    @test n1.branchings == [Cerberus.BranchingDecision(_VI(1), 1, Cerberus.UP_BRANCH)]
    @test n1.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)

    @test n2.branchings == [Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH)]
    @test n2.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)

    x2 = Dict(_VI(1) => 1.0, _VI(2) => 0.7, _VI(3) => 0.1)
    result.x = x2
    n3, n4 = @inferred Cerberus.branch(
        fm,
        Cerberus.MostInfeasible(),
        n2,
        result,
        config,
    )
    @test n3.branchings == [
        Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH),
        Cerberus.BranchingDecision(_VI(3), 0, Cerberus.DOWN_BRANCH),
    ]
    @test n3.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)

    @test n4.branchings == [
        Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH),
        Cerberus.BranchingDecision(_VI(3), 1, Cerberus.UP_BRANCH),
    ]
    @test n4.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)

    # Nothing to branch on, should throw. Really, should have pruned by integrality before.
    x3 = Dict(_VI(1) => 1.0, _VI(2) => 0.7, _VI(3) => 0.0)
    result.x = x3
    @test_throws AssertionError Cerberus.branch(
        fm,
        Cerberus.MostInfeasible(),
        n4,
        result,
        config,
    )
end
