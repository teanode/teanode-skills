---
name: github
description: "GitHub through the gh command on the person's own computer: their repositories, issues, pull requests, workflow runs and searches"

# No token here, and that is the point. gh is already signed in on the
# person's machine, in their keyring, as them -- so this skill carries no
# credential, stores none on the server, and can do exactly what they can do
# from their own terminal and no more. Signing in, signing out and choosing
# an account stay theirs.
#
# Every command asks them first, because every command in a skill does: they
# run on a computer of theirs, and the server never runs one. That means
# this skill is for conversations they are present in, not for anything the
# server does on its own.
#
# The listing commands ask gh for JSON with the fields named, rather than
# the human tables, because a table of thirty issues is mostly borders and
# the JSON is what can actually be read back.
tools:
  - name: github_repos
    description: The person's own repositories, most recently pushed first, or one repository's state. A repository is named owner/name, as gh names them.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["mine", "get"]
          description: mine lists their repositories; get reads one
        repo:
          type: string
          description: For get - the repository as owner/name
      required: ["action"]
    actions:
      mine:
        - name: mine
          type: shell
          command: [gh, repo, list, --limit, "40", --json, "nameWithOwner,description,isPrivate,isArchived,pushedAt,primaryLanguage,stargazerCount"]
          timeout: 60
      get:
        - name: get
          type: shell
          command: [gh, repo, view, "{{repo}}", --json, "nameWithOwner,description,defaultBranchRef,isPrivate,isArchived,pushedAt,primaryLanguage,stargazerCount"]
          timeout: 60

  - name: github_issues
    description: Issues on one repository - list the open ones, read one with its comments, open a new one, or comment on one. Opening and commenting are published under the person's own name, in public where the repository is public.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["list", "get", "open", "comment"]
          description: What to do
        repo:
          type: string
          description: The repository as owner/name
        number:
          type: integer
          description: For get and comment - which issue
        title:
          type: string
          description: For open - the issue's title
        body:
          type: string
          description: For open and comment - what it says, in markdown
      required: ["action", "repo"]
    actions:
      list:
        - name: list
          type: shell
          command: [gh, issue, list, --repo, "{{repo}}", --limit, "30", --json, "number,title,state,updatedAt,author,labels,comments"]
          timeout: 60
      get:
        - name: get
          type: shell
          command: [gh, issue, view, "{{number}}", --repo, "{{repo}}", --comments]
          timeout: 60
      open:
        - name: open
          type: shell
          command: [gh, issue, create, --repo, "{{repo}}", --title, "{{title}}", --body, "{{body}}"]
          timeout: 60
      comment:
        - name: comment
          type: shell
          command: [gh, issue, comment, "{{number}}", --repo, "{{repo}}", --body, "{{body}}"]
          timeout: 60

  - name: github_pulls
    description: Pull requests on one repository - the open ones, one in detail with what it changes and whether it can merge, or what its checks are saying.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["list", "get", "checks"]
          description: What to do
        repo:
          type: string
          description: The repository as owner/name
        number:
          type: integer
          description: For get and checks - which pull request
      required: ["action", "repo"]
    actions:
      list:
        - name: list
          type: shell
          command: [gh, pr, list, --repo, "{{repo}}", --limit, "30", --json, "number,title,state,isDraft,updatedAt,author,headRefName,baseRefName,additions,deletions"]
          timeout: 60
      get:
        - name: get
          type: shell
          command: [gh, pr, view, "{{number}}", --repo, "{{repo}}", --json, "number,title,state,isDraft,body,author,headRefName,baseRefName,additions,deletions,changedFiles,mergeable,mergeStateStatus,files"]
          timeout: 60
      checks:
        - name: checks
          type: shell
          command: [gh, pr, checks, "{{number}}", --repo, "{{repo}}"]
          timeout: 120

  - name: github_actions
    description: What the workflows on one repository have been doing - the recent runs and how each ended, one run in detail, or the log of just the steps that failed in it.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["runs", "run", "failed"]
          description: runs lists recent runs; run reads one; failed prints the log of the failed steps of one
        repo:
          type: string
          description: The repository as owner/name
        id:
          type: integer
          description: For run and failed - the run's id, as runs reports it under databaseId
      required: ["action", "repo"]
    actions:
      runs:
        - name: runs
          type: shell
          command: [gh, run, list, --repo, "{{repo}}", --limit, "15", --json, "databaseId,workflowName,status,conclusion,headBranch,event,createdAt"]
          timeout: 60
      run:
        - name: run
          type: shell
          command: [gh, run, view, "{{id}}", --repo, "{{repo}}"]
          timeout: 60
      failed:
        - name: failed
          type: shell
          command: [gh, run, view, "{{id}}", --repo, "{{repo}}", --log-failed]
          timeout: 180

  - name: github_search
    description: Search GitHub in its own search syntax - repositories, or issues and pull requests across everything the person can see. For example "org:someplace language:go stars:>100", or "is:open is:issue author:@me label:bug".
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["repositories", "issues"]
          description: What kind of thing to look for
        query:
          type: string
          description: The search, in GitHub's own syntax
      required: ["action", "query"]
    actions:
      repositories:
        - name: repositories
          type: shell
          command: [gh, search, repos, "{{query}}", --limit, "20", --json, "fullName,description,stargazersCount,language,updatedAt"]
          timeout: 60
      issues:
        - name: issues
          type: shell
          command: [gh, search, issues, "{{query}}", --limit, "20", --json, "number,title,repository,state,updatedAt,url"]
          timeout: 60
---

This runs gh on the person's own computer, as them. There is no token in
this skill and none on the server: whatever their gh is signed in as is what
this can see, and if it is signed out, these commands say so and the answer
is for them to run `gh auth login` themselves.

Repositories are named owner/name. github_repos mine is the place to start
when somebody names a project without saying where it lives.

github_issues open and comment publish under their name and cannot be taken
back from here. Say what you are about to post and where, and post it once.

An empty list is an answer: `[]` means the repository has no open issues,
not that the command failed.

For a failing build, github_actions runs gives the ids, and failed prints
only the steps that failed, which is usually the whole of what is wanted.
