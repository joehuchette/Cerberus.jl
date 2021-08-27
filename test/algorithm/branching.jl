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

struct DummyVariableBranchingRule <: Cerberus.AbstractVariableBranchingRule end

@testset "variable branching helpers" begin
    form = _build_dmip_formulation()
    config =
        Cerberus.AlgorithmConfig(branching_rule = DummyVariableBranchingRule())
    @testset "branching_candidates" begin
        let nr = Cerberus.NodeResult(
                Cerberus.OPTIMAL_LP,
                12.3,
                [0.6, 0.7, 0.1],
                12,
                13,
                14,
            )
            bc = @inferred Cerberus.branching_candidates(form, nr, config)
            @test bc == [
                Cerberus.VariableBranchingCandidate(_CVI(1), 0.6),
                Cerberus.VariableBranchingCandidate(_CVI(3), 0.1),
            ]
        end
        let nr = Cerberus.NodeResult(
                Cerberus.OPTIMAL_LP,
                12.3,
                [0.8, 0.7, 0.0],
                12,
                13,
                14,
            )
            bc = @inferred Cerberus.branching_candidates(form, nr, config)
            @test bc == [Cerberus.VariableBranchingCandidate(_CVI(1), 0.8)]
        end
        let nr = Cerberus.NodeResult(
                Cerberus.OPTIMAL_LP,
                12.3,
                [1.0, 0.7, 0.0],
                12,
                13,
                14,
            )
            bc = @inferred Cerberus.branching_candidates(form, nr, config)
            @test isempty(bc)
        end
    end

    @testset "branch_on" begin
        candidate = @inferred Cerberus.VariableBranchingCandidate(_CVI(1), 0.6)
        let node = Cerberus.Node()
            let score = @inferred Cerberus.VariableBranchingScore(0.7, 0.8, 0.9)
                nodes = @inferred Cerberus.branch_on(node, candidate, score)
                @test length(nodes) == 2
                let node = nodes[1]
                    @test node.lt_bounds ==
                          [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))]
                    @test isempty(node.gt_bounds)
                    @test isempty(node.lt_general_constrs)
                    @test isempty(node.gt_general_constrs)
                    @test node.depth == 1
                end
                let node = nodes[2]
                    @test isempty(node.lt_bounds)
                    @test node.gt_bounds ==
                          [Cerberus.BoundUpdate(_CVI(1), _GT(1.0))]
                    @test isempty(node.lt_general_constrs)
                    @test isempty(node.gt_general_constrs)
                    @test node.depth == 1
                end
            end
            let score = @inferred Cerberus.VariableBranchingScore(0.8, 0.7, 0.9)
                nodes = @inferred Cerberus.branch_on(node, candidate, score)
                @test length(nodes) == 2

                let node = nodes[1]
                    @test isempty(node.lt_bounds)
                    @test node.gt_bounds ==
                          [Cerberus.BoundUpdate(_CVI(1), _GT(1.0))]
                    @test isempty(node.lt_general_constrs)
                    @test isempty(node.gt_general_constrs)
                    @test node.depth == 1
                end
                let node = nodes[2]
                    @test node.lt_bounds ==
                          [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))]
                    @test isempty(node.gt_bounds)
                    @test isempty(node.lt_general_constrs)
                    @test isempty(node.gt_general_constrs)
                    @test node.depth == 1
                end
            end
        end
        let node = Cerberus.Node(
                Cerberus.BoundUpdate{_LT}[],
                [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))],
                1,
            )
            let score = @inferred Cerberus.VariableBranchingScore(0.7, 0.8, 0.9)
                nodes = @inferred Cerberus.branch_on(node, candidate, score)
                @test length(nodes) == 2
                let node = nodes[1]
                    @test node.lt_bounds ==
                          [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))]
                    @test node.gt_bounds ==
                          [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))]
                    @test isempty(node.lt_general_constrs)
                    @test isempty(node.gt_general_constrs)
                    @test node.depth == 2
                end
                let node = nodes[2]
                    @test isempty(node.lt_bounds)
                    @test node.gt_bounds == [
                        Cerberus.BoundUpdate(_CVI(3), _GT(1.0)),
                        Cerberus.BoundUpdate(_CVI(1), _GT(1.0)),
                    ]
                    @test isempty(node.lt_general_constrs)
                    @test isempty(node.gt_general_constrs)
                    @test node.depth == 2
                end
            end
            let score = @inferred Cerberus.VariableBranchingScore(0.8, 0.7, 0.9)
                nodes = @inferred Cerberus.branch_on(node, candidate, score)
                @test length(nodes) == 2
                let node = nodes[1]
                    @test isempty(node.lt_bounds)
                    @test node.gt_bounds == [
                        Cerberus.BoundUpdate(_CVI(3), _GT(1.0)),
                        Cerberus.BoundUpdate(_CVI(1), _GT(1.0)),
                    ]
                    @test isempty(node.lt_general_constrs)
                    @test isempty(node.gt_general_constrs)
                    @test node.depth == 2
                end
                let node = nodes[2]
                    @test node.lt_bounds ==
                          [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))]
                    @test node.gt_bounds ==
                          [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))]
                    @test isempty(node.lt_general_constrs)
                    @test isempty(node.gt_general_constrs)
                    @test node.depth == 2
                end
            end
        end
    end
