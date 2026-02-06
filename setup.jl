using Pkg
using UUIDs

function write_file(path, content)
    mkpath(dirname(path))
    open(path, "w") do io
        write(io, content)
    end
    println("Created: $path")
end

println("✨ Generating Sugarcane Dashboard (Manual Session Fix)...")

# # ==========================================
# # 1. Project Configuration
# # ==========================================
# # FIX: Removed all problematic Session packages.
# write_file("Project.toml", """
# name = "SugarcaneGenie"
# uuid = "$(UUIDs.uuid4())"
# authors = ["Genie User"]
# version = "0.1.0"

# [deps]
# Genie = "c43c736e-a2d1-11e8-161f-af95117fbd1e"
# SearchLight = "5779bdad-336c-5461-82c5-8f645229235e"
# SearchLightSQLite = "32353723-96b0-5eff-96f7-b50031899e69"
# SQLite = "0aa819cd-b072-5ff4-a722-6bc14bd2081e"
# DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
# CSV = "336ed68f-0bac-5ca0-87d4-7b16f2d0c41d"
# JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
# MbedTLS = "739be429-bea8-5141-9913-cc70e7f3736d"
# Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
# Logging = "56ddb016-857b-54e1-b83d-db4d58db5568"
# """)

# ==========================================
# 2. Database Connection
# ==========================================
write_file("db/connection.yml", """
env: DEV

DEV:
  adapter: SQLite
  database: db/sugarcane.sqlite
""")

# ==========================================
# 3. Bootstrap
# ==========================================
write_file("bootstrap.jl", """
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
""")

# ==========================================
# 4. App Logic (Custom Session Manager)
# ==========================================
write_file("src/App.jl", """
module App

using Genie
using SearchLight
using SearchLightSQLite
using Genie.Router
using Genie.Renderer.Html, Genie.Renderer.Json
using Genie.Requests
using Genie.Cookies
using Random

# --- MANUAL SESSION MANAGER ---
module SimpleSession
    using Genie.Cookies
    using Random
    
    # Store: SessionToken => UserID
    # We use 'Any' for the value to support DbId, Int, or String
    const SESSIONS = Dict{String, Any}()

    # FIX: Removed the '::Int' type constraint on user_id
    function create(user_id)
        token = randstring(32)
        SESSIONS[token] = user_id
        
        # FIX: Simple cookie set (compatible with all Genie versions)
        Cookies.set!("session_token", token)
        return token
    end

    function get_user()
        if haskey(Cookies.all(), "session_token")
            token = Cookies.get("session_token")
            return get(SESSIONS, token, nothing)
        end
        return nothing
    end

    function destroy()
        if haskey(Cookies.all(), "session_token")
            token = Cookies.get("session_token")
            delete!(SESSIONS, token)
            Cookies.set!("session_token", "")
        end
    end
end

# Configuration
Genie.config.run_as_server = true

# Load Resources
include(joinpath("..", "app", "resources", "users", "Users.jl"))
include(joinpath("..", "app", "resources", "genomics", "Genomics.jl"))

# Load Controllers
include(joinpath("..", "app", "controllers", "AuthController.jl"))
include(joinpath("..", "app", "controllers", "DashboardController.jl"))

# Load Routes
include(joinpath("..", "routes.jl"))

end
""")

# ==========================================
# 5. Models (Mapped)
# ==========================================
write_file("app/resources/users/Users.jl", """
module Users
using SearchLight, MbedTLS, Dates
export User

mutable struct User <: AbstractModel
    id::DbId
    username::String
    password_hash::String
    email::String
end

User() = User(DbId(), "", "", "")
SearchLight.table(::Type{User}) = "users"

function hash_password(password::String)
    return "hashed:" * bytes2hex(digest(MD_SHA256, password, "SugarSalt"))
end

function authenticate(username, password)
    u = findone(User, username = username)
    if isnothing(u)
        return nothing
    end
    return (u.password_hash == hash_password(password)) ? u : nothing
end
end
""")

write_file("app/resources/genomics/Genomics.jl", """
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
SearchLight.table(::Type{GenomicFeature}) = "genomic_features"
end
""")

# ==========================================
# 6. Seeds
# ==========================================
write_file("db/seeds.jl", """
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
            g.name = "GWAS_Peak_\$(i)"
            g.value = -log10(rand() * 1e-4) 
        elseif r < 0.4
            g.feature_type = "gene"
            g.name = "SugarGene_\$(i)"
            g.value = 1.0
        else
            g.feature_type = "marker"
            g.name = "SNP_\$(i)"
            g.value = rand() 
        end
        save!(g)
    end
end
""")

