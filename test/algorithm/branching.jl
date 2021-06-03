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
        let nr = Cerberus.NodeResult(12.3, [0.6, 0.7, 0.1], 12, 13, 14)
            bc = @inferred Cerberus.branching_candidates(form, nr, config)
            @test bc == [
                Cerberus.VariableBranchingCandidate(_CVI(1), 0.6),
                Cerberus.VariableBranchingCandidate(_CVI(3), 0.1),
            ]
        end
        let nr = Cerberus.NodeResult(12.3, [0.8, 0.7, 0.0], 12, 13, 14)
            bc = @inferred Cerberus.branching_candidates(form, nr, config)
            @test bc == [Cerberus.VariableBranchingCandidate(_CVI(1), 0.8)]
        end
        let nr = Cerberus.NodeResult(12.3, [1.0, 0.7, 0.0], 12, 13, 14)
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
            nr = Cerberus.NodeResult(12.3, x, 12, 13, 14)
            let bc = Cerberus.VariableBranchingCandidate(_CVI(1), 0.6)
                vbs =
                    @inferred Cerberus.branching_score(state, bc, nr, mi_config)
                @test vbs == Cerberus.VariableBranchingScore(0.6, 0.4, 0.4)
            end
            let bc = Cerberus.VariableBranchingCandidate(_CVI(3), 0.35)
                vbs =
                    @inferred Cerberus.branching_score(state, bc, nr, mi_config)
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
            result = Cerberus.NodeResult(cost, x, 12, 13, 14)
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
            result = Cerberus.NodeResult(cost, x, 12, 13, 14)
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
            ac1 = Cerberus.AffineConstraint(4.0*v[1] + 2.0*v[2] + 2.0*v[3], _GT(5.0))
            ac2 = Cerberus.AffineConstraint(4.0*v[1] + 2.0*v[2] + 5.0*v[3], _LT(5.0))
            aff_constrs = [ac1, ac2]
            bounds = [_IN(0.0, Inf) for i in 1:3]
            p = Cerberus.Polyhedron(aff_constrs, bounds)
            variable_kind = [_GI() for i in 1:3]
            obj = _CSAF([-1.0, 1.0, 0.0], [_CVI(1), _CVI(2), _CVI(3)], 0.0)
            form = Cerberus.DMIPFormulation(p, variable_kind, obj)

            state = Cerberus.CurrentState()
            node = Cerberus.pop_node!(state.tree)
            Cerberus.populate_base_model!(state, form, node, sb_config)
            nr = Cerberus.process_node!(state, form, node, sb_config)

            bc = Cerberus.VariableBranchingCandidate(_CVI(1), nr.x[1])
            vbs =
                @inferred Cerberus.branching_score(state, form, bc, nr, node, sb_config)
            @test vbs == Cerberus.VariableBranchingScore(0.75, Inf, Inf)
        end

        let sb_config = Cerberus.AlgorithmConfig(
                branching_rule = Cerberus.StrongBranching(),
                silent = true,
            )
            v = [_SV(_VI(i)) for i in 1:3]
            ac1 = Cerberus.AffineConstraint(1.0*v[1] + 1/9*v[2] + 5/3*v[3], _LT(2.0))
            ac2 = Cerberus.AffineConstraint(1/9*v[1] + 1.0*v[2] + 5/3*v[3], _LT(2.0))
            ac3 = Cerberus.AffineConstraint(1.0*v[1] + 1.0*v[2] + 1.0*v[3], _LT(2.0))
            aff_constrs = [ac1, ac2]
            bounds = [_IN(0.0, Inf) for i in 1:3]
            p = Cerberus.Polyhedron(aff_constrs, bounds)
            variable_kind = [_ZO(), _ZO(), _GI()]
            obj = _CSAF([-1.0, -1.0, -1.5], [_CVI(1), _CVI(2), _CVI(3)], 0.0)
            form = Cerberus.DMIPFormulation(p, variable_kind, obj)

            state = Cerberus.CurrentState()
            node = Cerberus.pop_node!(state.tree)
            Cerberus.populate_base_model!(state, form, node, sb_config)
            nr = Cerberus.process_node!(state, form, node, sb_config)
            print(nr)

            bc = Cerberus.VariableBranchingCandidate(_CVI(3), nr.x[3])
            vbs =
                @inferred Cerberus.branching_score(state, form, bc, nr, node, sb_config)
            @test isapprox(vbs.down_branch_score, 0.8)
            @test isapprox(vbs.up_branch_score, 0.7)
            @test isapprox(vbs.aggregate_score, 43/60)
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
    ::Cerberus.DMIPFormulation,
    dbc::DummyBranchingCandidate,
    ::Cerberus.NodeResult,
    ::Cerberus.Node,
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
    nr = Cerberus.NodeResult(12.3, [0.6, 0.5, 1.0], 12, 13, 14)
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
