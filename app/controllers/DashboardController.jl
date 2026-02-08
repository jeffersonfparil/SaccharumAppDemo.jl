module DashboardController

using Genie, Genie.Renderer, Genie.Renderer.Html, Genie.Renderer.Json
using Genie.Requests, Genie.Router, SearchLight, DataFrames, CSV, HTTP
using ..App.Genomics, ..App.SimpleSession

# --- RENDERER ---
function get_dashboard_html()
    return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Genomic Breeding Portal | QAAFI Sugarcane</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
    <style>
        body { font-family: 'Inter', system-ui, -apple-system, sans-serif; }
        
        /* UQ PALETTE */
        .bg-uq-purple  { background-color: #51247a; }
        .text-uq-purple{ color: #51247a; }
        .bg-uq-magenta { background-color: #962a8b; }
        .bg-uq-green   { background-color: #2ea836; }
        .bg-uq-orange  { background-color: #eb602b; }
        .bg-uq-blue    { background-color: #4085c6; }
        
        .loader { border-top-color: #962a8b; -webkit-animation: spinner 1.5s linear infinite; animation: spinner 1.5s linear infinite; }
        @keyframes spinner { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body class="bg-gray-50 flex flex-col h-screen">

    <header class="bg-uq-purple text-white p-3 shadow-lg flex-none">
        <div class="container mx-auto flex justify-between items-center">
            <div class="flex items-center space-x-4">
                <div class="border-r border-purple-400 pr-4">
                    <h1 class="text-xl font-bold tracking-tight">QAAFI</h1>
                    <p class="text-xs uppercase tracking-widest text-purple-200">Centre for Crop Science</p>
                </div>
                <h2 class="text-lg font-medium">Sugarcane Genetics Portal</h2>
            </div>
            <div class="flex items-center gap-4">
                <div id="loading" class="hidden flex items-center gap-2 bg-white text-uq-magenta px-3 py-1 rounded text-xs font-bold shadow-sm">
                    <div class="loader ease-linear rounded-full border-2 border-t-2 border-gray-100 h-4 w-4"></div>
                    Processing...
                </div>
                
                <a href="/igv" class="text-white hover:text-gray-200 font-bold text-sm mr-2 border-r border-purple-400 pr-4 flex items-center gap-1">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path></svg>
                    Genome Browser (IGV)
                </a>

                <a href="/logout" class="bg-uq-orange hover:bg-opacity-90 text-white px-4 py-2 rounded text-sm transition font-bold shadow-sm">
                    Sign Out
                </a>
            </div>
        </div>
    </header>

    <div class="bg-white border-b p-4 shadow-sm flex-none z-20">
        <div class="container mx-auto flex flex-wrap justify-between items-center gap-4">
            <div class="flex items-center space-x-4">
                <div class="flex flex-col">
                    <label class="text-xs font-bold text-gray-400 uppercase tracking-wide">Chromosome</label>
                    <select id="chrom" onchange="load()" class="border-2 border-gray-200 rounded p-2 text-sm font-bold text-gray-700 focus:border-uq-purple outline-none bg-gray-50">
                        <option value="Chr1">Chr1 (S. officinarum)</option>
                        <option value="Chr2">Chr2 (S. officinarum)</option>
                        <option value="Chr3">Chr3 (S. officinarum)</option>
                    </select>
                </div>
                <button onclick="load()" class="mt-4 bg-uq-green hover:bg-opacity-90 text-white px-6 py-2 rounded font-bold shadow transition transform active:scale-95 flex items-center gap-2">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg>
                    Refresh Track
                </button>
            </div>
            
            <div class="relative w-96">
                <label class="text-xs font-bold text-gray-400 uppercase tracking-wide">Search Markers</label>
                <input id="search" type="text" placeholder="e.g. SNP_100, GWAS..." class="w-full border-2 border-gray-200 rounded p-2 text-sm focus:border-uq-magenta outline-none transition text-gray-700">
                <div id="searchRes" class="absolute bg-white w-full shadow-xl hidden z-50 border border-gray-100 mt-1 max-h-64 overflow-y-auto rounded-b"></div>
            </div>
            
            <button onclick="dl()" class="mt-4 bg-uq-blue hover:bg-opacity-90 text-white px-4 py-2 rounded text-sm font-bold flex items-center gap-2 shadow-sm transition">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>
                Export CSV
            </button>
        </div>
    </div>

    <main class="flex-grow p-4 overflow-hidden flex flex-col gap-4 relative bg-gray-50">
        
        <section class="bg-white rounded-xl shadow-sm border border-gray-200 flex-grow h-1/2 relative p-2">
            <div id="plot" class="w-full h-full"></div>
            <div id="empty-state" class="hidden absolute inset-0 flex items-center justify-center bg-white bg-opacity-95 z-10 rounded-xl">
                <div class="text-center">
                    <div class="mx-auto w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mb-3">
                        <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
                    </div>
                    <h3 class="text-lg font-bold text-gray-600">No Data Found</h3>
                    <p class="text-sm text-gray-400">Try selecting a different region or chromosome.</p>
                </div>
            </div>
        </section>
        
        <section class="bg-white rounded-xl shadow-sm border border-gray-200 flex-grow h-1/2 flex flex-col overflow-hidden">
            <div class="p-3 border-b border-gray-100 bg-gray-50 flex justify-between items-center flex-none rounded-t-xl">
                <h3 class="font-bold text-uq-purple text-sm uppercase tracking-wide">Feature Table</h3>
                <span id="count" class="text-xs font-bold bg-purple-50 text-uq-purple px-2 py-1 rounded border border-purple-100">0 records</span>
            </div>
            <div class="overflow-auto flex-grow">
                <table class="w-full text-left border-collapse">
                    <thead class="bg-gray-50 sticky top-0 text-xs uppercase text-gray-500 font-bold tracking-wider">
                        <tr>
                            <th class="p-3 border-b border-gray-200">Name</th>
                            <th class="p-3 border-b border-gray-200">Type</th>
                            <th class="p-3 border-b border-gray-200">Position (bp)</th>
                            <th class="p-3 border-b border-gray-200">Value (0-1)</th>
                        </tr>
                    </thead>
                    <tbody id="tbl" class="text-sm divide-y divide-gray-50"></tbody>
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
            const colors = {
                'marker': '#51247a',  // Purple
                'gene':   '#2ea836',  // Green
                'gwas_peak': '#eb602b', // Orange
                'default': '#4085c6'   // Blue
            };

            data.forEach(d => {
                if(!traces[d.type]) {
                    traces[d.type] = { 
                        x:[], y:[], text:[], 
                        mode:'markers', 
                        name:d.type, 
                        type:'scatter',
                        marker: { size: 8, opacity: 0.8, color: colors[d.type] || colors['default'] }
                    };
                }
                traces[d.type].x.push(d.pos); 
                traces[d.type].y.push(d.val); 
                traces[d.type].text.push(d.name);
            });
            
            const layout = { 
                title: false,
                xaxis: { title: 'Physical Position (bp)', gridcolor: '#f9fafb' },
                yaxis: { title: 'Signal Intensity', range: [0, 1], fixedrange: true, gridcolor: '#f9fafb' },
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
                       '<td class="p-3 font-mono font-bold text-uq-purple">' + d.name + '</td>' +
                       '<td class="p-3"><span class="bg-gray-100 text-gray-600 px-2 py-0.5 rounded text-xs font-bold uppercase tracking-wide">' + d.type + '</span></td>' +
                       '<td class="p-3 text-gray-500">' + d.pos.toLocaleString() + '</td>' +
                       '<td class="p-3 font-medium text-gray-800">' + d.val.toFixed(4) + '</td>' +
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
                    const res = await fetch('/api/search?q=' + q);
                    const results = await res.json();
                    
                    if(results.length === 0) {
                         searchRes.innerHTML = '<div class="p-3 text-sm text-gray-400">No matches found</div>';
                    } else {
                        searchRes.innerHTML = results.slice(0, 15).map(d => 
                            '<div class="p-3 hover:bg-purple-50 cursor-pointer text-sm border-b border-gray-50 flex justify-between group" onclick="jump(\\'' + d.chrom + '\\',' + d.pos + ')">' + 
                            '<span class="font-bold text-gray-700 group-hover:text-uq-purple">' + d.name + '</span>' + 
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
    return HTTP.Response(200, ["Content-Type" => "text/csv", "Content-Disposition" => "attachment; filename=\"sugarcane_export.csv\""], String(take!(io)))
end

end
