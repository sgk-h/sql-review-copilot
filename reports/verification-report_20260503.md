# 事前検証レポート — SQL自動レビュー基盤

**作成日時**: 2026-05-03  
**対象リポジトリ**: https://github.com/sgk-h/sql-review-copilot  
**目的**: crontab 登録・本番運用開始前に、システム全体の動作を実機で確認した記録

---

## 環境情報

| 項目 | 値 |
|---|---|
| OS | macOS |
| Copilot CLI | v1.0.32（`/Users/hironorishigaki/.nvm/versions/node/v22.20.0/bin/copilot`） |
| bash | GNU bash 3.2.57（macOS 標準） |
| レビュー対象ディレクトリ | `/Users/hironorishigaki/Workspace/SQL_Dir` |
| リポジトリルート | `/Users/hironorishigaki/Workspace/sql-review-copilot` |

---

## 検証1: Copilot CLI 基本動作・認証

**コマンド:**
```bash
copilot -p "Hello, respond with just OK" --allow-all-tools
```

**結果:** ✅ 正常動作
```
OK

Requests  1 Premium (7s)
```

**確認事項:**
- Fine-grained PAT（Copilot Requests: Read-only）による認証が正常に機能すること
- `--allow-all-tools` が非対話モード（`-p`）での必須フラグであること

---

## 検証2: `@ファイルパス` 構文の動作確認

**コマンド:**
```bash
copilot -p "次のファイルに SELECT * が含まれていたら「含まれています」とだけ答えてください。 @examples/bad_examples.sql" --allow-all-tools
```

**結果:** ✅ 正常動作
```
● Search (grep)
  │ "SELECT\s+\*" (examples/bad_examples.sql)
  └ 7 lines found

含まれています
```

**確認事項:**
- `@ファイルパス` 構文が Copilot CLI の `-p` モードでも有効なこと
- CLI 内部で grep/search ツールを自動呼び出してファイルを参照すること

---

## 検証3: prompt.md 埋め込み方式 + アンチパターン検出

**コマンド:**
```bash
PROMPT_BODY=$(awk '/^---/{n++; if(n==2){found=1; next}} found{print}' .github/prompts/sql-check.prompt.md)
RULES=$(cat rules/sql-antipatterns.csv)
SQL=$(cat examples/bad_examples.sql)
copilot -p "${PROMPT_BODY}

## ルール定義（CSV）
${RULES}

## チェック対象SQL
${SQL}" --allow-all-tools
```

**結果:** ✅ 正常動作

アンチパターン検出テーブルが正しく出力された（抜粋）：

| # | ルールID | 深刻度 | パターン名 | 該当箇所 | 検出内容 |
|---|---|---|---|---|---|
| 1 | SQL-001 | high | IN句での大量データ外部テーブル参照 | L13-L17 | DELETE文で IN (SELECT ...) により external_customers を参照 |
| 2 | SQL-001 | high | IN句での大量データ外部テーブル参照 | L20-L26 | SELECT文で IN (SELECT ...) により external_master_data を参照 |
| 3 | SQL-002 | medium | SELECT * の使用 | L41 | employees の全カラムを取得 |
| ... | ... | ... | ... | ... | ... |

**確認事項:**
- `awk` でフロントマター（`---` で囲まれた部分）を除去してプロンプト本文を抽出できること
- CSV・SQL を変数展開で直接埋め込む方式が確実に動作すること
- ルール定義に基づいた正確なアンチパターン検出が行われること

---

## 検証4: `--dry-run` モード

**コマンド:**
```bash
TARGET_DIR="./examples" COPILOT_GITHUB_TOKEN="dummy" bash scripts/run_sql_review.sh --dry-run
```

