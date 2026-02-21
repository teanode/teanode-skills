# teanode-skills

Official community skill registry content for TeaNode.

## Layout

- `index.json`: registry index consumed by TeaNode.
- `skills/<name>/<version>/skill.md`: installable skill payload.

## Skill format

Each skill payload is a markdown file with YAML frontmatter and markdown body.

Core frontmatter fields:

- `name`
- `description`
- `tools`

Optional advanced fields:

- `runtimeMinVersion`: minimum TeaNode runtime version required.
- `httpAuth`: shared HTTP auth profiles reusable by `http` actions/tools.

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
