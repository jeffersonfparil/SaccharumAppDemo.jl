using Pkg
Pkg.activate(".")

using Genie
using SearchLight
using SearchLightSQLite

# Load App Logic
include(joinpath("src", "App.jl"))

println("🧨 FORCE RESETTING DATABASE...")

# 1. Connect
SearchLight.Configuration.load()
SearchLight.connect()

# 2. Drop Tables
try
    SearchLight.query("DROP TABLE IF EXISTS users")
    SearchLight.query("DROP TABLE IF EXISTS genomic_features")
    println("🗑️  Old tables dropped.")
catch e
    println("Note: Tables might not have existed.")
end

# 3. Create Tables
SearchLight.query("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, password_hash TEXT, email TEXT)")
SearchLight.query("CREATE TABLE IF NOT EXISTS genomic_features (id INTEGER PRIMARY KEY AUTOINCREMENT, chromosome TEXT, position INTEGER, feature_type TEXT, name TEXT, value REAL, meta TEXT)")
println("🏗️  Tables created.")

# 4. Seed Admin
using .App.Users
u = User()
u.username = "admin"
u.password_hash = Users.hash_password("admin123")
u.email = "admin@sugarcane.org"
save!(u)
println("👤 Admin created.")

# 5. Seed Genome Data
using .App.Genomics
println("🧬 Seeding 500 fake records (this make take a few seconds)...")
chromosomes = ["Chr1", "Chr2", "Chr3"]

for i in 1:500
    g = GenomicFeature()
    g.chromosome = rand(chromosomes)
    g.position = rand(1:100_000_000)
    
    r = rand()
    if r < 0.2
        g.feature_type = "gwas_peak"
        g.name = "GWAS_Peak_" * string(i)
        g.value = -log10(rand() * 1e-4) 
    elseif r < 0.4
        g.feature_type = "gene"
        g.name = "SugarGene_" * string(i)
        g.value = 1.0
    else
        g.feature_type = "marker"
        g.name = "SNP_" * string(i)
        g.value = rand() 
    end
    save!(g)
end

println("✅ Database Reset & Seeded Successfully!")
println("   (You can now start the server)")
