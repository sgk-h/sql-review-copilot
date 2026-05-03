#!/usr/bin/env bash
# =============================================================
# check_diff.sh — 差分チェック（A案コア）
# 前回実行以降に変更された .sql ファイルを標準出力に返す
#
# 使い方:
#   source scripts/config.sh
#   changed_files=$(bash scripts/check_diff.sh)
#   [[ "$changed_files" == "SKIP" ]] && echo "変更なし"
#
# オプション:
#   --force  差分チェックをスキップして TARGET_DIR の全ファイルを返す
# =============================================================

set -euo pipefail

# config.sh が source されていなければ自動で読み込む
if [[ -z "${REPO_ROOT:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/config.sh"
fi

FORCE=false
for arg in "$@"; do
    [[ "$arg" == "--force" ]] && FORCE=true
done

# TARGET_DIR の存在確認
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: TARGET_DIR が存在しません: ${TARGET_DIR}" >&2
    exit 2
fi

# --force または初回実行（タイムスタンプなし）は全ファイルを対象にする
if [[ "$FORCE" == true ]] || [[ ! -f "$TIMESTAMP_FILE" ]]; then
    files=$(find "$TARGET_DIR" -name "*.sql" | sort)
    if [[ -z "$files" ]]; then
        echo "SKIP"
    else
        echo "$files"
    fi
    exit 0
fi

# rules/sql-antipatterns.csv がタイムスタンプより新しければ全ファイルを強制再チェック
if [[ "$RULES_CSV" -nt "$TIMESTAMP_FILE" ]]; then
    files=$(find "$TARGET_DIR" -name "*.sql" | sort)
    if [[ -z "$files" ]]; then
        echo "SKIP"
    else
        echo "$files"
    fi
    exit 0
fi

# 通常: タイムスタンプより新しい .sql ファイルのみ
files=$(find "$TARGET_DIR" -name "*.sql" -newer "$TIMESTAMP_FILE" | sort)
if [[ -z "$files" ]]; then
    echo "SKIP"
else
    echo "$files"
fi
