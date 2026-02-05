# SaccharumAppDemo.jl
Sugarcane Genomics App Demo using Genie.jl


Demo:

```julia
using Pkg
Pkg.instantiate()  # Downloads Genie, SearchLight, etc.

# Initialize DB (One time only)
include("bootstrap.jl") # This loads the app

# Run Migrations to create tables
include("db/migrations/setup_schema.jl")
setup()
# setdown()

# Create a Dummy Admin User (Fellow) and Gene
using .Users, .Genes, SearchLight
u = User(username="admin", password="password", name="Dr. Fellow", role="admin", email="fellow@uq.edu.au")
save(u)

g = Gene(locus_tag="SC_001", chromosome="1A", functional_annotation="Sucrose Synthase", sequence_data="ATGC...")
save(g)

# Start Server
Genie.up(8000, async=false)
```