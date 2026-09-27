# Apache Tika + Tika-JTD（一太郎パーサー組み込み Docker コンテナ）

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Apache Tika](https://img.shields.io/badge/Apache%20Tika-4.0.0-red.svg)](https://tika.apache.org/)
[![Tika-JTD](https://img.shields.io/badge/Tika--JTD-v0.2.0-green.svg)](https://github.com/KHiyowa/tika-jtd)

Apache Tika 4 公式サーバーに、一太郎文書（`.jtd` / `.jtt` / `.jttc`）パーサー [Tika-JTD](https://github.com/KHiyowa/tika-jtd) を組み込んだ Docker コンテナです。

**OpenWebUI**、各種 RAG パイプライン、全文検索エンジンへの組み込みを想定し、ファイル名や拡張子が付与されないストリーミング送信環境でも確実に一太郎文書を認識・パースできるように最適化されています。

---

## 主な特徴

- **超高速ビルド＆純 JVM 構成**:
  前身（Rust 版 `rjtd`）のようにコンテナ内で重厚なコンパイルを行う必要がありません。公式 `apache/tika:latest-full` に Kotlin/JVM 実装のパーサー JAR をドロップイン配置する構成のため、わずか数秒でビルドが完了します。
- **ヘッダーレス（ファイル名未指定）自動判定**:
  OpenWebUI などの HTTP クライアントは、ファイルを Tika へストリーミング転送する際に `Content-Disposition`（ファイル名・拡張子）を送信しない場合があります。本コンテナでは OLE2/CFB コンテナ内部の一太郎固有ストリームマーカーを検出する高優先度（priority 60）のマジックバイト定義を内包しているため、**拡張子情報が一切ない生バイナリでも 100% 確実に一太郎文書と自動判別**してテキストを救出します。
- **オブジェクト枠の再帰抽出**:
  一太郎文書内に埋め込まれた表計算データ（Excel / BIFF8）やベクター画像（WMF / EMF）、ラスタ画像（JPEG / PNG 等）も Tika の標準パイプラインを通じて再帰的に抽出されます。

---

## クイックスタート

### 1. 起動

```bash
docker compose up -d --build
```

### 2. 稼働確認

```bash
curl -s http://localhost:9998/version
# 出力例: Apache Tika 4.0.0
```

### 3. テキスト抽出テスト

```bash
# 標準テキストエンドポイント
curl -T sample.jtd http://localhost:9998/tika

# Tika 4 の JSON テキストエンドポイント（OpenWebUI が使用）
curl -T sample.jtd http://localhost:9998/tika/json/text
```
※ファイル名を指定せず直接バイナリをパイプしても正常に判定・抽出されます。

---

## OpenWebUI との連携手順

OpenWebUI の `docker-compose.yml` に本サービスを組み込む例です。

```yaml
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    ports:
      - "3000:8080"
    environment:
      - TIKA_SERVER_URL=http://tika:9998
    depends_on:
      - tika
    restart: always

  tika:
    build: ../tika-jtd-docker
    image: tika-jtd:latest
    container_name: tika
    ports:
      - "9998:9998"
    restart: always
```

### OpenWebUI 管理画面での設定

1. OpenWebUI に管理者でログインし、**管理者パネル → 設定 → ドキュメント** を開きます。
2. **コンテンツ抽出エンジン** で `Tika` を選択します。
3. **Tika Server URL** に `http://tika:9998`（またはコンテナ間の解決名）を入力して保存します。
4. これでチャット画面やナレッジベース（ドキュメント）に `.jtd` / `.jtt` / `.jttc` ファイルをそのままドラッグ＆ドロップして RAG 検索・要約が可能になります！

---

## 仕組み・アーキテクチャ

```text
[OpenWebUI / クライアント]
        │
        ▼ HTTP PUT /tika/json/text（※ファイル名ヘッダーなしでも可）
[Apache Tika Server 4.0.0]
        │
        ├─► [MimeTypes マジックバイト判定 (priority 60)]
        │     CFB ヘッダ（0xd0cf11e0a1b11ae1）+ "SsmgV.01" / "DocumentText" 等
        │     => application/vnd.justsystem.ichitaro を特定
        │
        ├─► [JtdParser (com.hiyowa.tika.jtd.JtdParser)]
        │     1. OLE2 / CFB ストリーム解体（Apache POI）
        │     2. 本文・マルチシート・脚注・枠内テキスト抽出
        │     3. オブジェクト枠（Excel, WMF, 画像等）の再帰的パース
        │
        ▼ 本文テキストおよびメタデータを JSON で返却
[OpenWebUI RAG / チャットコンテキスト]
```

---

## 関連プロジェクト

- [Tika-JTD](https://github.com/KHiyowa/tika-jtd) - Apache Tika 4 向け純 JVM 一太郎パーサー本体

## ライセンス

本プロジェクトは [Apache License, Version 2.0](LICENSE) のもとで公開されています。