end

@testset "MostInfeasible" begin
    mi_config = Cerberus.AlgorithmConfig(
        branching_rule = Cerberus.MostInfeasible(),
        silent = true,
    )
    @testset "branching_score" begin
        state = Cerberus.CurrentState()
        let x = [0.6, 0.5, 0.35]
            node = Cerberus.Node()
            nr = Cerberus.NodeResult(Cerberus.OPTIMAL_LP, 12.3, x, 12, 13, 14)
            let bc = Cerberus.VariableBranchingCandidate(_CVI(1), 0.6)
                vbs =
                    @inferred Cerberus.branching_score(state, bc, node, nr, mi_config)
                @test vbs == Cerberus.VariableBranchingScore(0.6, 0.4, 0.4)
            end
            let bc = Cerberus.VariableBranchingCandidate(_CVI(3), 0.35)
                vbs =
                    @inferred Cerberus.branching_score(state, bc, node, nr, mi_config)
                @test vbs == Cerberus.VariableBranchingScore(0.35, 0.65, 0.35)
            end
        end
    end

    @testset "end to end" begin
        let fm = _build_dmip_formulation()
            state = Cerberus.CurrentState()
            node = Cerberus.Node()
            x = [0.6, 0.7, 0.1]
            cost = 1.2
            result =
                Cerberus.NodeResult(Cerberus.OPTIMAL_LP, cost, x, 12, 13, 14)
            n1, n2 =
                @inferred Cerberus.branch(state, fm, node, result, mi_config)
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
            result =
                Cerberus.NodeResult(Cerberus.OPTIMAL_LP, cost, x, 12, 13, 14)
            fc, oc =
                @inferred Cerberus.branch(state, fm, node, result, mi_config)
            @test fc.lt_bounds == [Cerberus.BoundUpdate(_CVI(2), _LT(0.0))]
            @test isempty(fc.gt_bounds)
            @test fc.depth == 1
            @test isempty(oc.lt_bounds)
            @test oc.gt_bounds == [Cerberus.BoundUpdate(_CVI(2), _GT(1.0))]
            @test oc.depth == 1

            x2 = [0.6, 0.4, 2.55]
            result.x = x2
            fc_2, oc_2 =
                @inferred Cerberus.branch(state, fm, oc, result, mi_config)
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
end

