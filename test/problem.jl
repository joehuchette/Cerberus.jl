@testset "AffineConstraint" begin
    v = [_SV(_VI(i)) for i in 1:3]
    ac = Cerberus.AffineConstraint(v[1] + 2.0 * v[2] + 3.0 * v[3], _ET(3.0))
    _test_equal(ac.f, _CSAF([1.0, 2.0, 3.0], [_CVI(1), _CVI(2), _CVI(3)], 0.0))
    @test ac.s == _ET(3.0)
end

function _test_polyhedron(p::Cerberus.Polyhedron)
    @test Cerberus.num_constraints(p) == 2
    @test Cerberus.num_constraints(p, _LT) == length(p.lt_constrs) == 1
    @test Cerberus.num_constraints(p, _GT) == length(p.gt_constrs) == 0
    @test Cerberus.num_constraints(p, _ET) == length(p.et_constrs) == 1
    et_constr = @inferred Cerberus.get_constraint(p, _ET, 1)
    @test et_constr === p.et_constrs[1]
    _test_equal(
        et_constr.f,
        _CSAF([1.0, 2.1, 3.0], [_CVI(1), _CVI(2), _CVI(3)], 0.0),
    )
    @test et_constr.s == _ET(3.0)

    lt_constr = @inferred Cerberus.get_constraint(p, _LT, 1)
    @test lt_constr === p.lt_constrs[1]
    _test_equal(lt_constr.f, _CSAF([-3.5, 1.2], [_CVI(1), _CVI(2)], 0.0))
    @test lt_constr.s == _LT(4.0)

    @test p.bounds == [_IN(0.5, 1.0), _IN(-1.3, 2.3), _IN(0.0, 1.0)]

    return nothing
end

@testset "Polyhedron" begin
    p = @inferred _build_polyhedron()
    _test_polyhedron(p)

    # TODO: Test throws on malformed Polyhedron
    @test_throws AssertionError Cerberus.Polyhedron(
        [
            Cerberus.AffineConstraint(
                _CSAF([1.0, 2.0], [_CVI(1), _CVI(2)], 0.0),
                _ET(1.0),
            ),
        ],
        [_IN(0.0, 1.0)],
    )
    @testset "ambient_dim" begin
        @test Cerberus.ambient_dim(p) == 3
    end
    @testset "num_constraints" begin
        @test Cerberus.num_constraints(p) == 2
    end
    @testset "add_variable" begin
        Cerberus.add_variable(p)
        @test Cerberus.ambient_dim(p) == 4
    end
    @testset "empty constructor" begin
        p = @inferred Cerberus.Polyhedron()
        @test Cerberus.ambient_dim(p) == 0
        @test Cerberus.num_constraints(p) == 0
    end
end

