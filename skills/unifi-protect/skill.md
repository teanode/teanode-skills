---
name: unifi-protect
description: "UniFi Protect cameras on your own console: what they see now, and clips of what they saw"
secrets:
  - key: UNIFI_PROTECT_API_KEY
    scope: person
    description: An API key for your own UniFi Protect. Make one in UniFi OS under Settings, Control Plane, Integrations, and give it only the camera permissions you want the agent to have. This is not a UniFi account password, and not a bearer token taken from a browser session.
  - key: UNIFI_PROTECT_URL
    scope: person
    description: Where your UniFi OS is, whole - https://nvr.local or https://192.168.1.1, with a port if it is on one. The scheme is part of it rather than assumed, and it is a secret rather than a parameter of the tool so that the key above is only ever sent to the address you set, never one named in a request.
  - key: UNIFI_PROTECT_USERNAME
    scope: person
    description: The name you sign in to UniFi OS with. Only downloading a clip needs it, because that is the console's own interface rather than the integration API, and it answers to a session rather than to a key. Leave this unset and everything except protect_clip still works.
  - key: UNIFI_PROTECT_PASSWORD
    scope: person
    description: The password for that name. It is sent only to the host above, only to sign in, and only when a clip is asked for. Consider a UniFi OS account of its own with nothing but camera permissions rather than the one you use yourself.

# Both of these are each person's own, because a UniFi Protect is somebody's
# own equipment: their console, their key, their cameras. Scoping them
# together is also what keeps the key safe -- a host one person names could
# otherwise be handed a credential somebody else provided. A deployment where
# everybody shares one console can have an operator settle it the other way.
#
# The integration API, under /proxy/protect/integration/v1, is the one an API
# key opens. The console's own API, under /proxy/protect/api, answers 401 to a
# key however the key is presented: it takes a session from a sign-in, which
# is a password this skill deliberately does not ask anybody for. So the
# integration API is not a lesser choice here, it is the only one a key
# reaches -- and it is the documented one, which is the one that will still
# be there after a firmware update.
authenticationProfiles:
  protect:
    type: apiKey
    header: X-API-KEY
    value: "{{secret:UNIFI_PROTECT_API_KEY}}"
