@testset "AffineConstraint" begin
    v = [_SV(_VI(i)) for i in 1:3]
    ac = Cerberus.AffineConstraint(v[1] + 2.0 * v[2] + 3.0 * v[3], _ET(3.0))
    @test typeof(ac.f) == _SAF
    @test ac.f.terms == [
        MOI.ScalarAffineTerm{Float64}(2.0, _VI(2)),
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(3.0, _VI(3)),
    ]
    @test ac.f.constant == 0.0
    @test ac.s == _ET(3.0)
end

function _test_polyhedron(p::Cerberus.Polyhedron)
    @test typeof(p.aff_constrs[1].f) == _SAF
    @test p.aff_constrs[1].f.terms == [
        MOI.ScalarAffineTerm{Float64}(2.1, _VI(2)),
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(3.0, _VI(3)),
    ]
    @test p.aff_constrs[1].f.constant == 0.0
    @test p.aff_constrs[1].s == _ET(3.0)
    @test typeof(p.aff_constrs[2].f) == _SAF
    @test p.aff_constrs[2].f.terms == [
        MOI.ScalarAffineTerm{Float64}(-3.5, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(1.2, _VI(2)),
    ]
    @test p.aff_constrs[2].f.constant == 0.0
    @test p.aff_constrs[2].s == _LT(4.0)

    @test p.bounds == [_IN(0.5, 1.0), _IN(-1.3, 2.3), _IN(0.0, 1.0)]

    return nothing
end

@testset "Polyhedron" begin
    p = @inferred _build_polyhedron()
    _test_polyhedron(p)

    # TODO: Test throws on malformed Polyhedron
    @test_throws AssertionError Cerberus.Polyhedron(
        [Cerberus.AffineConstraint(
            1.0 * _SV(_VI(1)) + 2.0 * _SV(_VI(2)),
            _ET(1.0),
        )],
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

@testset "LPRelaxation" begin
    p = _build_polyhedron()
    lp = @inferred _build_relaxation()

    _test_polyhedron(lp.feasible_region)
    @test typeof(lp.obj) == _SAF
    @test lp.obj.terms == [
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(-1.0, _VI(2)),
    ]
    @test lp.obj.constant == 0.0

    @test Cerberus.num_variables(lp) == 3

    @testset "empty constructor" begin
        lp = @inferred Cerberus.LPRelaxation()
        @test Cerberus.num_variables(lp) == 0
        @test Cerberus.ambient_dim(lp.feasible_region) == 0
        @test Cerberus.num_constraints(lp.feasible_region) == 0
        @test isempty(lp.obj.terms)
        @test lp.obj.constant == 0.0
    end

    # TODO: Test throws on malformed LPRelaxation
end

@testset "DMIPFormulation" begin
    fm = @inferred _build_dmip_formulation()
    _test_polyhedron(fm.base_form.feasible_region)
    @test typeof(fm.base_form.obj) == _SAF
    @test fm.base_form.obj.terms == [
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(-1.0, _VI(2)),
    ]
    @test fm.base_form.obj.constant == 0.0
    @test isempty(fm.disjunction_formulaters)
    @test fm.integrality == [_ZO(), nothing, _ZO()]

    @testset "empty constructor" begin
        fm = @inferred Cerberus.DMIPFormulation()
        @test Cerberus.num_variables(fm) == 0
        @test Cerberus.ambient_dim(fm.base_form.feasible_region) == 0
        @test Cerberus.num_constraints(fm.base_form.feasible_region) == 0
        @test isempty(fm.base_form.obj.terms)
        @test fm.base_form.obj.constant == 0.0
        @test isempty(fm.disjunction_formulaters)
        @test isempty(fm.integrality)
    end

    # TODO: Test throws on malformed DMIPFormulation
end

function _test_gi_polyhedron(p::Cerberus.Polyhedron)
    @test length(p.aff_constrs) == 1
    @test typeof(p.aff_constrs[1].f) == _SAF
    @test p.aff_constrs[1].f.terms == [
        MOI.ScalarAffineTerm{Float64}(1.3, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(3.7, _VI(2)),
        MOI.ScalarAffineTerm{Float64}(2.4, _VI(3)),
    ]
    @test p.aff_constrs[1].f.constant == 0.0
    @test p.aff_constrs[1].s == _LT(5.5)

    @test p.bounds == [_IN(0.0, 4.5), _IN(0.0, 1.0), _IN(0.0, 3.0)]
end

@testset "General integer polyhedron/formulation" begin
    p = @inferred _build_gi_polyhedron()
    _test_gi_polyhedron(p)

    fm = @inferred _build_gi_dmip_formulation()
    _test_gi_polyhedron(fm.base_form.feasible_region)
    @test isempty(fm.disjunction_formulaters)
    @test fm.integrality == [nothing, _ZO(), _GI()]
end
