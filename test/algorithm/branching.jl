@testset "upbranch and downbranch" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    let db = @inferred Cerberus.down_branch(node, _VI(1), 0.5)
        @test db.branchings ==
              [Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH)]
    end

    let ub = @inferred Cerberus.up_branch(node, _VI(2), 0.5)
        @test ub.branchings ==
              [Cerberus.BranchingDecision(_VI(2), 1, Cerberus.UP_BRANCH)]
    end

    # Now do general integer branchings
    let db = @inferred Cerberus.down_branch(node, _VI(1), 3.7)
        @test db.branchings ==
              [Cerberus.BranchingDecision(_VI(1), 3, Cerberus.DOWN_BRANCH)]
    end

    let ub = @inferred Cerberus.up_branch(node, _VI(2), 3.7)
        @test ub.branchings ==
              [Cerberus.BranchingDecision(_VI(2), 4, Cerberus.UP_BRANCH)]
    end
end

@testset "MostInfeasible" begin
    let fm = _build_dmip_formulation()
        node = Cerberus.Node()
        x = [0.6, 0.7, 0.1]
        cost = 1.2
        result = Cerberus.NodeResult(
            cost,
            _vec_to_dict(x),
            12,
            13,
            14,
            Cerberus.IncrementalData(Cerberus.HOT_START),
        )
        n1, n2 = @inferred Cerberus.branch(
            fm,
            Cerberus.MostInfeasible(),
            node,
            result,
            CONFIG,
        )
        @test n1.branchings ==
              [Cerberus.BranchingDecision(_VI(1), 1, Cerberus.UP_BRANCH)]
        @test n1.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)

        @test n2.branchings ==
              [Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH)]
        @test n2.parent_info == Cerberus.ParentInfo(-Inf, nothing, nothing)

        x2 = Dict(_VI(1) => 1.0, _VI(2) => 0.7, _VI(3) => 0.1)
        result.x = x2
        n3, n4 = @inferred Cerberus.branch(
            fm,
            Cerberus.MostInfeasible(),
            n2,
            result,
            CONFIG,
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
            CONFIG,
        )
    end

    # General integer branching
    let fm = _build_gi_dmip_formulation()
        node = Cerberus.Node()
        x = [0.6, 0.4, 0.7]
        cost = 1.2
        result = Cerberus.NodeResult(
            cost,
            _vec_to_dict(x),
            12,
            13,
            14,
            Cerberus.IncrementalData(Cerberus.HOT_START),
        )
        fc, oc = @inferred Cerberus.branch(
            fm,
            Cerberus.MostInfeasible(),
            node,
            result,
            CONFIG,
        )
        @test fc.branchings ==
              [Cerberus.BranchingDecision(_VI(2), 0, Cerberus.DOWN_BRANCH)]
        @test oc.branchings ==
              [Cerberus.BranchingDecision(_VI(2), 1, Cerberus.UP_BRANCH)]

        x2 = [0.6, 0.4, 2.55]
        result.x = _vec_to_dict(x2)
        fc_2, oc_2 = @inferred Cerberus.branch(
            fm,
            Cerberus.MostInfeasible(),
            oc,
            result,
            CONFIG,
        )
        @test fc_2.branchings == [
            Cerberus.BranchingDecision(_VI(2), 1, Cerberus.UP_BRANCH),
            Cerberus.BranchingDecision(_VI(3), 3, Cerberus.UP_BRANCH),
        ]
        @test oc_2.branchings == [
            Cerberus.BranchingDecision(_VI(2), 1, Cerberus.UP_BRANCH),
            Cerberus.BranchingDecision(_VI(3), 2, Cerberus.DOWN_BRANCH),
        ]
    end
end
