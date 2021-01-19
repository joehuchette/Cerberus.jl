@testset "upbranch and downbranch" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    let db = @inferred Cerberus.down_branch(node, _VI(1), 0.5)
        @test db.lb_diff == Cerberus.BoundDiff()
        @test db.ub_diff == Cerberus.BoundDiff(_VI(1) => 0)
        @test db.depth == 1
    end

    let ub = @inferred Cerberus.up_branch(node, _VI(2), 0.5)
        @test ub.lb_diff == Cerberus.BoundDiff(_VI(2) => 1)
        @test ub.ub_diff == Cerberus.BoundDiff()
        @test ub.depth == 1
    end

    # Now do general integer branchings
    let db = @inferred Cerberus.down_branch(node, _VI(1), 3.7)
        @test db.lb_diff == Cerberus.BoundDiff()
        @test db.ub_diff == Cerberus.BoundDiff(_VI(1) => 3)
        @test db.depth == 1
    end

    let ub = @inferred Cerberus.up_branch(node, _VI(2), 3.7)
        @test ub.lb_diff == Cerberus.BoundDiff(_VI(2) => 4)
        @test ub.ub_diff == Cerberus.BoundDiff()
        @test ub.depth == 1
    end
end

@testset "MostInfeasible" begin
    let fm = _build_dmip_formulation()
        node = Cerberus.Node()
        x = [0.6, 0.7, 0.1]
        cost = 1.2
        result = Cerberus.NodeResult(cost, x, 12, 13, 14)
        n1, n2 = @inferred Cerberus.branch(
            fm,
            Cerberus.MostInfeasible(),
            node,
            result,
            CONFIG,
        )
        @test n1.lb_diff == Cerberus.BoundDiff(_VI(1) => 1)
        @test n1.ub_diff == Cerberus.BoundDiff()
        @test n1.depth == 1
        @test n1.dual_bound == -Inf

        @test n2.lb_diff == Cerberus.BoundDiff()
        @test n2.ub_diff == Cerberus.BoundDiff(_VI(1) => 0)
        @test n2.depth == 1
        @test n2.dual_bound == -Inf

        x2 = [1.0, 0.7, 0.1]
        result.x = x2
        n3, n4 = @inferred Cerberus.branch(
            fm,
            Cerberus.MostInfeasible(),
            n2,
            result,
            CONFIG,
        )
        @test n3.lb_diff == Cerberus.BoundDiff()
        @test n3.ub_diff == Cerberus.BoundDiff(_VI(1) => 0, _VI(3) => 0)
        @test n3.depth == 2
        @test n3.dual_bound == -Inf

        @test n4.lb_diff == Cerberus.BoundDiff(_VI(3) => 1)
        @test n4.ub_diff == Cerberus.BoundDiff(_VI(1) => 0)
        @test n4.depth == 2
        @test n4.dual_bound == -Inf

        # Nothing to branch on, should throw. Really, should have pruned by integrality before.
        x3 = [1.0, 0.7, 0.0]
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
        result = Cerberus.NodeResult(cost, x, 12, 13, 14)
        fc, oc = @inferred Cerberus.branch(
            fm,
            Cerberus.MostInfeasible(),
            node,
            result,
            CONFIG,
        )
        @test fc.lb_diff == Cerberus.BoundDiff()
        @test fc.ub_diff == Cerberus.BoundDiff(_VI(2) => 0)
        @test fc.depth == 1
        @test oc.lb_diff == Cerberus.BoundDiff(_VI(2) => 1)
        @test oc.ub_diff == Cerberus.BoundDiff()
        @test oc.depth == 1

        x2 = [0.6, 0.4, 2.55]
        result.x = x2
        fc_2, oc_2 = @inferred Cerberus.branch(
            fm,
            Cerberus.MostInfeasible(),
            oc,
            result,
            CONFIG,
        )
        @test fc_2.lb_diff == Cerberus.BoundDiff(_VI(2) => 1, _VI(3) => 3)
        @test fc_2.ub_diff == Cerberus.BoundDiff()
        @test fc_2.depth == 2
        @test oc_2.lb_diff == Cerberus.BoundDiff(_VI(2) => 1)
        @test oc_2.ub_diff == Cerberus.BoundDiff(_VI(3) => 2)
        @test oc_2.depth == 2
    end
end
