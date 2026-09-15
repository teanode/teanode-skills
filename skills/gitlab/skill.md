---
name: gitlab
description: "GitLab through the glab command on the person's own computer: issues, merge requests, pipelines and releases"

# No credential here. glab is already signed in on the person's machine,
# against gitlab.com or their own instance, and this acts as them.
#
# Merge requests and releases can answer in JSON; issues cannot -- glab's
# issue list offers details, ids or urls and no more -- so that one comes
# back as the text a person would see in their own terminal.
tools:
  - name: gitlab_issues
    description: Issues on one GitLab project, as glab prints them. The project is group/name, or group/subgroup/name.
    type: shell
    command: [glab, issue, list, --repo, "{{repo}}", --per-page, "30"]
    timeout: 60
    parameters:
      type: object
      properties:
        repo:
          type: string
          description: The project as group/name
      required: ["repo"]

  - name: gitlab_merge_requests
    description: Merge requests on one GitLab project, in JSON.
    type: shell
    command: [glab, mr, list, --repo, "{{repo}}", --output, json, --per-page, "30"]
    timeout: 60
    parameters:
      type: object
      properties:
        repo:
          type: string
          description: The project as group/name
      required: ["repo"]

  - name: gitlab_pipelines
    description: The recent CI pipelines of one GitLab project and how each ended.
    type: shell
    command: [glab, ci, list, --repo, "{{repo}}", --per-page, "20"]
    timeout: 60
    parameters:
      type: object
      properties:
        repo:
          type: string
          description: The project as group/name
      required: ["repo"]

  - name: gitlab_releases
    description: The releases of one GitLab project, newest first.
    type: shell
    command: [glab, release, list, --repo, "{{repo}}"]
    timeout: 60
    parameters:
      type: object
      properties:
        repo:
          type: string
          description: The project as group/name
      required: ["repo"]
---

This runs glab on the person's own computer, as them. There is no
credential in this skill.

A GitLab token expires, and glab then answers 401 to everything. That is
for the person to fix with `glab auth login`; nothing here can.

Projects are group/name, and may be nested: group/subgroup/name.
