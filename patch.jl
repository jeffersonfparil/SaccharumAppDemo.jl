using Pkg
using Downloads

println("🧬 Switching Genome to Saccharum hybrid (JAQSUU000000000)...")

# 1. Setup Directories
if !isdir("public/genome") mkpath("public/genome") end

# 2. Download the first sequence (JAQSUU010000001.1) from NCBI
# We use the NCBI Viewer API to get the raw FASTA
const SEQ_ID = "JAQSUU010000001.1"
const FASTA_URL = "https://www.ncbi.nlm.nih.gov/sviewer/viewer.fcgi?id=$(SEQ_ID)&db=nuccore&report=fasta&retmode=text"
const LOCAL_FASTA = "public/genome/saccharum_jaqsuu.fna"

if isfile(LOCAL_FASTA)
    println("✅ Sequence $SEQ_ID already exists locally.")
else
    println("⬇️  Downloading sequence $SEQ_ID from NCBI...")
    try
        Downloads.download(FASTA_URL, LOCAL_FASTA)
        println("✅ Download complete.")
    catch e
        println("❌ Download failed: $e")
    end
end

# 3. Update IGV Controller
println("🔧 Configuring IGV for JAQSUU Assembly...")

open("app/controllers/IGVController.jl", "w") do io
    write(io, """
module IGVController

using Genie, Genie.Renderer, Genie.Renderer.Html, Genie.Renderer.Json
using Genie.Requests, Genie.Router, SearchLight, DataFrames, CSV, HTTP
using ..App.Genomics, ..App.SimpleSession

# --- VIEW ---
function get_igv_html()
    return \"\"\"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>IGV | JAQSUU Reference</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/igv@2.15.5/dist/igv.min.js"></script>
    <style>
        body { font-family: 'Inter', sans-serif; }
        .bg-uq-purple  { background-color: #51247a; }
        .text-uq-purple{ color: #51247a; }
    </style>
</head>
<body class="bg-gray-50 flex flex-col h-screen">

    <header class="bg-uq-purple text-white p-3 shadow-lg flex-none">
        <div class="container mx-auto flex justify-between items-center">
            <h1 class="text-xl font-bold">QAAFI Sugarcane <span class="text-sm font-normal opacity-75">(Hybrid JAQSUU)</span></h1>
            <div class="flex items-center gap-4">
                 <a href="/dashboard" class="text-white hover:text-gray-200 font-bold text-sm">← Back to Dashboard</a>
                 <a href="/logout" class="bg-red-500 hover:bg-red-600 px-3 py-1 rounded text-xs font-bold">Sign Out</a>
            </div>
        </div>
    </header>

    <main class="flex-grow p-4 flex flex-col">
        <div class="bg-white p-4 rounded-xl shadow border border-gray-200 flex-grow flex flex-col">
            <div id="igv-div" class="w-full flex-grow"></div>
        </div>
    </main>

    <script>
        document.addEventListener("DOMContentLoaded", function () {
            var igvDiv = document.getElementById("igv-div");
            var options = {
                // 1. CUSTOM GENOME (JAQSUU)
                reference: {
                    id: "saccharum_jaqsuu",
                    name: "S. hybrid (JAQSUU010000001.1)",
                    fastaURL: "/genome/saccharum_jaqsuu.fna",
                    indexURL: "/genome/saccharum_jaqsuu.fna.fai" 
                },
                // Start view at the beginning of the scaffold
                locus: "JAQSUU010000001.1:1-20000",
                tracks: [
                    // 2. YOUR MARKER TRACK (BED)
                    {
                        name: "QAAFI Markers (Live DB)",
                        type: "annotation",
                        format: "bed",
                        url: "/api/igv/data.bed",
                        displayMode: "EXPANDED",
                        color: "#51247a", // UQ Purple
                        autoHeight: true
                    }
                ]
            };

            igv.createBrowser(igvDiv, options)
                .then(function (browser) {
                    console.log("IGV Loaded with JAQSUU Genome");
                });
        });
    </script>
</body>
</html>
\"\"\"
end

# --- HELPERS ---
function get_session_token()
    if !haskey(Genie.Router.params(), :REQUEST) return nothing end
    req = Genie.Router.params(:REQUEST)
    cookie_str = ""
    if hasproperty(req, :headers)
        for (k, v) in req.headers
            if lowercase(string(k)) == "cookie" cookie_str = v; break end
        end
    end
    if isempty(cookie_str) return nothing end
    m = match(r"session_token=([a-zA-Z0-9]+)", cookie_str)
    return isnothing(m) ? nothing : m.captures[1]
end

function check_auth()
    token = get_session_token()
    isnothing(token) && return false
    return !isnothing(SimpleSession.get_user(token))
end

function index()
    check_auth() ? get_igv_html() : redirect(:login_page)
end

# --- API: BED FILE GENERATOR ---
function api_bed_data()
    if !check_auth() return Genie.Renderer.Json.json(Dict("error" => "Unauthorized"), status=401) end
    
    features = all(GenomicFeature)
    io = IOBuffer()
    write(io, "track name='SugarcaneMarkers' description='QAAFI Genotypes' visibility=2 itemRgb='On'\\n")
    
    # MAPPING: DB "Chr1" -> NCBI "JAQSUU010000001.1"
    chrom_map = Dict(
        "Chr1" => "JAQSUU010000001.1" 
        # Note: We map Chr1 to this scaffold for the demo.
    )

    for f in features
        # Only output markers that map to our downloaded scaffold
        if haskey(chrom_map, f.chromosome)
            c = chrom_map[f.chromosome]
            s = f.position
            e = f.position + 5000 
            name = f.name
            score = Int(round(f.value * 1000))
            
            rgb = "81,36,122"
            if f.feature_type == "gene"
                rgb = "46,168,54"
            elseif f.feature_type == "gwas_peak"
                rgb = "235,96,43"
            end
            
            write(io, "\$c\\t\$s\\t\$e\\t\$name\\t\$score\\t.\\t\$s\\t\$e\\t\$rgb\\n")
        end
    end
    
    return HTTP.Response(200, ["Content-Type" => "text/plain"], String(take!(io)))
end

end
""")
end

println("✅ Genome Switched to JAQSUU000000000 (Scaffold 1).")
println("⚠️  REMINDER: You must generate a .fai index for 'public/genome/saccharum_jaqsuu.fna'!")