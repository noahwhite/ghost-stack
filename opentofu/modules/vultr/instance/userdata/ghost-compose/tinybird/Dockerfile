FROM python:3.14-slim@sha256:6a27522252aef8432841f224d9baaa6e9fce07b07584154fa0b9a96603af7456

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /data/tinybird

# Install Tinybird CLI
RUN curl https://tinybird.co | sh

ENV PATH="/root/.local/bin:$PATH"

# Default entrypoint for tb CLI operations
ENTRYPOINT ["tb"]
