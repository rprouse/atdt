# Linux Flutter toolchain for rendering golden test images.
# FLUTTER_VERSION must match the version pinned in .github/workflows/ci.yml.
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

ARG FLUTTER_VERSION=3.47.7
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
      https://github.com/flutter/flutter.git /opt/flutter
ENV PATH=/opt/flutter/bin:$PATH

RUN flutter config --no-analytics \
 && flutter precache --no-android --no-ios \
 && flutter --version
