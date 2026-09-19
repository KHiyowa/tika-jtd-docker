#!/bin/sh
set -e

# ==============================================================================
# OpenJTD Wrapper for Apache Tika ExternalParser
# 
# Usage: /usr/local/bin/rjtd-wrapper.sh <input_file>
#
# Processes .jtd, .jtt, and .jttc files using OpenJTD (rjtd).
# Tries Document Model plain-text export first, falls back to direct payload extraction.
# ==============================================================================

INPUT_FILE="$1"

if [ -z "$INPUT_FILE" ]; then
    echo "Error: No input file specified." >&2
    echo "Usage: $0 <input_file>" >&2
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 1
fi

# 1. 優先: Document Model 経由の構造化テキスト抽出 (export --format txt)
#    ルビ基本文字の解決や段落構造が反映されたテキストが得られます。
if output=$(/usr/local/bin/rjtd export "$INPUT_FILE" --format txt 2>/dev/null) && [ -n "$output" ]; then
    printf "%s\n" "$output"
    exit 0
fi

# 2. フォールバック: /DocumentText ペイロード等の直接抽出 (cat)
#    モデル構築が未対応の特殊構造や断片化ファイルでもテキストを回収します。
if output=$(/usr/local/bin/rjtd cat "$INPUT_FILE" 2>/dev/null) && [ -n "$output" ]; then
    printf "%s\n" "$output"
    exit 0
fi

# 3. 両方失敗した場合はエラーログを出力して終了
echo "Error: OpenJTD could not extract text from $INPUT_FILE" >&2
/usr/local/bin/rjtd export "$INPUT_FILE" --format txt 2>&1 >/dev/null || true
exit 1
