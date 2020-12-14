abstract type NodeResult end

struct PruneByInfeasibility <: NodeResult end

struct PruneByIntegrality <: NodeResult
    solution::Vector{Float64}
    objective_value::Float64
end

struct PruneByBound <: NodeResult end

struct Branching <: NodeResult
    favorite_child::Node
    other_child::Node
end
