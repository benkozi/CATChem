FROM deckyfre/catchem-spack-base:0.0.2

# Use bash for subsequent RUN commands
SHELL ["/bin/bash", "-c"]

# Copy in CATChem src directory to /opt/src
# Since context is now project root, we copy everything to ensure CMakeLists.txt and subdirs are present
COPY . /opt/src

# Activate the catchem spack environment
# Build CATChem with cmake calls, etc.
# Run CATChem tests
RUN source /opt/catchem/spack-stack/setup.sh && \
    spack env activate catchem && \
    cd /opt/src && \
    mkdir build && \
    cd build && \
    cmake .. \
      -DCATCHEM_BUILD_TESTING=ON \
      -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    ctest --output-on-failure