using Test
using Pkg

# Activate the project environment
Pkg.activate(".")

# Load the Genie App (Bootstrapping)
# We need to load the app to access Models and Controllers
include("../bootstrap.jl")

@testset "SugarcaneGenomics App Tests" begin
    
    # Run specific test files
    include("unit_tests_genes.jl")
    include("unit_tests_models.jl")
    
end
