# teanode-skills

Official community skill registry content for TeaNode.

## Layout

- `index.json`: registry index consumed by TeaNode.
- `skills/<name>/skill.md`: installable skill payload.

## Skill format

Each skill payload is a markdown file with YAML frontmatter and markdown body.

Core frontmatter fields:

- `name`
- `description`
- `tools`

Optional advanced fields:

- `runtimeMinVersion`: minimum TeaNode runtime version required.
- `httpAuth`: shared HTTP auth profiles reusable by `http` actions/tools.

- `watches`: what the agent keeps watch on through the skill's own tools,
  to tell the person about what arrives (see "Watches" below).

Supported tool types:

- `shell`
- `http`
- `workflow`

`workflow` supports:

- `steps` and `finally`
- `forEach` and `switch` control flow
- `actions` + `actionField` for first-class multi-action routing
- retries (`retries`, `retryDelayMs`) and error policy (`onError`)
- output shaping (`result: json`, `extract`, `select`, `saveAs`)
- output contracts (`outputSchema`)

Template features include:

- path lookup (`{{steps.fetch.id}}`)
- filters (`json`, `urlencode`, `base64`, `default`, `join`)
- secret loading (`{{secret:NAME}}`) with environment fallback
- direct env lookup (`{{env:NAME}}`)

## Watches

A skill can say what is worth watching. The agent runs each watch every few
minutes, for each person who has the skill installed and alerts on, using only
the tools the watch names, and tells the person about what the judgement says
they should hear about now or today, within their quiet hours, daily limit and
mutes.

```yaml
watches:
  - name: new_transactions          # lower-case words joined by underscores
    description: new transactions on their cards and bank accounts
    kind: item                      # mail: judged like mail; item: by the guidance
    every: 10m                      # how often it looks; 10m when left out
    overlap: 72h                    # how far each look reaches before the newest item seen; 10m when left out
    guidance: |                     # for item: what is worth telling, and what is not
      A charge they may not have made is worth telling now. ...
    list: {tool: link_new_transactions, arguments: {}}
    read: {tool: some_read_tool, arguments: {action: full}}   # optional
```

The list tool declares whichever of these parameters it takes, and the watch
fills them in with the moment to look from: `since` (RFC 3339), `since_epoch`
(seconds) and `since_date` (YYYY-MM-DD, UTC). It answers with a JSON array of
items, or an object with the array under `items`, each item an object with
these keys:

| Key | |
|-----|---|
| `id` | required: what the item is known by |
| `version` | changes when the item does, such as a thread's message count, so that it is looked at again |
| `at` | when it happened: RFC 3339, `YYYY-MM-DD`, or seconds since 1970 |
| `from` | who it is from: an address, a name, a merchant |
| `title` | a line saying what it is |
| `text` | what it says |
| `url` | where the person can see it |

Shape what a program prints into that with `jq`, as the skills here do. A read
tool, when there is one, takes the item's `id` and prints the item in full. The
first look only takes note of what is there.

## Included skills

| Skill | Type | Description |
|-------|------|-------------|
| `weather` | workflow | US weather forecasts via NWS API. Chains four HTTP steps: Nominatim geocoding → NWS grid lookup → hourly forecast → daily forecast. Uses `extract` and `select` for output shaping. |
| `dictionary` | http | English word definitions via dictionaryapi.dev. |
| `git` | shell | Local git operations (status, diff, log). |
| `news` | http | News headlines and search via NewsAPI. |
| `unifi-protect` | workflow | UniFi Protect camera operations with action routing. |
| `gmail` | workflow | Gmail through the `gog` command on the person's computer: search, read, draft, send and label. Watches new mail, archived or not. |
| `google-drive` | workflow | Google Drive through the `gog` command on the person's computer: search, list, read, download, upload and share. |
| `link` | workflow | Link by Stripe through the `link-cli` command on the person's computer: transactions, balances, connected accounts and insights, and payments approved in the Link app. Watches new transactions. |

## Index contract

TeaNode registry client expects entries with:

- `name`
- `description`
- `version`
- `url`
- `sha256`
- `signature`
- optional `tags`

## Signing

### Quick start

```sh
# 1) Generate a keypair (once)
scripts/generate-key.sh

# 2) Print base64 public key for TeaNode config
scripts/sign-index.sh --key keys/teanode-skills-ed25519-private.pem --print-public-key

# 3) Sign index.json in place
scripts/sign-index.sh --key keys/teanode-skills-ed25519-private.pem --in-place

# 4) Verify signatures
scripts/verify-index.sh --public-key-file keys/teanode-skills-ed25519-public.pem --index index.json
```

This bootstrap repository is populated with starter skills. Before production use,
generate signatures for each index entry and publish trusted public keys in TeaNode config.

### Makefile shortcuts

```sh
# Generate keypair
make keygen

# Print TeaNode publicKeys value (base64)
make pubkey

# Sign index.json in place
make sign

# Verify signatures
make verify
```
