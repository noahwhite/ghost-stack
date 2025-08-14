FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    && rm -rf /var/lib/apt/lists/*

# Install OpenTofu v1.10.5 via official standalone release (manual download)
RUN curl -L https://github.com/opentofu/opentofu/releases/download/v1.10.5/tofu_1.10.5_linux_amd64.tar.gz -o tofu.tar.gz \
    && tar -xzf tofu.tar.gz \
    && mv tofu /usr/local/bin/ \
    && chmod +x /usr/local/bin/tofu \
    && rm tofu.tar.gz



# Add user
ARG USERNAME=devops
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME/app

CMD ["/bin/bash"]