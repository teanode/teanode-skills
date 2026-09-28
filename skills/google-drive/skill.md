---
name: google-drive
description: "Google Drive through the gog command on the person's own computer: searching and listing their files, reading a Google Doc as text, downloading and uploading files, and sharing"

# No token here. gog is already signed in to Google on the person's machine,
# as them, so this skill carries no credential, stores none on the server,
# and can do exactly what they can do from their own terminal.
#
# Every call runs on a computer of theirs, never on the server, and each is
# judged before it runs: a search, a listing or a read goes ahead, an upload
# or a download is a change of theirs that goes ahead, and sharing with
# somebody asks first.
#
# Listings ask gog for JSON rather than its tables. Limits are written into
# the commands: a skill's arguments are all or nothing, and an empty one would
# reach gog as an empty word.
tools:
  - name: drive_search
    description: Search the person's Google Drive by the words in their files' names and contents. Answers up to 25 files, each with its id, name, type and when it changed.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["search"]
          description: search
        query:
          type: string
          description: Words to look for
      required: ["action", "query"]
    actions:
      search:
        - name: search
          type: shell
          command: [gog, drive, search, "{{query}}", --max, "25", --json, --no-input]
          timeout: 60

  - name: drive_list
    description: List what is in the person's Google Drive - the top of My Drive, or one folder by its id. Up to 50 files each.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["top", "folder"]
          description: top lists My Drive; folder lists the folder named
        folder_id:
          type: string
          description: For folder - the folder's id
      required: ["action"]
    actions:
      top:
        - name: top
          type: shell
          command: [gog, drive, ls, --max, "50", --json, --no-input]
          timeout: 60
      folder:
        - name: folder
          type: shell
          command: [gog, drive, ls, --parent, "{{folder_id}}", --max, "50", --json, --no-input]
          timeout: 60

  - name: drive_read
    description: Read from the person's Google Drive - a file's details, a Google Doc's text, or a file downloaded to a path on their computer, where the filesystem tool can read or hand it over.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["info", "doc_text", "download"]
          description: info reads a file's details; doc_text prints a Google Doc as text; download saves a copy on their computer
        file_id:
          type: string
          description: The file's id, from drive_search or drive_list
        path:
          type: string
          description: For download - where on their computer to save it, such as ~/Downloads/report.pdf
      required: ["action", "file_id"]
    actions:
      info:
        - name: info
          type: shell
          command: [gog, drive, get, "{{file_id}}", --json, --no-input]
          timeout: 60
      doc_text:
        - name: doc_text
          type: shell
          command: [gog, docs, cat, "{{file_id}}", --no-input]
          timeout: 120
      download:
        - name: download
          type: shell
          command: [gog, drive, download, "{{file_id}}", --out, "{{path}}", --no-input]
          timeout: 300

  - name: drive_write
    description: Put a file from the person's computer into their Google Drive, into My Drive or a folder by its id.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["upload", "upload_to_folder"]
          description: upload puts it in My Drive; upload_to_folder into the folder named
        path:
          type: string
          description: The file on their computer
        folder_id:
          type: string
          description: For upload_to_folder - the folder's id
      required: ["action", "path"]
    actions:
      upload:
        - name: upload
          type: shell
          command: [gog, drive, upload, "{{path}}", --json, --no-input]
          timeout: 300
      upload_to_folder:
        - name: upload_to_folder
          type: shell
          command: [gog, drive, upload, "{{path}}", --parent, "{{folder_id}}", --json, --no-input]
          timeout: 300

  - name: drive_share
    description: Share a file or folder in the person's Google Drive with somebody by their address, to read or to edit. This gives another person access, so say what it will share with whom first.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["reader", "writer"]
          description: reader lets them read; writer lets them edit
        file_id:
          type: string
          description: The file or folder's id
        email:
          type: string
          description: The address of the person to share with
      required: ["action", "file_id", "email"]
    actions:
      reader:
        - name: reader
          type: shell
          command: [gog, drive, share, "{{file_id}}", --to, user, --email, "{{email}}", --role, reader, --no-input]
          timeout: 60
      writer:
        - name: writer
          type: shell
          command: [gog, drive, share, "{{file_id}}", --to, user, --email, "{{email}}", --role, writer, --no-input]
          timeout: 60
---

# Google Drive

The person's Google Drive, through [gog](https://github.com/steipete/gogcli)
on their own computer. Install gog there and sign in once with `gog auth add`;
the skill uses whatever account gog uses by default.

Searching, listing and reading go ahead, and so do downloads and uploads,
which stay among the person's own things. Sharing gives somebody else access
and asks first.