@testset "DMIPFormulation" begin
    fm = @inferred _build_dmip_formulation()
    _test_polyhedron(fm._feasible_region)
    _test_equal(fm.obj, _CSAF([1.0, -1.0], [_CVI(1), _CVI(2)], 0.0))
    @test isempty(fm.disjunction_formulaters)
    @test [Cerberus.get_variable_kind(fm, _CVI(i)) for i in 1:3] == [_ZO(), nothing, _ZO()]

    @testset "empty constructor" begin
        empty_fm = @inferred Cerberus.DMIPFormulation()
        @test Cerberus.num_variables(empty_fm) == 0
        @test Cerberus.ambient_dim(empty_fm._feasible_region) == 0
        @test Cerberus.num_constraints(empty_fm._feasible_region) == 0
        _test_equal(empty_fm.obj, _CSAF())
        @test isempty(empty_fm.disjunction_formulaters)
        @test isempty(empty_fm._variable_kind)
    end

    @testset "num_variables" begin
        @test @inferred Cerberus.num_variables(fm) == 3
    end

    @testset "add_variable" begin
        @inferred Cerberus.add_variable(fm)
        @test Cerberus.num_variables(fm) == 4
    end

    @testset "get_variable_kind" begin
        @test Cerberus.get_variable_kind(fm, _CVI(1)) == _ZO()
        @test Cerberus.get_variable_kind(fm, _CVI(2)) === nothing
        @test Cerberus.get_variable_kind(fm, _CVI(3)) == _ZO()
        @test Cerberus.get_variable_kind(fm, _CVI(4)) === nothing
    end

    @testset "set_variable_kind!" begin
        @inferred Cerberus.set_variable_kind!(fm, _CVI(4), _GI())
        @test Cerberus.get_variable_kind(fm, _CVI(4)) == _GI()
    end

    @testset "num_constraints" begin
        @test @inferred Cerberus.num_constraints(fm) == 2
        @test @inferred Cerberus.num_constraints(fm, _LT) == 1
        @test @inferred Cerberus.num_constraints(fm, _GT) == 0
        @test @inferred Cerberus.num_constraints(fm, _ET) == 1
    end

    @testset "get_constraint(s)" begin
        lt_true = @inferred Cerberus.get_constraint(fm, _LT, 1)
        _test_equal(lt_true.f, _CSAF([-3.5, 1.2], [_CVI(1), _CVI(2)], 0.0))
        @test lt_true.s == _LT(4.0)
        et_true = @inferred Cerberus.get_constraint(fm, _ET, 1)
        _test_equal(et_true.f, _CSAF([1.0, 2.1, 3.0], [_CVI(1), _CVI(2), _CVI(3)], 0.0))
        @test et_true.s == _ET(3.0)
        @test length(Cerberus.get_constraints(fm, _LT)) == 1
        @test Cerberus.get_constraints(fm, _LT) == [lt_true]
        @test length(Cerberus.get_constraints(fm, _GT)) == 0
        @test length(Cerberus.get_constraints(fm, _ET)) == 1
        @test Cerberus.get_constraints(fm, _ET) == [et_true]
    end

    @testset "add_constraint" begin
        f = _CSAF([2.1, 5.4], [_CVI(3), _CVI(4)], 1.2)
        s = _GT(7.2)
        ac = Cerberus.AffineConstraint(f, s)
        @inferred Cerberus.add_constraint(fm, ac)
        @test Cerberus.num_constraints(fm, _GT) == 1
        @test Cerberus.get_constraint(fm, _GT, 1) == ac
        @test Cerberus.get_constraints(fm, _GT)[1] == ac
    end

    @testset "isempty" begin
        @test !isempty(fm)
        empty_form = Cerberus.DMIPFormulation()
        @test isempty(empty_form)
        Cerberus.add_constraint(empty_form, Cerberus.AffineConstraint(_CSAF(), _LT(1.0)))
        @test !isempty(empty_form)
    end

    @testset "get_bounds" begin
        l, u = @inferred Cerberus.get_bounds(fm, _CVI(1))
        @test Cerberus.get_bounds(fm, _CVI(1)) == (0.5, 1.0)
        @test Cerberus.get_bounds(fm, _CVI(2)) == (-1.3, 2.3)
        @test Cerberus.get_bounds(fm, _CVI(3)) == (0.0, 1.0)
        @test Cerberus.get_bounds(fm, _CVI(4)) == (-Inf, Inf)
    end

    @testset "set_bounds!" begin
        @inferred Cerberus.set_bounds!(fm, _CVI(4), _IN(5.7, 8.4))
        @test Cerberus.get_bounds(fm, _CVI(4)) == (5.7, 8.4)
    end

    # TODO: Test throws on malformed DMIPFormulation
end

function _test_gi_polyhedron(p::Cerberus.Polyhedron)
    @test Cerberus.num_constraints(p) == 1
    @test Cerberus.num_constraints(p, _LT) == 1
    @test Cerberus.num_constraints(p, _GT) == 0
    @test Cerberus.num_constraints(p, _ET) == 0
    lt_constr = @inferred Cerberus.get_constraint(p, _LT, 1)
    @test lt_constr === p.lt_constrs[1]
    _test_equal(
        lt_constr.f,
        _CSAF([1.3, 3.7, 2.4], [_CVI(1), _CVI(2), _CVI(3)], 0.0),
    )
    @test lt_constr.f.constant == 0.0
    @test lt_constr.s == _LT(5.5)

    @test p.bounds == [_IN(0.0, 4.5), _IN(0.0, 1.0), _IN(0.0, 3.0)]
end

@testset "General integer polyhedron/formulation" begin
    p = @inferred _build_gi_polyhedron()
    _test_gi_polyhedron(p)

    fm = @inferred _build_gi_dmip_formulation()
    _test_gi_polyhedron(fm._feasible_region)
    @test isempty(fm.disjunction_formulaters)
    @test [Cerberus.get_variable_kind(fm, _CVI(i)) for i in 1:3] == [nothing, _ZO(), _GI()]
end
