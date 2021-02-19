@testset "upbranch and downbranch" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    let db = @inferred Cerberus.down_branch(node, _CVI(1), 0.5)
        @test db.lt_bounds == [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))]
        @test isempty(db.gt_bounds)
        @test db.depth == 1
    end

    let ub = @inferred Cerberus.up_branch(node, _CVI(2), 0.5)
        @test isempty(ub.lt_bounds)
        @test ub.gt_bounds == [Cerberus.BoundUpdate(_CVI(2), _GT(1.0))]
        @test ub.depth == 1
    end

    # Now do general integer branchings
    let db = @inferred Cerberus.down_branch(node, _CVI(1), 3.7)
        @test db.lt_bounds == [Cerberus.BoundUpdate(_CVI(1), _LT(3.0))]
        @test isempty(db.gt_bounds)
        @test db.depth == 1
    end

    let ub = @inferred Cerberus.up_branch(node, _CVI(2), 3.7)
        @test isempty(ub.lt_bounds)
        @test ub.gt_bounds == [Cerberus.BoundUpdate(_CVI(2), _GT(4.0))]
        @test ub.depth == 1
    end
end

@testset "apply_branching!" begin
    fm = _build_dmip_formulation()
    node = Cerberus.Node()
    let f = _CVI(2), s = _LT(1.0)
        bd = Cerberus.BoundUpdate(f, s)
        @inferred Cerberus.apply_branching!(node, bd)
        @test node.lt_bounds == [Cerberus.BoundUpdate(_CVI(2), _LT(1.0))]
        @test isempty(node.gt_bounds)
        @test isempty(node.lt_general_constrs)
        @test isempty(node.gt_general_constrs)
        @test node.depth == 1
        @test node.dual_bound == -Inf
    end
    let f = _CVI(4), s = _GT(3.0)
        bd = Cerberus.BoundUpdate(f, s)
        @inferred Cerberus.apply_branching!(node, bd)
        @test node.lt_bounds == [Cerberus.BoundUpdate(_CVI(2), _LT(1.0))]
        @test node.gt_bounds == [Cerberus.BoundUpdate(_CVI(4), _GT(3.0))]
        @test isempty(node.lt_general_constrs)
        @test isempty(node.gt_general_constrs)
        @test node.depth == 2
        @test node.dual_bound == -Inf
    end
    let f = _CSAF([1.2, 3.4], [_CVI(1), _CVI(3)], 5.6), s = _LT(7.8)
        bd = Cerberus.AffineConstraint(f, s)
        @inferred Cerberus.apply_branching!(node, bd)
        @test node.lt_bounds == [Cerberus.BoundUpdate(_CVI(2), _LT(1.0))]
        @test node.gt_bounds == [Cerberus.BoundUpdate(_CVI(4), _GT(3.0))]
        @test length(node.lt_general_constrs) == 1
        lt_constr = node.lt_general_constrs[1]
        @test _is_equal(lt_constr.f, _CSAF([1.2, 3.4], [_CVI(1), _CVI(3)], 0.0))
        @test lt_constr.s == _LT(7.8 - 5.6)
        @test isempty(node.gt_general_constrs)
        @test node.depth == 3
        @test node.dual_bound == -Inf
    end
    let f = _CSAF([2.4, 4.6], [_CVI(2), _CVI(1)], 6.8), s = _GT(8.0)
        bd = Cerberus.AffineConstraint(f, s)
        @inferred Cerberus.apply_branching!(node, bd)
        @test node.lt_bounds == [Cerberus.BoundUpdate(_CVI(2), _LT(1.0))]
        @test node.gt_bounds == [Cerberus.BoundUpdate(_CVI(4), _GT(3.0))]
        @test length(node.lt_general_constrs) == 1
        @test _is_equal(
            node.lt_general_constrs[1].f,
            _CSAF([1.2, 3.4], [_CVI(1), _CVI(3)], 0.0),
        )
        @test node.lt_general_constrs[1].s == _LT(7.8 - 5.6)
        @test length(node.gt_general_constrs) == 1
        gt_constr = node.gt_general_constrs[1]
        @test _is_equal(gt_constr.f, _CSAF([2.4, 4.6], [_CVI(2), _CVI(1)], 0.0))
        @test gt_constr.s == _GT(8.0 - 6.8)
        @test node.depth == 4
        @test node.dual_bound == -Inf
    end
