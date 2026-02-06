module Genomics
using SearchLight
export GenomicFeature

mutable struct GenomicFeature <: AbstractModel
    id::DbId
    chromosome::String
    position::Int
    feature_type::String 
    name::String
    value::Float64 
    meta::String   
end

GenomicFeature() = GenomicFeature(DbId(), "", 0, "", "", 0.0, "{}")

# EXPLICT MAPPING:
SearchLight.table(::Type{GenomicFeature}) = "genomic_features"
end
