---
name: confluence
description: "Confluence through the confluence command on the person's own computer: search the wiki, read a page, list spaces"

# No credential here. The confluence command is already configured on the
# person's machine, against whichever site they use, and this acts as them.
#
# Reading only, deliberately. The command can create, update, move and
# delete pages, and a wiki is commonly shared with a great many people who
# did not ask an agent to edit it. Writing can be added when somebody wants
# it and says so; until then this cannot change a page.
tools:
  - name: confluence_search
    description: Search the person's Confluence for pages matching some words. Ten at a time.
    type: shell
    command: [confluence, search, "{{query}}", --limit, "10"]
    timeout: 90
    parameters:
      type: object
      properties:
        query:
          type: string
          description: What to look for, in words
      required: ["query"]

  - name: confluence_find
    description: Find a Confluence page by its exact title, when the title is known.
    type: shell
    command: [confluence, find, "{{title}}"]
    timeout: 90
    parameters:
      type: object
      properties:
        title:
          type: string
          description: The page's title
      required: ["title"]

  - name: confluence_read
    description: Read a Confluence page, by its id or its URL, as text.
    type: shell
    command: [confluence, read, "{{page}}"]
    timeout: 90
    parameters:
      type: object
      properties:
        page:
          type: string
          description: The page's id, or its full URL
      required: ["page"]

  - name: confluence_info
    description: What is known about a Confluence page without reading it - its title, space, version and when it last changed.
    type: shell
    command: [confluence, info, "{{page}}"]
    timeout: 90
    parameters:
      type: object
      properties:
        page:
          type: string
          description: The page's id, or its full URL
      required: ["page"]

  - name: confluence_spaces
    description: The spaces on the person's Confluence, by key and name.
    type: shell
    command: [confluence, spaces]
    timeout: 90
    parameters:
      type: object
      properties: {}
---

This runs the confluence command on the person's own computer, as them,
against whichever site it is configured for. There is no credential here.

Search takes words, not CQL. A page is addressed by its id or by pasting
its URL, and either works everywhere a page is asked for.

Nothing here changes a page. Asked to write one, say that this skill reads
only, rather than reaching for another way round.
