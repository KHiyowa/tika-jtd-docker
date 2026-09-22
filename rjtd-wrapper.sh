#!/bin/sh
set -e

# ==============================================================================
# OpenJTD Wrapper for Apache Tika ExternalParser
# 
# Usage: /usr/local/bin/rjtd-wrapper.sh <input_file> [output_file]
#
# Processes .jtd, .jtt, and .jttc files using OpenJTD (rjtd).
# Tries Document Model plain-text export first, falls back to direct payload extraction.
# ==============================================================================

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [ -z "$INPUT_FILE" ]; then
    echo "Error: No input file specified." >&2
    echo "Usage: $0 <input_file> [output_file]" >&2
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    # --------------------------------------------------------------------------
    # Output-file mode (Tika ExternalParser with ${OUTPUT_FILE})
    # Stream directly to file without buffering in memory or hitting stdout limits.
    # --------------------------------------------------------------------------
    # 1. 優先: Document Model 経由の構造化テキスト抽出 (export --format txt)
    if /usr/local/bin/rjtd export "$INPUT_FILE" --format txt > "$OUTPUT_FILE" 2>/dev/null && [ -s "$OUTPUT_FILE" ]; then
        exit 0
    fi

    # 2. フォールバック: /DocumentText ペイロード等の直接抽出 (cat)
    if /usr/local/bin/rjtd cat "$INPUT_FILE" > "$OUTPUT_FILE" 2>/dev/null && [ -s "$OUTPUT_FILE" ]; then
        exit 0
    fi
else
    # --------------------------------------------------------------------------
    # Stdout mode (Manual CLI execution / fallback)
    # --------------------------------------------------------------------------
    # 1. 優先: Document Model 経由の構造化テキスト抽出 (export --format txt)
    if output=$(/usr/local/bin/rjtd export "$INPUT_FILE" --format txt 2>/dev/null) && [ -n "$output" ]; then
        printf "%s\n" "$output"
        exit 0
    fi

    # 2. フォールバック: /DocumentText ペイロード等の直接抽出 (cat)
    if output=$(/usr/local/bin/rjtd cat "$INPUT_FILE" 2>/dev/null) && [ -n "$output" ]; then
        printf "%s\n" "$output"
        exit 0
    fi
fi

# 3. 両方失敗した場合はエラーログを出力して終了
echo "Error: OpenJTD could not extract text from $INPUT_FILE" >&2
/usr/local/bin/rjtd export "$INPUT_FILE" --format txt 2>&1 >/dev/null || true
exit 1
