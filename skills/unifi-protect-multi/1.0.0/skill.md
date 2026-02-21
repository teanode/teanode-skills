---
name: unifi-protect-multi
description: Single multi-action UniFi Protect tool
tools:
  - name: protect_ops
    description: Run one UniFi Protect action (list/get/snapshot/light/recording/privacy)
    type: http
    method: "{{method}}"
    url: "https://{{host}}{{path}}"
    headers:
      Accept: application/json
      Content-Type: application/json
      Authorization: "Bearer {{token}}"
    body: "{{body}}"
    timeout: 30
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
            - set_recording_mode
            - set_privacy_mode
          description: Protect operation to run
        host:
          type: string
          description: UniFi OS host (e.g. nvr.local)
        token:
          type: string
          description: Protect bearer token
        cameraId:
          type: string
          description: Required for camera-specific actions
        method:
          type: string
          enum: ["GET", "PATCH"]
          description: HTTP method derived from action
        path:
          type: string
          description: API path derived from action
        body:
          type: string
          description: JSON request body for PATCH actions
        enabled:
          type: boolean
          description: Used by set_status_light / set_privacy_mode
        mode:
          type: string
          enum: ["always", "detections", "never"]
          description: Used by set_recording_mode
      required: ["action", "host", "token", "method", "path"]
---

Use protect_ops as a single entrypoint for UniFi Protect.
Always list cameras first to obtain valid camera IDs.
