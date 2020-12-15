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
        return new(SparseArrays.sparse(A), b, senses, l, u)
    end
end

Base.size(poly::Polyhedron) = Base.size(poly.A)
_ambient_dim(poly::Polyhedron) = Base.size(poly)[2]

struct Disjunction
    disjuncts::Vector{Polyhedron}

    function Disjunction(disjuncts::Vector{Polyhedron})
        ambient_dims = _ambient_dim.(disjuncts)
        @assert length(unique(ambient_dims)) == 1
        return new(disjuncts)
    end
end

# Assumption: Problem is being minimized
struct Formulation
    poly::Polyhedron
    c::Vector{Float64}
    integrality::Vector{Bool}

    function Formulation(poly::Polyhedron, c::Vector, integrality::Vector{Bool})
        n = _ambient_dim(poly)
        @assert n == length(c) == length(integrality)
        return new(poly, c, integrality)
    end
end
num_constraints(form::Formulation) = size(form.poly)[1]
num_variables(form::Formulation) = size(form.poly)[2]

function integral_indices(form::Formulation)
    return filter(i -> form.integrality[i], 1:length(form.integrality))
end

abstract type FormulationUpdater end

struct Problem
    base_form::Formulation
    updaters::Vector{FormulationUpdater}
end

num_constraints(prob::Problem) = num_constraints(prob.base_form)
num_variables(prob::Problem) = num_variables(prob.base_form)


