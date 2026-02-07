using Pkg

println("🔧 Fixing CSV Export (Switching to Raw HTTP Response)...")

# --- PART 1: The HTML/JS Content (Preserved) ---
const HTML_CONTENT = raw"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Genomic Breeding Portal | QAAFI Sugarcane</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
    <style>
        body { font-family: 'Inter', sans-serif; }
        .uq-purple { background-color: #51247a; }
        .loader { border-top-color: #51247a; -webkit-animation: spinner 1.5s linear infinite; animation: spinner 1.5s linear infinite; }
        @keyframes spinner { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body class="bg-gray-50 flex flex-col h-screen">

    <header class="uq-purple text-white p-3 shadow-lg flex-none">
        <div class="container mx-auto flex justify-between items-center">
            <div class="flex items-center space-x-4">
                <div class="border-r border-purple-400 pr-4">
                    <h1 class="text-xl font-bold">QAAFI</h1>
                    <p class="text-xs uppercase tracking-tighter text-purple-200">Centre for Crop Science</p>
                </div>
                <h2 class="text-lg font-medium">Sugarcane Genetics Portal</h2>
            </div>
            <div class="flex items-center gap-4">
                <div id="loading" class="hidden flex items-center gap-2 bg-white text-purple-800 px-3 py-1 rounded text-xs font-bold">
                    <div class="loader ease-linear rounded-full border-2 border-t-2 border-gray-200 h-4 w-4"></div>
                    Loading...
                </div>
                <a href="/logout" class="bg-purple-600 hover:bg-red-600 px-4 py-2 rounded text-sm transition font-bold border border-purple-500">Sign Out</a>
            </div>
        </div>
    </header>

    <div class="bg-white border-b p-4 shadow-sm flex-none z-20">
        <div class="container mx-auto flex flex-wrap justify-between items-center gap-4">
            <div class="flex items-center space-x-4">
                <div class="flex flex-col">
                    <label class="text-xs font-bold text-gray-400 uppercase">Chromosome</label>
                    <select id="chrom" onchange="load()" class="border-2 border-gray-200 rounded p-2 text-sm font-bold text-gray-700 focus:border-purple-500 outline-none">
                        <option value="Chr1">Chr1 (S. officinarum)</option>
                        <option value="Chr2">Chr2 (S. officinarum)</option>
                        <option value="Chr3">Chr3 (S. officinarum)</option>
                    </select>
                </div>
                <button onclick="load()" class="mt-4 bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded font-bold shadow transition transform active:scale-95">
                    Refresh Track
                </button>
            </div>
            
            <div class="relative w-96">
                <label class="text-xs font-bold text-gray-400 uppercase">Search Markers</label>
                <input id="search" type="text" placeholder="e.g. SNP_100, GWAS..." class="w-full border-2 border-gray-200 rounded p-2 text-sm focus:border-purple-500 outline-none transition">
                <div id="searchRes" class="absolute bg-white w-full shadow-2xl hidden z-50 border mt-1 max-h-64 overflow-y-auto rounded-b"></div>
            </div>
            
            <button onclick="dl()" class="mt-4 bg-gray-100 hover:bg-gray-200 text-gray-700 border px-4 py-2 rounded text-sm font-bold flex items-center gap-2">
                <span>📥</span> Export CSV
            </button>
        </div>
    </div>

    <main class="flex-grow p-4 overflow-hidden flex flex-col gap-4 relative">
        
        <section class="bg-white rounded-xl shadow-sm border flex-grow h-1/2 relative p-2">
            <div id="plot" class="w-full h-full"></div>
            <div id="empty-state" class="hidden absolute inset-0 flex items-center justify-center bg-white bg-opacity-90 z-10">
                <div class="text-center">
                    <h3 class="text-xl font-bold text-gray-400">No Data Found</h3>
                    <p class="text-gray-400">Try selecting a different region or chromosome.</p>
                </div>
            </div>
        </section>
        
        <section class="bg-white rounded-xl shadow-sm border flex-grow h-1/2 flex flex-col overflow-hidden">
            <div class="p-3 border-b bg-gray-50 flex justify-between items-center flex-none">
                <h3 class="font-bold text-gray-700 text-sm uppercase">Feature Table</h3>
                <span id="count" class="text-xs font-mono bg-purple-100 text-purple-700 px-2 py-1 rounded">0 records</span>
            </div>
            <div class="overflow-auto flex-grow">
                <table class="w-full text-left border-collapse">
                    <thead class="bg-gray-100 sticky top-0 text-xs uppercase text-gray-500 font-bold">
                        <tr>
                            <th class="p-3 border-b">Name</th>
                            <th class="p-3 border-b">Type</th>
                            <th class="p-3 border-b">Position (bp)</th>
                            <th class="p-3 border-b">Value (-log10 p)</th>
                        </tr>
                    </thead>
                    <tbody id="tbl" class="text-sm divide-y divide-gray-100"></tbody>
                </table>
            </div>
        </section>
    </main>

    <script>
        let currentData = [];

        async function load() {
            document.getElementById('loading').classList.remove('hidden');
            document.getElementById('empty-state').classList.add('hidden');
            
            const chrom = document.getElementById('chrom').value;
            const layout = document.getElementById('plot').layout;
            let s = 0; 
            let e = 100000000;
            
            if(layout && layout.xaxis && layout.xaxis.range) { 
                s = Math.floor(layout.xaxis.range[0]); 
                e = Math.floor(layout.xaxis.range[1]); 
            }
            
            const url = '/api/data?chrom=' + chrom + '&start=' + s + '&end=' + e;
            console.log("Fetching: " + url);
            
            try {
                const res = await fetch(url);
                if (!res.ok) throw new Error("API Failed");
                
                const json = await res.json();
                currentData = json.features;
                
                console.log("Loaded " + currentData.length + " items");
                
                document.getElementById('count').innerText = currentData.length + ' records';
                
                if (currentData.length === 0) {
                    document.getElementById('empty-state').classList.remove('hidden');
                }
                
                draw(currentData, chrom);
                tabulate(currentData);
                
            } catch (err) { 
                console.error(err);
                alert("Error loading data. Check console.");
            } finally {
                document.getElementById('loading').classList.add('hidden');
            }
        }

        function draw(data, chrom) {
            const traces = {};
            
            data.forEach(d => {
                if(!traces[d.type]) {
                    traces[d.type] = { 
                        x:[], y:[], text:[], 
                        mode:'markers', 
                        name:d.type, 
                        type:'scatter',
                        marker: { size: 8, opacity: 0.7 }
                    };
                }
                traces[d.type].x.push(d.pos); 
                traces[d.type].y.push(d.val); 
                traces[d.type].text.push(d.name);
            });
            
            const layout = { 
                title: false,
                xaxis: { title: 'Physical Position (bp)', gridcolor: '#f3f4f6' },
                yaxis: { title: 'Signal Intensity', gridcolor: '#f3f4f6' },
                margin: { t:20, b:40, l:60, r:20 },
                hovermode: 'closest',
                plot_bgcolor: 'white'
            };
            
            Plotly.react('plot', Object.values(traces), layout);
            
            document.getElementById('plot').on('plotly_relayout', function(ev) {
                if(ev['xaxis.range[0]']) {
                    const s = ev['xaxis.range[0]'];
                    const end = ev['xaxis.range[1]'];
                    const sub = currentData.filter(d => d.pos >= s && d.pos <= end);
                    tabulate(sub);
                } else if (ev['xaxis.autorange']) {
                    tabulate(currentData);
                }
            });
        }

        function tabulate(data) {
            const el = document.getElementById('tbl');
            if (data.length === 0) {
                el.innerHTML = '<tr><td colspan="4" class="p-4 text-center text-gray-400">No data in this view</td></tr>';
                return;
            }
            el.innerHTML = data.slice(0, 100).map(d => {
                return '<tr class="hover:bg-purple-50 transition border-b border-gray-50">' + 
                       '<td class="p-3 font-mono font-bold text-purple-700">' + d.name + '</td>' +
                       '<td class="p-3"><span class="bg-gray-100 text-gray-600 px-2 py-0.5 rounded text-xs font-bold uppercase">' + d.type + '</span></td>' +
                       '<td class="p-3 text-gray-600">' + d.pos.toLocaleString() + '</td>' +
                       '<td class="p-3 font-medium">' + d.val.toFixed(4) + '</td>' +
                       '</tr>';
            }).join('');
        }

        const searchInput = document.getElementById('search');
        const searchRes = document.getElementById('searchRes');
        let debounceTimer;

        searchInput.addEventListener('input', (e) => {
            clearTimeout(debounceTimer);
            const q = e.target.value;
            
            if(q.length < 2) { 
                searchRes.classList.add('hidden'); 
                return; 
            }
            
            debounceTimer = setTimeout(async () => {
                try {
                    console.log("Searching for: " + q);
                    const res = await fetch('/api/search?q=' + q);
                    const results = await res.json();
                    
                    if(results.length === 0) {
                         searchRes.innerHTML = '<div class="p-3 text-sm text-gray-400">No matches found</div>';
                    } else {
                        searchRes.innerHTML = results.slice(0, 15).map(d => 
                            '<div class="p-3 hover:bg-purple-50 cursor-pointer text-sm border-b flex justify-between group" onclick="jump(\\'' + d.chrom + '\\',' + d.pos + ')">' + 
                            '<span class="font-bold text-gray-800 group-hover:text-purple-700">' + d.name + '</span>' + 
                            '<span class="text-xs text-gray-400">' + d.chrom + ' : ' + d.pos + '</span>' +
                            '</div>'
                        ).join('');
                    }
                    searchRes.classList.remove('hidden');
                } catch(err) { console.error(err); }
            }, 300);
        });

        function jump(c, p) {
            document.getElementById('chrom').value = c;
            load().then(() => { 
                Plotly.relayout('plot', {'xaxis.range': [p-50000, p+50000]}); 
            });
            searchRes.classList.add('hidden');
            searchInput.value = '';
        }

        function dl() { 
            const chrom = document.getElementById('chrom').value;
            window.location.href = '/api/export_csv?chrom=' + chrom; 
        }

        load();
    </script>
</body>
</html>
"""

# --- PART 2: The Julia Controller Code (Rewriting the Export Logic) ---

open("app/controllers/DashboardController.jl", "w") do io
    # Write Header (Added HTTP to imports)
    write(io, """
module DashboardController

using Genie, Genie.Renderer, Genie.Renderer.Html, Genie.Renderer.Json
using Genie.Requests, Genie.Router, SearchLight, DataFrames, CSV, HTTP
using ..App.Genomics, ..App.SimpleSession

# --- RENDERER ---
function get_dashboard_html()
    return \"\"\"
""")

    # Write HTML Content
    write(io, HTML_CONTENT)

    # Write Footer of HTML function
    write(io, """
\"\"\"
end

# --- SESSION & API LOGIC ---

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
    check_auth() ? get_dashboard_html() : redirect(:login_page)
end

function api_genome_data()
    !check_auth() && return json(Dict("error" => "Unauthorized"), status=401)
    
    chrom = get(params(), :chrom, "Chr1")
    s_pos = parse(Int, get(params(), :start, "0"))
    e_pos = parse(Int, get(params(), :end, "1000000000"))
    
    features = find(GenomicFeature, SQLWhereExpression("chromosome = ? AND position >= ? AND position <= ?", chrom, s_pos, e_pos))
    
    return json(Dict("features" => [Dict("id"=>f.id, "pos"=>f.position, "val"=>f.value, "type"=>f.feature_type, "name"=>f.name) for f in features]))
end

function api_search()
    !check_auth() && return json(Dict("error" => "Unauthorized"), status=401)
    q = get(params(), :q, "")
    results = find(GenomicFeature, SQLWhereExpression("name LIKE ?", "%" * q * "%"))
    return json([Dict("name" => r.name, "chrom" => r.chromosome, "pos" => r.position) for r in results])
end

# --- FIXED EXPORT FUNCTION ---
function export_csv()
    if !check_auth() return redirect(:login_page) end
    
    chrom = get(params(), :chrom, "Chr1")
    features = find(GenomicFeature, SQLWhereExpression("chromosome = ?", chrom))
    
    df = DataFrame(
        Name = [f.name for f in features],
        Chromosome = [f.chromosome for f in features],
        Position = [f.position for f in features],
        Type = [f.feature_type for f in features],
        Value = [f.value for f in features]
    )
    
    io = IOBuffer()
    CSV.write(io, df)
    
    # Using Raw HTTP Response to avoid Genie Renderer errors
    return HTTP.Response(
        200, 
        ["Content-Type" => "text/csv", "Content-Disposition" => "attachment; filename=\\"sugarcane_export.csv\\""], 
        String(take!(io))
    )
end

end
""")
end

println("✅ Export CSV Fixed (Switched to Raw HTTP).")