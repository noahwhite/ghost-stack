#!/bin/bash

# Ensure required secrets are available in the host environment
: "${TF_VAR_cloudflare_account_id:?Environment variable not set}"
: "${TF_VAR_cloudflare_api_token:?Environment variable not set}"

# Build container if needed
docker build -t ghost_stack_shell ./docker

# Run container with secure env injection and history suppression
HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0 docker run --rm -it \
  -e TF_VAR_cloudflare_account_id="$TF_VAR_cloudflare_account_id" \
  -e TF_VAR_cloudflare_api_token="$TF_VAR_cloudflare_api_token" \
  -e CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
  -e USER_UID="$(id -u)" \
  -e USER_GID="$(id -g)" \
  -v "$(pwd)":/home/devops/app \
  -v tofu_plugins:/home/devops/.tofu.d \
  ghost_stack_shell \
  bash --norc --noprofile -c 'unset HISTFILE; export HISTFILE=/dev/null; export HISTSIZE=0; export HISTFILESIZE=0; exec bash'
