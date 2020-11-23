FROM debian:9.8
LABEL maintainer="e.demirel@qmul.qc.uk"


# Installing libraries
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        g++ \
        make \
        automake \
        autoconf \
        bzip2 \
        unzip \
        wget \
        sox \
        bc \
        libtool \
        git \
        subversion \
        python2.7 \
        python3 \
        zlib1g-dev \
        ca-certificates \
        gfortran \
        patch \
        ffmpeg \
	vim && \
    rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python2.7 /usr/bin/python 

# Installing Kaldi
RUN git clone --depth 1 https://github.com/kaldi-asr/kaldi.git /opt/kaldi && \
    cd /opt/kaldi && \
    cd /opt/kaldi/tools && \
    ./extras/install_mkl.sh && \
    make -j $(nproc) && \
    cd /opt/kaldi/src && \
    ./configure --shared && \
    make depend -j $(nproc) && \
    make -j $(nproc) && \
    cd /opt/kaldi/tools && \
    apt-get install python-dev -y && \
    ./extras/install_irstlm.sh  && \
    ./extras/install_phonetisaurus.sh && \
    sed -i "s/env[[:space:]]python/env python2.7/g" /opt/kaldi/tools/phonetisaurus-g2p/src/scripts/phonetisaurus-apply 

# Installing Anaconda
ENV PATH="/root/miniconda3/bin:${PATH}"
ARG PATH="/root/miniconda3/bin:${PATH}"
RUN apt-get update

RUN wget \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && mkdir /root/.conda \
    && bash Miniconda3-latest-Linux-x86_64.sh -b \
    && rm -f Miniconda3-latest-Linux-x86_64.sh 
RUN conda --version

COPY a2l /a2l

# Installing Audio-2-lyrics alignment package and the rest of the dependencies
RUN cd a2l/ && \
    git clone https://github.com/facebookresearch/demucs && \
    conda env update -f environment.yml && \
    PATH_TO_YOUR_KALDI_INSTALLATION=/opt/kaldi && \
    sed -i -- 's/path-to-your-kaldi-installation/${PATH_TO_YOUR_KALDI_INSTALLATION}/g' path.sh && \
    cp local/demucs/separate.py demucs/demucs/separate.py


WORKDIR /a2l

ENTRYPOINT ["/bin/bash"]