@testset "StrongBranching" begin
    @testset "branching_score" begin
        let sb_config = Cerberus.AlgorithmConfig(
                branching_rule = Cerberus.StrongBranching(),
                silent = true,
            )
            v = [_SV(_VI(i)) for i in 1:3]
            ac1 = Cerberus.AffineConstraint(
                4.0 * v[1] + 2.0 * v[2] + 2.0 * v[3],
                _GT(5.0),
            )
            ac2 = Cerberus.AffineConstraint(
                4.0 * v[1] + 2.0 * v[2] + 5.0 * v[3],
                _LT(5.0),
            )
            aff_constrs = [ac1, ac2]
            bounds = [_IN(0.0, Inf) for i in 1:3]
            p = Cerberus.Polyhedron(aff_constrs, bounds)
            variable_kind = [_GI() for i in 1:3]
            obj = _CSAF([-1.0, 1.0, 0.0], [_CVI(1), _CVI(2), _CVI(3)], 0.0)
            form = Cerberus.DMIPFormulation(p, variable_kind, obj)

            state = Cerberus.CurrentState()
            node = Cerberus.pop_node!(state.tree)
            nr = Cerberus.process_node!(state, form, node, sb_config)

            bc = Cerberus.VariableBranchingCandidate(_CVI(1), nr.x[1])
            vbs = @inferred Cerberus.branching_score(state, bc, node, nr, sb_config)
            @test vbs == Cerberus.VariableBranchingScore(0.75, Inf, Inf)
        end

        let sb_config = Cerberus.AlgorithmConfig(
                branching_rule = Cerberus.StrongBranching(),
                silent = true,
            )
            v = [_SV(_VI(i)) for i in 1:3]
            ac1 = Cerberus.AffineConstraint(
                1.0 * v[1] + 1 / 9 * v[2] + 5 / 3 * v[3],
                _LT(2.0),
            )
            ac2 = Cerberus.AffineConstraint(
                1 / 9 * v[1] + 1.0 * v[2] + 5 / 3 * v[3],
                _LT(2.0),
            )
            ac3 = Cerberus.AffineConstraint(
                1.0 * v[1] + 1.0 * v[2] + 1.0 * v[3],
                _LT(2.0),
            )
            aff_constrs = [ac1, ac2]
            bounds = [_IN(0.0, Inf) for i in 1:3]
            p = Cerberus.Polyhedron(aff_constrs, bounds)
            variable_kind = [_ZO(), _ZO(), _GI()]
            obj = _CSAF([-1.0, -1.0, -1.5], [_CVI(1), _CVI(2), _CVI(3)], 0.0)
            form = Cerberus.DMIPFormulation(p, variable_kind, obj)

            state = Cerberus.CurrentState()
            node = Cerberus.pop_node!(state.tree)
            nr = Cerberus.process_node!(state, form, node, sb_config)

            bc = Cerberus.VariableBranchingCandidate(_CVI(3), nr.x[3])
            vbs = @inferred Cerberus.branching_score(state, bc, node, nr, sb_config)
            @test isapprox(vbs.down_branch_score, 0.8)
            @test isapprox(vbs.up_branch_score, 0.7)
            @test isapprox(vbs.aggregate_score, 43 / 60)
        end
    end

    @testset "end-to-end" begin
        let sb_config = Cerberus.AlgorithmConfig(
                branching_rule = Cerberus.StrongBranching(),
                silent = true,
            )
            v = [_SV(_VI(i)) for i in 1:3]
            ac1 = Cerberus.AffineConstraint(
                1.0 * v[1] + 1.0 * v[2] + 2.0 * v[3],
                _GT(4.5),
            )
            ac2 = Cerberus.AffineConstraint(
                1.0 * v[1] + 2.0 * v[2] + 1.0 * v[3],
                _GT(4.5),
            )
            ac3 = Cerberus.AffineConstraint(
                2.0 * v[1] + 1.0 * v[2] + 1.0 * v[3],
                _GT(4.5),
            )
            aff_constrs = [ac1, ac2, ac3]
            bounds = [_IN(0.0, 4.0) for i in 1:3]
            p = Cerberus.Polyhedron(aff_constrs, bounds)
            variable_kind = [_GI() for i in 1:3]
            obj = _CSAF([1.0, 2.0, 3.0], [_CVI(1), _CVI(2), _CVI(3)], 0.0)
            fm = Cerberus.DMIPFormulation(p, variable_kind, obj)

            state = Cerberus.CurrentState()
            node = Cerberus.pop_node!(state.tree)
            nr = Cerberus.process_node!(state, fm, node, sb_config)

            n1, n2 = @inferred Cerberus.branch(state, fm, node, nr, sb_config)

            @test isempty(n1.gt_bounds)
            @test n1.lt_bounds == [Cerberus.BoundUpdate(_CVI(2), _LT(0.0))]
            @test n1.depth == 1
            @test n1.dual_bound == -Inf

            @test n2.gt_bounds == [Cerberus.BoundUpdate(_CVI(2), _GT(1.0))]
            @test isempty(n2.lt_bounds)
            @test n2.depth == 1
            @test n2.dual_bound == -Inf

            nr1 = Cerberus.process_node!(state, fm, n1, sb_config)
            n3, n4 = @inferred Cerberus.branch(state, fm, n1, nr1, sb_config)
            @test n3.lt_bounds == [Cerberus.BoundUpdate(_CVI(2), _LT(0.0))]
            @test n3.gt_bounds == [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))]
            @test n3.depth == 2
            @test n3.dual_bound == -Inf

            @test n4.lt_bounds == [
                Cerberus.BoundUpdate(_CVI(2), _LT(0.0)),
                Cerberus.BoundUpdate(_CVI(3), _LT(0.0)),
            ]
            @test isempty(n4.gt_bounds)
            @test n4.depth == 2
            @test n4.dual_bound == -Inf
        end
    end
