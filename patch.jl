using Pkg
Pkg.activate(".")

using Genie
using SearchLight
using SearchLightSQLite
using SQLite
using DataFrames # Used for safe verification

println("🔧 Starting Final Database Repair...")

# 1. Connect to Database
if !isdir("db") mkdir("db") end
db_path = joinpath("db", "sugarcane.sqlite")
db = SQLite.DB(db_path)
println("🔌 Connected to: $db_path")

# 2. Re-create Table (Dropping old one to be sure)
println("🧨 Resetting 'genomic_features' table...")
SQLite.execute(db, "DROP TABLE IF EXISTS genomic_features")
SQLite.execute(db, "CREATE TABLE genomic_features (id INTEGER PRIMARY KEY AUTOINCREMENT, chromosome TEXT, position INTEGER, feature_type TEXT, name TEXT, value REAL, meta TEXT)")

# 3. Insert Data (Using explicit transaction)
println("🧬 Injecting 500 records...")
SQLite.transaction(db) do
    stmt = SQLite.Stmt(db, "INSERT INTO genomic_features (chromosome, position, feature_type, name, value) VALUES (?, ?, ?, ?, ?)")
    
    chroms = ["Chr1", "Chr2", "Chr3"]
    for i in 1:500
        c = rand(chroms)
        p = rand(1:100_000_000)
        
        r = rand()
        if r < 0.2
            SQLite.execute(stmt, (c, p, "gwas_peak", "GWAS_Peak_$i", rand()))
        elseif r < 0.4
            SQLite.execute(stmt, (c, p, "gene", "SugarGene_$i", 1.0))
        else
            SQLite.execute(stmt, (c, p, "marker", "SNP_$i", rand()))
        end
    end
end
println("✅ Injection phase complete.")

# 4. Verify using DataFrames (The safe way)
println("📊 Verifying data...")
df = DBInterface.execute(db, "SELECT * FROM genomic_features") |> DataFrame
count = nrow(df)

println("------------------------------------------------")
println("Total Rows Found: $count")
println("Sample Data:")
println(first(df, 3))
println("------------------------------------------------")

if count > 0
    println("✅ SUCCESS: Database is ready.")
else
    println("❌ ERROR: Table is still empty.")
end