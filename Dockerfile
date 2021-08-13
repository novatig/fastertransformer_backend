ARG BASE_IMAGE=nvcr.io/nvidia/tritonserver:21.07-py3
ARG SDK_IMAGE=nvcr.io/nvidia/tritonserver:21.07-py3-sdk

ARG MODEL_ANALYZER_VERSION=1.6.0
ARG MODEL_ANALYZER_CONTAINER_VERSION=21.07

FROM ${SDK_IMAGE} as sdk_image

FROM $BASE_IMAGE

ARG MODEL_ANALYZER_VERSION
ARG MODEL_ANALYZER_CONTAINER_VERSION

# DCGM version to install for Model Analyzer
ENV DCGM_VERSION=2.0.13

# Ensure apt-get won't prompt for selecting options
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y python3-dev \
        libpng-dev \
        curl \
        libopencv-dev \
        libopencv-core-dev \
        libzmq3-dev \
        python3-dev \
        python3-pip \
        python3-protobuf \
        python3-setuptools \
        swig \
        golang-go \
        nginx \
        protobuf-compiler \
        valgrind \
        wkhtmltopdf

RUN mkdir -p /opt/triton-model-analyzer

# Install DCGM
RUN wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb && \
    dpkg -i datacenter-gpu-manager_${DCGM_VERSION}_amd64.deb

# Install tritonclient
COPY --from=sdk_image /workspace/install/python /tmp/tritonclient
RUN find /tmp/tritonclient -maxdepth 1 -type f -name \
    "tritonclient-*-manylinux1_x86_64.whl" | xargs printf -- '%s[all]' | \
    xargs pip3 install --upgrade && rm -rf /tmp/tritonclient/

WORKDIR /opt/triton-model-analyzer
RUN rm -fr *

COPY . .
RUN chmod +x /opt/triton-model-analyzer/nvidia_entrypoint.sh

RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install nvidia-pyindex && \
    python3 -m pip install wheel setuptools docker numpy pillow future grpcio && \
    python3 -m pip install requests gsutil awscli six boofuzz grpcio-channelz && \
    python3 -m pip install azure-cli grpcio-tools grpcio-channelz && \
    python3 -m pip install torch==1.9.0+cu111 -f https://download.pytorch.org/whl/torch_stable.html


RUN mkdir /opt/tritonserver/backends/fastertransformer && chmod 777 /opt/tritonserver/backends/fastertransformer

# FROM ftbe_sdk as ftbe_work
# # for debug
# RUN apt update -q && apt install -y --no-install-recommends openssh-server zsh tmux mosh locales-all clangd sudo
# RUN sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config
# RUN mkdir /var/run/sshd

ENTRYPOINT ["/opt/triton-model-analyzer/nvidia_entrypoint.sh"]
ENV MODEL_ANALYZER_VERSION ${MODEL_ANALYZER_VERSION}
ENV MODEL_ANALYZER_CONTAINER_VERSION ${MODEL_ANALYZER_CONTAINER_VERSION}

