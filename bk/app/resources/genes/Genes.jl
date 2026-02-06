module Genes

using SearchLight, SearchLight.Validation

export Gene

mutable struct Gene <: AbstractModel
  id::DbId
  locus_tag::String
  chromosome::String
  functional_annotation::String
  sequence_data::String
end

Gene(; id=DbId(), locus_tag="", chromosome="", functional_annotation="", sequence_data="") = 
  Gene(id, locus_tag, chromosome, functional_annotation, sequence_data)

function SearchLight.Validation.validator(g::Gene)
  ValidationResult([
    ValidationRule(:locus_tag, Gene, presence=true)
  ])
end

end
