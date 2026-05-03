#!/usr/bin/env bash
# =============================================================
# run_sql_review.sh — メインエントリポイント
# SQLファイルの差分チェックを行い、変更があれば Copilot CLI でレビューを実行する
#
# 使い方:
#   export COPILOT_GITHUB_TOKEN=github_pat_xxx
#   ./scripts/run_sql_review.sh            # 差分のみ
#   ./scripts/run_sql_review.sh --force    # 全ファイル強制実行
#   ./scripts/run_sql_review.sh --dry-run  # API呼び出しなし・対象ファイル確認のみ
#
# 終了コード:
#   0 — 成功（スキップ含む）
#   1 — 部分失敗（一部ファイルでエラー）
#   2 — 致命的エラー（認証失敗・設定不備など）
# =============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# ---------------------------------------------------------------
# オプション解析
# ---------------------------------------------------------------
DRY_RUN=false
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --force)   FORCE=true ;;
    esac
done

# ---------------------------------------------------------------
# ログ関数
# ---------------------------------------------------------------
LOG_FILE="${LOGS_DIR}/sql-review_$(date '+%Y%m%d').log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

# ---------------------------------------------------------------
# 前提チェック
# ---------------------------------------------------------------
if [[ -z "${COPILOT_GITHUB_TOKEN:-}" ]]; then
    echo "ERROR: 環境変数 COPILOT_GITHUB_TOKEN が設定されていません。" >&2
    echo "  export COPILOT_GITHUB_TOKEN=github_pat_xxx" >&2
    exit 2
fi

if [[ ! -f "$SQL_CHECK_PROMPT" ]]; then
    echo "ERROR: プロンプトファイルが見つかりません: ${SQL_CHECK_PROMPT}" >&2
    exit 2
fi

if [[ ! -f "$RULES_CSV" ]]; then
    echo "ERROR: ルール定義CSVが見つかりません: ${RULES_CSV}" >&2
    exit 2
fi

# ---------------------------------------------------------------
# ディレクトリ初期化（なければ作成）
# ---------------------------------------------------------------
mkdir -p "$REPORTS_DIR" "$LOGS_DIR" "$STATE_DIR"

# ---------------------------------------------------------------
# 差分チェック
# ---------------------------------------------------------------
log "===== SQL自動レビュー 開始 ====="
[[ "$FORCE"   == true ]] && log "モード: --force（全ファイル強制再チェック）"
[[ "$DRY_RUN" == true ]] && log "モード: --dry-run（API呼び出しなし）"

DIFF_ARGS=""
[[ "$FORCE" == true ]] && DIFF_ARGS="--force"

# check_diff.sh の出力を配列に格納（bash v3互換）
target_files=()
while IFS= read -r line; do
    [[ -n "$line" ]] && target_files+=("$line")
done < <(bash "${SCRIPT_DIR}/check_diff.sh" ${DIFF_ARGS})

if [[ "${target_files[0]:-}" == "SKIP" ]] || [[ ${#target_files[@]} -eq 0 ]]; then
    log "変更なし — スキップ（API呼び出し: 0件）"
    log "===== SQL自動レビュー 終了 ====="
    exit 0
fi

log "処理対象: ${#target_files[@]} ファイル"

if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] 対象ファイル一覧:"
    for f in "${target_files[@]}"; do
        log "  - ${f}"
    done
    log "===== SQL自動レビュー 終了（dry-run） ====="
    exit 0
fi

# ---------------------------------------------------------------
# プロンプト本文・ルール定義を事前に読み込む（ループ外で1回のみ）
# ---------------------------------------------------------------
PROMPT_BODY=$(awk '/^---/{n++; if(n==2){found=1; next}} found{print}' "$SQL_CHECK_PROMPT")
RULES=$(cat "$RULES_CSV")

# ---------------------------------------------------------------
# ファイルごとにレビュー実行
# ---------------------------------------------------------------
success_count=0
error_count=0

for target_file in "${target_files[@]}"; do
    filename=$(basename "$target_file" .sql)
    timestamp=$(date '+%Y%m%d%H%M%S')
    report_file="${REPORTS_DIR}/sql-check-report_${filename}_${timestamp}.md"

    log "レビュー開始: ${target_file}"

    SQL=$(cat "$target_file")

    MODEL_OPT=""
    [[ -n "${SQL_REVIEW_MODEL:-}" ]] && MODEL_OPT="--model ${SQL_REVIEW_MODEL}"

    if copilot -p "${PROMPT_BODY}

## ルール定義（CSV）
${RULES}

## チェック対象SQL（ファイル: ${target_file}）
${SQL}" --allow-all-tools --allow-all-paths ${MODEL_OPT} > "$report_file" 2>&1; then
        log "  → 完了: ${report_file}"
        ((success_count++)) || true
    else
        log "  → ERROR: レビュー失敗 (${target_file})"
        ((error_count++)) || true
    fi
done

# ---------------------------------------------------------------
# タイムスタンプ更新
# ---------------------------------------------------------------
touch "$TIMESTAMP_FILE"
log "タイムスタンプ更新: ${TIMESTAMP_FILE}"

# ---------------------------------------------------------------
# 結果サマリー
# ---------------------------------------------------------------
log "完了: 成功 ${success_count} 件 / エラー ${error_count} 件"
log "===== SQL自動レビュー 終了 ====="

if [[ $error_count -gt 0 ]]; then
    exit 1
fi
exit 0