**結果:** ✅ 正常動作
```
[2026-05-03 20:59:37] ===== SQL自動レビュー 開始 =====
[2026-05-03 20:59:37] モード: --dry-run（API呼び出しなし）
[2026-05-03 20:59:37] 処理対象: 3 ファイル
[2026-05-03 20:59:37] [dry-run] 対象ファイル一覧:
[2026-05-03 20:59:37]   - ./examples/bad_examples copy.sql
[2026-05-03 20:59:37]   - ./examples/bad_examples.sql
[2026-05-03 20:59:37]   - ./examples/good_examples.sql
[2026-05-03 20:59:37] ===== SQL自動レビュー 終了（dry-run） =====
```

**確認事項:**
- API を消費せずに処理対象ファイル一覧を確認できること
- `COPILOT_GITHUB_TOKEN` が `dummy` でも dry-run は正常終了すること（API呼び出しなし）

---

## 検証5: `--force` モード

**コマンド:**
```bash
TARGET_DIR="./examples" COPILOT_GITHUB_TOKEN="dummy" bash scripts/run_sql_review.sh --force --dry-run
```

**結果:** ✅ 正常動作  
タイムスタンプの有無に関わらず全3ファイルが対象として列挙された。

**確認事項:**
- `--force` により差分チェックをスキップして全ファイルが対象になること

---

## 検証6: 差分チェック SKIP 動作

**手順:**
1. `touch state/last_run.timestamp` でタイムスタンプファイルを作成
2. `run_sql_review.sh --dry-run` を再実行（SQLファイルは変更なし）

**結果:** ✅ 正常動作
```
[2026-05-03 20:59:45] ===== SQL自動レビュー 開始 =====
[2026-05-03 20:59:45] モード: --dry-run（API呼び出しなし）
[2026-05-03 20:59:45] 変更なし — スキップ（API呼び出し: 0件）
[2026-05-03 20:59:45] ===== SQL自動レビュー 終了 =====
```

**確認事項:**
- 前回実行以降に変更のないファイルはスキップされ、API が消費されないこと
- プレミアムリクエストの節約設計が機能すること

---

## 検証7: cron の PATH 問題の特定と対処

**問題:**  
`copilot` コマンドは NVM 経由でインストールされており、cron 実行時の最小 PATH には含まれない。

```
実際のパス: /Users/hironorishigaki/.nvm/versions/node/v22.20.0/bin/copilot
cron の PATH: /usr/bin:/bin:/usr/sbin:/sbin のみ
```

このままでは cron から実行すると `copilot: command not found` で失敗する。

**対処:**  
`cron_setup_personal.sh` を新規作成。`copilot` のフルパスを自動検出し、crontab エントリに `PATH=<NVM_BIN_DIR>:$PATH` を明示的に付与する形式で出力する。

**結果:** ✅ 解消済み  
`cron_setup_personal.sh` の出力するエントリ例：
```
0 2 * * * PATH=/Users/hironorishigaki/.nvm/versions/node/v22.20.0/bin:$PATH source ~/.copilot_env && bash /Users/hironorishigaki/Workspace/sql-review-copilot/scripts/run_sql_review.sh >> .../logs/cron.log 2>&1
```

---

## 総合判定

| 検証項目 | 結果 |
|---|---|
| Copilot CLI 認証・基本動作 | ✅ |
| `@ファイルパス` 構文 | ✅ |
| prompt.md 埋め込み + アンチパターン検出 | ✅ |
| `--dry-run` モード | ✅ |
| `--force` モード | ✅ |
| 差分チェック SKIP 動作 | ✅ |
| cron PATH 問題の対処 | ✅ |

**全項目確認済み。crontab 登録・本番運用開始の前提条件を満たしている。**

---

## 残タスク（crontab 登録前）

- [ ] `~/.copilot_env` にトークンを保存（手順1）
- [ ] `crontab -e` でエントリを登録（手順2〜3）
- [ ] `run_sql_review.sh --force` を手動実行して実際のレポート生成を確認（エンドツーエンドテスト）
- [ ] `crontab -l` で登録内容を確認（手順4）
