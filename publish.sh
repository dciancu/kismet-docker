#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

image_name="${DOCKER_IMAGE:-dciancu/kismet-wireless-docker}"

function pushManifest() {
    docker manifest create "$1" "${2:-$1}-arm" "${2:-$1}-x86"
    docker manifest push "$1"
}

echo "$DOCKER_PASS" | docker login -u "$DOCKER_USERNAME" --password-stdin

if [[ -n "${CIRCLE_BRANCH+x}" ]] && [[ "$CIRCLE_BRANCH" == 'test' ]]; then
    pushManifest "${image_name}:test-stable"
    pushManifest "${image_name}:test-edge"
    pushManifest "${image_name}:test-build-stable"
    pushManifest "${image_name}:test-build-edge"
else
    pushManifest "${image_name}:stable"
    pushManifest "${image_name}:edge"

    version="$(tr -d '\n' < VERSION.txt)"
    pushManifest "${image_name}:stable-${version}" "${image_name}:stable"
    pushManifest "${image_name}:edge-${version}" "${image_name}:edge"
fi

