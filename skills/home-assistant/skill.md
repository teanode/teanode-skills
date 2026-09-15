---
name: home-assistant
description: "Your own Home Assistant: ask it something, read one thing's state, call a service, look at a camera"
secrets:
  - key: HOME_ASSISTANT_URL
    scope: person
    description: Where your Home Assistant is, with the scheme and the port if it has one - https://home.example.com, or http://homeassistant.local:8123. It is a secret rather than a parameter of the tools so that the token below is only ever sent to the address you set, never one named in a request.
  - key: HOME_ASSISTANT_TOKEN
    scope: person
    description: A long-lived access token. Make one in Home Assistant under your own profile, Security, at the bottom. It can do anything your account can do in the house, so consider making the account it belongs to a limited one.

# A house is one person's, so both of these are theirs: their address, their
# token, their doors and lights. Scoping them together is also what keeps the
# token safe -- a host one person named could otherwise be handed a
# credential somebody else provided.
authenticationProfiles:
  home:
    type: bearer
    token: "{{secret:HOME_ASSISTANT_TOKEN}}"
tools:
  # Home Assistant already knows the house: which lights are in the kitchen,
  # what somebody calls the back door, which of it is on. Asking it in words
  # is better than listing eight hundred entities here and working it out
  # again at this end -- and it is the same sentence the person would have
  # said to it themselves.
  - name: home_ask
    description: Ask the person's Home Assistant something, or tell it to do something, in one plain sentence - "is the garage door open", "turn off the kitchen lights", "what is the temperature upstairs", "which lights are on". It resolves the names itself, so say what the person said rather than an entity id. It answers in a sentence. Use this first; the other tools are for when you already know the exact entity.
    type: http
    method: POST
    url: "{{secret:HOME_ASSISTANT_URL}}/api/conversation/process"
    auth: home
    headers:
      Accept: application/json
    body:
      text: "{{text}}"
      language: "{{language}}"
    result: json
    select:
      answer: response.speech.plain.speech
      kind: response.response_type
    parameters:
      type: object
      properties:
        text:
          type: string
          description: What to ask or tell it, as a person would say it
        language:
          type: string
          default: en
          description: The language of that sentence, as a code like en or ja
      required: ["text"]

  # Everything the house has, a domain at a time. /api/states answers with
  # all of it -- a third of a megabyte here, most of it attributes nobody
  # asked for -- so this asks Home Assistant to render just the three things
  # that matter instead. The template is fixed: the only part of it that
  # comes from the call is the domain, as a value, so there is no Jinja for
  # anybody to write at this end.
  - name: home_list
    description: List what the house has of one kind - every light, every switch, every camera - with each one's entity id, the name the house calls it, and its state. Start here when you do not know an entity id. The domains a house usually has are light, switch, binary_sensor, sensor, camera, lock, cover, climate, fan, media_player, vacuum, person, device_tracker, scene and script.
    type: http
    method: POST
    url: "{{secret:HOME_ASSISTANT_URL}}/api/template"
    auth: home
    headers:
      Accept: text/plain
    body:
      template: "{% for s in states[{{domain|json}}] %}{{{{ s.entity_id }}}}|{{{{ s.name }}}}|{{{{ s.state }}}}\n{% endfor %}"
    result: text
    parameters:
      type: object
      properties:
        domain:
          type: string
          description: Which kind - light, switch, camera, lock, sensor, binary_sensor, cover, climate, fan, media_player, vacuum, scene, script
      required: ["domain"]

  - name: home_find
    description: Find the things in the house matching some words - "gym fan", "front door", "kitchen" - across every kind at once, with each one's state. Every word has to appear somewhere in the thing's name or id, in any order, so "gym fan" finds the Gym Ceiling Fan. Use it when you know what the person calls something but not its exact name or which kind it is. One thing often appears several times, as a fan, a light and half a dozen sensors of the same device: the one to act on is the one whose id starts with the domain you want.
    type: http
    method: POST
    url: "{{secret:HOME_ASSISTANT_URL}}/api/template"
    auth: home
    headers:
      Accept: text/plain
    body:
      # Every word, anywhere, rather than the whole phrase in one piece.
      # A house calls something "Gym Ceiling Fan Ceiling Fan" and its id is
      # fan.gym_ceiling_fan, so a person asking for the "gym fan" matched
      # neither: the words are there and not next to each other. The id's
      # underscores and dots are spaces for this, so a word matches whether
      # it came from the name or the id.
      template: "{% set words = ({{words|json}} | lower | trim).split() %}{% for s in states %}{% set hay = (s.entity_id ~ ' ' ~ s.name) | lower | replace('_', ' ') | replace('.', ' ') %}{% if words | reject('in', hay) | list | count == 0 %}{{{{ s.entity_id }}}}|{{{{ s.name }}}}|{{{{ s.state }}}}\n{% endif %}{% endfor %}"
    result: text
    maxBytes: 65536
    parameters:
      type: object
      properties:
        words:
          type: string
          description: What to look for in an entity id or a name, for example door, kitchen, garage
      required: ["words"]

  - name: home_state
    description: Read one thing's state exactly - its state, its attributes and when it last changed - by its entity id, for example binary_sensor.front_door or sensor.upstairs_temperature. Use it when you know the entity and want the number rather than a sentence.
    type: http
    method: GET
    url: "{{secret:HOME_ASSISTANT_URL}}/api/states/{{entityId}}"
    auth: home
    headers:
      Accept: application/json
    result: json
    parameters:
      type: object
      properties:
        entityId:
          type: string
          description: The entity id, domain first - light.kitchen, lock.front_door, sensor.outside_temperature
      required: ["entityId"]

  - name: home_service
    description: Call one service on one thing, when you know both - domain light, service turn_on, entity light.kitchen. Prefer home_ask for anything a person would say in words; this is for when you need the exact call. It changes the house, so it asks first.
    type: http
    method: POST
    url: "{{secret:HOME_ASSISTANT_URL}}/api/services/{{domain}}/{{service}}"
    auth: home
    headers:
      Accept: application/json
    body:
      entity_id: "{{entityId}}"
    result: json
    parameters:
      type: object
      properties:
        domain:
          type: string
          description: The service's domain - light, switch, lock, cover, climate, fan, media_player, vacuum, scene, script
        service:
          type: string
          description: The service - turn_on, turn_off, toggle, open_cover, lock, set_temperature
        entityId:
          type: string
          description: Which thing to call it on, as an entity id
      required: ["domain", "service", "entityId"]

  - name: home_camera
    description: Look at what one of the house's cameras sees at this moment, by its entity id, for example camera.back_door. The picture comes back for you to look at, and the person is handed the same picture. Use it to answer what is actually there rather than what a sensor says.
    type: http
    method: GET
    url: "{{secret:HOME_ASSISTANT_URL}}/api/camera_proxy/{{entityId}}"
    auth: home
    headers:
      Accept: image/jpeg
    result: image
    parameters:
      type: object
      properties:
        entityId:
          type: string
          description: The camera's entity id, which starts with camera.
      required: ["entityId"]