end

@testset "PseudocostBranching" begin
    @testset "node" begin
        let pb_config = Cerberus.AlgorithmConfig(
                branching_rule = Cerberus.PseudocostBranching(),
                silent = true,
            )
            v = [_SV(_VI(i)) for i in 1:2]
            ac = Cerberus.AffineConstraint(
                6/19 * v[1] + 4/19 * v[2],
                _LT(1.0)
            )
            aff_constrs = [ac]
            bounds = [_IN(0.0, Inf), _IN(0.0, 2.25)]
            p = Cerberus.Polyhedron(aff_constrs, bounds)
            variable_kind = [_GI(), _GI()]
            obj = _CSAF([-1.0, -1.0], [_CVI(1), _CVI(2)], 0.0)
            form = Cerberus.DMIPFormulation(p, variable_kind, obj)

            state = Cerberus.CurrentState()
            node = Cerberus.pop_node!(state.tree)
            nr = Cerberus.process_node!(state, form, node, pb_config)
            Cerberus.update_state!(state, form, node, nr, pb_config)

            n1 = Cerberus.pop_node!(state.tree)
            n2 = Cerberus.pop_node!(state.tree)
            @test n1.dual_bound == nr.cost
            @test n2.dual_bound == nr.cost
            @test n1.bound_update == Cerberus.BoundUpdate(_CVI(1), _LT(1.0))
            @test n2.bound_update == Cerberus.BoundUpdate(_CVI(1), _GT(2.0))
            @test isapprox(n1.fractional_value, 2/3)
            @test isapprox(n2.fractional_value, 1/3)
        end
    end

    @testset "end to end" begin
        let pb_config = Cerberus.AlgorithmConfig(
                branching_rule = Cerberus.PseudocostBranching(),
                silent = true,
            )
            v = [_SV(_VI(i)) for i in 1:2]
            ac = Cerberus.AffineConstraint(
                6/19 * v[1] + 4/19 * v[2],
                _LT(1.0)
            )
            aff_constrs = [ac]
            bounds = [_IN(0.0, Inf), _IN(0.0, 2.25)]
            p = Cerberus.Polyhedron(aff_constrs, bounds)
            variable_kind = [_GI(), _GI()]
            obj = _CSAF([-1.0, -1.0], [_CVI(1), _CVI(2)], 0.0)
            form = Cerberus.DMIPFormulation(p, variable_kind, obj)

            state = Cerberus.CurrentState()
            node = Cerberus.pop_node!(state.tree)
            nr = Cerberus.process_node!(state, form, node, pb_config)

            bc = Cerberus.VariableBranchingCandidate(_CVI(1), nr.x[1])
            vbs = @inferred Cerberus.branching_score(state, bc, node, nr, pb_config)
            @test isapprox(vbs.down_branch_score, 2/3)
            @test isapprox(vbs.up_branch_score, 1/3)
            @test isapprox(vbs.aggregate_score, 7/18)

            bc = Cerberus.VariableBranchingCandidate(_CVI(2), nr.x[2])
            vbs = @inferred Cerberus.branching_score(state, bc, node, nr, pb_config)
            @test isapprox(vbs.down_branch_score, 1/4)
            @test isapprox(vbs.up_branch_score, 3/4)
            @test isapprox(vbs.aggregate_score, 1/3)

            Cerberus.update_state!(state, form, node, nr, pb_config)
            node1 = Cerberus.pop_node!(state.tree)
            nr1 = Cerberus.process_node!(state, form, node1, pb_config)
            pseudocost = pb_config.branching_rule.downward_pseudocost_hist[_CVI(1)]
            @test pseudocost.η == 1
            @test pseudocost.σ == 1.0
            @test pseudocost.ψ == 1.0

            bc = Cerberus.VariableBranchingCandidate(_CVI(2), nr1.x[2])
            vbs = @inferred Cerberus.branching_score(state, bc, node, nr, pb_config)
            @test isapprox(vbs.down_branch_score, 1/4)
            @test isapprox(vbs.up_branch_score, 3/4)
            @test isapprox(vbs.aggregate_score, 1/3)

            Cerberus.update_state!(state, form, node1, nr1, pb_config)
            node2 = Cerberus.pop_node!(state.tree)
            nr2 = Cerberus.process_node!(state, form, node2, pb_config)
            @test nr2.status == Cerberus.INFEASIBLE_LP

            Cerberus.update_state!(state, form, node, nr2, pb_config)
            node3 = Cerberus.pop_node!(state.tree)
            nr3 = Cerberus.process_node!(state, form, node3, pb_config)
            @test nr3.int_infeas == 0
            pseudocost = pb_config.branching_rule.downward_pseudocost_hist[_CVI(2)]
            @test pseudocost.η == 1
            @test pseudocost.σ == 1.0
            @test pseudocost.ψ == 1.0

            Cerberus.update_state!(state, form, node, nr3, pb_config)
            node4 = Cerberus.pop_node!(state.tree)
            nr4 = Cerberus.process_node!(state, form, node4, pb_config)
            pseudocost = pb_config.branching_rule.upward_pseudocost_hist[_CVI(1)]
            @test pseudocost.η == 1
            @test isapprox(pseudocost.σ, 0.5)
            @test isapprox(pseudocost.ψ, 0.5)
            @test isapprox(pb_config.branching_rule.ψ⁺_average, 0.5)

            bc = Cerberus.VariableBranchingCandidate(_CVI(2), nr4.x[2])
            vbs = @inferred Cerberus.branching_score(state, bc, node, nr, pb_config)
            @test isapprox(vbs.down_branch_score, 3/4)
            @test isapprox(vbs.up_branch_score, 1/8)
            @test isapprox(vbs.aggregate_score, 11/48)
        end
    end
