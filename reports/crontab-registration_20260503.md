# crontab 登録レポート

**作成日時**: 2026-05-03  
**作業者**: hironorishigaki  
**対象リポジトリ**: https://github.com/sgk-h/sql-review-copilot

---

## 登録内容

```
# SQL自動レビュー — 毎日午後10時に実行（NVM環境対応）
0 22 * * * PATH=/Users/hironorishigaki/.nvm/versions/node/v22.20.0/bin:$PATH source ~/.copilot_env && bash /Users/hironorishigaki/Workspace/sql-review-copilot/scripts/run_sql_review.sh >> /Users/hironorishigaki/Workspace/sql-review-copilot/logs/cron.log 2>&1
```

| 項目 | 値 |
|---|---|
| 実行スケジュール | 毎日 22:00（午後10時） |
| copilot パス | `/Users/hironorishigaki/.nvm/versions/node/v22.20.0/bin` |
| メインスクリプト | `/Users/hironorishigaki/Workspace/sql-review-copilot/scripts/run_sql_review.sh` |
| cron ログ | `/Users/hironorishigaki/Workspace/sql-review-copilot/logs/cron.log` |
| トークン管理 | `~/.copilot_env`（パーミッション 600）|

---

## 登録時の注意事項・対処記録

### 発生した問題

`cron_setup_personal.sh` の出力結果ではなく、スクリプトファイル内のテキストをそのままコピーしたため、以下のように変数が未展開の状態で登録された。

```
# 誤った登録内容（変数が展開されていない）
0 22 * * * PATH=${NVM_BIN_DIR}:\$PATH source ~/.copilot_env && bash ${RUN_SCRIPT} >> ${CRON_LOG} 2>&1
```

このままでは cron 実行時に `PATH` が正しく設定されず、`copilot: command not found` で失敗する。

### 対処

誤ったエントリを削除し、フルパスを展開した正しいエントリで再登録した。

### 正しい手順（今後のために）

`cron_setup_personal.sh` は**実行して出力された内容**をコピーする。ファイルを直接開いてテキストをコピーしない。

```bash
# 正しい手順
cd /Users/hironorishigaki/Workspace/sql-review-copilot
bash scripts/cron_setup_personal.sh
# → 出力された「手順3」のエントリをコピーして crontab -e に貼り付ける
```

---

## 登録確認

```bash
$ crontab -l
# SQL自動レビュー — 毎日午後10時に実行（NVM環境対応）
0 22 * * * PATH=/Users/hironorishigaki/.nvm/versions/node/v22.20.0/bin:$PATH source ~/.copilot_env && bash /Users/hironorishigaki/Workspace/sql-review-copilot/scripts/run_sql_review.sh >> /Users/hironorishigaki/Workspace/sql-review-copilot/logs/cron.log 2>&1
```

---

## 次のステップ

- [ ] `run_sql_review.sh --force` を手動実行してエンドツーエンド動作を確認
- [ ] `reports/` にレポートが生成されることを確認
- [ ] 翌日 22:00 以降に `logs/cron.log` を確認して cron の自動実行を確認
