# Apache Tika + OpenJTD (Ichitaro / 一太郎 Parser Container)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Apache Tika](https://img.shields.io/badge/Apache%20Tika-4.0.0-red.svg)](https://tika.apache.org/)
[![OpenJTD](https://img.shields.io/badge/OpenJTD-rjtd-orange.svg)](https://github.com/KimEJ/OpenJTD)

An Apache Tika Server container extended with [OpenJTD](https://github.com/KHiyowa/OpenJTD) (`rjtd`) support to parse Ichitaro (一太郎) documents (`.jtd`, `.jtt`, `.jttc`).

Designed for seamless integration with **OpenWebUI**, document RAG pipelines, and enterprise search platforms.

---

## Features / 特徴

- **Multi-stage Docker Build**: Builds the Rust `rjtd-cli` toolset (`rust:slim`) and packages only the lightweight binary into the `apache/tika:latest-full` (v4.0.0) runtime.
- **Headerless Magic Byte Detection**: OpenWebUI and many HTTP clients do not transmit `Content-Disposition` (filename) headers when streaming files to Tika. This project includes custom MIME magic byte rules (`custom-mimetypes.xml`) that accurately detect Ichitaro CFB containers via internal stream markers (`SsmgV.01`, `DocumentText`, `JustCompressedDocument`) even without filenames.
- **Robust Text Extraction**: Prioritizes `rjtd export --format txt` (Document Model text extraction) with automatic fallback to `rjtd cat` (direct `/DocumentText` payload recovery).
- **Tika 4.x Compatible**: Uses the modern JSON configuration format (`tika-config.json`) with `ExternalParser` and preserves all existing Tika parsers (`default-parser`).

---

## Quick Start / クイックスタート

### 1. Build and Run with Docker Compose

```bash
docker compose up -d --build
```

### 2. Verify Server Status

```bash
curl -s http://localhost:9998/version
# Output: Apache Tika 4.0.0
```

### 3. Extract Text from an Ichitaro Document

```bash
# Via text endpoint
curl -T sample.jtd http://localhost:9998/tika

# Via JSON text endpoint (used by OpenWebUI / Tika 4)
curl -T sample.jtd http://localhost:9998/tika/json/text
```

---

## Integration with OpenWebUI

In your OpenWebUI `docker-compose.yml`, replace the default Tika image with this custom build:

```yaml
services:
  tika:
    build: ./tika
    image: tika-openjtd:latest
    container_name: tika
    ports:
      - "9998:9998"
    restart: always
```

Once started:
1. Navigate to OpenWebUI **Admin Panel > Settings > Documents**.
2. Set **Content Extraction Engine** to `Tika`.
3. Set **Tika Server URL** to `http://tika:9998` (or your host IP).
4. Upload any `.jtd`, `.jtt`, or `.jttc` file in your chat or knowledge base!

---

## How It Works / アーキテクチャ解説

```
[User / OpenWebUI]
        │
        ▼ HTTP PUT /tika/json/text
[Apache Tika Server 4.0.0]
        │
        ├─► [MimeTypes / MagicDetector]
        │     Detects CFB header (D0 CF 11 E0 A1 B1 1A E1) + "SsmgV.01" / "DocumentText"
        │     => application/x-jtd (Priority 60 > default OLE 40)
        │
        ├─► [ExternalParser]
        │     Invokes /usr/local/bin/rjtd-wrapper.sh ${INPUT_FILE} ${OUTPUT_FILE}
        │
        ├─► [OpenJTD / rjtd]
        │     1. rjtd export <file> --format txt (Document Model parsing)
        │     2. Fallback: rjtd cat <file> (Direct stream recovery)
        │
        ▼ Return JSON with "tk:content"
[OpenWebUI RAG / Chat Context]
```

---

## Repository Structure

```
.
├── Dockerfile              # Multi-stage build (Rust builder -> Tika runtime)
├── docker-compose.yml      # Standalone compose setup
├── custom-mimetypes.xml    # FreeDesktop/Tika MIME & Magic byte rules
├── tika-config.json        # Tika 4.0.0 server & external parser config
├── rjtd-wrapper.sh         # Resilient parser execution wrapper
├── LICENSE                 # Apache-2.0
└── README.md
```

---

## Acknowledgements / 謝辞

- [OpenJTD](https://github.com/KimEJ/OpenJTD) by KimEJ - An outstanding open-source reverse-engineering and parser effort for Ichitaro documents.
- [KHiyowa/OpenJTD](https://github.com/KHiyowa/OpenJTD) - Fork used for building this container. Temporarily, the source is built from this fork (pending upstream inclusion in KimEJ/OpenJTD); it will be switched back once the changes land upstream.
- [Apache Tika](https://tika.apache.org/) by The Apache Software Foundation.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
