FROM ubuntu:22.04
LABEL authors="noah@noahwhite.net"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    file \
    squashfs-tools \
    xz-utils \
    binutils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /build

# Set up environment
ENV VERSION=1.10.2
ENV ARCHITECTURE=amd64

CMD ["/bin/bash"]