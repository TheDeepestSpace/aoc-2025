FROM public.ecr.aws/lts/ubuntu:22.04_stable

ARG DEBIAN_FRONTEND=noninteractive
ARG KEYRING_PATH=/usr/share/keyrings
ARG APT_SOURCES_PATH=/etc/apt/sources.list.d

# update and upgrade
RUN apt update && apt upgrade -y

# install essentialls
RUN apt update && \
    apt install -y \
    man make build-essential git zsh vim curl wget procps gnupg gnupg2 ca-certificates zip \
    software-properties-common

# unminimize the system
RUN bash -c "yes | unminimize"

# create dev sudo user
RUN useradd --create-home dev && \
    usermod --append --groups sudo dev && \
    apt update && apt install -y sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# install dumb init system
USER root
RUN apt update && apt install -y dumb-init

# setup oh-my-zsh
USER dev
ARG DOCKER_OHMYZSH_SCRIPT_NAME=zsh-in-docker.sh
ARG DOCKER_OHMYZSH_SCRIPT_URL=https://github.com/deluan/zsh-in-docker/releases/download/v1.1.3/${DOCKER_OHMYZSH_SCRIPT_NAME}
ARG DOCKER_OHMYZSH_SCRIPT_HASH="ffa8175332ef01b500ace59d03ce7e2f3a7453651e9a37060974bb6536f0706b  ${DOCKER_OHMYZSH_SCRIPT_NAME}"
RUN cd /tmp && \
    wget ${DOCKER_OHMYZSH_SCRIPT_URL} && \
    echo ${DOCKER_OHMYZSH_SCRIPT_HASH} | sha256sum -c && \
    chmod +x ./${DOCKER_OHMYZSH_SCRIPT_NAME} && \
    ./${DOCKER_OHMYZSH_SCRIPT_NAME} -t robbyrussell -p git -p ssh-agent && \
    rm ./${DOCKER_OHMYZSH_SCRIPT_NAME}

# build and install Verilator
USER dev
ARG VERILATOR_VERSION=v5.042
ARG VERILATOR_GIT_REPO=https://github.com/verilator/verilator
RUN sudo apt update && \
    sudo apt-get install -y git help2man perl python3 make autoconf g++ flex bison ccache \
    libgoogle-perftools-dev numactl perl-doc \
    libfl2 \
    libfl-dev \
    zlib1g zlib1g-dev && \
    cd /tmp && \
    git clone --depth=1 --branch ${VERILATOR_VERSION} ${VERILATOR_GIT_REPO} && \
    cd verilator && \
    autoconf && ./configure && make -j `nproc` && sudo make install && \
    cd .. && rm -rf verilator

# install cocotb
USER dev
RUN sudo apt update && sudo apt install -y python3 python3-pip libpython3-dev && \
  pip3 install cocotb~=1.9

# install svlint
USER dev
ARG SVLINT_VERSION=0.9.3
ARG SVLINT_ZIP_NAME=svlint-v${SVLINT_VERSION}-x86_64-lnx.zip
ARG SVLINT_ZIP_URL=https://github.com/dalance/svlint/releases/download/v${SVLINT_VERSION}/${SVLINT_ZIP_NAME}
ARG SVLINT_ZIP_HASH="df44caa38e0cddd09bafa93365d489e47f4823bdda26aa923028c2f06df90456  ${SVLINT_ZIP_NAME}"
RUN mkdir -p /tmp/svlint && \
    cd /tmp/svlint && \
    wget ${SVLINT_ZIP_URL} && \
    echo ${SVLINT_ZIP_HASH} | sha256sum -c && \
    unzip ${SVLINT_ZIP_NAME} && \
    sudo mv bin/* /usr/local/bin/ && \
    cd .. && rm -r /tmp/svlint

# install svls
USER dev
ARG SVLS_VERSION=0.2.12
ARG SVLS_ZIP_NAME=svls-v${SVLS_VERSION}-x86_64-lnx.zip
ARG SVLS_ZIP_URL=https://github.com/dalance/svls/releases/download/v${SVLS_VERSION}/${SVLS_ZIP_NAME}
ARG SVLS_ZIP_HASH="bebdb42731d3d186c7de4263651f0cf06f346f492b30398a128465f50136f33f  ${SVLS_ZIP_NAME}"
RUN mkdir -p /tmp/svls && \
    cd /tmp/svls && \
    wget ${SVLS_ZIP_URL} && \
    echo ${SVLS_ZIP_HASH} | sha256sum -c && \
    unzip ${SVLS_ZIP_NAME} && \
    sudo mv svls /usr/local/bin/ && \
    cd .. && rm -r /tmp/svls

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
