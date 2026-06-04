ARG BASE_IMAGE=deckyfre/catchem-spack-base:latest
FROM ${BASE_IMAGE}

# Use bash for subsequent RUN commands
SHELL ["/bin/bash", "-c"]

# Copy in CATChem src directory to /opt/src
# Since context is now project root, we copy everything to ensure CMakeLists.txt and subdirs are present
COPY . /opt/catchem/src

# Activate the catchem spack environment
# Build CATChem with cmake calls, etc.
# Run CATChem tests
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

CMD ["/bin/bash"]
