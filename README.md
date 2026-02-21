# teanode-skills

Official community skill registry content for TeaNode.

## Layout

- `index.json`: registry index consumed by TeaNode.
- `skills/<name>/<version>/skill.md`: installable skill payload.

## Skill Format

Each skill payload is a markdown file with YAML frontmatter and markdown body.

## Index Contract (current)

The current TeaNode registry client expects entries with:

- `name`
- `description`
- `version`
- `url`
- `sha256`
- `signature` (required by policy; fill with a valid signature for production)
- optional `tags`

## Signing

### Quick start

```sh
# 1) Generate a keypair (once)
scripts/generate-key.sh

# 2) Print base64 public key for TeaNode config
scripts/sign-index.sh --key keys/teanode-skills-ed25519-private.pem --print-public-key

# 3) Sign index.json in place

# 4) Verify signatures in index.json
scripts/verify-index.sh --public-key-file keys/teanode-skills-ed25519-public.pem --index index.json
scripts/sign-index.sh --key keys/teanode-skills-ed25519-private.pem --in-place
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
