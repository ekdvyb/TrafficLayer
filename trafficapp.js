import React, { useState, useEffect } from 'react';
import { GoogleMap, useJsApiLoader, TrafficLayer, DistanceMatrixService } from '@react-google-maps/api';

const containerStyle = { width: '100%', height: '70vh' };
const center = { lat: -17.8252, lng: 31.0335 }; // Harare CBD

const HarareTrafficApp = () => {
  const { isLoaded } = useJsApiLoader({
    id: 'google-map-script',
    googleMapsApiKey: "YOUR_GOOGLE_MAPS_API_KEY"
  });

  const [travelTimes, setTravelTimes] = useState([
    { id: 1, route: "CBD to Chitungwiza (Seke Rd)", time: "Loading...", status: "Checking" },
    { id: 2, route: "CBD to Norton (Bulawayo Rd)", time: "Loading...", status: "Checking" },
    { id: 3, route: "CBD to Ruwa (Mutare Rd)", time: "Loading...", status: "Checking" },
  ]);

  // Logic to fetch travel times for the "In/Out" Dashboard
  const handleDistanceResponse = (response, index) => {
    if (response !== null && response.rows[0].elements[0].status === 'OK') {
      const newTimes = [...travelTimes];
      newTimes[index].time = response.rows[0].elements[0].duration_in_traffic.text;
      newTimes[index].status = "Real-time";
      setTravelTimes(newTimes);
    }
  };

  return isLoaded ? (
    <div className="flex flex-col h-screen bg-gray-900 text-white font-sans">
      {/* Header */}
      <header className="p-4 bg-red-600 shadow-lg">
        <h1 className="text-xl font-bold text-center">HARARE TRAFFIC WATCH</h1>
      </header>

      {/* Real-time Map */}
      <div className="flex-grow">
        <GoogleMap mapContainerStyle={containerStyle} center={center} zoom={12}>
          <TrafficLayer /> {/* This renders the Red/Yellow/Green lines automatically */}
        </GoogleMap>
      </div>

      {/* Traffic Dashboard (In and Out of Harare) */}
      <div className="p-4 bg-gray-800 rounded-t-3xl -mt-6 z-10 overflow-y-auto">
        <h2 className="text-lg font-semibold mb-3">Live Commute Times</h2>
        <div className="space-y-3">
          {travelTimes.map((item, index) => (
            <div key={item.id} className="flex justify-between items-center bg-gray-700 p-3 rounded-lg">
              <div>
                <p className="text-sm font-medium">{item.route}</p>
                <p className="text-xs text-gray-400">{item.status}</p>
              </div>
              <div className="text-green-400 font-bold text-lg">{item.time}</div>
              
              {/* Invisible Service to fetch data */}
              <DistanceMatrixService
                options={{
                  destinations: [item.route.split("to ")[1]],
                  origins: ["Harare CBD"],
                  travelMode: "DRIVING",
                  drivingOptions: { departureTime: new Date(), trafficModel: 'bestguess' }
                }}
                callback={(res) => handleDistanceResponse(res, index)}
              />
            </div>
          ))}
        </div>
      </div>
      
      {/* Quick Report Button for Harare Drivers */}
      <button className="fixed bottom-6 right-6 bg-yellow-500 p-4 rounded-full shadow-2xl text-black font-bold">
        REPORT CLOG
      </button>
    </div>
  ) : <div className="flex h-screen items-center justify-center bg-gray-900 text-white">Loading Harare Map...</div>;
};

export default HarareTrafficApp;
