#!/usr/bin/env bash

# Get dependent parameters
source "$(dirname "$(readlink -f "${0}")")/get_param.sh"

docker run --rm \
    --privileged \
    --network=host \
    --ipc=host \
    ${GPU_FLAG} \
    -v /tmp/.Xauthority:/home/"${user}"/.Xauthority \
    -e XAUTHORITY=/home/"${user}"/.Xauthority \
    -e DISPLAY="${DISPLAY}" \
    -e QT_X11_NO_MITSHM=1 \
    -e "ACCEPT_EULA=Y" \
    -e "OMNI_USER=<admin>" \
    -e "OMNI_PASS=<admin>" \
    -e "PRIVACY_CONSENT=Y" \
    -v ~/docker/isaac-sim/cache/kit:/isaac-sim/kit/cache:rw \
    -v ~/docker/isaac-sim/cache/ov:/${user}/.cache/ov:rw \
    -v ~/docker/isaac-sim/cache/pip:/${user}/.cache/pip:rw \
    -v ~/docker/isaac-sim/cache/glcache:/${user}/.cache/nvidia/GLCache:rw \
    -v ~/docker/isaac-sim/cache/computecache:/${user}/.nv/ComputeCache:rw \
    -v ~/docker/isaac-sim/logs:/${user}/.nvidia-omniverse/logs:rw \
    -v ~/docker/isaac-sim/data:/${user}/.local/share/ov/data:rw \
    -v ~/docker/isaac-sim/documents:/${user}/Documents:rw \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /etc/timezone:/etc/timezone:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v /dev:/dev \
    -v "${WS_PATH}":/home/"${user}"/work \
    -it --name "${CONTAINER}" "${DOCKER_HUB_USER}"/"isaac-sim"

