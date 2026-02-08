module BrowsersController

using Genie, Genie.Renderer, Genie.Renderer.Html, Genie.Renderer.Json
using Genie.Requests, Genie.Router, SearchLight, DataFrames, CSV, HTTP
using ..App.Genomics, ..App.SimpleSession

# --- AUTH HELPERS ---
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

# --- 1. JBROWSE 2 VIEW ---
function jbrowse()
    if !check_auth() return redirect(:login_page) end
    
    return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>JBrowse 2 | QAAFI Sugarcane</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/react@16/umd/react.production.min.js"></script>
    <script src="https://unpkg.com/react-dom@16/umd/react-dom.production.min.js"></script>
    <script src="https://unpkg.com/@jbrowse/react-linear-genome-view/dist/react-linear-genome-view.umd.production.min.js"></script>
    <style>
        body { font-family: 'Inter', sans-serif; }
        .bg-uq-purple { background-color: #51247a; }
    </style>
</head>
<body class="bg-gray-50 flex flex-col h-screen">

    <header class="bg-uq-purple text-white p-3 shadow-lg flex-none">
        <div class="container mx-auto flex justify-between items-center">
            <h1 class="text-xl font-bold">QAAFI Sugarcane <span class="text-sm font-normal opacity-75">(JBrowse 2)</span></h1>
            <div class="flex items-center gap-4">
                 <a href="/dashboard" class="text-white hover:text-gray-200 font-bold text-sm">← Dashboard</a>
                 <a href="/logout" class="bg-red-500 hover:bg-red-600 px-3 py-1 rounded text-xs font-bold">Sign Out</a>
            </div>
        </div>
    </header>

    <main class="flex-grow p-4">
        <div id="jbrowse_linear_genome_view" class="h-full w-full bg-white rounded-xl shadow border border-gray-200 overflow-hidden"></div>
    </main>

    <script>
        const { createViewState, JBrowseLinearGenomeView } = JBrowseReactLinearGenomeView
        const { createElement } = React
        const { render } = ReactDOM

        const assembly = {
            name: 'JAQSUU010000001.1',
            sequence: {
                type: 'ReferenceSequenceTrack',
                trackId: 'JAQSUU_ref_seq',
                adapter: {
                    type: 'IndexedFastaAdapter',
                    fastaLocation: { uri: '/genome/saccharum_jaqsuu.fna' },
                    faiLocation: { uri: '/genome/saccharum_jaqsuu.fna.fai' },
                },
            },
        }

        const tracks = [
            {
                type: 'FeatureTrack',
                trackId: 'qaafi_markers',
                name: 'QAAFI DB Markers (BED)',
                assemblyNames: ['JAQSUU010000001.1'],
                category: ['Genotypes'],
                adapter: {
                    type: 'BedAdapter',
                    bedLocation: { uri: '/api/igv/data.bed' }, // We reuse the BED API
                },
            },
             {
                type: 'FeatureTrack',
                trackId: 'ncbi_genes',
                name: 'NCBI Hybrid Genes (GFF3)',
                assemblyNames: ['JAQSUU010000001.1'],
                category: ['Annotation'],
                adapter: {
                    type: 'Gff3Adapter',
                    gffLocation: { uri: '/genome/saccharum_hybrid.gff' },
                },
            },
        ]

        const state = createViewState({
            assembly,
            tracks,
            location: 'JAQSUU010000001.1:1000..50000',
            defaultSession: {
                name: 'My Session',
                view: {
                    id: 'linearGenomeView',
                    type: 'LinearGenomeView',
                    tracks: [
                        { type: 'ReferenceSequenceTrack', configuration: 'JAQSUU_ref_seq', displays: [{ type: 'LinearReferenceSequenceDisplay', configuration: 'JAQSUU_ref_seq-LinearReferenceSequenceDisplay' }] },
                        { type: 'FeatureTrack', configuration: 'qaafi_markers', displays: [{ type: 'LinearBasicDisplay', configuration: 'qaafi_markers-LinearBasicDisplay' }] },
                         { type: 'FeatureTrack', configuration: 'ncbi_genes', displays: [{ type: 'LinearBasicDisplay', configuration: 'ncbi_genes-LinearBasicDisplay' }] },
                    ],
                },
            },
        })

        render(
            createElement(JBrowseLinearGenomeView, { viewState: state }),
            document.getElementById('jbrowse_linear_genome_view'),
        )
    </script>
</body>
</html>
"""
end

# --- 2. GBROWSE (LEGACY SIMULATION) ---
function gbrowse()
    if !check_auth() return redirect(:login_page) end
    
    return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>GBrowse Archive | QAAFI</title>
    <style>
        body { font-family: sans-serif; background-color: #ffffee; margin: 0; }
        .gb-header { background-color: #000080; color: white; padding: 10px; border-bottom: 3px solid #ffcc00; }
        .gb-menu { background-color: #dddddd; padding: 5px; border-bottom: 1px solid #999; font-size: 12px; }
        .gb-content { padding: 20px; text-align: center; }
        .track-img { width: 100%; height: 150px; background: repeating-linear-gradient(45deg,#f0f0f0,#f0f0f0 10px,#e0e0e0 10px,#e0e0e0 20px); border: 1px solid #999; position: relative; }
        .gene-block { position: absolute; top: 40px; height: 10px; background-color: blue; }
        .snp-mark { position: absolute; top: 80px; height: 10px; width: 2px; background-color: red; }
    </style>
</head>
<body>
    <div class="gb-header">
        <b>GBrowse 2.55</b> - Saccharum Legacy Archive
    </div>
    <div class="gb-menu">
        [ <a href="/dashboard">Return to Modern Portal</a> ] | [ Help ] | [ Select Tracks ] | [ Karyotype ]
    </div>
    
    <div class="gb-content">
        <h3>Viewing: JAQSUU010000001.1:1..50000</h3>
        <p style="color: red; font-weight: bold;">NOTE: This is a read-only archive of legacy data.</p>
        
        <div style="border: 1px solid black; padding: 10px; background: white; width: 90%; margin: auto;">
            <div class="track-img">
                <div style="position: absolute; top: 10px; left: 10px; font-weight: bold; font-family: monospace;">RefSeq</div>
                
                <div class="gene-block" style="left: 10%; width: 5%;"></div>
                <div class="gene-block" style="left: 30%; width: 8%;"></div>
                <div class="gene-block" style="left: 60%; width: 4%;"></div>
                
                <div class="snp-mark" style="left: 12%;"></div>
                <div class="snp-mark" style="left: 35%;"></div>
                <div class="snp-mark" style="left: 62%;"></div>
                
                <div style="position: absolute; top: 120px; width: 100%; border-top: 1px solid black; text-align: center; font-size: 10px;">
                    10k -------- 20k -------- 30k -------- 40k -------- 50k
                </div>
            </div>
        </div>
        
        <br>
        <form>
            Landmark or Region: <input type="text" value="JAQSUU010000001.1:1..50000" size="30">
            <button type="button" onclick="alert('Search disabled in archive mode.')">Search</button>
        </form>
    </div>
</body>
</html>
"""
end

end
