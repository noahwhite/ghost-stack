FROM python:3.14-slim@sha256:4ed33101ee7ec299041cc41dd268dae17031184be94384b1ce7936dc4e5dead3

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
