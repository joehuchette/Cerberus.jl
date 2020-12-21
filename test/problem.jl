@testset "AffineConstraint" begin
    v = [_SV(_VI(i)) for i in 1:3]
    ac = Cerberus.AffineConstraint(
        v[1] + 2.0 * v[2] + 3.0 * v[3],
        MOI.EqualTo(3.0)
    )
    @test typeof(ac.f) == MOI.ScalarAffineFunction{Float64}
    @test ac.f.terms ==
        [
            MOI.ScalarAffineTerm{Float64}(2.0, _VI(2)),
            MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
            MOI.ScalarAffineTerm{Float64}(3.0, _VI(3)),
        ]
    @test ac.f.constant == 0.0
    @test ac.s == MOI.EqualTo(3.0)
end

function _test_polyhedron(p::Cerberus.Polyhedron)
    @test typeof(p.aff_constrs[1].f) == MOI.ScalarAffineFunction{Float64}
    @test p.aff_constrs[1].f.terms ==
        [
            MOI.ScalarAffineTerm{Float64}(2.0, _VI(2)),
            MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
            MOI.ScalarAffineTerm{Float64}(3.0, _VI(3)),
        ]
    @test p.aff_constrs[1].f.constant == 0.0
    @test p.aff_constrs[1].s == MOI.EqualTo(3.0)
    @test typeof(p.aff_constrs[2].f) == MOI.ScalarAffineFunction{Float64}
    @test p.aff_constrs[2].f.terms ==
        [
            MOI.ScalarAffineTerm{Float64}(-3.5, _VI(1)),
            MOI.ScalarAffineTerm{Float64}(1.2, _VI(2)),
        ]
    @test p.aff_constrs[2].f.constant == 0.0
    @test p.aff_constrs[2].s == MOI.LessThan(4.0)

    @test p.bounds[1] == MOI.Interval{Float64}(0.5, 1.0)
    @test p.bounds[2] == MOI.Interval{Float64}(-1.3, 2.3)
    @test p.bounds[3] == MOI.Interval{Float64}(0.0, 1.0)

    return nothing
end

@testset "Polyhedron" begin
    p = @inferred _build_polyhedron()
    _test_polyhedron(p)
    @test Cerberus.ambient_dim(p) == 3

    # TODO: Test throws on malformed Polyhedron
    @test_throws AssertionError Cerberus.Polyhedron(
        [
            Cerberus.AffineConstraint(
                1.0 * _SV(_VI(1)) + 2.0 * _SV(_VI(2)),
                MOI.EqualTo(1.0),
            )
        ],
        [MOI.Interval(0.0, 1.0)],
    )
end

@testset "LPRelaxation" begin
    p = _build_polyhedron()
    lp = @inferred _build_relaxation()

    _test_polyhedron(lp.feasible_region)
    @test typeof(lp.obj) == MOI.ScalarAffineFunction{Float64}
    @test lp.obj.terms ==
        [
            MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
            MOI.ScalarAffineTerm{Float64}(-1.0, _VI(2)),
        ]
    @test lp.obj.constant == 0.0

    # TODO: Test throws on malformed LPRelaxation
end

@testset "DMIPFormulation" begin
    fm = @inferred _build_dmip_formulation()
    _test_polyhedron(fm.base_form.feasible_region)
    @test typeof(fm.base_form.obj) == MOI.ScalarAffineFunction{Float64}
    @test fm.base_form.obj.terms ==
        [
            MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
            MOI.ScalarAffineTerm{Float64}(-1.0, _VI(2)),
        ]
    @test fm.base_form.obj.constant == 0.0
    @test isempty(fm.disjunction_formulaters)
    @test fm.integrality == [_VI(1), _VI(3)]

    # TODO: Test throws on malformed DMIPFormulation
end
