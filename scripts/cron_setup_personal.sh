#!/usr/bin/env bash
# =============================================================
# cron_setup_personal.sh — 個人端末（macOS + NVM環境）向け crontab 登録手順
#
# 標準の cron_setup.sh との違い:
#   macOS では cron 実行時に NVM の PATH が読み込まれないため、
#   copilot コマンドが見つからず失敗する。
#   このスクリプトでは copilot のフルパスを明示的に指定したエントリを出力する。
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

RUN_SCRIPT="${SCRIPT_DIR}/run_sql_review.sh"
CRON_LOG="${LOGS_DIR}/cron.log"

# copilot のフルパスを取得
COPILOT_BIN="$(which copilot 2>/dev/null || echo '')"
if [[ -z "$COPILOT_BIN" ]]; then
    echo "ERROR: copilot コマンドが見つかりません。NVM や PATH の設定を確認してください。" >&2
    exit 2
fi

# NVM の bin ディレクトリ（copilot が含まれるディレクトリ）
NVM_BIN_DIR="$(dirname "$COPILOT_BIN")"

cat <<EOF
================================================================
  SQL自動レビュー — crontab 登録手順（個人端末・NVM環境向け）
================================================================

【確認】このスクリプトが検出した copilot のパス:
  ${COPILOT_BIN}

  cron は NVM の PATH を引き継がないため、上記フルパスを使用します。

----------------------------------------------------------------

【手順1】トークンを ~/.copilot_env に保存する

  $ cat >> ~/.copilot_env <<'ENVEOF'
  export COPILOT_GITHUB_TOKEN=github_pat_ここにトークンを貼り付け
  ENVEOF
  $ chmod 600 ~/.copilot_env

  確認:
  $ cat ~/.copilot_env
  $ ls -la ~/.copilot_env   # -rw------- (600) になっていること

【手順2】crontab を編集する

  $ crontab -e

【手順3】以下のエントリをそのままコピーして貼り付ける

  # SQL自動レビュー — 毎日午前2時に実行（NVM環境対応）
  0 2 * * * PATH=${NVM_BIN_DIR}:\$PATH source ~/.copilot_env && bash ${RUN_SCRIPT} >> ${CRON_LOG} 2>&1

  ┌─ 分 (0-59)
  │ ┌─ 時 (0-23)  ← 2 = 午前2時
  │ │ ┌─ 日 (1-31)  * = 毎日
  │ │ │ ┌─ 月 (1-12)  * = 毎月
  │ │ │ │ ┌─ 曜日 (0-7)  * = 毎曜日
  0 2 * * *

【手順4】登録を確認する

  $ crontab -l

----------------------------------------------------------------

【動作確認】crontab 登録前に手動で正常動作を確認する

  # ① dry-run（APIなし・対象ファイル一覧のみ表示）
  source ~/.copilot_env && bash ${RUN_SCRIPT} --dry-run

  # ② 実際にレビューを1回実行（全ファイル対象）
  source ~/.copilot_env && bash ${RUN_SCRIPT} --force

  # ③ reports/ にレポートが生成されたことを確認
  ls -lt ${REPO_ROOT}/reports/

  # ④ 差分チェックが機能することを確認（②の直後に実行 → SKIPになるはず）
  source ~/.copilot_env && bash ${RUN_SCRIPT} --dry-run

----------------------------------------------------------------

【オプション: 実行頻度を変える場合】

  毎時0分に実行:    0 * * * *
  平日のみ午前2時:  0 2 * * 1-5
  週1回（月曜2時）: 0 2 * * 1

================================================================
EOF
