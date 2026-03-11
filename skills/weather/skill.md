---
name: weather
description: Weather forecast via the National Weather Service API (US locations)
tools:
  - name: get_weather
    description: Get weather forecast for a US location (free-form input like "Alpharetta, GA" or "Chicago, IL")
    type: workflow
    timeout: 30
    parameters:
      type: object
      properties:
        location:
          type: string
          description: "Free-form location (e.g. 'Alpharetta, GA', 'Chicago, IL', 'Portland, OR')"
      required: ["location"]
    steps:
      - name: geocode
        type: http
        method: GET
        url: "https://nominatim.openstreetmap.org/search?q={{location|urlencode}}&format=json&limit=1&countrycodes=us"
        headers:
          User-Agent: "TeaNode-Weather-Skill/1.0 (teanode-skills; github.com/teanode/teanode-skills)"
          Accept: application/json
        result: json
        extract:
          lat: "[0].lat"
          lon: "[0].lon"
          display_name: "[0].display_name"

      - name: points
        type: http
        method: GET
        url: "https://api.weather.gov/points/{{steps.geocode.lat}},{{steps.geocode.lon}}"
        headers:
          User-Agent: "TeaNode-Weather-Skill/1.0 (teanode-skills; github.com/teanode/teanode-skills)"
          Accept: application/geo+json
        result: json
        extract:
          forecast: "properties.forecast"
          forecastHourly: "properties.forecastHourly"

      - name: hourly
        type: http
        method: GET
        url: "{{steps.points.forecastHourly}}"
        headers:
          User-Agent: "TeaNode-Weather-Skill/1.0 (teanode-skills; github.com/teanode/teanode-skills)"
          Accept: application/geo+json
        result: json
        extract:
          temperature: "properties.periods[0].temperature"
          temperatureUnit: "properties.periods[0].temperatureUnit"
          windSpeed: "properties.periods[0].windSpeed"
          windDirection: "properties.periods[0].windDirection"
          shortForecast: "properties.periods[0].shortForecast"
          humidity: "properties.periods[0].relativeHumidity.value"
          precipitationChance: "properties.periods[0].probabilityOfPrecipitation.value"

      - name: daily
        type: http
        method: GET
        url: "{{steps.points.forecast}}"
        headers:
          User-Agent: "TeaNode-Weather-Skill/1.0 (teanode-skills; github.com/teanode/teanode-skills)"
          Accept: application/geo+json
        result: json
        extract:
          highTemp: "properties.periods[0].temperature"
          isDaytime: "properties.periods[0].isDaytime"
          detail: "properties.periods[0].detailedForecast"
          todayPrecip: "properties.periods[0].probabilityOfPrecipitation.value"
          lowTemp: "properties.periods[1].temperature"

    select:
      location: "{{steps.geocode.display_name}}"
      coordinates:
        lat: "{{steps.geocode.lat}}"
        lon: "{{steps.geocode.lon}}"
      current:
        temperature: "{{steps.hourly.temperature}}"
        temperatureUnit: "{{steps.hourly.temperatureUnit}}"
        windSpeed: "{{steps.hourly.windSpeed}}"
        windDirection: "{{steps.hourly.windDirection}}"
        shortForecast: "{{steps.hourly.shortForecast}}"
        humidity: "{{steps.hourly.humidity}}"
        precipitationChance: "{{steps.hourly.precipitationChance}}"
      today:
        high: "{{steps.daily.highTemp}}"
        low: "{{steps.daily.lowTemp}}"
        precipitationChance: "{{steps.daily.todayPrecip}}"
        detail: "{{steps.daily.detail}}"
      source: "National Weather Service (api.weather.gov)"
---

Get weather forecasts for US locations using the **National Weather Service** API.

Use `get_weather` with a free-form location string (city, state, or address).
The tool geocodes the input via OpenStreetMap Nominatim, then fetches the NWS
forecast through a four-step HTTP workflow:

1. **Geocode** — resolve location to coordinates via Nominatim (US only).
2. **NWS Points** — look up the NWS grid for those coordinates.
3. **Hourly forecast** — current conditions proxy (first hourly period).
4. **Daily forecast** — today's high/low and detailed outlook.

### Output format

```json
{
  "location": "Alpharetta, Fulton County, Georgia, US",
  "coordinates": { "lat": "34.0754", "lon": "-84.2941" },
  "current": {
    "temperature": 72,
    "temperatureUnit": "F",
    "windSpeed": "5 mph",
    "windDirection": "NW",
    "shortForecast": "Partly Cloudy",
    "humidity": 55,
    "precipitationChance": 10
  },
  "today": {
    "high": 78,
    "low": 58,
    "precipitationChance": 10,
    "detail": "Partly cloudy, with a high near 78..."
  },
  "source": "National Weather Service (api.weather.gov)"
}
```

### Limitations

- **US locations only.** The NWS API only covers the United States and
  territories. Non-US queries will return an error.
- **Rate limits.** NWS asks consumers to be reasonable (no hard key required).
  Nominatim requires a `User-Agent` header and asks for ≤ 1 req/sec.
- **"Current" conditions are approximate.** NWS does not expose a real-time
  current-conditions endpoint; the first hourly forecast period is used as a
  proxy.
- **Day/night periods.** The daily forecast extracts the first two periods.
  When queried after sunset, `high` reflects tonight's temperature and `low`
  reflects the next period. A future `round` or conditional filter could
  improve this.

### Framework notes

This skill uses the `workflow` tool type with `steps`, `extract`, and `select`.
The `extract` directive uses dot-path notation with bracket indices to pull
nested fields from JSON responses. The `select` directive at the workflow level
composes the final output from multiple step results.
