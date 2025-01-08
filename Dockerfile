FROM nvcr.io/nvidia/isaac-sim:4.2.0
############################## SYSTEM PARAMETERS ##############################
# * Arguments
ARG USER=initial
ARG GROUP=initial
ARG UID=1000
ARG GID="${UID}"
ARG SHELL=/bin/bash
ARG HARDWARE=x86_64
ARG ENTRYPOINT_FILE=entrypint.sh

# * Env vars for the nvidia-container-runtime.
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all
# ENV NVIDIA_DRIVER_CAPABILITIES graphics,utility,compute


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


RUN apt update && apt install -y --no-install-recommends \
    python3-pip \
    git-lfs \
    wget \
    # cuda-toolkit-11-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists  

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


RUN ./config/pip/pip_setup.sh


# * install cuda 11.8
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
RUN mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
RUN apt update
RUN apt install -y cuda-toolkit-11-8 

RUN echo "export PATH="/usr/local/cuda-11.8/bin:$PATH"" >> ~/.bashrc
RUN echo "LD_LIBRARY_PATH="/usr/local/cuda-11.8/lib64:$LD_LIBRARY_PATH"" >> ~/.bashrc


# * install torch
RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118



RUN mkdir -p /home/"${USER}"/work
WORKDIR /home/"${USER}"/work

RUN git clone https://github.com/NVlabs/curobo.git

WORKDIR /home/"${USER}"/work/curobo

ENV TORCH_CUDA_ARCH_LIST="8.9"

# * install curobo
RUN echo "alias omni_python='/isaac-sim/python.sh'" >> ~/.bashrc
RUN ["/bin/bash", "-c", "source ~/.bashrc"]
RUN ["/bin/bash", "-c", "/isaac-sim/python.sh -m pip install tomli wheel ninja"]
RUN ["/bin/bash", "-c", "/isaac-sim/python.sh -m pip install -e .[isaacsim] --no-build-isolation"]

WORKDIR /home/"${USER}"/work

# * install ROS2
RUN apt install -y software-properties-common
RUN add-apt-repository universe
RUN apt update && apt install curl -y
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null
RUN apt update
RUN apt install -y ros-humble-desktop
# * Cyclone DDS
RUN apt install -y ros-humble-rmw-cyclonedds-cpp
RUN echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
RUN echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> ~/.bashrc


# * Make SSH available
EXPOSE 22

# ENTRYPOINT [ "/entrypoint.sh", "terminator" ]
# ENTRYPOINT [ "/entrypoint.sh", "tmux" ]
ENTRYPOINT [ "/entrypoint.sh", "bash" ]
# ENTRYPOINT [ "/entrypoint.sh" ]