tools:
  - name: protect_ops
    description: Run one UniFi Protect action (list cameras, read one, look at a camera now, status light, microphone volume, console)
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum:
            - list_cameras
            - get_camera
            - get_snapshot
            - set_status_light
            - set_microphone_volume
            - get_console
          description: Protect operation to run
        cameraId:
          type: string
          description: Camera ID for camera-specific actions, as list_cameras reports it
        enabled:
          type: boolean
          description: Used by set_status_light -- whether the camera's status light is lit
        volume:
          type: integer
          description: Used by set_microphone_volume -- 0 to 100, where 0 is silent
      required: ["action"]
    actions:
      list_cameras:
        - name: list_cameras
          type: http
          method: GET
          url: "{{secret:UNIFI_PROTECT_URL}}/proxy/protect/integration/v1/cameras"
          auth: protect
          headers:
            Accept: application/json
          result: json
      get_snapshot:
        - name: get_snapshot
          type: http
          method: GET
          # Not highQuality=true: a G4 Instant and a G5 Flex answer 400 to
          # it, and only a doorbell, a turret and a G6 accept it. The plain
          # snapshot is served by every camera, and is the smaller picture
          # of the two, which is the one worth looking at anyway.
          url: "{{secret:UNIFI_PROTECT_URL}}/proxy/protect/integration/v1/cameras/{{cameraId}}/snapshot"
          auth: protect
          headers:
            Accept: image/jpeg
          result: image
      get_camera:
        - name: get_camera
          type: http
          method: GET
          url: "{{secret:UNIFI_PROTECT_URL}}/proxy/protect/integration/v1/cameras/{{cameraId}}"
          auth: protect
          headers:
            Accept: application/json
          result: json
      set_status_light:
        - name: set_status_light
          type: http
          method: PATCH
          url: "{{secret:UNIFI_PROTECT_URL}}/proxy/protect/integration/v1/cameras/{{cameraId}}"
          auth: protect
          headers:
            Accept: application/json
            Content-Type: application/json
          body: '{"ledSettings":{"isEnabled":{{enabled|json}}}}'
          result: json
      set_microphone_volume:
        - name: set_microphone_volume
          type: http
          method: PATCH
          url: "{{secret:UNIFI_PROTECT_URL}}/proxy/protect/integration/v1/cameras/{{cameraId}}"
          auth: protect
          headers:
            Accept: application/json
            Content-Type: application/json
          body: '{"micVolume":{{volume|json}}}'
          result: json
      get_console:
        - name: get_console
          type: http
          method: GET
          url: "{{secret:UNIFI_PROTECT_URL}}/proxy/protect/integration/v1/nvrs"
          auth: protect
          headers:
            Accept: application/json
          result: json
  - name: protect_clip
    description: Download what a camera recorded between two moments, as an MP4 handed to the person. Times are milliseconds since the epoch. Keep the window short -- a minute of video is tens of megabytes, and too long a window is refused rather than truncated. Use protect_ops list_cameras first for the camera's ID.
    type: workflow
    parameters:
      type: object
      properties:
        cameraId:
          type: string
          description: Which camera, as list_cameras reports it
        start:
          type: integer
          description: When the clip starts, in milliseconds since the epoch
        end:
          type: integer
          description: When the clip ends, in milliseconds since the epoch
      required: ["cameraId", "start", "end"]
    steps:
      # The console's own interface, not the integration API: exporting a
      # clip is the one thing here an API key cannot do, and it answers
      # only to a session. So this signs in first, and the session carries
      # into the step below it.
      - name: sign_in
        type: http
        method: POST
        url: "{{secret:UNIFI_PROTECT_URL}}/api/auth/login"
        headers:
          Accept: application/json
          Content-Type: application/json
        body: '{"username":"{{secret:UNIFI_PROTECT_USERNAME}}","password":"{{secret:UNIFI_PROTECT_PASSWORD}}"}'
        result: json
        select:
          signed_in_as: username
      - name: clip
        type: http
        method: GET
        url: "{{secret:UNIFI_PROTECT_URL}}/proxy/protect/api/video/export?camera={{cameraId}}&start={{start}}&end={{end}}"
        headers:
          Accept: video/mp4
        result: file
        timeout: 120
---

Use protect_ops as a single entrypoint for UniFi Protect operations.
Set `UNIFI_PROTECT_API_KEY` and `UNIFI_PROTECT_URL` in TeaNode's skill
secrets. The host is a secret rather than a parameter of the tool on
purpose: the key is sent to it, so it must be the address the person set
and not one chosen when the tool is called.

For camera-specific actions, call list_cameras first to obtain a valid
camera ID. What list_cameras reports about each camera is its name, model,
state, status light, microphone, on-screen display and smart detections.

get_snapshot is what a camera sees at the moment it is asked: the picture
comes back for you to look at, and the person is handed the same picture in
the conversation, so answering "is the car on the drive" is looking rather
than guessing. It is a still, not a stream, and it is what the camera sees
now -- there is no way here to ask for a moment that has passed.

protect_clip is what the camera recorded earlier, rather than what it sees
now: give it two moments and it hands the person an MP4 of what happened
between them. You do not watch it yourself. What you can do is work on it:
the answer carries an attachment id, and `filesystem put` writes that file
onto the person's own computer, where `shell` can reach whatever is
installed there -- ffmpeg to cut it, speed it up, or take frames out of it,
and those frames can then be shown to you with share_file. Ask for a short
window; a minute is already tens of megabytes, and the person waits while it
is assembled.

Two things a UniFi Protect can do are not here, because neither interface
carries them for an agent: the recording mode and privacy zones. Asked for
either, say it is done from the Protect app rather than guessing at another
way round.
