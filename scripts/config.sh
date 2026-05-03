#!/usr/bin/env bash
# =============================================================
# config.sh — 設定変数の一元管理
# scripts/ 配下の各スクリプトから source して使用する
# =============================================================

# このスクリプトが置かれているディレクトリからリポジトリルートを導出
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------
# ★ 要変更: レビュー対象SQLファイルが格納された外部ディレクトリの絶対パス
# 例: TARGET_DIR="/path/to/your-app/src/sql"
# 環境変数で上書き可能（例: TARGET_DIR=/other/path bash run_sql_review.sh）
# ---------------------------------------------------------------
TARGET_DIR="${TARGET_DIR:-/Users/hironorishigaki/Workspace/SQL_Dir}"

# 出力・状態管理ディレクトリ
REPORTS_DIR="${REPO_ROOT}/reports"
LOGS_DIR="${REPO_ROOT}/logs"
STATE_DIR="${REPO_ROOT}/state"

# 差分管理用タイムスタンプファイル（git管理外・実行ごとに更新）
TIMESTAMP_FILE="${STATE_DIR}/last_run.timestamp"

# プロンプト・ルール定義ファイル
SQL_CHECK_PROMPT="${REPO_ROOT}/.github/prompts/sql-check.prompt.md"
RULES_CSV="${REPO_ROOT}/rules/sql-antipatterns.csv"
