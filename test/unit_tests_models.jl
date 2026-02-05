using Test
using SearchLight
using SearchLight.Validation
using Genes
using Users

@testset "Model Validation Rules" begin

    @testset "Gene Model" begin
        # Test 1: Valid Gene
        valid_gene = Gene(locus_tag="SC_TEST_01", chromosome="1", functional_annotation="Test", sequence_data="ATGC")
        @test validate(valid_gene) == ValidationResult[]

        # Test 2: Invalid Gene (Missing Locus Tag)
        # We defined in Genes.jl that locus_tag must be present
        invalid_gene = Gene(chromosome="1")
        result = validate(invalid_gene)
        
        # Verify that validation fails
        @test !is_success(result)
        # Verify the specific error is about locus_tag
        @test result[1].field == :locus_tag
    end

    @testset "User Model" begin
        # Test 1: Valid User
        valid_user = User(username="admin", password="123", role="admin")
        @test validate(valid_user) == ValidationResult[]

        # Test 2: Invalid Role
        # Our validator only accepts "admin" or "student"
        invalid_user = User(username="hacker", password="123", role="supervillain")
        result = validate(invalid_user)
        
        @test !is_success(result)
        @test any(r -> r.field == :role, result)
    end
    
end