# ==========================================
# 7. Controllers (Using SimpleSession)
# ==========================================
write_file("app/controllers/AuthController.jl", """
module AuthController
using Genie.Renderer.Html, Genie.Requests, Genie.Router
using ..App.Users
using ..App.SimpleSession 

function login_page()
    html(:authentication, :login)
end

function login()
    username = postpayload(:username)
    password = postpayload(:password)
    user = Users.authenticate(username, password)
    
    if !isnothing(user)
        # Create session manually
        SimpleSession.create(user.id)
        return redirect(:dashboard)
    else
        return redirect(:login_page)
    end
end

function logout()
    SimpleSession.destroy()
    return redirect(:login_page)
end
end
""")

write_file("app/controllers/DashboardController.jl", """
module DashboardController
using Genie.Renderer.Html, Genie.Renderer.Json, Genie.Requests
using SearchLight, DataFrames, CSV
using ..App.Genomics
using ..App.SimpleSession

function check_auth()
    uid = SimpleSession.get_user()
    return !isnothing(uid)
end

function index()
    if !check_auth() return redirect(:login_page) end
    html(:dashboard, :index)
end

function api_genome_data()
    if !check_auth() return json(Dict("error" => "Unauthorized"), status=401) end
    start_pos = parse(Int, get(params(), :start, "0"))
    end_pos = parse(Int, get(params(), :end, "1000000000"))
    chrom = get(params(), :chrom, "Chr1")
    
    features = find(GenomicFeature, SQLWhereExpression("chromosome = ? AND position >= ? AND position <= ?", chrom, start_pos, end_pos))
    return json(Dict("features" => [Dict("id"=>f.id, "pos"=>f.position, "val"=>f.value, "type"=>f.feature_type, "name"=>f.name) for f in features]))
end

function api_search()
    if !check_auth() return json(Dict("error" => "Unauthorized"), status=401) end
    term = get(params(), :q, "")
    # Note: Escaped \$
    results = find(GenomicFeature, SQLWhereExpression("name LIKE ?", "%\$(term)%"))
    return json([Dict("name" => r.name, "chrom" => r.chromosome, "pos" => r.position) for r in results])
end

function export_csv()
    if !check_auth() return redirect(:login_page) end
    chrom = get(params(), :chrom, "Chr1")
    features = find(GenomicFeature, SQLWhereExpression("chromosome = ?", chrom))
    
    df = DataFrame(Name=[f.name for f in features], Chromosome=[f.chromosome for f in features], Position=[f.position for f in features], Type=[f.feature_type for f in features], Value=[f.value for f in features])
    io = IOBuffer()
    CSV.write(io, df)
    return Genie.Renderer.respond(String(take!(io)), headers = Dict("Content-Type" => "text/csv", "Content-Disposition" => "attachment; filename=\\"genome_data.csv\\""))
end
end
""")

# ==========================================
# 8. Routes
# ==========================================
write_file("routes.jl", """
using Genie.Router
using .AuthController
using .DashboardController

route("/", AuthController.login_page, named=:login_page)
route("/login", AuthController.login, method=POST)
route("/logout", AuthController.logout)

route("/dashboard", DashboardController.index, named=:dashboard)

route("/api/data", DashboardController.api_genome_data)
route("/api/search", DashboardController.api_search)
route("/api/export_csv", DashboardController.export_csv)
""")

# ==========================================
# 9. Views (HTML)
# ==========================================
write_file("app/layouts/app.jl.html", """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Sugarcane Genome</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
    <style>body { font-family: sans-serif; }</style>
</head>
<body class="bg-gray-100"><% @yield %></body>
</html>
""")

write_file("app/resources/authentication/views/login.jl.html", """
<div class="flex h-screen justify-center items-center">
    <div class="bg-white p-8 rounded shadow w-96">
        <h2 class="text-2xl font-bold mb-4 text-green-700">Sugarcane DB</h2>
        <form action="/login" method="POST">
            <input type="text" name="username" placeholder="Username" class="w-full border p-2 mb-4 rounded">
            <input type="password" name="password" placeholder="Password" class="w-full border p-2 mb-4 rounded">
            <button class="w-full bg-green-600 text-white p-2 rounded hover:bg-green-700">Login</button>
        </form>
        <div class="mt-4 text-sm text-gray-500 text-center">Use: admin / admin123</div>
    </div>
</div>
""")

