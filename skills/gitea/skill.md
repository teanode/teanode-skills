---
name: gitea
description: "Gitea through the tea command on the person's own computer: repositories, issues, pull requests and releases on whichever Gitea they are signed in to"

# No credential here. tea is already signed in on the person's machine,
# against whichever Gitea they use, and this acts as them. A Gitea is
# commonly somebody's work or a small server of their own, so which one it
# talks to is settled there and not named here.
#
# Every command asks them first, as every command in a skill does: they run
# on a computer of theirs, never on the server.
tools:
  - name: gitea_repos
    description: The repositories the person can see on their Gitea.
    type: shell
    command: [tea, repos, ls, --output, json]
    timeout: 60
    parameters:
      type: object
      properties: {}

  - name: gitea_issues
    description: Issues on one Gitea repository. The repository is owner/name as Gitea names it; open ones unless another state is asked for.
    type: shell
    command: [tea, issues, ls, --repo, "{{repo}}", --state, "{{state}}", --limit, "30", --output, json]
    timeout: 60
    parameters:
      type: object
      properties:
        repo:
          type: string
          description: The repository as owner/name
        state:
          type: string
          enum: ["open", "closed", "all"]
          default: open
          description: Which issues to list
      required: ["repo"]

  - name: gitea_pulls
    description: Pull requests on one Gitea repository, open ones unless another state is asked for.
    type: shell
    command: [tea, pulls, ls, --repo, "{{repo}}", --state, "{{state}}", --limit, "30", --output, json]
    timeout: 60
    parameters:
      type: object
      properties:
        repo:
          type: string
          description: The repository as owner/name
        state:
          type: string
          enum: ["open", "closed", "all"]
          default: open
          description: Which pull requests to list
      required: ["repo"]

  - name: gitea_releases
    description: The releases of one Gitea repository, newest first.
    type: shell
    command: [tea, releases, ls, --repo, "{{repo}}", --limit, "20", --output, json]
    timeout: 60
    parameters:
      type: object
      properties:
        repo:
          type: string
          description: The repository as owner/name
      required: ["repo"]
---

This runs tea on the person's own computer, as them, against whichever
Gitea their tea is signed in to. There is no credential in this skill.

A Gitea sign-in expires. When a command answers that it cannot refresh its
token, the answer is for the person to run `tea login oauth-refresh <host>`
themselves; there is nothing to be done about it from here.

Repositories are owner/name. An empty list means there are none in that
state, not that the command failed.
