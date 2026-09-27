# ==============================================================================
# Apache Tika Server with Tika-JTD (Ichitaro / 一太郎 Parser)
#
# Stage 1: Download latest tika-parser-jtd JAR & kotlin-stdlib
# Stage 2: Deploy JARs into apache/tika:latest-full (/tika-extras/)
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Downloader
# ------------------------------------------------------------------------------
FROM alpine:latest AS downloader

RUN apk add --no-cache curl jq

ARG JTD_VERSION=latest
ARG KOTLIN_VERSION=2.4.20

# Download tika-parser-jtd JAR from GitHub Releases (exclude -javadoc, -cli, etc.)
RUN if [ "$JTD_VERSION" = "latest" ]; then \
      RELEASE_URL="https://api.github.com/repos/KHiyowa/Tika-JTD/releases/latest"; \
    else \
      RELEASE_URL="https://api.github.com/repos/KHiyowa/Tika-JTD/releases/tags/${JTD_VERSION}"; \
    fi && \
    JAR_URL=$(curl -s "$RELEASE_URL" \
      | jq -r '.assets[] | select(.name | test("^tika-parser-jtd-[0-9][^-]*\\.jar$")) | .browser_download_url') && \
    echo "Downloading Tika JTD from: $JAR_URL" && \
    curl -fL -o /tmp/tika-parser-jtd.jar "$JAR_URL"

# Download kotlin-stdlib (required by Kotlin-based parser in Tika extras)
RUN echo "Downloading kotlin-stdlib ${KOTLIN_VERSION}..." && \
    curl -fL -o /tmp/kotlin-stdlib.jar \
      "https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-stdlib/${KOTLIN_VERSION}/kotlin-stdlib-${KOTLIN_VERSION}.jar"

# ------------------------------------------------------------------------------
# Stage 2: Runtime
# ------------------------------------------------------------------------------
FROM apache/tika:latest-full

USER root

# Place parser and runtime dependencies into /tika-extras/ (included in Tika Server default classpath)
RUN mkdir -p /tika-extras
COPY --from=downloader /tmp/tika-parser-jtd.jar /tika-extras/tika-parser-jtd.jar
COPY --from=downloader /tmp/kotlin-stdlib.jar /tika-extras/kotlin-stdlib.jar
RUN chown -R 35002:35002 /tika-extras && chmod 644 /tika-extras/*.jar

USER 35002:35002

EXPOSE 9998
