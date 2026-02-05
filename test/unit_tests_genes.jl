using Test
using GenesController

@testset "Bioinformatics Logic: GC Content" begin
    # Test 1: Standard sequence
    # G=1, C=1, Total=4 -> 50%
    @test GenesController.calculate_gc("ATGC") == 50.0

    # Test 2: High GC sugarcane marker
    # G=3, C=3, Total=6 -> 100%
    @test GenesController.calculate_gc("GGGCCC") == 100.0

    # Test 3: Lowercase handling (Bioinformatics data is often messy)
    @test GenesController.calculate_gc("atgc") == 50.0

    # Test 4: Empty sequence handling
    @test GenesController.calculate_gc("") == 0.0
end