end

struct DummyBranchingRule <: Cerberus.AbstractBranchingRule end
struct DummyBranchingCandidate <: Cerberus.AbstractBranchingCandidate
    cvi::_CVI
end
struct DummyBranchingScore <: Cerberus.AbstractBranchingScore
    val::Any
end
function Cerberus.branching_candidates(
    ::Cerberus.DMIPFormulation,
    ::Cerberus.NodeResult,
    config::Cerberus.AlgorithmConfig{DummyBranchingRule},
)
    @assert config.branching_rule === DummyBranchingRule()
    return [DummyBranchingCandidate(_CVI(1)), DummyBranchingCandidate(_CVI(3))]
end
function Cerberus.branching_score(
    ::Cerberus.CurrentState,
    dbc::DummyBranchingCandidate,
    ::Cerberus.Node,
    ::Cerberus.NodeResult,
    config::Cerberus.AlgorithmConfig{DummyBranchingRule},
)
    @assert config.branching_rule === DummyBranchingRule()
    return DummyBranchingScore(Cerberus.index(dbc.cvi))
end
Cerberus.aggregate_score(::DummyBranchingScore) = 42.0
function Cerberus.branch_on(
    node::Cerberus.Node,
    ::DummyBranchingCandidate,
    ::DummyBranchingScore,
)
    return (
        Cerberus.Node(
            vcat(node.lt_bounds, Cerberus.BoundUpdate(_CVI(3), _LT(1.0))),
            vcat(node.gt_bounds, Cerberus.BoundUpdate(_CVI(3), _GT(1.0))),
            node.depth + 1,
        ),
        Cerberus.Node(
            vcat(node.lt_bounds, Cerberus.BoundUpdate(_CVI(3), _LT(2.0))),
            vcat(node.gt_bounds, Cerberus.BoundUpdate(_CVI(3), _GT(2.0))),
            node.depth + 1,
        ),
        Cerberus.Node(
            vcat(node.lt_bounds, Cerberus.BoundUpdate(_CVI(3), _LT(3.0))),
            vcat(node.gt_bounds, Cerberus.BoundUpdate(_CVI(3), _GT(3.0))),
            node.depth + 1,
        ),
    )
