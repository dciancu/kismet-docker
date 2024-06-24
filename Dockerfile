FROM debian:stable-slim as builder

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
RUN git clone --depth 1 https://github.com/kismetwireless/kismet.git . && rm -rf .git
RUN ./configure
RUN make
#RUN make -j $(nproc)
#RUN make suidinstall DESTDIR=/opt/kismet
#RUN make forceconfigs DESTDIR=/opt/kismet
