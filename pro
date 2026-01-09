<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Harare Command Center</title>

    <script src="https://cdn.tailwindcss.com"></script>

    <script crossorigin src="https://unpkg.com/react@18/umd/react.development.js"></script>
    <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>

    <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>

    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

    <style>
        /* Custom UI Tweaks */
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: rgba(31, 41, 55, 0.5); }
        ::-webkit-scrollbar-thumb { background: rgba(75, 85, 99, 0.8); border-radius: 3px; }
        
        .map-container { width: 100%; height: 100vh; z-index: 0; }
        
        .glass-panel {
            background: rgba(17, 24, 39, 0.85); /* More translucent */
            backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.1);
        }

        /* Marker Animations */
        .poi-marker {
            transition: transform 0.2s;
        }
        .poi-marker:hover {
            transform: scale(1.2);
            z-index: 1000 !important;
        }

        /* Toggle Switch */
        .toggle-checkbox:checked {
            right: 0;
            border-color: #10B981;
        }
        .toggle-checkbox:checked + .toggle-label {
            background-color: #10B981;
        }
        
        /* Popup Styling */
        .leaflet-popup-content-wrapper {
            background: rgba(17, 24, 39, 0.95);
            color: white;
            border: 1px solid #374151;
            border-radius: 8px;
        }
        .leaflet-popup-tip {
            background: rgba(17, 24, 39, 0.95);
        }
    </style>
