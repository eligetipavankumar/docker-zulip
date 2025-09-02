# Stage 1: Base image
FROM ubuntu:24.04 AS base

ENV LANG="C.UTF-8"

ARG UBUNTU_MIRROR

RUN { [ ! "$UBUNTU_MIRROR" ] || sed -i "s|http://\(\w*\.\)*archive\.ubuntu\.com/ubuntu/\? |$UBUNTU_MIRROR |" /etc/apt/sources.list; } && \
    apt-get -q update && \
    apt-get -q dist-upgrade -y && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -q install --no-install-recommends -y ca-certificates git locales python3 sudo tzdata && \
    touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu && \
    useradd -d /home/zulip -m zulip -u 1000

# Stage 2: Build release tarball
FROM base AS build

RUN echo 'zulip ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

USER zulip
WORKDIR /home/zulip

ARG ZULIP_GIT_URL=https://github.com/zulip/zulip.git
ARG ZULIP_GIT_REF=11.0

RUN git clone "$ZULIP_GIT_URL" && \
    cd zulip && \
    git checkout -b current "$ZULIP_GIT_REF"

WORKDIR /home/zulip/zulip

ARG CUSTOM_CA_CERTIFICATES

# Build production release tarball
RUN SKIP_VENV_SHELL_WARNING=1 ./tools/provision --build-release-tarball-only && \
    uv run --no-sync ./tools/build-release-tarball docker && \
    mv /tmp/tmp.*/zulip-server-docker.tar.gz /tmp/zulip-server-docker.tar.gz

# Stage 3: Production image
FROM base

ENV DATA_DIR="/data"

# Install production release
COPY --from=build /tmp/zulip-server-docker.tar.gz /root/
COPY custom_zulip_files/ /root/custom_zulip

ARG CUSTOM_CA_CERTIFICATES

RUN \
    dpkg-divert --add --rename /etc/init.d/nginx && \
    ln -s /bin/true /etc/init.d/nginx && \
    mkdir -p "$DATA_DIR" && \
    cd /root && \
    tar -xf zulip-server-docker.tar.gz && \
    rm -f zulip-server-docker.tar.gz && \
    mv zulip-server-docker zulip && \
    cp -rf /root/custom_zulip/* /root/zulip && \
    rm -rf /root/custom_zulip && \
    /root/zulip/scripts/setup/install --hostname="$(hostname)" --email="docker-zulip" \
      --puppet-classes="zulip::profile::docker" --postgresql-version=14 && \
    rm -f /etc/zulip/zulip-secrets.conf /etc/zulip/settings.py && \
    apt-get -qq autoremove --purge -y && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy entrypoint & make executable
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod +x /sbin/entrypoint.sh

# Copy certbot hook
COPY certbot-deploy-hook /sbin/certbot-deploy-hook

VOLUME ["$DATA_DIR"]
EXPOSE 25 80 443

# Set entrypoint and default command
ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["app:run"]
