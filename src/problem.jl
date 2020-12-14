@enum Sense EQUAL_TO LESS_THAN GREATER_THAN

struct Polyhedron
    A::SparseArrays.SparseMatrixCSC{Float64,Int}
    b::Vector{Float64}
    senses::Vector{Sense}
    l::Vector{Float64}
    u::Vector{Float64}

    function Polyhedron(A::AbstractMatrix, b::Vector, senses::Vector{Sense}, l::Vector, u::Vector)
        m, n = size(A)
        @assert m == length(b) == length(senses)
        @assert n == length(l) == length(u)
        return new(sparse(A), b, senses, l, u)
    end
end

size(poly::Polyhedron) = size(poly.A)

struct Disjunction
    disjuncts::Vector{Polyhedron}
end

# Assumption: Problem is being minimized
struct Formulation
    poly::Polyhedron
    c::Vector{Float64}
    integrality::Vector{Bool}

    function Formulation(poly::Polyhedron, c::Vector, integrality::Vector{Bool})
        n = size(poly)[2]
        @assert n == length(c) == length(integrality)
        return new(poly, c, integrality)
    end
end
num_constraints(form::Formulation) = size(form.poly)[1]
num_variables(form::Formulation) = size(form.poly)[2]

abstract type FormulationUpdater end

struct Problem
    base_form::Formulation
    updaters::Vector{FormulationUpdater}
end

num_constraints(prob::Problem) = size(prob.form)[1]
num_variables(prob::Problem) = size(prob.form)[2]