</head>
<body class="bg-gray-900 text-white overflow-hidden">

    <div id="root"></div>

    <script type="text/babel">
        const { useState, useEffect, useRef } = React;

        const API_KEY = "8843db4128644049a678c9de38de9f10";

        const App = () => {
            const mapRef = useRef(null);
            const mapInstance = useRef(null);
            const routeLayer = useRef(null);
            const placesLayer = useRef(null); // For POI markers

            // State
            const [origin, setOrigin] = useState("");
            const [destination, setDestination] = useState("");
            const [mode, setMode] = useState("drive");
            const [avoidHighways, setAvoidHighways] = useState(false);
            const [instructions, setInstructions] = useState([]);
            const [summary, setSummary] = useState(null);
            const [loading, setLoading] = useState(false);
            const [activePOIs, setActivePOIs] = useState([]);

            // Default: Harare CBD
            const harareCBD = [-17.8252, 31.0335];

            // POI Categories Configuration
            const POI_TYPES = [
                { id: 'education', label: 'Schools', icon: '🎓', color: '#3b82f6', category: 'education' },
                { id: 'tourism', label: 'Monuments', icon: '🏛️', color: '#eab308', category: 'tourism.sights' },
                { id: 'commercial', label: 'Malls', icon: '🛍️', color: '#ec4899', category: 'commercial.shopping_mall' },
                { id: 'finance', label: 'Banks', icon: '🏦', color: '#22c55e', category: 'service.financial' },
            ];

            // Initialize Map
            useEffect(() => {
                if (mapRef.current && !mapInstance.current) {
                    const map = L.map(mapRef.current, { zoomControl: false }).setView(harareCBD, 13);

                    // --- LAYERS ---
                    const nightLayer = L.tileLayer(`https://maps.geoapify.com/v1/tile/dark-matter-brown/{z}/{x}/{y}.png?apiKey=${API_KEY}`, { attribution: 'Geoapify', maxZoom: 20 });
                    const dayLayer = L.tileLayer(`https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=${API_KEY}`, { attribution: 'Geoapify', maxZoom: 20 });
                    const satelliteLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', { attribution: 'Esri', maxZoom: 19 });

                    nightLayer.addTo(map);

                    // Traffic Layer
                    const trafficFlow = L.tileLayer(`https://maps.geoapify.com/v1/tile/flow/{z}/{x}/{y}.png?apiKey=${API_KEY}`, { maxZoom: 20, opacity: 1 });
                    trafficFlow.addTo(map);

                    // Controls
                    L.control.layers({ "Night Mode": nightLayer, "Day View": dayLayer, "Satellite": satelliteLayer }, { "Traffic": trafficFlow }, { position: 'topright' }).addTo(map);
                    
                    // Create layer group for Places
                    placesLayer.current = L.layerGroup().addTo(map);

                    mapInstance.current = map;
                }
            }, []);

            // Handle POI Toggle
            const togglePOI = async (typeId) => {
                const isActive = activePOIs.includes(typeId);
                let newActive = isActive ? activePOIs.filter(t => t !== typeId) : [...activePOIs, typeId];
                setActivePOIs(newActive);
                
                updateMapMarkers(newActive);
            };

            // Fetch and Update Markers
            const updateMapMarkers = async (activeTypes) => {
                if (!mapInstance.current) return;
                
                placesLayer.current.clearLayers();
                if (activeTypes.length === 0) return;

                const center = mapInstance.current.getCenter();
                // Search radius: 5km around map center
                const radius = 5000; 
                
                for (const typeId of activeTypes) {
                    const poiConfig = POI_TYPES.find(p => p.id === typeId);
                    if (!poiConfig) continue;

                    try {
                        const url = `https://api.geoapify.com/v2/places?categories=${poiConfig.category}&filter=circle:${center.lng},${center.lat},${radius}&limit=20&apiKey=${API_KEY}`;
                        const res = await fetch(url);
                        const data = await res.json();

                        if (data.features) {
                            data.features.forEach(place => {
                                const [lng, lat] = place.geometry.coordinates;
                                const name = place.properties.name || poiConfig.label;
                                const address = place.properties.formatted || "Harare";

                                // Custom Icon
                                const iconHtml = `<div style="background:${poiConfig.color}; width:30px; height:30px; border-radius:50%; display:flex; align-items:center; justify-content:center; box-shadow: 0 0 10px ${poiConfig.color}; border: 2px solid white; font-size:14px;">${poiConfig.icon}</div>`;
                                
                                const customIcon = L.divIcon({
                                    html: iconHtml,
                                    className: 'poi-marker',
                                    iconSize: [30, 30],
                                    iconAnchor: [15, 15],
                                    popupAnchor: [0, -15]
                                });

                                const marker = L.marker([lat, lng], { icon: customIcon });
                                
                                // Popup with Street View Button
                                const popupContent = `
                                    <div class="text-center min-w-[150px]">
                                        <h3 class="font-bold text-lg mb-1">${name}</h3>
                                        <p class="text-xs text-gray-400 mb-2">${address}</p>
                                        <a href="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${lat},${lng}" 
                                           target="_blank"
                                           class="inline-block bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold py-1 px-3 rounded shadow transition">
                                           👁️ Street View
                                        </a>
                                    </div>
                                `;
                                
                                marker.bindPopup(popupContent).addTo(placesLayer.current);
                            });
                        }
                    } catch (err) {
                        console.error("Error fetching POIs", err);
                    }
                }
            };

            // Locate User
            const handleLocateMe = () => {
                if (!navigator.geolocation) return alert("Geolocation not supported");
                setLoading(true);
                navigator.geolocation.getCurrentPosition((pos) => {
                    const { latitude, longitude } = pos.coords;
                    mapInstance.current.setView([latitude, longitude], 15);
                    
                    // Add User Marker
                    L.circleMarker([latitude, longitude], {
                        color: '#3b82f6', fillColor: '#60a5fa', fillOpacity: 1, radius: 8
                    }).addTo(mapInstance.current).bindPopup("You are here").openPopup();

                    setOrigin(`${latitude},${longitude}`);
                    setLoading(false);
                }, () => { alert("Location error"); setLoading(false); });
            };

            // Calculate Route
            const getRoute = async () => {
                if (!origin || !destination) return alert("Enter Origin & Destination");
                setLoading(true);
                try {
                    // 1. Geocode Destination (if not coords)
                    let destCoords = destination;
                    if (!destination.includes(",")) {
                        const geoRes = await fetch(`https://api.geoapify.com/v1/geocode/search?text=${encodeURIComponent(destination)}&filter=countrycode:zw&apiKey=${API_KEY}`);
                        const geoData = await geoRes.json();
                        if (geoData.features?.[0]) {
                            const p = geoData.features[0].properties;
                            destCoords = `${p.lat},${p.lon}`;
                        } else {
                            throw new Error("Destination not found");
                        }
                    }

                    // 2. Routing API
                    let url = `https://api.geoapify.com/v1/routing?waypoints=${origin}|${destCoords}&mode=${mode}&details=instruction_details&traffic=approximated&apiKey=${API_KEY}`;
                    if (avoidHighways) url += "&avoid=highways";

                    const res = await fetch(url);
                    const data = await res.json();

                    if (data.features?.[0]) {
                        const route = data.features[0];
                        if (routeLayer.current) mapInstance.current.removeLayer(routeLayer.current);

                        routeLayer.current = L.geoJSON(route, {
                            style: { color: mode === 'walk' ? '#60a5fa' : (avoidHighways ? '#d946ef' : '#22c55e'), weight: 6 }
                        }).addTo(mapInstance.current);

                        mapInstance.current.fitBounds(routeLayer.current.getBounds(), { padding: [50, 50] });
                        setInstructions(route.properties.legs[0].steps);
                        
                        const mins = Math.round(route.properties.time / 60);
                        const hrs = Math.floor(mins / 60);
                        const remMins = mins % 60;
                        setSummary({ 
                            time: hrs > 0 ? `${hrs}h ${remMins}m` : `${mins} min`, 
                            dist: (route.properties.distance / 1000).toFixed(1) + " km" 
                        });
                    } else {
                        alert("No route found");
                    }
                } catch (err) {
                    alert(err.message || "Routing Error");
                }
                setLoading(false);
            };

            // Voice
            const speak = (text) => {
                window.speechSynthesis.cancel();
                window.speechSynthesis.speak(new SpeechSynthesisUtterance(text));
            };

            return (
                <div className="relative h-screen w-full flex flex-col md:flex-row">
                    
                    {/* Control Panel */}
                    <div className="glass-panel w-full md:w-[400px] p-4 flex flex-col h-[60%] md:h-full z-20 shadow-2xl absolute md:relative top-0 left-0 order-2 md:order-1 transition-all">
                        <div className="mb-4 flex justify-between items-center">
                            <h1 className="text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-red-500 to-yellow-500">
                                HARARE NAV
                            </h1>
                            <div className="text-xs bg-red-600 px-2 py-1 rounded text-white font-bold animate-pulse">LIVE</div>
                        </div>

                        {/* Navigation Inputs */}
                        <div className="bg-gray-800/50 p-3 rounded-xl mb-4 border border-gray-700">
                            <div className="flex gap-2 mb-2">
                                <input className="w-full bg-gray-900 border border-gray-600 rounded-lg p-2 text-sm focus:border-blue-500 outline-none" 
                                    placeholder="Start Point..." value={origin} onChange={(e) => setOrigin(e.target.value)} />
                                <button onClick={handleLocateMe} className="bg-blue-600 hover:bg-blue-500 p-2 rounded-lg text-white">📍</button>
                            </div>
                            <input className="w-full bg-gray-900 border border-gray-600 rounded-lg p-2 text-sm focus:border-blue-500 outline-none mb-3" 
                                placeholder="Where to? (e.g. Avondale)" value={destination} onChange={(e) => setDestination(e.target.value)} />

                            <div className="flex justify-between items-center mb-3">
                                <div className="flex bg-gray-900 rounded-lg p-1">
                                    <button onClick={() => setMode('drive')} className={`px-3 py-1 rounded-md text-xs font-bold transition ${mode === 'drive' ? 'bg-gray-700 text-white' : 'text-gray-400'}`}>🚗 Drive</button>
                                    <button onClick={() => setMode('walk')} className={`px-3 py-1 rounded-md text-xs font-bold transition ${mode === 'walk' ? 'bg-gray-700 text-white' : 'text-gray-400'}`}>🚶 Walk</button>
                                </div>
                                <label className="flex items-center gap-2 cursor-pointer">
                                    <span className="text-xs text-gray-400">Back Roads</span>
                                    <input type="checkbox" checked={avoidHighways} onChange={() => setAvoidHighways(!avoidHighways)} className="accent-purple-500 h-4 w-4" />
                                </label>
                            </div>

                            <button onClick={getRoute} disabled={loading} 
                                className="w-full bg-gradient-to-r from-yellow-500 to-orange-500 hover:from-yellow-400 hover:to-orange-400 text-black font-bold py-2 rounded-lg shadow-lg transform transition hover:scale-[1.02]">
                                {loading ? "CALCULATING..." : "GET DIRECTIONS"}
                            </button>
                        </div>

                        {/* Points of Interest Toggles */}
                        <div className="mb-4">
                            <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Show Nearby Places</h3>
                            <div className="grid grid-cols-4 gap-2">
                                {POI_TYPES.map((type) => (
                                    <button 
                                        key={type.id}
                                        onClick={() => togglePOI(type.id)}
                                        className={`flex flex-col items-center justify-center p-2 rounded-lg border transition-all ${activePOIs.includes(type.id) ? 'bg-gray-700 border-white/50 text-white' : 'bg-gray-800/30 border-gray-700 text-gray-500 hover:bg-gray-800'}`}
                                    >
                                        <span className="text-lg mb-1">{type.icon}</span>
                                        <span className="text-[10px] font-medium">{type.label}</span>
                                    </button>
                                ))}
                            </div>
                        </div>

                        {/* Route Summary & Instructions */}
                        {summary && (
                            <div className="flex-grow overflow-hidden flex flex-col">
                                <div className="bg-gray-800/80 p-3 rounded-t-xl border-b border-gray-700 flex justify-between items-center">
                                    <div>
                                        <div className="text-2xl font-bold text-white">{summary.time}</div>
                                        <div className="text-xs text-gray-400">{summary.dist}</div>
                                    </div>
                                    <div className="text-right">
                                        <div className="text-xs bg-green-900 text-green-300 px-2 py-1 rounded">Fastest Route</div>
                                    </div>
                                </div>
                                <div className="overflow-y-auto flex-grow bg-gray-900/50 rounded-b-xl p-2 space-y-1">
                                    {instructions.map((step, idx) => (
                                        <div key={idx} onClick={() => speak(step.instruction.text)} 
                                            className="p-3 hover:bg-gray-700 rounded cursor-pointer group flex gap-3 transition">
                                            <div className="mt-1 text-gray-500 group-hover:text-white">➤</div>
                                            <div>
                                                <p className="text-sm text-gray-300 group-hover:text-white">{step.instruction.text}</p>
                                                <p className="text-xs text-gray-600">{step.distance}m</p>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}
                    </div>

                    {/* Map Area */}
                    <div className="flex-grow h-[40%] md:h-full relative order-1 md:order-2">
                        <div ref={mapRef} className="map-container h-full w-full" />
                        
                        {/* Traffic Signs / Legend */}
                        <div className="absolute top-4 right-14 bg-gray-900/90 backdrop-blur p-3 rounded-lg border border-gray-700 shadow-xl z-[400] text-xs">
                            <div className="font-bold mb-2 text-gray-300">Traffic Status</div>
                            <div className="space-y-1">
                                <div className="flex items-center gap-2"><div className="w-8 h-1.5 bg-green-500 rounded-full"></div> <span className="text-green-400">Free Flow</span></div>
                                <div className="flex items-center gap-2"><div className="w-8 h-1.5 bg-orange-500 rounded-full"></div> <span className="text-orange-400">Moderate</span></div>
                                <div className="flex items-center gap-2"><div className="w-8 h-1.5 bg-red-600 rounded-full"></div> <span className="text-red-400">Heavy Jam</span></div>
                            </div>
                        </div>
                    </div>
                </div>
            );
        };

        const root = ReactDOM.createRoot(document.getElementById('root'));
        root.render(<App />);
    </script>
</body>
</html>