end

@testset "branch" begin
    form = _build_dmip_formulation()
    config = Cerberus.AlgorithmConfig(
        branching_rule = DummyBranchingRule(),
        silent = true,
    )
    state = Cerberus.CurrentState()
    node = Cerberus.Node(
        Cerberus.BoundUpdate{_LT}[],
        [Cerberus.BoundUpdate(_CVI(1), _GT(1.0))],
        1,
    )
    nr = Cerberus.NodeResult(
        Cerberus.OPTIMAL_LP,
        12.3,
        [0.6, 0.5, 1.0],
        12,
        13,
        14,
    )
    nodes = @inferred Cerberus.branch(state, form, node, nr, config)
    @test length(nodes) == 3
    for i in 1:3
        node = nodes[i]
        @test node.lt_bounds == [Cerberus.BoundUpdate(_CVI(3), _LT(i))]
        @test node.gt_bounds == [
            Cerberus.BoundUpdate(_CVI(1), _GT(1.0)),
            Cerberus.BoundUpdate(_CVI(3), _GT(i)),
        ]
        @test isempty(node.lt_general_constrs)
        @test isempty(node.gt_general_constrs)
        @test node.depth == 2
    end
end

pb_config = Cerberus.AlgorithmConfig(
        branching_rule = Cerberus.PseudocostBranching(),
        silent = true,
    )
v = [_SV(_VI(i)) for i in 1:2]
ac = Cerberus.AffineConstraint(
    6/19 * v[1] + 4/19 * v[2],
    _LT(1.0)
)
aff_constrs = [ac]
bounds = [_IN(0.0, Inf), _IN(0.0, 2.25)]
p = Cerberus.Polyhedron(aff_constrs, bounds)
variable_kind = [_GI(), _GI()]
obj = _CSAF([-1.0, -1.0], [_CVI(1), _CVI(2)], 0.0)
form = Cerberus.DMIPFormulation(p, variable_kind, obj)

state = Cerberus.CurrentState()
node = Cerberus.pop_node!(state.tree)
nr = Cerberus.process_node!(state, form, node, pb_config)
Cerberus.update_state!(state, form, node, nr, pb_config)

n1 = Cerberus.pop_node!(state.tree)
n2 = Cerberus.pop_node!(state.tree)
