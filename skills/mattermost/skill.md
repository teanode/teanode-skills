---
name: mattermost
description: "Mattermost through the mm command on the person's own computer: what is unread, the messages in a channel, a thread, their direct messages, and posting as them"

# No token here, and that is the point. mm is already signed in on the
# person's machine, as them, against whichever server they use -- so this
# skill carries no credential, stores none on the server, and can do exactly
# what they can do from their own terminal and no more. Signing in, switching
# profile and choosing a team stay theirs.
#
# Every command asks them first, because every command in a skill does: they
# run on a computer of theirs, and the server never runs one. That means this
# skill is for conversations they are present in, not for anything the server
# does on its own -- which matters more here than in most, because the other
# end of a Mattermost is colleagues.
#
# Reading and writing are separate tools rather than actions of one, so that
# the tool a run reaches for to catch up is not the tool that can say
# something to a roomful of people.
#
# Every command asks for --json. The human output is a table meant for a
# terminal, and a table of thirty messages is mostly borders; the JSON is
# what can be read back and quoted.
tools:
  - name: mattermost_channels
    description: The person's channels - what is unread and waiting, what they are in, or one channel's details. Start with unread - it is the short list, and it carries the mention count, which is what separates a channel that wants them from one that is merely busy.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["unread", "mine", "info"]
          description: unread lists only channels with unread messages; mine lists every channel they are in; info reads one
        channel:
          type: string
          description: For info - the channel, by its slug as the listings give it
        team:
          type: string
          default: ""
          description: Which team's channels to look in. Leave it out for the team they are in; name another to reach its channels - mattermost_whoami lists the ones they are on. A channel belongs to a team, and the same name can exist in two of them.
      required: ["action"]
    actions:
      unread:
        - name: unread
          type: shell
          command: [mm, channel, unread, -T, "{{team}}", --json]
          timeout: 60
      mine:
        - name: mine
          type: shell
          # Every channel on the server is eight hundred rows of mostly
          # direct-message pairs named by a pair of user ids, which is far
          # past what a tool may answer with and unreadable besides. The
          # open and private channels are what "mine" means; the jq program
          # is a separate argument so nothing inside it is parsed as shell.
          command:
            - sh
            - -c
            - 'mm channel list -T "$1" --json | jq -c "$0"'
            - '[.[] | select(.type == "O" or .type == "P") | {name, display_name, type, last_post_at}] | sort_by(-.last_post_at)'
            - "{{team}}"
          timeout: 60
      info:
        - name: info
          type: shell
          command: [mm, channel, info, "{{channel}}", -T, "{{team}}", --json]
          timeout: 60

  - name: mattermost_posts
    description: Messages in a channel, a thread in full, or a search across the team. unread is what they have not read in that channel; list is the recent messages whether read or not. A message's id is what thread and reply take; list prints them in full, while search abbreviates them, so follow a search by reading the channel it points at.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["unread", "list", "thread", "search"]
          description: unread is what is new in the channel; list is the recent messages; thread is one message and its replies; search looks across the team
        channel:
          type: string
          description: For unread and list - the channel, by slug
        post:
          type: string
          description: For thread - the message's id
        query:
          type: string
          description: For search - the words to look for; every word must appear unless you say OR
        count:
          type: string
          default: "20"
          description: For list - how many messages, most recent last
        team:
          type: string
          default: ""
          description: Which team's channels to look in. Leave it out for the team they are in; name another to reach its channels - mattermost_whoami lists the ones they are on. A channel belongs to a team, and the same name can exist in two of them.
      required: ["action"]
    actions:
      unread:
        - name: unread
          type: shell
          command: [mm, post, unread, "{{channel}}", -T, "{{team}}", --json]
          timeout: 60
      list:
        - name: list
          type: shell
          # Not --json here: the plain listing names the people, where the
          # JSON gives their ids and five times the bytes. --full-id because
          # the id it prints otherwise is an abbreviation, and thread and
          # reply refuse one.
          command: [mm, post, list, "{{channel}}", -n, "{{count}}", -T, "{{team}}", --full-id]
          timeout: 60
      thread:
        - name: thread
          type: shell
          command: [mm, post, thread, "{{post}}", -T, "{{team}}", --json]
          timeout: 60
      search:
        - name: search
          type: shell
          # A common word matches hundreds of messages and the JSON for them
          # is a couple of hundred kilobytes, so this takes the plain form
          # and stops at eighty lines. The words being searched for are a
          # separate argument the script names positionally, so nothing in
          # them is ever read as shell.
          command:
            - sh
            - -c
            - 'mm post search "$0" -T "$1" | head -n 80'
            - "{{query}}"
            - "{{team}}"
          timeout: 90

  - name: mattermost_direct
    description: The person's direct messages - who has written to them lately, and the history with one person. Names are Mattermost usernames, as the listing gives them.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["list", "read"]
          description: list is their recent conversations; read is the history with one person
        user:
          type: string
          description: For read - the other person's username
      required: ["action"]
    actions:
      list:
        - name: list
          type: shell
          # The plain listing rather than the JSON: only the plain one
          # resolves the other person's name, and the JSON names a direct
          # channel by a pair of user ids nobody can read. It is name-ordered
          # and eight hundred long, so this takes the thirty most recently
          # spoken in -- the date sits at a fixed column, and a conversation
          # that never had a message has none there to sort on.
          command:
            - sh
            - -c
            - 'mm dm list | tail -n +2 | grep -E "20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" | sort -r -k1.75,1.90 | head -n 30'
          timeout: 60
      read:
        - name: read
          type: shell
          command: [mm, dm, read, "{{user}}", --json]
          timeout: 60

  - name: mattermost_send
    description: Say something as them - in a channel, as a reply in a thread, or as a direct message. This is them speaking to colleagues under their own name, so write what they asked and nothing more, and show them the words before you send unless they have already given you them.
    type: workflow
    actionField: action
    parameters:
      type: object
      properties:
        action:
          type: string
          enum: ["post", "reply", "direct"]
          description: post puts a message in a channel; reply answers in a thread; direct writes to one person
        channel:
          type: string
          description: For post - the channel, by slug
        post:
          type: string
          description: For reply - the id of the message being replied to
        user:
          type: string
          description: For direct - the other person's username
        message:
          type: string
          description: What to say, exactly as it should appear
        team:
          type: string
          default: ""
          description: Which team's channels to look in. Leave it out for the team they are in; name another to reach its channels - mattermost_whoami lists the ones they are on. A channel belongs to a team, and the same name can exist in two of them.
      required: ["action", "message"]
    actions:
      post:
        - name: post
          type: shell
          command: [mm, post, create, "{{channel}}", "{{message}}", -T, "{{team}}", --json]
          timeout: 60
      reply:
        - name: reply
          type: shell
          command: [mm, post, reply, "{{post}}", "{{message}}", -T, "{{team}}", --json]
          timeout: 60
      direct:
        - name: direct
          type: shell
          command: [mm, dm, send, "{{user}}", "{{message}}", --json]
          timeout: 60

  - name: mattermost_whoami
    description: Which server and which team the mm command is signed in to, and as whom. Worth reading before anything else when a channel or a name cannot be found, because a channel belongs to a team and only one team is active.
    type: workflow
    parameters:
      type: object
      properties: {}
    steps:
      - name: account
        type: shell
        command: [mm, auth, status]
        timeout: 30
      - name: teams
        type: shell
        command: [mm, team, list, --json]
        timeout: 60
---
