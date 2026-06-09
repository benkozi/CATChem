ARG BASE_IMAGE=deckyfre/catchem-spack-base:latest
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-c"]

COPY . /opt/catchem/src

RUN source /opt/catchem/spack-stack/setup.sh && \
    spack env activate catchem && \
    cd /opt/catchem/src && \
    mkdir build && \
    cd build && \
    cmake .. \
      -DCATCHEM_BUILD_TESTING=ON \
      -DCMAKE_INSTALL_PREFIX=/opt/catchem/install \
      -DCMAKE_BUILD_TYPE=Debug && \
    make -j$(nproc) && \
    make install && \
    ctest --output-on-failure

RUN cat <<EOF >> ~/.bashrc
# enable spack env by default
source /opt/catchem/spack-stack/setup.sh
spack env activate catchem
EOF

WORKDIR /opt

CMD ["/bin/bash"]
