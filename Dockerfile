FROM debian:12-slim as builder

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
    && chown kismet-build:kismet-build /opt/kismet-build

USER kismet-build
WORKDIR /opt/kismet-build

ARG KISMET_STABLE
ARG KISMET_REPO='https://github.com/kismetwireless/kismet.git'
RUN set -euo pipefail \
    && KISMET_STABLE="${KISMET_STABLE:-}" \
    # KISMET_STABLE not set \
    && test ! -z "$KISMET_STABLE" || BRANCH='master' \
    # KISMET_STABLE set
    && test -z "$KISMET_STABLE" || \
        BRANCH="$(set -euo pipefail && git init &>/dev/null \
            && git remote add origin "$KISMET_REPO" &>/dev/null \
            && git ls-remote --tags origin \
                | cut -f 2 \
                | cut -d / -f 3 \
                | grep -P '[kK]ismet-\d+-\d+-R[a-zA-Z0-9]+' \
                | sort -V \
                | tail -n 1 \
                | tr -d '\n' \
            && rm -rf .git &>/dev/null \
        )" \
    && echo "Cloning branch ${BRANCH} of ${KISMET_REPO}" \
    && git clone --depth 1 --branch "$BRANCH" "$KISMET_REPO" . \
    && rm -rf .git
RUN ./configure
#RUN make
RUN make -j "$(nproc)"
#RUN make suidinstall DESTDIR=/opt/kismet
#RUN make forceconfigs DESTDIR=/opt/kismet


FROM debian:12-slim AS image

COPY --from=builder /opt/kismet-build /opt/kismet-build

RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    set -euo pipefail \
    && apt-get update \
    && apt-get install -y apt-transport-https ca-certificates \
    && sed -i 's/http:/https:/g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get -y dist-upgrade \
    && apt-get --purge autoremove -y \
    && apt-get --no-install-recommends -y install make

RUN set -euo pipefail \
    && cd /opt/kismet-build \
    && make suidinstall DESTDIR=/opt/kismet
