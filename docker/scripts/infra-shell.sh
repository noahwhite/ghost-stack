#!/bin/bash

# Build container if needed
docker build -t ghost_stack_shell .

# Run container with:
# - your UID/GID
# - current dir mounted
# - TTY + bash
docker run --rm -it \
  -e USER_UID=$(id -u) \
  -e USER_GID=$(id -g) \
  -v $(pwd):/home/devops/app \
  -v tofu_plugins:/home/devops/.tofu.d \
  ghost_stack_shell