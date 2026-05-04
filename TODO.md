# 未対応機能・既知の制限事項

最終更新: 2026-05-04

---

## 1. `.sql` 以外のファイル形式が自動レビュー対象外

### 状況

`sql-check.prompt.md` のチェック対象定義には以下が含まれているが、`check_diff.sh` と `run_sql_review.sh` の `find` コマンドが `.sql` のみを対象にしているため、実際の自動レビューでは処理されない。

| ファイル形式 | プロンプト定義 | スクリプトの実態 |
|---|---|---|
| `.sql` | ✅ 対象 | ✅ 処理される |
| `.java`（埋め込みSQL） | ✅ 対象 | ❌ 処理されない |
| `*Mapper.xml`（MyBatis） | ✅ 対象 | ❌ 処理されない |
| `.jsp` | ❌ 未定義 | ❌ 処理されない |
| `.js` / `.ts`（Node.js等） | ❌ 未定義 | ❌ 処理されない |

### 対応が必要なファイル

- `scripts/check_diff.sh` — `find -name "*.sql"` のパターンを拡張
- `scripts/run_sql_review.sh` — `basename "$target_file" .sql` の拡張子除去処理を汎用化
- `.github/prompts/sql-check.prompt.md` — `.jsp`・`.js` を対象に追記するか否かの判断

---

## 2. エンドツーエンドテストが未実施

### 状況

cron による自動実行（毎日 22:00）は登録済みだが、実際に cron が起動して正常にレポートが生成されることを確認していない。

### 確認手順

```bash
source ~/.copilot_env && bash /Users/hironorishigaki/Workspace/sql-review-copilot/scripts/run_sql_review.sh --force
```

確認項目:
1. `reports/` にレポートが生成されているか
2. `state/last_run.timestamp` が更新されているか
3. 翌実行時に変更なしで SKIP されるか
4. `logs/cron.log` に cron 起動時のログが記録されているか

---

## 3. ファイル名にスペースが含まれる場合の動作

### 状況

`bad_examples copy.sql` のようなスペース入りファイル名は現状動作しているが、`check_diff.sh` の `find` 出力を行分割して配列に格納する処理はスペースを含むパスに対して脆弱な実装になっている可能性がある。

### 影響範囲

- `scripts/check_diff.sh` — `find` 出力の行分割処理
- `scripts/run_sql_review.sh` — レポートファイル名生成（スペースがそのままファイル名に入る）

---

## 4. レポートの集約・サマリー機能がない

### 状況

現在は1ファイル = 1レポートで個別に出力される。複数ファイルをまとめたサマリーレポートは生成されない。

### 考えられる追加機能

- 実行ごとに `reports/summary_YYYYMMDD.md` を生成
- 検出件数・深刻度別の集計表を含める
- エラー0件だったファイルの一覧も記録

---

## 5. `sql-fix.prompt.md` が未活用

### 状況

`.github/prompts/sql-fix.prompt.md` が存在するが、自動レビュー基盤（`run_sql_review.sh`）では使用していない。現状は検出のみで自動修正は行われない。

### 考えられる追加機能

- `--fix` オプション追加: レビュー後に `sql-fix.prompt.md` を使って修正案を別レポートとして出力
- `run_sql_fix.sh` として別スクリプトに分離

---

## 6. トークン期限切れ時の通知機能がない

### 状況

`COPILOT_GITHUB_TOKEN` が期限切れになると認証エラーで失敗するが、ログに記録されるだけで通知は行われない。cron 実行時は気づきにくい。

### 考えられる追加機能

- エラー時に macOS 通知（`osascript`）を送信
- `run_sql_review.sh` の終了コード 1 を監視するスクリプトの追加
