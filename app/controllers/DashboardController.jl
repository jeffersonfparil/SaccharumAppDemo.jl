module DashboardController
using Genie
using Genie.Renderer
using Genie.Renderer.Html
using Genie.Renderer.Json
using Genie.Requests
using Genie.Router
using SearchLight
using DataFrames
using CSV
using ..App.Genomics
using ..App.SimpleSession

# --- HELPER: RAW HTML STRING ---
function get_dashboard_html()
    return """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Sugarcane Genome</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
    <style>body { font-family: sans-serif; }</style>
</head>
<body class="bg-gray-100">

<div class="flex flex-col h-screen">
    <nav class="bg-green-800 text-white p-4 flex justify-between items-center shadow-md">
        <div class="font-bold text-lg">🌱 Sugarcane Genome</div>
        <div class="flex gap-4 items-center">
            <div class="relative">
                <input id="search" type="text" placeholder="Search..." class="px-2 py-1 rounded text-black w-64 border border-gray-300 focus:outline-none focus:ring-2 focus:ring-green-500">
                <div id="searchRes" class="absolute bg-white text-black w-full shadow-lg hidden z-10 rounded-b mt-1 max-h-60 overflow-y-auto"></div>
            </div>
            <a href="/logout" class="text-sm hover:underline text-red-200">Logout</a>
        </div>
    </nav>

    <div class="p-4 flex gap-4 bg-white border-b items-center shadow-sm z-0">
        <label class="font-semibold text-gray-700">Chromosome:</label>
        <select id="chrom" class="border p-1 rounded bg-gray-50">
            <option>Chr1</option>
            <option>Chr2</option>
            <option>Chr3</option>
        </select>
        <button onclick="load()" class="bg-green-600 hover:bg-green-700 text-white px-4 py-1 rounded shadow transition">Refresh Data</button>
        <button onclick="dl()" class="ml-auto bg-gray-600 hover:bg-gray-700 text-white px-4 py-1 rounded shadow transition">Export CSV</button>
    </div>

    <div class="flex-grow p-4 flex flex-col gap-4 overflow-hidden">
        <div id="plot" class="bg-white p-2 rounded shadow h-1/2 border border-gray-200"></div>
        
        <div class="bg-white p-2 rounded shadow h-1/2 flex flex-col border border-gray-200">
            <h3 class="font-bold p-2 border-b text-gray-700">Region Details <span id="count" class="text-xs text-gray-500 font-normal"></span></h3>
            <div class="overflow-auto flex-grow">
                <table class="w-full text-sm text-left">
                    <thead class="bg-gray-100 sticky top-0 text-gray-600 uppercase text-xs">
                        <tr><th class="p-3">Name</th><th class="p-3">Type</th><th class="p-3">Pos</th><th class="p-3">Value</th></tr>
                    </thead>
                    <tbody id="tbl" class="divide-y divide-gray-100"></tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<script>
    let currentData = [];

    async function load() {
        console.log("Loading data...");
        const chrom = document.getElementById('chrom').value;
        const layout = document.getElementById('plot').layout;
        let s = 0;
        let e = 100000000;
        
        if(layout && layout.xaxis && layout.xaxis.range) { 
            s = Math.floor(layout.xaxis.range[0]); 
            e = Math.floor(layout.xaxis.range[1]); 
        }
        
        const url = '/api/data?chrom=' + chrom + '&start=' + s + '&end=' + e;
        
        try {
            const res = await fetch(url);
            if (!res.ok) {
                if (res.status === 401) {
                    alert("Session expired. Please log in again.");
                    window.location.href = "/login";
                    return;
                }
                throw new Error("API Error: " + res.status);
            }
            
            const json = await res.json();
            
            if (!json.features) {
                console.error("Invalid JSON:", json);
                return;
            }

            currentData = json.features;
            console.log("Loaded features:", currentData.length);
            document.getElementById('count').innerText = '(' + currentData.length + ' records)';
            
            draw(currentData, chrom);
            tabulate(currentData);
            
        } catch (err) {
            console.error(err);
            alert("Failed to load data: " + err.message);
        }
    }

    function draw(data, chrom) {
        const traces = {};
        
        if (data.length === 0) {
            Plotly.react('plot', [], { 
                title: 'No Data for ' + chrom, 
                xaxis: {title: 'Position (bp)', range: [0, 100000000]}, 
                yaxis: {title: 'Value'}
            });
            return;
        }

        data.forEach(d => {
            if(!traces[d.type]) {
                traces[d.type] = {
                    x: [], y: [], text: [], 
                    mode: 'markers', 
                    name: d.type, 
                    type: 'scatter',
                    marker: { size: 6 }
                };
            }
            traces[d.type].x.push(d.pos);
            traces[d.type].y.push(d.val);
            traces[d.type].text.push(d.name);
        });
        
        const plotData = Object.values(traces);
        const layout = { 
            title: 'Genome Browser: ' + chrom, 
            dragmode: 'zoom', 
            xaxis: {title: 'Position (bp)'}, 
            yaxis: {title: 'Value'},
            hovermode: 'closest' 
        };
        
        Plotly.react('plot', plotData, layout);
        
        document.getElementById('plot').on('plotly_relayout', function(e) {
            if(e['xaxis.range[0]']) {
                const s = e['xaxis.range[0]'];
                const end = e['xaxis.range[1]'];
                const visible = currentData.filter(d => d.pos >= s && d.pos <= end);
                tabulate(visible);
            } else if (e['xaxis.autorange']) {
                tabulate(currentData);
            }
        });
    }

    function tabulate(data) {
        const rows = data.slice(0, 200).map(d => {
            return '<tr class="hover:bg-green-50 transition">' + 
                   '<td class="p-3 font-mono text-green-700">' + d.name + '</td>' +
                   '<td class="p-3">' + d.type + '</td>' +
                   '<td class="p-3 text-gray-600">' + d.pos + '</td>' +
                   '<td class="p-3 font-bold">' + d.val.toFixed(3) + '</td>' +
                   '</tr>';
        }).join('');
        
        document.getElementById('tbl').innerHTML = rows;
    }

    function dl() { 
        const chrom = document.getElementById('chrom').value;
        window.location.href = '/api/export_csv?chrom=' + chrom; 
    }

    document.getElementById('search').addEventListener('input', async (e) => {
        const q = e.target.value;
        const div = document.getElementById('searchRes');
        
        if(q.length < 2) { 
            div.classList.add('hidden'); 
            return; 
        }
        
        const res = await fetch('/api/search?q=' + q);
        const data = await res.json();
        
        const html = data.map(d => {
            return '<div class="p-2 hover:bg-green-100 cursor-pointer border-b" onclick="jump(\'' + d.chrom + '\', ' + d.pos + ')">' + 
                   '<strong>' + d.name + '</strong> <span class="text-xs text-gray-500">(' + d.chrom + ')</span>' + 
                   '</div>';
        }).join('');
        
        div.innerHTML = html;
        div.classList.remove('hidden');
    });

    function jump(chrom, pos) {
        document.getElementById('chrom').value = chrom;
        load().then(() => { 
            Plotly.relayout('plot', {'xaxis.range': [pos-50000, pos+50000]}); 
        });
        document.getElementById('searchRes').classList.add('hidden');
        document.getElementById('search').value = '';
    }

    load();
</script>

</body>
</html>
    """
