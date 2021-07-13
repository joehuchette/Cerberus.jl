@testset "NodeResult" begin end

@testset "CurrentState" begin
    fm = _build_dmip_formulation()

    nvars = Cerberus.num_variables(fm)
    pb_float = 12.4
    pb_int = 12

    cs1 = @inferred _CurrentState()
    cs2 = @inferred _CurrentState(primal_bound = pb_float)
    cs3 = @inferred _CurrentState(primal_bound = pb_int)

    @test length(cs1.tree) == 1
    @test length(cs2.tree) == 1
    @test length(cs3.tree) == 1

    @test Cerberus._is_root_node(Cerberus.pop_node!(cs1.tree))
    @test Cerberus._is_root_node(Cerberus.pop_node!(cs2.tree))
    @test Cerberus._is_root_node(Cerberus.pop_node!(cs3.tree))

    @test cs1.primal_bound == Inf
    @test cs2.primal_bound == pb_float
    @test cs3.primal_bound == pb_int

    @test cs1.dual_bound == -Inf
    @test cs2.dual_bound == -Inf
    @test cs3.dual_bound == -Inf

    @test isempty(cs1.best_solution)
    @test isempty(cs2.best_solution)
    @test isempty(cs3.best_solution)

    @test cs1.total_node_count == 0
    @test cs2.total_node_count == 0
    @test cs3.total_node_count == 0

    @test cs1.total_simplex_iters == 0
    @test cs2.total_simplex_iters == 0
    @test cs3.total_simplex_iters == 0
end

@testset "copy(::Basis)" begin
    src = Cerberus.Basis(
        [MOI.NONBASIC_AT_LOWER, MOI.BASIC, MOI.NONBASIC_AT_LOWER],
        [MOI.BASIC],
        MOI.BasisStatusCode[],
        [MOI.NONBASIC],
        MOI.BasisStatusCode[],
        [MOI.NONBASIC_AT_UPPER],
    )
    dest = copy(src)
    @test src.base_var_constrs == dest.base_var_constrs
    @test src.base_lt_constrs == dest.base_lt_constrs
    @test src.base_gt_constrs == dest.base_gt_constrs
    @test src.base_et_constrs == dest.base_et_constrs
    @test src.branch_lt_constrs == dest.branch_lt_constrs
    @test src.branch_gt_constrs == dest.branch_gt_constrs
    empty!(src.base_var_constrs)
    empty!(src.base_lt_constrs)
    empty!(src.base_gt_constrs)
    empty!(src.base_et_constrs)
    empty!(src.branch_lt_constrs)
    empty!(src.branch_gt_constrs)
    @test dest.base_var_constrs ==
          [MOI.NONBASIC_AT_LOWER, MOI.BASIC, MOI.NONBASIC_AT_LOWER]
    @test dest.base_lt_constrs == [MOI.BASIC]
    @test isempty(dest.base_gt_constrs)
    @test dest.base_et_constrs == [MOI.NONBASIC]
    @test isempty(dest.branch_lt_constrs)
    @test dest.branch_gt_constrs == [MOI.NONBASIC_AT_UPPER]
end

@testset "reset_formulation_state!" begin
    form = _build_formulation_with_single_disjunction()
    state = Cerberus.CurrentState()
    node = Cerberus.Node(
        [Cerberus.BoundUpdate(_CVI(5), _LT(0.0))],
        [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))],
        [Cerberus.AffineConstraint(_CSAF([2.3], [_CVI(2)], 0.0), _LT(2.3))],
        [Cerberus.AffineConstraint(_CSAF([2.3], [_CVI(2)], 0.0), _GT(2.3))],
        4,
    )
    node_result = Cerberus.NodeResult(node)
    Cerberus.populate_lp_model!(state, form, node, node_result, CONFIG)
    Cerberus.apply_branchings!(state, node)
    Cerberus.formulate_disjunctions!(state, form, node, node_result, CONFIG)
    @test length(state._variable_indices) == 5
    @test length(state.constraint_state.base_state.var_constrs) == 5
    @test isempty(state.constraint_state.base_state.lt_constrs)
    @test length(state.constraint_state.base_state.gt_constrs) == 1
    @test isempty(state.constraint_state.base_state.et_constrs)
    @test state.constraint_state.branch_state.num_lt_branches == 1
    @test state.constraint_state.branch_state.num_gt_branches == 1
    @test length(state.constraint_state.branch_state.lt_general_constrs) == 1
    @test length(state.constraint_state.branch_state.lt_general_constrs) == 1
    @test length(state.disjunction_state) == 1

    Cerberus.reset_formulation_state!(state)
    @test isempty(state._variable_indices)
    @test isempty(state.constraint_state.base_state.var_constrs)
    @test isempty(state.constraint_state.base_state.lt_constrs)
    @test isempty(state.constraint_state.base_state.gt_constrs)
    @test isempty(state.constraint_state.base_state.et_constrs)
    @test state.constraint_state.branch_state.num_lt_branches == 0
    @test state.constraint_state.branch_state.num_gt_branches == 0
    @test isempty(state.constraint_state.branch_state.lt_general_constrs)
    @test isempty(state.constraint_state.branch_state.lt_general_constrs)
    @test isempty(state.disjunction_state)
end

@testset "instantiate" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState()
    vis = state._variable_indices
    @test isempty(vis)
    node = Cerberus.Node()
    node_result = Cerberus.NodeResult(node)
    Cerberus.populate_lp_model!(state, form, node, node_result, CONFIG)
    @test length(vis) == 3
    vi_1 = @inferred Cerberus.instantiate(_CVI(1), state)
    @test vi_1 == vis[1]
    @test Cerberus.instantiate(_CVI(2), state) == vis[2]
    @test Cerberus.instantiate(_CVI(3), state) == vis[3]
    svs = _SV.(vis)
    @test _is_equal(
        Cerberus.instantiate(
            _CSAF([1.2, 3.4, 5.6], [_CVI(3), _CVI(1), _CVI(2)], 7.8),
            state,
        ),
        1.2 * svs[3] + 3.4 * svs[1] + 5.6 * svs[2] + 7.8,
    )
    @test_throws BoundsError Cerberus.instantiate(_CVI(4), state)

    cvi = @inferred Cerberus.attach_index!(state, _VI(7))
    @test cvi == _CVI(4)
end
