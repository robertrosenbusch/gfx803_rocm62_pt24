# Docker Buildfile for ROCm 6.2 to use ComfyUI with a RX570 / Polaris AMD GPU
# build and compiled by Robert Rosenbusch at August 2024

#FROM rocm/pytorch:rocm6.2_ubuntu22.04_py3.10_pytorch_release_2.3.0
FROM rocm/pytorch:rocm6.2.3_ubuntu22.04_py3.10_pytorch_release_2.3.0

ENV PORT=8188 \
    COMMANDLINE_ARGS='' \
    ### how many CPUCores are using while compiling
    MAX_JOBS=14 \ 
    ### Settings for AMD GPU RX570/RX580/RX590 GPU
    HSA_OVERRIDE_GFX_VERSION=8.0.3 \ 
    PYTORCH_ROCM_ARCH=gfx803 \
    ROCM_ARCH=gfx803 \ 
    TORCH_BLAS_PREFER_HIPBLASLT=0\ 
    ROC_ENABLE_PRE_VEGA=1 \
    USE_CUDA=0 \  
    USE_ROCM=1 \ 
    USE_NINJA=1 \
    FORCE_CUDA=1 \ 
#######
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONENCODING=UTF-8\      
    REQS_FILE='requirements.txt' \
    COMMANDLINE_ARGS='' 

## Write the Environment VARSs to global... to compile later with while you use #docker save# or #docker commit#
RUN echo MAX_JOBS=${MAX_JOBS} >> /etc/environment && \ 
    echo HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION} >> /etc/environment && \ 
    echo PYTORCH_ROCM_ARCH=${PYTORCH_ROCM_ARCH} >> /etc/environment && \ 
    echo ROCM_ARCH=${ROCM_ARCH} >> /etc/environment && \ 
    echo TORCH_BLAS_PREFER_HIPBLASLT=${TORCH_BLAS_PREFER_HIPBLASLT} >> /etc/environment && \ 
    echo ROC_ENABLE_PRE_VEGA=${ROC_ENABLE_PRE_VEGA} >> /etc/environment && \
    echo USE_CUDA=${USE_CUDA} >> /etc/environment && \
    echo USE_ROCM=${USE_ROCM} >> /etc/environment && \
    echo USE_NINJA=${USE_NINJA} >> /etc/environment && \
    echo FORCE_CUDA=${FORCE_CUDA} >> /etc/environment && \
    true

## Export the AMD Stuff
RUN export MAX_JOBS=${MAX_JOBS} && \ 
    export HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION} && \
    export ROC_ENABLE_PRE_VEGA=${ROC_ENABLE_PRE_VEGA} && \
    export PYTORCH_ROCM_ARCH=${PYTORCH_ROCM_ARCH} && \
    export ROCM_ARCH=${ROCM_ARCH} && \
    export TORCH_BLAS_PREFER_HIPBLASLT=${TORCH_BLAS_PREFER_HIPBLASLT} && \    
    export USE_CUDA=${USE_CUDA}  && \
    export USE_ROCM=${USE_ROCM}  && \
    export USE_NINJA=${USE_NINJA} && \
    export FORCE_CUDA=${FORCE_CUDA} && \
    true

# Update System and install ffmpeg for SDXL video and python virtual Env
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get install -y --no-install-recommends ffmpeg virtualenv google-perftools ccache tmux mc pigz plocate && \
    pip install --upgrade pip wheel && \
    pip install cmake mkl mkl-include && \ 
    apt --fix-broken install -y && \
    true


ENV ROCBLAS_GIT_VERSION="rocm-6.2.2"
#ENV PYTORCH_GIT_VERSION="nightly"
RUN echo "Checkout ROCBLAS " && \
    git clone https://github.com/ROCm/rocBLAS.git -b ${ROCBLAS_GIT_VERSION} /rocblas && \
    true

WORKDIR /rocblas

RUN echo "BUILDING rocBLAS with ARCH: ${ROCM_ARCH} and JOBS: ${MAX_JOBS}" && \
    ./install.sh -ida ${ROCM_ARCH} -j ${MAX_JOBS} && \
    true

######
# If you trust my WHL-Files i uploaded at github and you are able to transfer th WHL-Files into this Docker-Image!? Then comment out the following lines to the next ######
##
# git clone PyTorch Version you need for
### PyTorch Version

ENV PYTORCH_GIT_VERSION="release/2.4"
#ENV PYTORCH_GIT_VERSION="nightly"
RUN echo "Checkout PyTorch Version: ${PYTORCH_GIT_VERSION} " && \  
    git clone --recursive https://github.com/pytorch/pytorch.git -b ${PYTORCH_GIT_VERSION} /pytorch && \
    true

#git clone Torchvision you need
## Torchvision Version
ENV TORCH_GIT_VERSION="release/0.19"
#ENV TORCH_GIT_VERSION="nightly"
RUN echo "Checkout Torchvision Version: ${TORCH_GIT_VERSION} " && \ 
   git clone https://github.com/pytorch/vision.git -b ${TORCH_GIT_VERSION} /vision && \
   true

WORKDIR /pytorch
RUN echo "BULDING PYTORCH $(git describe --tags --exact | sed 's/^v//')" && \
    true 

RUN python setup.py clean && \
     pip install -r ${REQS_FILE} && \
     true

RUN ln -s /opt/rocm/aotriton/lib/libaotriton_v2.so /opt/rocm/aotriton/lib/libaotriton_v2.a

RUN python3 tools/amd_build/build_amd.py && \
     true


RUN echo "** BUILDING PYTORCH *** " && \ 
     python3 setup.py bdist_wheel && \
     true

RUN echo "** INSTALL PYTORCH ***" && \    
     pip install dist/torch*-cp310-cp310-linux_x86_64.whl && \
     true

# # Build Vision
WORKDIR /vision

#RUN export BUILD_VERSION=$(git describe --tags --exact | sed 's/^v//')  && \
RUN python3 setup.py bdist_wheel && \
    pip install dist/torchvision-*-cp310-cp310-linux_x86_64.whl && \
    true

######
# End of building pytorch and torchvision WHL-Files
######

EXPOSE ${PORT}
EXPOSE 22/tcp

#VOLUME [ "/ComfyUI", "/ComfyUI/custom_nodes","/ComfyUI/models","/ComfyUI/output","/ComfyUI/input"]
#ENTRYPOINT python main.py --listen --use-split-cross-attention --port "${PORT}"
CMD ["/bin/bash","-c"]

