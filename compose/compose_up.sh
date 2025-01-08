#!/usr/bin/env bash

# Get dependent parameters
source "$(dirname "$(readlink -f "${0}")")/get_param.sh"



# helpFunction()
# {
#    echo ""
#    echo "Usage: $0 -image1 Image1 -image2 Image2"
#    echo -e "\t-a Description of what is Image1"
#    echo -e "\t-b Description of what is Image2"
#    exit 1 # Exit script after printing help
# }

# while getopts "a:b:c:" opt
# do
#    case "$opt" in
#       image1 ) Image1="$OPTARG" ;;
#       image2 ) Image2="$OPTARG" ;;
#       ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
#    esac
# done

# # Print helpFunction in case parameters are empty
# if [ -z "$Image1" ] || [ -z "$Image2" ]
# then
#    echo "Some or all of the parameters are empty";
#    helpFunction
# fi

image1=\'$1\'
image2=\'$2\'

# set -x
# Write docker compose parameters to .env file
cat << EOF >> ${FILE_DIR}/.env
DOCKER_HUB_USER=${DOCKER_HUB_USER}
user=${user}
group=${group}
uid=${uid}
gid=${gid}
hardware=${hardware}
FILE_DIR=${FILE_DIR}
WS_PATH=${WS_PATH}
IMAGE=${IMAGE}
CONTAINER=${CONTAINER}
DOCKERFILE_NAME=${DOCKERFILE_NAME}
ENTRYPOINT_FILE=${ENTRYPOINT_FILE}
COMPOSE_GPU_FLAG=${COMPOSE_GPU_FLAG}
COMPOSE_GPU_CAPABILITIES=${COMPOSE_GPU_CAPABILITIES}
EOF

# TODO: multi docker container up
# Create a new Docker Compose file
cat << EOF > docker-compose.yml
services:
  basic: &basic
    # docker build params
    #image: ${DOCKER_HUB_USER}/${IMAGE}
    image: ${image1}
    # image: ${DOCKER_HUB_USER}/${IMAGE}:${tag}
    # build:
    #   context: ${FILE_DIR}
    #   dockerfile: ${DOCKERFILE_NAME}
    #   args:
    #     user: ${user}
    #     UID: ${uid}
    #     GROUP: ${group}
    #     GID: ${gid}
    #     HARDWARE: ${hardware}
    #     ENTRYPOINT_FILE: ${ENTRYPOINT_FILE}
    # docker run params
    container_name: ${CONTAINER}
    # tty: true
    # stdin_open: true
    # restart: no
    privileged: true
    runtime: nvidia
    network_mode: host
    ipc: host
    environment:
      #- NVIDIA_VISIBLE_DEVICES=all
      - XAUTHORITY=/home/${user}/.Xauthority
      - DISPLAY=${DISPLAY}
      - QT_X11_NO_MITSHM=1
    volumes:
      - ${WS_PATH}:/home/${user}/work
      - /dev:/dev
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
      - /tmp/.Xauthority:/home/${user}/.Xauthority:rw
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    # ports:
    #   - "5000:5000"
  20.04_cuda12_tf1.15:
    #image: taiting/20.04_cuda12_tf1.15
    image: ${image2}
    runtime: nvidia
    privileged: true
    # network: host
    # ipc: host
    environment:
      # - NVIDIA_VISIBLE_DEVICES=all
      - XAUTHORITY=/home/${user}/.Xauthority
      - DISPLAY=${DISPLAY}
      - QT_X11_NO_MITSHM=1
    volumes: 
      - ${WS_PATH}:/home/${user}/work/
      - /dev:/dev
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
      - /tmp/.Xauthority:/home/${user}/.Xauthority:rw
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    # ports:
    #   - 8080:80
    links:
      - basic:ubuntu22
EOF

# TODO: confirm nvidia card found, enable gpu functionality
cat << EOF >> docker-compose.yml
    deploy:
      resources:
        reservations:
          devices:
            - driver: ${COMPOSE_GPU_FLAG}
              capabilities: [${COMPOSE_GPU_CAPABILITIES}]
EOF

# TODO: get_parm.sh add docker-compose.yml
# * docker compose up
docker compose \
    -f ${FILE_DIR}/docker-compose.yml \
    --env-file ${FILE_DIR}/.env \
    up --build -d

# * remove docker compose
# docker rm -f ${CONTAINER} >/dev/null && echo "remove '${CONTAINER}' container"
