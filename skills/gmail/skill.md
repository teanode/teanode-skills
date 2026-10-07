---
name: gmail
description: "Gmail through the gog command on the person's own computer: searching and reading their mail, drafting and sending as them, and labeling, archiving and marking threads"

# No token here. gog is already signed in to Google on the person's machine,
# as them, so this skill carries no credential, stores none on the server,
# and can do exactly what they can do from their own terminal.
#
# Every call runs on a computer of theirs, never on the server, and each is
# judged before it runs: a search or a read goes ahead, a label is a change
# of theirs that goes ahead, and a send speaks for them and asks first.
#
# Listings ask gog for JSON rather than its tables, which is what can be read
# back. Limits are written into the commands: a skill's arguments are all or
# nothing, and an empty one would reach gog as an empty word.
tools:
  - name: gmail_search
    description: Search the person's Gmail with Gmail's own query syntax - from:, to:, subject:, label:, is:unread, has:attachment, after:2026/01/31, newer_than:7d, and plain words. Answers up to 25 threads, newest first, each with its thread id.
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
          description: The Gmail search, as it would be typed in Gmail's search box
      required: ["action", "query"]
    actions:
      search:
        - name: search
          type: shell
          command: [gog, gmail, search, "{{query}}", --max, "25", --json, --no-input]
          timeout: 60

  - name: gmail_read
    description: Read from the person's Gmail - a whole thread with every message's body, or one message. Take the thread id from gmail_search.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["thread", "message", "thread_latest"]
          description: thread reads a whole conversation; message reads one message; thread_latest reads the end of a conversation as text, its newest message last
        id:
          type: string
          description: The thread id for thread and thread_latest, the message id for message
      required: ["action", "id"]
    actions:
      thread:
        - name: thread
          type: shell
          command: [gog, gmail, thread, get, "{{id}}", --full, --json, --no-input]
          timeout: 60
      message:
        - name: message
          type: shell
          command: [gog, gmail, get, "{{id}}", --json, --no-input]
          timeout: 60
      thread_latest:
        # The thread as text, decoded, and only its end: what is new in a
        # long conversation is its last message, and the beginning of a
        # thread of fifty replies is what would be cut otherwise.
        - name: thread_latest
          type: shell
          command:
            - sh
            - -c
            - 'gog gmail thread get "$0" --full --no-input | tail -c 20000'
            - "{{id}}"
          timeout: 60

  - name: gmail_draft
    description: Write a draft in the person's Gmail, which they review and send themselves - a new message, or a reply to a message in a thread. Nothing is sent.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["new", "reply"]
          description: new starts a message; reply answers the message named
        to:
          type: string
          description: Recipients, comma-separated addresses
        subject:
          type: string
          description: The subject; for a reply, the original's with Re in front
        body:
          type: string
          description: The message, as plain text
        message_id:
          type: string
          description: For reply - the id of the message being answered
      required: ["action", "to", "subject", "body"]
    actions:
      new:
        - name: new
          type: shell
          command: [gog, gmail, drafts, create, --to, "{{to}}", --subject, "{{subject}}", --body, "{{body}}", --no-input]
          timeout: 60
      reply:
        - name: reply
          type: shell
          command: [gog, gmail, drafts, create, --reply-to-message-id, "{{message_id}}", --to, "{{to}}", --subject, "{{subject}}", --body, "{{body}}", --no-input]
          timeout: 60

  - name: gmail_send
    description: Send mail from the person's Gmail, as them - a new message, or a reply to everybody on a thread. This speaks for them, so say what it will send before sending.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["new", "reply"]
          description: new sends a message; reply answers everybody on the thread named
        to:
          type: string
          description: For new - recipients, comma-separated addresses
        subject:
          type: string
          description: The subject; for a reply, the original's with Re in front
        body:
          type: string
          description: The message, as plain text
        thread_id:
          type: string
          description: For reply - the thread being answered
      required: ["action", "subject", "body"]
    actions:
      new:
        - name: new
          type: shell
          command: [gog, gmail, send, --to, "{{to}}", --subject, "{{subject}}", --body, "{{body}}", --no-input]
          timeout: 60
      reply:
        - name: reply
          type: shell
          command: [gog, gmail, send, --thread-id, "{{thread_id}}", --reply-all, --subject, "{{subject}}", --body, "{{body}}", --no-input]
          timeout: 60

  - name: gmail_labels
    description: Organize the person's Gmail - list their labels, or add and remove labels on a thread. Archiving is removing INBOX; marking read is removing UNREAD; starring is adding STARRED.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["list", "add", "remove"]
          description: list shows every label; add and remove change one thread's
        thread_id:
          type: string
          description: For add and remove - the thread
        labels:
          type: string
          description: For add and remove - label names or ids, comma-separated
      required: ["action"]
    actions:
      list:
        - name: list
          type: shell
          command: [gog, gmail, labels, list, --json, --no-input]
          timeout: 60
      add:
        - name: add
          type: shell
          command: [gog, gmail, thread, modify, "{{thread_id}}", --add, "{{labels}}", --no-input]
          timeout: 60
      remove:
        - name: remove
          type: shell
          command: [gog, gmail, thread, modify, "{{thread_id}}", --remove, "{{labels}}", --no-input]
          timeout: 60

  - name: gmail_new
    description: Threads in the person's Gmail with mail that arrived since a moment, archived or not, leaving out what they sent, drafts, spam, trash and the promotions and social tabs. Up to 25, each with its id, how many messages it has, when the newest came, from whom, its subject and its labels. For keeping watch; to look something up, gmail_search takes any query.
    type: shell
    parameters:
      type: object
      properties:
        since_epoch:
          type: string
          description: The moment to look from, in seconds since 1970
      required: ["since_epoch"]
    # Shaped into the items a watch reads: the thread's message count is
    # its version, so a reply to an old thread is new again. Dates in UTC,
    # since without the flag gog prints local time with no zone.
    command:
      - sh
      - -c
      - 'gog gmail search "after:$0 -in:sent -in:drafts -in:chats -in:spam -in:trash -category:promotions -category:social" --max 25 --json --no-input --timezone UTC | jq -c "$1"'
      - "{{since_epoch}}"
      - '[.threads[]? | {id, version: (.messageCount | tostring), at: ((.date | sub(" "; "T")) + ":00Z"), from, title: .subject, text: ("Gmail labels: " + ((.labels // []) | join(", "))), url: ("https://mail.google.com/mail/#all/" + .id)}]'
    timeout: 60

watches:
  - name: new_mail
    description: mail that arrives in their Gmail, archived or not
    kind: mail
    list: {tool: gmail_new}
    read: {tool: gmail_read, arguments: {action: thread_latest}}
---

# Gmail

The person's Gmail, through [gog](https://github.com/steipete/gogcli) on their
own computer. Install gog there and sign in once with `gog auth add`; the
skill uses whatever account gog uses by default.

Searching, reading and labeling go ahead. Drafts are written for the person to
send. Sending asks first, every time.
