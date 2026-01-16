FROM ubuntu:22.04

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    apt-transport-https \
    gnupg \
    lsb-release \
    dkms \
    make \
    linux-headers-generic \
    clang \
    llvm \
    dialog \
    systemd \
    systemd-sysv \
    vim \
    net-tools \
    iputils-ping \
    sudo \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create tester user (non-root for privilege escalation tests)
RUN useradd -m -s /bin/bash tester && \
    echo "tester ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/tester && \
    chown -R tester:tester /home/tester

# Copy Falco installation and test scripts
COPY scripts/install_falco.sh /tmp/install_falco.sh
COPY scripts/test_falco.sh /tmp/test_falco.sh
RUN chmod +x /tmp/install_falco.sh /tmp/test_falco.sh && \
    chmod 755 /tmp/install_falco.sh /tmp/test_falco.sh && \
    chown root:root /tmp/install_falco.sh /tmp/test_falco.sh && \
    chmod 4755 /tmp/install_falco.sh  # Setuid so tester can run with sudo

# Switch to tester user by default
USER tester
WORKDIR /home/tester

# Keep container running
CMD ["/bin/bash", "-c", "tail -f /dev/null"]
