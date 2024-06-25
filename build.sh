#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

image_name="${DOCKER_IMAGE:-dciancu/kismet-wireless-docker}"
image_arch="${BUILD_ARCH:-$(arch | tr -d '\n')}"

if [[ -n "${CIRCLE_BRANCH+x}" ]] && [[ "$CIRCLE_BRANCH" == 'test' ]]; then
    image_stable_tag="${image_name}:test-stable-${image_arch}"
    build_stable_tag="${image_name}:test-build-stable-${image_arch}"
    image_edge_tag="${image_name}:test-edge-${image_arch}"
    build_edge_tag="${image_name}:test-build-edge-${image_arch}"
else
    if [[ -n "${CIRCLE_BRANCH+x}" ]] && [[ "$CIRCLE_BRANCH" == 'build' ]]; then
        docker images | grep "$image_name" | tr -s ' ' | cut -d ' ' -f 2 \
            | xargs -I {} docker rmi -f "${image_name}:{}" || true
        docker buildx prune -f
    fi
    image_stable_tag="${image_name}:stable-${image_arch}"
    build_stable_tag="${image_name}:build-stable-${image_arch}"
    image_edge_tag="${image_name}:edge-${image_arch}"
    build_edge_tag="${image_name}:build-edge-${image_arch}"
fi

docker build --target build -t "$build_stable_tag" --pull \
    --build-arg KISMET_STABLE=1 --build-arg "KISMET_REPO=${KISMET_REPO:-}" .
#docker build --target build -t "$build_edge_tag" --build-arg "KISMET_REPO=${KISMET_REPO:-}" .

docker build -t "$image_stable_tag" --pull --build-arg KISMET_STABLE=1 --build-arg "KISMET_REPO=${KISMET_REPO:-}" .
#docker build -t "$image_edge_tag" --build-arg "KISMET_REPO=${KISMET_REPO:-}" .

if [[ -n "${CIRCLE_BRANCH+x}" ]]; then
    echo "$DOCKER_PASS" | docker login -u "$DOCKER_USERNAME" --password-stdin

    docker push "$image_stable_tag"
#    docker push "$image_edge_tag"

    if [[ "$CIRCLE_BRANCH" == 'test' ]]; then
        docker push "$build_stable_tag"
#        docker push "$build_edge_tag"
    fi
fi
