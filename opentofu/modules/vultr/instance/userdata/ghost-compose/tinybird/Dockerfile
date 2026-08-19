FROM python:3.14-slim@sha256:ce40764625a4ff50df3548277632e7f96c4e77fe75fa848aae9885476e7df5a4

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
