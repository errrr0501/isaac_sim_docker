FROM nvcr.io/nvidia/isaac-sim:4.2.0
############################## SYSTEM PARAMETERS ##############################
# * Arguments
ARG USER=initial
ARG GROUP=initial
ARG UID=1001
ARG GID="${UID}"
ARG SHELL=/bin/bash
ARG HARDWARE=x86_64
ARG ENTRYPOINT_FILE=entrypint.sh

# * Env vars for the nvidia-container-runtime.
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all
# ENV NVIDIA_DRIVER_CAPABILITIES graphics,utility,compute


# RUN set -eux; \
#     # If there's already a group with GID=1000, remove it
#     if getent group "${GID}" >/dev/null; then \
#         groupdel "$(getent group "${GID}" | cut -d: -f1)"; \
#     fi; \
#     # If there's already a user with UID=1000, remove it
#     if getent passwd "${UID}" >/dev/null; then \
#         userdel -r "$(getent passwd "${UID}" | cut -d: -f1)"; \
#     fi;
# 1) Remove the user `ubuntu` first, if it exists
RUN if id "ubuntu" &>/dev/null; then \
      userdel -r ubuntu; \
    fi


RUN groupadd --gid "${GID}" "${GROUP}" \
    && useradd --gid "${GID}" --uid "${UID}" -ms "${SHELL}" "${USER}" \
    && mkdir -p /etc/sudoers.d \
    && echo "${USER}:x:${UID}:${UID}:${USER},,,:/home/${USER}:${SHELL}" >> /etc/passwd \
    && echo "${USER}:x:${UID}:" >> /etc/group \
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${USER}" \
    && chmod 0440 "/etc/sudoers.d/${USER}"

# * Replace apt urls
# ? Change to tku
# RUN sed -i 's@archive.ubuntu.com@ftp.tku.edu.tw@g' /etc/apt/sources.list
# ? Change to Taiwan
# RUN sed -i 's@archive.ubuntu.com@tw.archive.ubuntu.com@g' /etc/apt/sources.list

# * Time zone
ENV TZ=Asia/Taipei
RUN ln -snf /usr/share/zoneinfo/"${TZ}" /etc/localtime && echo "${TZ}" > /etc/timezone

# * Copy custom configuration
# ? Requires docker version >= 17.09
COPY --chmod=0775 ./${ENTRYPOINT_FILE} /entrypoint.sh
COPY --chown="${USER}":"${GROUP}" --chmod=0775 config config



RUN apt update \
    && apt install -y --no-install-recommends \
        sudo \
        vim \
        git \
        htop \
        wget \
        curl \
        psmisc \
        git-lfs \
        # * Shell
        tmux \
        terminator \
        # * base tools
        udev \
        python3-pip \
        python3-dev \
        python3-setuptools \
        software-properties-common \
        lsb-release \
        # * Work tools
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# * add key requirement
RUN apt-get update && apt-get install -y \
    gnupg \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# * add cuda key
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub \
    && mkdir -p /etc/apt/keyrings \
    && gpg --dearmor < 3bf863cc.pub > /etc/apt/keyrings/cuda-archive-keyring.gpg \
    && rm 3bf863cc.pub

RUN echo "deb [signed-by=/etc/apt/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /" | tee /etc/apt/sources.list.d/cuda.list



# * install cuda 11.8
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
RUN mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
RUN apt update
RUN apt install -y cuda-toolkit-11-8 

RUN ./config/pip/pip_setup.sh

# # * install torch
# RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# * install ROS2
RUN apt install -y software-properties-common
RUN add-apt-repository universe
RUN apt update && apt install curl -y
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null
RUN apt update
RUN apt install -y ros-humble-desktop
RUN apt install -y python3-colcon-common-extensions

# * Cyclone DDS
RUN apt install -y ros-humble-rmw-cyclonedds-cpp


# ############################# USER CONFIG ####################################
# * Switch user to ${USER}
USER ${USER}

RUN ./config/shell/bash_setup.sh "${USER}" "${GROUP}" \
    && ./config/shell/terminator/terminator_setup.sh "${USER}" "${GROUP}" \
    && ./config/shell/tmux/tmux_setup.sh "${USER}" "${GROUP}" \
    && ./config/pip/pip_setup.sh \
    && sudo rm -rf /config

RUN export CXX=g++
RUN export MAKEFLAGS="-j nproc"

RUN echo "export PATH="/usr/local/cuda-11.8/bin:$PATH"" >> ~/.bashrc
RUN echo "LD_LIBRARY_PATH="/usr/local/cuda-11.8/lib64:$LD_LIBRARY_PATH"" >> ~/.bashrc

RUN echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
RUN echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> ~/.bashrc

# * Switch workspace to ~/work
RUN mkdir -p /home/"${USER}"/work
WORKDIR /home/"${USER}"/work

RUN git clone https://github.com/NVlabs/curobo.git

WORKDIR /home/"${USER}"/work/curobo

ENV TORCH_CUDA_ARCH_LIST="8.9"

# # * install torch
RUN ["/bin/bash", "-c", "/isaac-sim/python.sh -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118"]
# * install curobo
RUN echo "alias omni_python='/isaac-sim/python.sh'" >> ~/.bashrc
RUN ["/bin/bash", "-c", "source ~/.bashrc"]
RUN ["/bin/bash", "-c", "/isaac-sim/python.sh -m pip install tomli wheel ninja"]
RUN ["/bin/bash", "-c", "/isaac-sim/python.sh -m pip install -e .[isaacsim] --no-build-isolation"]

RUN sudo apt update && sudo apt install -y ros-humble-moveit*
RUN sudo apt install -y ros-humble-ros2-control
RUN sudo apt install -y ros-humble-ros2-controllers
RUN sudo apt install -y ninja-build
# RUN sudo apt install -y ros-humble-control*
RUN sudo apt install ros-humble-topic-based-ros2-control
RUN sudo chown -R "${USER}":"${USER}" /isaac-sim*


WORKDIR /home/"${USER}"/work


# * Make SSH available
EXPOSE 22

ENTRYPOINT [ "/entrypoint.sh", "terminator" ]
# ENTRYPOINT [ "/entrypoint.sh", "tmux" ]
# ENTRYPOINT [ "/entrypoint.sh", "bash" ]
# ENTRYPOINT [ "/entrypoint.sh" ]
