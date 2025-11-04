#############################
# 1) Build stage            #
#############################
FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

# ---- essential build tool-chain + mvfst deps ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git build-essential cmake ninja-build \
    python3 sudo \
    net-tools iputils-ping \
    zlib1g-dev m4 \
    libssl-dev libzstd1 \
    libsodium23 \
    libgoogle-glog0v6t64   \
    libgflags2.2              \
    libdouble-conversion3     \
    libboost-all-dev          \
    libboost-context1.83.0    \
    libboost-filesystem1.83.0 \
    libevent-2.1-7            \
    libssl3                   \
    liblzma5 liblz4-1         \
    libsnappy1v5 libunwind8   \
    libstdc++6 libgcc-s1

WORKDIR /src
RUN git clone https://github.com/b4lt0/qw.git .

# ---- build & install fast_float exactly as qw README shows ----
RUN git clone https://github.com/fastfloat/fast_float.git && \
    cd fast_float && mkdir build && \
    cd build && cmake .. && sudo make install

# ---- clean stale mvfst CMake cache (optional) ----
RUN rm -rf /src/proxygen/proxygen/_build/deps/mvfst/build/CMakeCache.txt \
           /src/proxygen/proxygen/_build/deps/mvfst/build/CMakeFiles || true

# ---- compile mvfst + Proxygen with QUIC ----
WORKDIR /src/proxygen/proxygen
RUN ./build.sh -j $(( $(nproc) / 4 )) --no-tests

# ---- strip symbols from final binary to shrink it further ----
RUN strip _build/proxygen/httpserver/hq


#############################
# 2) Runtime stage          #
#############################
FROM martenseemann/quic-network-simulator-endpoint:latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates iproute2 tcpdump \
    iperf ethtool wget \
    net-tools iputils-ping \
    zlib1g-dev m4 \
    libssl-dev libzstd1 \
    libsodium23 \
    libgoogle-glog0v6t64           \
    libgflags2.2              \
    libdouble-conversion3     \
    libboost-all-dev          \
    libboost-context1.83.0    \
    libboost-filesystem1.83.0 \
    libevent-2.1-7            \
    libssl3                   \
    liblzma5 liblz4-1         \
    libsnappy1v5 libunwind8   \
    libstdc++6 libgcc-s1 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /qw

# main server / client binary
COPY --from=build /src/proxygen/proxygen/_build/proxygen/httpserver/hq /usr/local/bin/hq

# shared objects built by mvfst / Proxygen
COPY --from=build /src/proxygen/proxygen/_build/**/*.so /usr/local/lib/

ENV PATH="/qw/proxygen/proxygen/_build/proxygen/httpserver:${PATH}"
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV PATH="/usr/local/bin:${PATH}"

RUN mkdir /logs

COPY run_endpoint.sh /run_endpoint.sh
RUN chmod +x /run_endpoint.sh
ENTRYPOINT ["/run_endpoint.sh"]
