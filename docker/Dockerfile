FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    tar \
    unzip \
    ca-certificates \
    bash \
    git \
    gnupg \
    xclip \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install OpenTofu v1.11.1 via official standalone release (manual download)
RUN curl -L https://github.com/opentofu/opentofu/releases/download/v1.11.1/tofu_1.11.1_linux_amd64.tar.gz -o tofu.tar.gz \
    && tar -xzf tofu.tar.gz \
    && mv tofu /usr/local/bin/ \
    && chmod +x /usr/local/bin/tofu \
    && rm tofu.tar.gz

# Install Vultr CLI v3.4.0 for block storage attachment workaround
# See: https://github.com/vultr/vultr-cli/releases
RUN curl -L https://github.com/vultr/vultr-cli/releases/download/v3.4.0/vultr-cli_v3.4.0_linux_amd64.tar.gz -o vultr-cli.tar.gz \
    && tar -xzf vultr-cli.tar.gz \
    && mv vultr-cli /usr/local/bin/ \
    && chmod +x /usr/local/bin/vultr-cli \
    && rm vultr-cli.tar.gz



# Add user
ARG USERNAME=devops
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME/app

CMD ["/bin/bash"]
