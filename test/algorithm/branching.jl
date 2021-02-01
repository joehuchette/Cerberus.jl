@testset "upbranch and downbranch" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    let db = @inferred Cerberus.down_branch(node, _CVI(1), 0.5)
        @test db.lb_diff == Cerberus.BoundDiff()
        @test db.ub_diff == Cerberus.BoundDiff(_CVI(1) => 0)
        @test db.depth == 1
    end

    let ub = @inferred Cerberus.up_branch(node, _CVI(2), 0.5)
        @test ub.lb_diff == Cerberus.BoundDiff(_CVI(2) => 1)
        @test ub.ub_diff == Cerberus.BoundDiff()
        @test ub.depth == 1
    end

    # Now do general integer branchings
    let db = @inferred Cerberus.down_branch(node, _CVI(1), 3.7)
        @test db.lb_diff == Cerberus.BoundDiff()
        @test db.ub_diff == Cerberus.BoundDiff(_CVI(1) => 3)
        @test db.depth == 1
    end

    let ub = @inferred Cerberus.up_branch(node, _CVI(2), 3.7)
        @test ub.lb_diff == Cerberus.BoundDiff(_CVI(2) => 4)
        @test ub.ub_diff == Cerberus.BoundDiff()
        @test ub.depth == 1
    end
end

@testset "apply_branching!" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    let f = _CVI(2), s = _LT(1.0)
        bd = Cerberus.VariableBranchingDecision(f, s)
        @inferred Cerberus.apply_branching!(node, bd)
        @test isempty(node.lb_diff)
        @test node.ub_diff == Cerberus.BoundDiff(_CVI(2) => 1)
        @test isempty(node.lt_constrs)
        @test isempty(node.gt_constrs)
        @test node.depth == 1
        @test node.dual_bound == -Inf
    end
    let f = _CVI(4), s = _GT(3.0)
        bd = Cerberus.VariableBranchingDecision(f, s)
        @inferred Cerberus.apply_branching!(node, bd)
        @test node.lb_diff == Cerberus.BoundDiff(_CVI(4) => 3)
        @test node.ub_diff == Cerberus.BoundDiff(_CVI(2) => 1)
        @test isempty(node.lt_constrs)
        @test isempty(node.gt_constrs)
        @test node.depth == 2
        @test node.dual_bound == -Inf
    end
    let f = _CSAF([1.2, 3.4], [_CVI(1), _CVI(3)], 5.6), s = _LT(7.8)
        bd = Cerberus.GeneralBranchingDecision(Cerberus.AffineConstraint(f, s))
        @inferred Cerberus.apply_branching!(node, bd)
        @test node.lb_diff == Cerberus.BoundDiff(_CVI(4) => 3)
        @test node.ub_diff == Cerberus.BoundDiff(_CVI(2) => 1)
        @test length(node.lt_constrs) == 1
        lt_constr = node.lt_constrs[1]
        _test_equal(lt_constr.f, _CSAF([1.2, 3.4], [_CVI(1), _CVI(3)], 0.0))
        @test lt_constr.s == _LT(7.8 - 5.6)
        @test isempty(node.gt_constrs)
        @test node.depth == 3
        @test node.dual_bound == -Inf
    end
    let f = _CSAF([2.4, 4.6], [_CVI(2), _CVI(1)], 6.8), s = _GT(8.0)
        bd = Cerberus.GeneralBranchingDecision(Cerberus.AffineConstraint(f, s))
        @inferred Cerberus.apply_branching!(node, bd)
        @test node.lb_diff == Cerberus.BoundDiff(_CVI(4) => 3)
        @test node.ub_diff == Cerberus.BoundDiff(_CVI(2) => 1)
        @test length(node.lt_constrs) == 1
        _test_equal(
            node.lt_constrs[1].f,
            _CSAF([1.2, 3.4], [_CVI(1), _CVI(3)], 0.0),
        )
        @test node.lt_constrs[1].s == _LT(7.8 - 5.6)
        @test length(node.gt_constrs) == 1
        gt_constr = node.gt_constrs[1]
        _test_equal(gt_constr.f, _CSAF([2.4, 4.6], [_CVI(2), _CVI(1)], 0.0))
        @test gt_constr.s == _GT(8.0 - 6.8)
        @test node.depth == 4
        @test node.dual_bound == -Inf
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
        @test n1.lb_diff == Cerberus.BoundDiff(_CVI(1) => 1)
        @test n1.ub_diff == Cerberus.BoundDiff()
        @test n1.depth == 1
        @test n1.dual_bound == -Inf

        @test n2.lb_diff == Cerberus.BoundDiff()
        @test n2.ub_diff == Cerberus.BoundDiff(_CVI(1) => 0)
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
        @test n3.ub_diff == Cerberus.BoundDiff(_CVI(1) => 0, _CVI(3) => 0)
        @test n3.depth == 2
        @test n3.dual_bound == -Inf

        @test n4.lb_diff == Cerberus.BoundDiff(_CVI(3) => 1)
        @test n4.ub_diff == Cerberus.BoundDiff(_CVI(1) => 0)
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
        @test fc.ub_diff == Cerberus.BoundDiff(_CVI(2) => 0)
        @test fc.depth == 1
        @test oc.lb_diff == Cerberus.BoundDiff(_CVI(2) => 1)
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
        @test fc_2.lb_diff == Cerberus.BoundDiff(_CVI(2) => 1, _CVI(3) => 3)
        @test fc_2.ub_diff == Cerberus.BoundDiff()
        @test fc_2.depth == 2
        @test oc_2.lb_diff == Cerberus.BoundDiff(_CVI(2) => 1)
        @test oc_2.ub_diff == Cerberus.BoundDiff(_CVI(3) => 2)
        @test oc_2.depth == 2
    end
end
