@testset "Node" begin
    lb_diff = Cerberus.BoundDiff(_VI(2) => 1, _VI(3) => 0, _VI(6) => 1)
    ub_diff = Cerberus.BoundDiff(_VI(1) => 0, _VI(3) => 1, _VI(5) => 0)
    depth = 6
    basis = _Basis(
        Dict(
            _CI{_SV,_IN}(1) => MOI.BASIC,
            _CI{_SV,_IN}(2) => MOI.NONBASIC,
            _CI{_SV,_IN}(3) => MOI.BASIC,
            _CI{_SV,_IN}(4) => MOI.NONBASIC_AT_LOWER,
            _CI{_SV,_IN}(5) => MOI.BASIC,
            _CI{_SAF,_LT}(1) => MOI.NONBASIC,
            _CI{_SAF,_GT}(2) => MOI.BASIC,
            _CI{_SAF,_GT}(3) => MOI.NONBASIC,
            _CI{_SAF,_GT}(4) => MOI.BASIC,
        ),
    )
    dual_bound = 3.2
    parent_info = Cerberus.ParentInfo(dual_bound, basis, nothing)

    n1 = @inferred Cerberus.Node()
    n2 = @inferred Cerberus.Node(lb_diff, ub_diff, depth)
    n3 = @inferred Cerberus.Node(lb_diff, ub_diff, depth, parent_info)
    @test_throws ArgumentError Cerberus.Node(
        lb_diff,
        ub_diff,
        depth - 1,
        parent_info,
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

    @test n1.parent_info.dual_bound == -Inf
    @test n2.parent_info.dual_bound == -Inf
    @test n3.parent_info.dual_bound == dual_bound

    @test n1.parent_info.basis === nothing
    @test n2.parent_info.basis === nothing
    @test n3.parent_info.basis == basis

    @testset "copy_without_pi" begin
        _n1 = Cerberus.copy_without_pi(n1)
        _n2 = Cerberus.copy_without_pi(n2)
        _n3 = Cerberus.copy_without_pi(n3)

        @test _n1.depth == 0
        @test _n2.depth == depth
        @test _n3.depth == depth

        @test isempty(_n1.lb_diff)
        @test _n2.lb_diff == lb_diff
        @test _n3.lb_diff == lb_diff

        @test isempty(_n1.ub_diff)
        @test _n2.ub_diff == ub_diff
        @test _n3.ub_diff == ub_diff

        @test _n1.parent_info.dual_bound == -Inf
        @test _n2.parent_info.dual_bound == -Inf
        @test _n3.parent_info.dual_bound == -Inf

        @test _n1.parent_info.basis === nothing
        @test _n2.parent_info.basis === nothing
        @test _n3.parent_info.basis === nothing
    end
    @testset "apply_branching!" begin
        let bd = Cerberus.BranchingDecision(_VI(4), 7, Cerberus.DOWN_BRANCH)
            Cerberus.apply_branching!(n1, bd)
            Cerberus.apply_branching!(n2, bd)
            Cerberus.apply_branching!(n3, bd)

            @test n1.depth == 1
            @test n2.depth == depth + 1
            @test n3.depth == depth + 1

            new_ub_diff = copy(ub_diff)
            new_ub_diff[_VI(4)] = 7

            @test isempty(n1.lb_diff)
            @test n2.lb_diff == lb_diff
            @test n3.lb_diff == lb_diff

            @test n1.ub_diff == Dict(_VI(4) => 7)
            @test n2.ub_diff == new_ub_diff
            @test n3.ub_diff == new_ub_diff
        end

        # Now apply a dominated branch
        let bd = Cerberus.BranchingDecision(_VI(1), 0, Cerberus.UP_BRANCH)
            Cerberus.apply_branching!(n1, bd)
            Cerberus.apply_branching!(n2, bd)
            Cerberus.apply_branching!(n3, bd)

            @test n1.depth == 2
            @test n2.depth == depth + 2
            @test n3.depth == depth + 2

            @test n1.lb_diff == Dict(_VI(1) => 0)
            @test n2.lb_diff == lb_diff
            @test n3.lb_diff == lb_diff

            @test n1.ub_diff == Dict(_VI(4) => 7)
            @test n2.ub_diff == ub_diff
            @test n3.ub_diff == ub_diff
        end
    end
end

@testset "Tree" begin
    # BFS, branching first on 1 and then on 2
    n1 = Cerberus.Node()
    n2 = Cerberus.Node(Cerberus.BoundDiff(), Cerberus.BoundDiff(_VI(1) => 0), 1)
    n3 = Cerberus.Node(Cerberus.BoundDiff(_VI(1) => 1), Cerberus.BoundDiff(), 1)
    n4 = Cerberus.Node(
        Cerberus.BoundDiff(_VI(1) => 1),
        Cerberus.BoundDiff(_VI(2) => 0),
        2,
    )
    n5 = Cerberus.Node(
        Cerberus.BoundDiff(_VI(2) => 1),
        Cerberus.BoundDiff(_VI(1) => 0),
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