end

# --- CONTROLLER LOGIC ---

function get_session_token()
    if !haskey(Genie.Router.params(), :REQUEST)
        return nothing
    end
    req = Genie.Router.params(:REQUEST)
    cookie_str = ""
    if hasproperty(req, :headers)
        for (k, v) in req.headers
            if lowercase(string(k)) == "cookie"
                cookie_str = v
                break
            end
        end
    end
    if isempty(cookie_str) return nothing end
    m = match(r"session_token=([a-zA-Z0-9]+)", cookie_str)
    return isnothing(m) ? nothing : m.captures[1]
end

function check_auth()
    token = get_session_token()
    if isnothing(token) return false end
    uid = SimpleSession.get_user(token)
    return !isnothing(uid)
end

function index()
    if !check_auth() 
        return redirect(:login_page) 
    end
    return get_dashboard_html()
end

function api_genome_data()
    # Debug Logging
    println("API Call: Get Data")
    if !check_auth() 
        println("API: Unauthorized")
        return Genie.Renderer.Json.json(Dict("error" => "Unauthorized"), status=401) 
    end
    
    start_pos = parse(Int, get(params(), :start, "0"))
    end_pos = parse(Int, get(params(), :end, "1000000000"))
    chrom = get(params(), :chrom, "Chr1")
    
    # FIX: Used correct variable names start_pos and end_pos
    println("API: Querying $chrom ($start_pos - $end_pos)")
    
    features = find(GenomicFeature, SQLWhereExpression("chromosome = ? AND position >= ? AND position <= ?", chrom, start_pos, end_pos))
    println("API: Found $(length(features)) features")
    
    return Genie.Renderer.Json.json(Dict("features" => [Dict("id"=>f.id, "pos"=>f.position, "val"=>f.value, "type"=>f.feature_type, "name"=>f.name) for f in features]))
end

function api_search()
    if !check_auth() return Genie.Renderer.Json.json(Dict("error" => "Unauthorized"), status=401) end
    term = get(params(), :q, "")
    results = find(GenomicFeature, SQLWhereExpression("name LIKE ?", "%$(term)%"))
    return Genie.Renderer.Json.json([Dict("name" => r.name, "chrom" => r.chromosome, "pos" => r.position) for r in results])
end

function export_csv()
    if !check_auth() return redirect(:login_page) end
    chrom = get(params(), :chrom, "Chr1")
    features = find(GenomicFeature, SQLWhereExpression("chromosome = ?", chrom))
    df = DataFrame(Name=[f.name for f in features], Chromosome=[f.chromosome for f in features], Position=[f.position for f in features], Type=[f.feature_type for f in features], Value=[f.value for f in features])
    io = IOBuffer()
    CSV.write(io, df)
    return Genie.Renderer.respond(String(take!(io)), headers = Dict("Content-Type" => "text/csv", "Content-Disposition" => "attachment; filename=\"genome_data.csv\""))
end
end
