# ==============================================================================
# Apache Tika Server with Tika-JTD (Ichitaro / 一太郎 Parser)
#
# Stage 1: Download latest tika-parser-jtd-*-server.jar (bundles kotlin-stdlib)
# Stage 2: Deploy JAR into apache/tika:latest-full (/tika-extras/)
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Downloader
# ------------------------------------------------------------------------------
FROM alpine:latest AS downloader

RUN apk add --no-cache curl jq

ARG JTD_VERSION=latest

# Download tika-parser-jtd-*-server.jar from GitHub Releases
RUN if [ "$JTD_VERSION" = "latest" ]; then \
      RELEASE_URL="https://api.github.com/repos/KHiyowa/Tika-JTD/releases/latest"; \
    else \
      RELEASE_URL="https://api.github.com/repos/KHiyowa/Tika-JTD/releases/tags/${JTD_VERSION}"; \
    fi && \
    JAR_URL=$(curl -s "$RELEASE_URL" \
      | jq -r '.assets[] | select(.name | test("^tika-parser-jtd-.*-server\\.jar$")) | .browser_download_url') && \
    echo "Downloading Tika JTD from: $JAR_URL" && \
    curl -fL -o /tmp/tika-parser-jtd.jar "$JAR_URL"

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM apache/tika:latest-full

USER root

# Place parser JAR into /tika-extras/ (included in Tika Server default classpath)
RUN mkdir -p /tika-extras
COPY --from=downloader /tmp/tika-parser-jtd.jar /tika-extras/tika-parser-jtd.jar
RUN chown -R 35002:35002 /tika-extras && chmod 644 /tika-extras/*.jar

USER 35002:35002

EXPOSE 9998