end

@testset "MostInfeasible" begin
    mi_config = Cerberus.AlgorithmConfig(
        branching_rule = Cerberus.MostInfeasible(),
        silent = true,
    )
    let fm = _build_dmip_formulation()
        state = Cerberus.CurrentState()
        node = Cerberus.Node()
        x = [0.6, 0.7, 0.1]
        cost = 1.2
        result = Cerberus.NodeResult(cost, x, 12, 13, 14)
        n1, n2 = @inferred Cerberus.branch(state, fm, node, result, mi_config)
        @test isempty(n1.lt_bounds)
        @test n1.gt_bounds == [Cerberus.BoundUpdate(_CVI(1), _GT(1.0))]
        @test n1.depth == 1
        @test n1.dual_bound == -Inf

        @test n2.lt_bounds == [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))]
        @test isempty(n2.gt_bounds)
        @test n2.depth == 1
        @test n2.dual_bound == -Inf

        x2 = [1.0, 0.7, 0.1]
        result.x = x2
        n3, n4 = @inferred Cerberus.branch(state, fm, n2, result, mi_config)
        @test n3.lt_bounds == [
            Cerberus.BoundUpdate(_CVI(1), _LT(0.0)),
            Cerberus.BoundUpdate(_CVI(3), _LT(0.0)),
        ]
        @test isempty(n3.gt_bounds)
        @test n3.depth == 2
        @test n3.dual_bound == -Inf

        @test n4.lt_bounds == [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))]
        @test n4.gt_bounds == [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))]
        @test n4.depth == 2
        @test n4.dual_bound == -Inf

        # Nothing to branch on, should throw. Really, should have pruned by integrality before.
        x3 = [1.0, 0.7, 0.0]
        result.x = x3
        @test_throws ErrorException Cerberus.branch(
            state,
            fm,
            n4,
            result,
            mi_config,
        )
    end

    # General integer branching
    let fm = _build_gi_dmip_formulation()
        state = Cerberus.CurrentState()
        node = Cerberus.Node()
        x = [0.6, 0.4, 0.7]
        cost = 1.2
        result = Cerberus.NodeResult(cost, x, 12, 13, 14)
        fc, oc = @inferred Cerberus.branch(state, fm, node, result, mi_config)
        @test fc.lt_bounds == [Cerberus.BoundUpdate(_CVI(2), _LT(0.0))]
        @test isempty(fc.gt_bounds)
        @test fc.depth == 1
        @test isempty(oc.lt_bounds)
        @test oc.gt_bounds == [Cerberus.BoundUpdate(_CVI(2), _GT(1.0))]
        @test oc.depth == 1

        x2 = [0.6, 0.4, 2.55]
        result.x = x2
        fc_2, oc_2 = @inferred Cerberus.branch(state, fm, oc, result, mi_config)
        @test isempty(fc_2.lt_bounds)
        @test fc_2.gt_bounds == [
            Cerberus.BoundUpdate(_CVI(2), _GT(1.0)),
            Cerberus.BoundUpdate(_CVI(3), _GT(3.0)),
        ]
        @test fc_2.depth == 2
        @test oc_2.lt_bounds == [Cerberus.BoundUpdate(_CVI(3), _LT(2.0))]
        @test oc_2.gt_bounds == [Cerberus.BoundUpdate(_CVI(2), _GT(1.0))]
        @test oc_2.depth == 2
    end
end
