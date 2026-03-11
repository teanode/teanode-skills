---
name: weather
description: Weather forecast via the National Weather Service API (US locations)
tools:
  - name: get_weather
    description: Get weather forecast for a US location (free-form input like "Alpharetta, GA" or "Chicago, IL")
    type: shell
    command:
      - "python3"
      - "-c"
      - |
        import json, sys, urllib.request, urllib.parse, os, hashlib, time, pathlib

        location = sys.argv[1]

        UA = "TeaNode-Weather-Skill/1.0 (teanode-skills; github.com/teanode/teanode-skills)"

        # --- Simple disk cache ---
        CACHE_DIR = pathlib.Path(os.environ.get("TEANODE_CACHE_DIR", "/tmp/teanode-weather-cache"))
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        CACHE_TTL = 600  # 10 minutes

        def cache_key(url):
            return hashlib.sha256(url.encode()).hexdigest()

        def cache_get(url):
            p = CACHE_DIR / cache_key(url)
            if p.exists() and (time.time() - p.stat().st_mtime) < CACHE_TTL:
                return json.loads(p.read_text())
            return None

        def cache_set(url, data):
            p = CACHE_DIR / cache_key(url)
            p.write_text(json.dumps(data))

        def fetch_json(url, ua=UA):
            cached = cache_get(url)
            if cached is not None:
                return cached
            req = urllib.request.Request(url, headers={"User-Agent": ua, "Accept": "application/geo+json"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
            cache_set(url, data)
            return data

        # 1. Geocode via Nominatim
        geo_url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode({
            "q": location, "format": "json", "limit": "1", "countrycodes": "us"
        })
        geo = fetch_json(geo_url)
        if not geo:
            print(json.dumps({"error": "Location not found. Provide a US city/state (e.g. 'Atlanta, GA')."}))
            sys.exit(0)

        lat = round(float(geo[0]["lat"]), 4)
        lon = round(float(geo[0]["lon"]), 4)
        display_name = geo[0].get("display_name", location)

        # 2. NWS Points
        points_url = f"https://api.weather.gov/points/{lat},{lon}"
        points = fetch_json(points_url)
        props = points.get("properties", {})
        forecast_hourly_url = props.get("forecastHourly")
        forecast_url = props.get("forecast")
        if not forecast_hourly_url or not forecast_url:
            print(json.dumps({"error": "NWS has no forecast data for this location. NWS covers US only."}))
            sys.exit(0)

        # 3. Fetch hourly forecast (current conditions proxy) and regular forecast (day summary)
        hourly = fetch_json(forecast_hourly_url)
        daily = fetch_json(forecast_url)

        hourly_periods = hourly.get("properties", {}).get("periods", [])
        daily_periods = daily.get("properties", {}).get("periods", [])

        # Current conditions from first hourly period
        current = {}
        if hourly_periods:
            h = hourly_periods[0]
            current = {
                "temperature": h.get("temperature"),
                "temperatureUnit": h.get("temperatureUnit"),
                "windSpeed": h.get("windSpeed"),
                "windDirection": h.get("windDirection"),
                "shortForecast": h.get("shortForecast"),
                "humidity": h.get("relativeHumidity", {}).get("value"),
                "precipitationChance": h.get("probabilityOfPrecipitation", {}).get("value"),
            }

        # Today high/low and precip from daily forecast
        today_high = None
        today_low = None
        today_precip = None
        today_detail = None
        for p in daily_periods[:2]:
            temp = p.get("temperature")
            if p.get("isDaytime"):
                today_high = temp
                today_detail = p.get("detailedForecast")
                pc = p.get("probabilityOfPrecipitation", {}).get("value")
                if pc is not None:
                    today_precip = pc
            else:
                today_low = temp

        result = {
            "location": display_name,
            "coordinates": {"lat": lat, "lon": lon},
            "current": current,
            "today": {
                "high": today_high,
                "low": today_low,
                "precipitationChance": today_precip,
                "detail": today_detail,
            },
            "source": "National Weather Service (api.weather.gov)",
        }
        print(json.dumps(result, indent=2))
      - "{{location}}"
    timeout: 30
    parameters:
      type: object
      properties:
        location:
          type: string
          description: "Free-form location (e.g. 'Alpharetta, GA', 'Chicago, IL', 'Portland, OR')"
      required: ["location"]
---

Get weather forecasts for US locations using the **National Weather Service** API.

Use `get_weather` with a free-form location string (city, state, or address).
The tool geocodes the input via OpenStreetMap Nominatim, then fetches the NWS
forecast.

### Limitations

- **US locations only.** The NWS API only covers the United States and
  territories. Non-US queries will return an error.
- **Rate limits.** NWS asks consumers to be reasonable (no hard key required).
  Nominatim requires a `User-Agent` header and asks for ≤ 1 req/sec. Results
  are cached for 10 minutes to stay well within limits.
- **"Current" conditions are approximate.** NWS does not expose a real-time
  current-conditions endpoint; the first hourly forecast period is used as a
  proxy.
