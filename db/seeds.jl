using SearchLight
using .App.Users
using .App.Genomics

SearchLight.query("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, password_hash TEXT, email TEXT)")
SearchLight.query("CREATE TABLE IF NOT EXISTS genomic_features (id INTEGER PRIMARY KEY AUTOINCREMENT, chromosome TEXT, position INTEGER, feature_type TEXT, name TEXT, value REAL, meta TEXT)")

if count(User) == 0
    u = User()
    u.username = "admin"
    u.password_hash = Users.hash_password("admin123")
    u.email = "admin@sugarcane.org"
    save!(u)
    println("User created: admin / admin123")
end

if count(GenomicFeature) == 0
    println("Seeding 500 fake records...")
    chromosomes = ["Chr1", "Chr2", "Chr3"]
    for i in 1:500
        g = GenomicFeature()
        g.chromosome = rand(chromosomes)
        g.position = rand(1:100_000_000)
        r = rand()
        if r < 0.2
            g.feature_type = "gwas_peak"
            g.name = "GWAS_Peak_$(i)"
            g.value = -log10(rand() * 1e-4) 
        elseif r < 0.4
            g.feature_type = "gene"
            g.name = "SugarGene_$(i)"
            g.value = 1.0
        else
            g.feature_type = "marker"
            g.name = "SNP_$(i)"
            g.value = rand() 
        end
        save!(g)
    end
end
