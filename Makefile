SHELL := /usr/bin/env bash

INDEX ?= index.json
KEY ?= keys/teanode-skills-ed25519-private.pem
PUB ?= keys/teanode-skills-ed25519-public.pem
KEY_DIR ?= keys
KEY_NAME ?= teanode-skills

.PHONY: help keygen pubkey sign sign-out verify

help:
	@echo "Targets:"
	@echo "  make keygen                 # generate Ed25519 keypair into $(KEY_DIR)/"
	@echo "  make pubkey                 # print base64 public key for TeaNode config"
	@echo "  make sign                   # sign $(INDEX) in place using $(KEY)"
	@echo "  make sign-out OUT=...       # sign to output file"
	@echo "  make verify                 # verify signatures in $(INDEX) using $(PUB)"

keygen:
	scripts/generate-key.sh "$(KEY_DIR)" "$(KEY_NAME)"

pubkey:
	scripts/sign-index.sh --key "$(KEY)" --print-public-key

sign:
	scripts/sign-index.sh --key "$(KEY)" --index "$(INDEX)" --in-place

sign-out:
	@test -n "$(OUT)" || (echo "OUT is required, e.g. make sign-out OUT=index.signed.json" >&2; exit 1)
	scripts/sign-index.sh --key "$(KEY)" --index "$(INDEX)" --output "$(OUT)"

verify:
	scripts/verify-index.sh --public-key-file "$(PUB)" --index "$(INDEX)"
