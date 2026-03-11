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

US weather forecast via Nominatim geocoding + NWS (api.weather.gov).