write_file("app/resources/dashboard/views/index.jl.html", """
<div class="flex flex-col h-screen">
    <nav class="bg-green-800 text-white p-4 flex justify-between items-center">
        <div class="font-bold text-lg">🌱 Sugarcane Genome</div>
        <div class="flex gap-4 items-center">
            <div class="relative">
                <input id="search" type="text" placeholder="Search..." class="px-2 py-1 rounded text-black w-64">
                <div id="searchRes" class="absolute bg-white text-black w-full shadow hidden z-10"></div>
            </div>
            <a href="/logout" class="text-sm hover:underline">Logout</a>
        </div>
    </nav>
    <div class="p-4 flex gap-4 bg-white border-b items-center">
        <span>Chromosome:</span>
        <select id="chrom" class="border p-1 rounded"><option>Chr1</option><option>Chr2</option><option>Chr3</option></select>
        <button onclick="load()" class="bg-blue-600 text-white px-3 py-1 rounded">Load</button>
        <button onclick="dl()" class="ml-auto bg-gray-600 text-white px-3 py-1 rounded">Export CSV</button>
    </div>
    <div class="flex-grow p-4 flex flex-col gap-4 overflow-hidden">
        <div id="plot" class="bg-white p-2 rounded shadow h-1/2"></div>
        <div class="bg-white p-2 rounded shadow h-1/2 flex flex-col">
            <h3 class="font-bold p-2 border-b">Details</h3>
            <div class="overflow-auto flex-grow">
                <table class="w-full text-sm text-left"><thead class="bg-gray-100 sticky top-0"><tr><th class="p-2">Name</th><th class="p-2">Type</th><th class="p-2">Pos</th><th class="p-2">Val</th></tr></thead><tbody id="tbl"></tbody></table>
            </div>
        </div>
    </div>
</div>
<script>
    let currentData = [];
    async function load() {
        const chrom = document.getElementById('chrom').value;
        const layout = document.getElementById('plot').layout;
        let s = 0, e = 100000000;
        if(layout && layout.xaxis && layout.xaxis.range) { s = layout.xaxis.range[0]; e = layout.xaxis.range[1]; }
        const res = await fetch(`/api/data?chrom=\${chrom}&start=\${s}&end=\${e}`);
        const json = await res.json();
        currentData = json.features;
        draw(currentData, chrom);
        tabulate(currentData);
    }
    function draw(data, chrom) {
        const traces = {};
        data.forEach(d => {
            if(!traces[d.type]) traces[d.type] = {x:[], y:[], text:[], mode:'markers', name: d.type, type:'scatter'};
            traces[d.type].x.push(d.pos);
            traces[d.type].y.push(d.val);
            traces[d.type].text.push(d.name);
        });
        const plotData = Object.values(traces);
        const layout = { title: `Genome: \${chrom}`, dragmode: 'zoom', xaxis: {title: 'Base Pairs'}, hovermode: 'closest' };
        Plotly.react('plot', plotData, layout);
        document.getElementById('plot').on('plotly_relayout', e => {
            if(e['xaxis.range[0]']) {
                const s = e['xaxis.range[0]'], end = e['xaxis.range[1]'];
                tabulate(currentData.filter(d => d.pos >= s && d.pos <= end));
            } else if (e['xaxis.autorange']) tabulate(currentData);
        });
    }
    function tabulate(data) {
        document.getElementById('tbl').innerHTML = data.slice(0,200).map(d => `<tr class="border-b hover:bg-gray-50"><td class="p-2 font-mono">\${d.name}</td><td class="p-2">\${d.type}</td><td class="p-2">\${d.pos}</td><td class="p-2">\${d.val.toFixed(3)}</td></tr>`).join('');
    }
    function dl() { window.location.href = `/api/export_csv?chrom=\${document.getElementById('chrom').value}`; }
    document.getElementById('search').addEventListener('input', async (e) => {
        const q = e.target.value;
        const div = document.getElementById('searchRes');
        if(q.length < 2) { div.classList.add('hidden'); return; }
        const res = await fetch(`/api/search?q=\${q}`);
        const data = await res.json();
        div.innerHTML = data.map(d => `<div class="p-2 hover:bg-gray-200 cursor-pointer" onclick="jump('\${d.chrom}', \${d.pos})">\${d.name} (\${d.chrom})</div>`).join('');
        div.classList.remove('hidden');
    });
    function jump(chrom, pos) {
        document.getElementById('chrom').value = chrom;
        load().then(() => { Plotly.relayout('plot', {'xaxis.range': [pos-50000, pos+50000]}); });
        document.getElementById('searchRes').classList.add('hidden');
    }
    load();
</script>
""")

# println("\\n✅ Done! Application is ready (Manual Session Mode).")
# println("------------------------------------------------")
# println("1. cd SugarcaneGenie")
# println("2. julia --project=.")
# println("3. using Pkg; Pkg.instantiate()")
# println("4. include(\\"bootstrap.jl\\")")
# println("------------------------------------------------")






include("bootstrap.jl")