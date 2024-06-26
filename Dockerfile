FROM debian:12-slim as build

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/usr/bin/env", "bash", "-c"]

# https://www.kismetwireless.net/docs/readme/installing/linux/

RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    set -euo pipefail \
    && apt-get update \
    && apt-get install -y apt-transport-https ca-certificates \
    && sed -i 's/http:/https:/g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get -y dist-upgrade \
    && apt-get --purge autoremove -y \
    && apt-get --no-install-recommends -y install \
        build-essential git libwebsockets-dev pkg-config \
        zlib1g-dev libnl-3-dev libnl-genl-3-dev libcap-dev libpcap-dev \
        libnm-dev libdw-dev libsqlite3-dev libprotobuf-dev libprotobuf-c-dev \
        protobuf-compiler protobuf-c-compiler libsensors4-dev libusb-1.0-0-dev \
        python3 python3-setuptools python3-protobuf python3-requests \
        python3-numpy python3-serial python3-usb python3-dev python3-websockets \
        librtlsdr0 libubertooth-dev libbtbb-dev libmosquitto-dev rtl-433 \
    && adduser --gecos '' --shell /bin/bash --disabled-password --disabled-login kismet-build \
    && mkdir /opt/kismet-build \
    && mkdir /opt/kismet \
    && chown kismet-build:kismet-build /opt/kismet-build /opt/kismet

USER kismet-build
WORKDIR /opt/kismet-build

COPY configure_override.txt /opt/

ARG KISMET_STABLE
ARG KISMET_REPO_URL
ARG KISMET_REPO='https://github.com/kismetwireless/kismet.git'
RUN set -euo pipefail \
    && KISMET_STABLE="${KISMET_STABLE:-}" \
    && KISMET_REPO_URL="${KISMET_REPO_URL:-$KISMET_REPO}" \
    # KISMET_STABLE not set \
    && test ! -z "$KISMET_STABLE" || BRANCH='master' \
    # KISMET_STABLE set \
    && test -z "$KISMET_STABLE" || \
        BRANCH="$(set -euo pipefail && git init &>/dev/null \
            && git remote add origin "$KISMET_REPO_URL" &>/dev/null \
            && git ls-remote --tags origin \
                | cut -f 2 \
                | cut -d / -f 3 \
                | grep -P '[kK]ismet-\d+-\d+-R[a-zA-Z0-9]+' \
                | sort -V \
                | tail -n 1 \
                | tr -d '\n' \
            && rm -rf .git &>/dev/null \
        )" \
    && echo "Cloning branch ${BRANCH} of ${KISMET_REPO_URL}" \
    && git clone --depth 1 --branch "$BRANCH" "$KISMET_REPO_URL" . \
    && rm -rf .git
RUN ./configure $(grep -o '^[^#]*' /opt/configure_override.txt | tr '\n' ' ')
#RUN make
RUN make -j "$(nproc)"

USER root
RUN addgroup --gid 1500 kismet
RUN make suidinstall DESTDIR=/opt/kismet
#RUN make forceconfigs DESTDIR=/opt/kismet


FROM debian:12-slim AS image

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/usr/bin/env", "bash", "-c"]

ARG KISMET_APT_KEY_URL='https://www.kismetwireless.net/repos/kismet-release.gpg.key'
ARG KISMET_APT_URL='https://www.kismetwireless.net/repos/apt/release/bookworm'
RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    set -euo pipefail \
    && apt-get update \
    && apt-get install -y apt-transport-https ca-certificates \
    && sed -i 's/http:/https:/g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get -y dist-upgrade \
    && apt-get --purge autoremove -y \
    && apt-get --no-install-recommends -y install gpg wget \
    && wget -O - "$KISMET_APT_KEY_URL" --quiet \
        | gpg --dearmor \
        | tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] ${KISMET_APT_URL} ${KISMET_APT_URL##*/} main" \
        | tee /etc/apt/sources.list.d/kismet.list \
    && apt-get update \
    && apt-get --no-install-recommends -y install \
        libubertooth1 \
        $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances kismet \
            | grep '^\w' \
            | grep -Pv 'kismet|libelogind0' \
            | sort -u \
            | tr '\n' ' ' \
        ) \
    && rm /etc/apt/sources.list.d/kismet.list /usr/share/keyrings/kismet-archive-keyring.gpg \
    && addgroup --gid 1500 kismet \
    && adduser --gecos '' --shell /bin/bash --disabled-password --disabled-login --gid 1500 kismet

COPY --from=build /opt/kismet /
RUN su -l -c 'kismet --version' kismet || true
RUN echo -e '\nopt_override=/mnt/custom-conf/kismet_custom.conf' >> /usr/local/etc/kismet.conf \
    && mv /usr/local/etc /usr/local/etc.orig \
    && mkdir /usr/local/etc \
    && mv /home/kismet /home/kismet.orig \
    && mkdir /home/kismet \
    && mkdir /mnt/custom-conf

COPY entrypoint.sh /

EXPOSE 2501/tcp
EXPOSE 3501/tcp
CMD ["/bin/bash", "/entrypoint.sh"]
