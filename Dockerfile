# ==============================================================================
# Multi-stage Dockerfile: Apache Tika Server with OpenJTD (Ichitaro Parser)
#
# Stage 1: Build OpenJTD (rjtd-cli) using Rust
# Stage 2: Deploy rjtd binary & Tika configuration into apache/tika:latest-full
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder
# ------------------------------------------------------------------------------
FROM rust:slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    zip \
    binutils \
    && rm -rf /var/lib/apt/lists/*

# Clone OpenJTD repository
WORKDIR /usr/src
RUN git clone --depth 1 https://github.com/KimEJ/OpenJTD.git openjtd

# Build rjtd CLI in release mode
WORKDIR /usr/src/openjtd/rjtd
RUN cargo build --release -p rjtd-cli && \
    strip /usr/src/openjtd/rjtd/target/release/rjtd

# Package custom-mimetypes.xml into a JAR for classpath inclusion
WORKDIR /tmp
COPY custom-mimetypes.xml /tmp/custom-mimetypes.xml
RUN zip -q /tmp/custom-mimetypes.jar custom-mimetypes.xml

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM apache/tika:latest-full

USER root

# 1. Install OpenJTD binary
COPY --from=builder /usr/src/openjtd/rjtd/target/release/rjtd /usr/local/bin/rjtd
RUN chmod 755 /usr/local/bin/rjtd

# 2. Install wrapper script for ExternalParser
COPY rjtd-wrapper.sh /usr/local/bin/rjtd-wrapper.sh
RUN chmod 755 /usr/local/bin/rjtd-wrapper.sh

# 3. Install Tika JSON configuration
COPY tika-config.json /opt/tika-server/tika-config.json
RUN chmod 644 /opt/tika-server/tika-config.json

# 4. Install custom MIME types definition
COPY custom-mimetypes.xml /opt/tika-server/custom-mimetypes.xml
RUN chmod 644 /opt/tika-server/custom-mimetypes.xml

# 5. Place custom-mimetypes.jar into /tika-extras/ (included in Tika default classpath)
RUN mkdir -p /tika-extras
COPY --from=builder /tmp/custom-mimetypes.jar /tika-extras/custom-mimetypes.jar
RUN chmod 644 /tika-extras/custom-mimetypes.jar

# 6. Ensure ownership matches Tika's non-root user (UID 35002)
RUN chown -R 35002:35002 /opt/tika-server /tika-extras

USER 35002:35002

EXPOSE 9998

# Launch Tika Server with custom-mimetypes and custom config enabled
ENTRYPOINT [ "/bin/sh", "-c", "exec java -Dtika.custom-mimetypes=/opt/tika-server/custom-mimetypes.xml -cp \"/opt/tika-server/*:/opt/tika-server/lib/*:/tika-extras/*\" org.apache.tika.server.core.TikaServerCli -h 0.0.0.0 -c /opt/tika-server/tika-config.json $0 $@" ]
