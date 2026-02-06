using Pkg
Pkg.activate(".")

using Genie
using SearchLight
using SearchLightSQLite

# 1. Connect to DB
println("🔌 Connecting to Database...")
SearchLight.Configuration.load()
SearchLight.connect()

# 2. Load App Logic
include(joinpath("src", "App.jl"))

# 3. Initialize/Seed DB if needed
if !isfile("db/seeded.marker")
    println("🌱 Seeding data...")
    include(joinpath("db", "seeds.jl"))
    touch("db/seeded.marker")
end

# 4. Start Server
println("🚀 Starting Server on http://127.0.0.1:8000")
up(8000, async=false)