---

home_list and home_find are how to see what is there: a domain at a time,
or by the words a person would use. Both answer with one line per thing --
entity id, name, state -- which is what the other tools want.

home_ask hands a whole sentence to Home Assistant's own assistant, which
knows the house's names and rooms. It is the shortest way to do something
ordinary, and it fails often: a Home Assistant answers only the sentences it
has patterns for, unless its owner has given it a model of its own.

When it does not understand, finish the job yourself rather than handing the
problem back. The person asked for something; home_ask not understanding it
is this skill's difficulty, not a change of mind. Find the entity with
home_find and carry it out with home_service, and say what you did. Asking
"shall I turn it on now?" after they have just asked you to turn it on is
the one answer that is certainly wrong.

Ask them again only when the thing itself is in doubt -- two fans could be
the one they meant, or what turns up is a lock rather than a light. Then
name what you found and let them choose.

home_state gives one thing's exact state when a sentence would round it
off; home_service makes one exact call when you know the domain, the
service and the entity; and home_camera shows you what a camera sees, which
is how to answer whether the car is on the drive rather than what a door
sensor last reported.

Entity ids are domain first: `light.kitchen`, `binary_sensor.front_door`,
`camera.back_door`, `fan.gym_ceiling_fan`. Never guess one: home_find takes
the words a person would use and answers with the ids that match.

Turning something on or off is `home_service` with the domain the entity id
starts with, the service `turn_on`, `turn_off` or `toggle`, and that entity.
A fan is `fan.turn_on`, a light `light.turn_on`, a switch `switch.turn_on`.

Anything that changes the house asks the person first. That is deliberate:
a house is not a place to be tidied up in by surprise.
