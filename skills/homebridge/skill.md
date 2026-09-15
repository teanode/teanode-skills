---
name: homebridge
description: "Homebridge through its own interface: the accessories it bridges, their state, and setting one"
secrets:
  - key: HOMEBRIDGE_HOST
    scope: person
    description: Where the Homebridge interface is, with its port and scheme - http://homebridge.local:8581, or an address on your own network. It is a secret rather than a parameter of the tools so that the name and password below are only ever sent to the address you set.
  - key: HOMEBRIDGE_USERNAME
    scope: person
    description: The name you sign in to the Homebridge interface with. Consider making a second account for this, with only the access you want the agent to have, rather than the one you use yourself.
  - key: HOMEBRIDGE_PASSWORD
    scope: person
    description: The password for that name. It is sent only to the host above, only to sign in, and a fresh session is taken for each call rather than kept anywhere.

# Homebridge has no command-line tool worth speaking of, so this talks to
# its interface over HTTP. That interface takes a name and a password and
# hands back a token, so every tool here signs in first and uses the token
# it was given -- a session per call, nothing kept.
#
# Note that this is commonly plain HTTP on somebody's own network. The
# password is therefore only as private as that network is, which is worth
# knowing before putting the one you use yourself in here.
tools:
  - name: homebridge_accessories
    description: Everything Homebridge bridges - each accessory's name, what kind it is, the room it is in, and the state of every characteristic it exposes. This is the place to start - it is where the unique id needed to set anything comes from.
    type: workflow
    parameters:
      type: object
      properties: {}
    steps:
      - name: sign_in
        type: http
        method: POST
        url: "{{secret:HOMEBRIDGE_HOST}}/api/auth/login"
        headers:
          Accept: application/json
          Content-Type: application/json
        body:
          username: "{{secret:HOMEBRIDGE_USERNAME}}"
          password: "{{secret:HOMEBRIDGE_PASSWORD}}"
        result: json
        select:
          token: access_token
      - name: accessories
        type: http
        method: GET
        url: "{{secret:HOMEBRIDGE_HOST}}/api/accessories"
        headers:
          Accept: application/json
          Authorization: "Bearer {{steps.sign_in.token}}"
        result: json
        maxBytes: 262144

  - name: homebridge_accessory
    description: One accessory in full, by its unique id as homebridge_accessories reports it - every characteristic, its current value, and which of them can be written.
    type: workflow
    parameters:
      type: object
      properties:
        uniqueId:
          type: string
          description: The accessory's uniqueId, as homebridge_accessories reports it
      required: ["uniqueId"]
    steps:
      - name: sign_in
        type: http
        method: POST
        url: "{{secret:HOMEBRIDGE_HOST}}/api/auth/login"
        headers:
          Accept: application/json
          Content-Type: application/json
        body:
          username: "{{secret:HOMEBRIDGE_USERNAME}}"
          password: "{{secret:HOMEBRIDGE_PASSWORD}}"
        result: json
        select:
          token: access_token
      - name: accessory
        type: http
        method: GET
        url: "{{secret:HOMEBRIDGE_HOST}}/api/accessories/{{uniqueId}}"
        headers:
          Accept: application/json
          Authorization: "Bearer {{steps.sign_in.token}}"
        result: json

  - name: homebridge_set
    description: Set one characteristic of one accessory - On to true or false, Brightness to a number, TargetTemperature, and so on. The characteristic has to be one the accessory says can be written; homebridge_accessory lists them. This changes something in the house.
    type: workflow
    parameters:
      type: object
      properties:
        uniqueId:
          type: string
          description: The accessory's uniqueId, as homebridge_accessories reports it
        characteristic:
          type: string
          description: Which characteristic to set, spelled as Homebridge spells it - On, Brightness, TargetTemperature, RotationSpeed, TargetPosition
        value:
          type: string
          description: What to set it to - true or false for On, a number for the rest
      required: ["uniqueId", "characteristic", "value"]
    steps:
      - name: sign_in
        type: http
        method: POST
        url: "{{secret:HOMEBRIDGE_HOST}}/api/auth/login"
        headers:
          Accept: application/json
          Content-Type: application/json
        body:
          username: "{{secret:HOMEBRIDGE_USERNAME}}"
          password: "{{secret:HOMEBRIDGE_PASSWORD}}"
        result: json
        select:
          token: access_token
      - name: set
        type: http
        method: PUT
        url: "{{secret:HOMEBRIDGE_HOST}}/api/accessories/{{uniqueId}}"
        headers:
          Accept: application/json
          Content-Type: application/json
          Authorization: "Bearer {{steps.sign_in.token}}"
        body:
          characteristicType: "{{characteristic}}"
          value: "{{value}}"
        result: json

  - name: homebridge_status
    description: How Homebridge itself is doing - whether it is up, how long it has been running, and what the machine it runs on is doing.
    type: workflow
    parameters:
      type: object
      properties: {}
    steps:
      - name: sign_in
        type: http
        method: POST
        url: "{{secret:HOMEBRIDGE_HOST}}/api/auth/login"
        headers:
          Accept: application/json
          Content-Type: application/json
        body:
          username: "{{secret:HOMEBRIDGE_USERNAME}}"
          password: "{{secret:HOMEBRIDGE_PASSWORD}}"
        result: json
        select:
          token: access_token
      - name: homebridge
        type: http
        method: GET
        url: "{{secret:HOMEBRIDGE_HOST}}/api/status/homebridge"
        headers:
          Accept: application/json
          Authorization: "Bearer {{steps.sign_in.token}}"
        result: json
      - name: uptime
        type: http
        method: GET
        url: "{{secret:HOMEBRIDGE_HOST}}/api/status/uptime"
        headers:
          Accept: application/json
          Authorization: "Bearer {{steps.sign_in.token}}"
        result: json
---

homebridge_accessories first, always: it is where a uniqueId comes from, and
a uniqueId is what everything else here takes. Guessing one is not possible
and not worth attempting.

Homebridge speaks HomeKit's language, so a thing is an accessory with
characteristics rather than an entity with a state: a lamp is `On` true or
false and `Brightness` a number, a blind is `TargetPosition`, a thermostat
is `TargetTemperature`. Set the one that is marked as writable, with the
spelling the accessory itself uses.

What Homebridge bridges may also be in Home Assistant, reached through the
home-assistant skill, and the two are different roads to the same lamp. If
both are set up, prefer whichever the person talks about; if they have said
nothing, Home Assistant knows the house's own names and rooms and is the
better place to start.

Nothing here edits the Homebridge configuration, installs a plugin or
restarts the server. Those are how a bridge is broken, and they are done by
somebody sitting in front of it.
