@testset "Node" begin
    lb_diff = Cerberus.BoundDiff(_CVI(2) => 1, _CVI(3) => 0, _CVI(6) => 1)
    ub_diff = Cerberus.BoundDiff(_CVI(1) => 0, _CVI(3) => 1, _CVI(5) => 0)
    lt_constrs =
        [Cerberus.AffineConstraint{_LT}(_CSAF([2.3], [_CVI(5)], 1.9), _LT(4.5))]
    gt_constrs = [
        Cerberus.AffineConstraint{_GT}(
            _CSAF([2.3, 4.5], [_CVI(5), _CVI(3)], 6.7),
            _GT(6.7),
        ),
    ]
    depth = 6
    dual_bound = 3.2

    n1 = @inferred Cerberus.Node()
    n2 =
        @inferred Cerberus.Node(lb_diff, ub_diff, lt_constrs, gt_constrs, depth)
    n3 = @inferred Cerberus.Node(
        lb_diff,
        ub_diff,
        lt_constrs,
        gt_constrs,
        depth,
        dual_bound,
    )
    @test_throws ArgumentError Cerberus.Node(
        lb_diff,
        ub_diff,
        lt_constrs,
        gt_constrs,
        depth - 1,
        dual_bound,
    )

    @test n1.depth == 0
    @test n2.depth == depth
    @test n3.depth == depth

    @test isempty(n1.lb_diff)
    @test n2.lb_diff == lb_diff
    @test n3.lb_diff == lb_diff

    @test isempty(n1.ub_diff)
    @test n2.ub_diff == ub_diff
    @test n3.ub_diff == ub_diff

    @test isempty(n1.lt_constrs)
    @test n2.lt_constrs == lt_constrs
    @test n3.lt_constrs == lt_constrs

    @test isempty(n1.gt_constrs)
    @test n2.gt_constrs == gt_constrs
    @test n3.gt_constrs == gt_constrs

    @test n1.dual_bound == -Inf
    @test n2.dual_bound == -Inf
    @test n3.dual_bound == dual_bound

    @testset "copy" begin
        _n1 = copy(n1)
        _n2 = copy(n2)
        _n3 = copy(n3)

        @test _n1.depth == 0
        @test _n2.depth == depth
        @test _n3.depth == depth

        @test isempty(_n1.lb_diff)
        @test _n2.lb_diff == lb_diff
        @test _n3.lb_diff == lb_diff

        @test isempty(_n1.ub_diff)
        @test _n2.ub_diff == ub_diff
        @test _n3.ub_diff == ub_diff

        @test isempty(_n1.lt_constrs)
        @test _n2.lt_constrs == lt_constrs
        @test _n3.lt_constrs == lt_constrs

        @test isempty(_n1.gt_constrs)
        @test _n2.gt_constrs == gt_constrs
        @test _n3.gt_constrs == gt_constrs

        @test _n1.dual_bound == -Inf
        @test _n2.dual_bound == -Inf
        @test _n3.dual_bound == dual_bound
    end
    @testset "apply_branching!" begin
        let bd = Cerberus.VariableBranchingDecision(_CVI(4), _LT(7.0))
            Cerberus.apply_branching!(n1, bd)
            Cerberus.apply_branching!(n2, bd)
            Cerberus.apply_branching!(n3, bd)

            @test n1.depth == 1
            @test n2.depth == depth + 1
            @test n3.depth == depth + 1

            new_ub_diff = copy(ub_diff)
            new_ub_diff[_CVI(4)] = 7

            @test isempty(n1.lb_diff)
            @test n2.lb_diff == lb_diff
            @test n3.lb_diff == lb_diff

            @test n1.ub_diff == Dict(_CVI(4) => 7)
            @test n2.ub_diff == new_ub_diff
            @test n3.ub_diff == new_ub_diff
        end

        # Now apply a dominated branch
        let bd = Cerberus.VariableBranchingDecision(_CVI(1), _GT(0.0))
            Cerberus.apply_branching!(n1, bd)
            Cerberus.apply_branching!(n2, bd)
            Cerberus.apply_branching!(n3, bd)

            @test n1.depth == 2
            @test n2.depth == depth + 2
            @test n3.depth == depth + 2

            @test n1.lb_diff == Dict(_CVI(1) => 0)
            @test n2.lb_diff == lb_diff
            @test n3.lb_diff == lb_diff

            @test n1.ub_diff == Dict(_CVI(4) => 7)
            @test n2.ub_diff == ub_diff
            @test n3.ub_diff == ub_diff
        end
    end
end

@testset "Tree" begin
    # BFS, branching first on 1 and then on 2
    n1 = Cerberus.Node()
    n2 = Cerberus.Node(
        Cerberus.BoundDiff(),
        Cerberus.BoundDiff(_CVI(1) => 0),
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        1,
    )
    n3 = Cerberus.Node(
        Cerberus.BoundDiff(_CVI(1) => 1),
        Cerberus.BoundDiff(),
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        1,
    )
    n4 = Cerberus.Node(
        Cerberus.BoundDiff(_CVI(1) => 1),
        Cerberus.BoundDiff(_CVI(2) => 0),
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        2,
    )
    n5 = Cerberus.Node(
        Cerberus.BoundDiff(_CVI(2) => 1),
        Cerberus.BoundDiff(_CVI(1) => 0),
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        2,
    )

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
