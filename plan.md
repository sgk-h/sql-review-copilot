# Plan: Copilot CLI 自動SQLレビュー基盤の構築

## TL;DR

新 GitHub Copilot CLI（`copilot` コマンド）の `-p` オプションで非対話実行。  
差分チェック機能（前回実行以降の変更ファイルのみ処理）でプレミアムリクエスト消費を最小化。

> **実現可能性確認済み**: 実装着手前に主要な技術的リスクを実機で検証し、全項目で動作を確認済み。詳細は「[実現可能性の事前検証](#実現可能性の事前検証)」セクションを参照。

---

## ディレクトリ構成（完成形）

```
sql-review-copilot/               ← このリポジトリ（レビュー基盤）
├── .github/
│   └── prompts/
│       ├── sql-check.prompt.md   # 既存
│       └── sql-fix.prompt.md     # 既存
├── examples/                     # 既存（動作確認用サンプルSQL）
├── rules/
│   └── sql-antipatterns.csv      # 既存（変更監視対象に追加）
├── reports/                      # 既存（レポート出力先）
│   └── sql-check-report_*.md
├── logs/                         # 新規
│   ├── .gitkeep
│   └── sql-review_YYYYMMDD.log
├── scripts/                      # 新規
│   ├── config.sh                 # 設定変数一元管理
│   ├── check_diff.sh             # 差分チェック（A案コア）
│   ├── run_sql_review.sh         # メインエントリポイント
│   └── cron_setup.sh             # cron設定サンプル出力
├── state/                        # 新規（差分管理用）
│   ├── .gitkeep
│   └── last_run.timestamp        # 前回実行タイムスタンプ（動的生成・git管理外）
├── tests/
│   └── test_sql_review.py        # 既存
└── README.md                     # 既存

/path/to/your-app/                ← レビュー対象ソース（外部・別リポジトリ等）
└── src/
    └── sql/
        └── *.sql                 # ← TARGET_DIR に指定する実アプリのSQLファイル群
```

> **ソースファイルの配置方針（B案）**  
> レビュー対象のSQLファイルは**このリポジトリ外の所定ディレクトリ**に配置する。  
> `scripts/config.sh` の `TARGET_DIR` に対象ディレクトリの絶対パスを設定するだけでよく、  
> このリポジトリ自体は変更不要。複数のアプリリポジトリを対象にする場合は `TARGET_DIR` を変えて複数回実行することも可能。

---

## フェーズ 0: 前提環境整備（手動・1回限り）

1. **Copilot CLI インストール**
   - macOS/Linux: `brew install copilot-cli` または `curl -fsSL https://gh.io/copilot-install | bash`
   - Windows: `winget install GitHub.Copilot`

2. **Fine-grained PAT 作成**
   - GitHub Settings > Developer settings > Personal access tokens > Fine-grained tokens
   - Resource owner: **個人アカウント**を選択（Organization は不可）
   - Repository access: **No repositories**（リポジトリ権限は不要）
   - Permissions > Account タブ > **Copilot Requests: Read-only** を付与
     > **補足**: 「Read-only」が正しい設定。「Read-only = Copilot API にリクエストを送受信できる（＝Copilotを使う）」を意味する権限設計のため、Write は不要。Pro 個人契約では組織設定が存在しないため、選択肢自体が Read-only のみ表示される。
   - 生成したトークン（`github_pat_...`）を環境変数 `COPILOT_GITHUB_TOKEN` に設定

3. **信頼ディレクトリ事前登録は不要**
   - `copilot` の `--allow-all-paths` フラグを使用することでファイルパス検証をスキップできることを実機確認済み。
   - スクリプトに `--allow-all-paths --allow-all-tools` を付与すれば、事前のインタラクティブ登録作業なしに cron から安全に実行できる。

---

## 実現可能性の事前検証

> 実装着手前に以下3点の技術的リスクを実機で検証した。すべて動作確認済み。

| # | 検証項目 | 結果 | 確認内容 |
|---|---|---|---|
| ① | `@ファイルパス` 構文が `copilot -p` で動作するか | ✅ 動作する | CLI内部でgrep/searchツールを自動呼び出してファイルを参照。結果も正確に返却された |
| ② | `prompt.md` 本文の抽出・プロンプト埋め込み方式 | ✅ 動作する | `awk` でフロントマターを除去 → CSV・SQLを変数展開で埋め込み → アンチパターン検出テーブルが正しく出力された |
| ③ | cron（TTYなし）での実行時にファイルアクセスが通るか | ✅ 解消済み | `--allow-all-paths` フラグで信頼ディレクトリ検証をスキップできることを確認。信頼ディレクトリの事前登録作業は不要 |

**検証時に判明した重要事項:**
- `--allow-all-tools` は非対話モード（`-p`）で**必須**のフラグ（未指定だと権限確認でブロックされる）
- `--allow-all-paths` により外部ディレクトリへのアクセスも許可される（B案の実現に必要）
- プロンプト文字列にCSV・SQLを直接埋め込む方式が最もシンプルかつ確実に動作する

---

## Businessプラン / SAML SSO 環境での追加確認事項

> 所属組織が GitHub Copilot Business プランを利用しており、SAML SSO（ブラウザでユーザーIDを入力するだけでログインできる環境）を使用している場合に確認が必要な事項。

### Fine-grained PAT の生成可否

**生成できます。**  
Fine-grained PAT は**個人の GitHub アカウント単位**で作成するものであり、Businessプランでも手順は同じ。  
"Copilot Requests" 権限は **Account レベルの権限**（Organization レベルではない）のため、Resource owner は個人アカウントを選択する。

### SAML SSO と PAT の関係

| PAT の種類 | SAML SSO への対応 |
|---|---|
| **Classic PAT**（`ghp_`） | 作成後に「Configure SSO」で組織ごとの承認が別途必要。**Copilot CLI では使用不可のため非推奨。** |
| **Fine-grained PAT**（`github_pat_`） | トークン作成時に組織アクセスの承認が完了する仕様。追加手順不要。 |

今回使用する Fine-grained PAT の "Copilot Requests" は Account レベル権限のため、**SAML SSO の追加承認は基本的に不要**。  
Copilot API への呼び出しはユーザー個人の操作として扱われ、組織リソースへのアクセスではない。

### 組織管理者への確認事項（事前に確認推奨）

| 確認事項 | 詳細 |
|---|---|
| **Copilot CLI の有効化** | 組織の Settings > Copilot > Policies で Copilot CLI が有効になっているか |
| **Fine-grained PAT の制限** | 組織が Fine-grained PAT の使用を制限・承認制にしていないか |
| **IP アドレス制限** | Enterprise で IP アクセス許可リストが設定されている場合、cron を実行するサーバーの IP が許可されているか（社内ネットワーク外のサーバーで実行する場合） |

### 動作確認（設定完了後の最初のテスト）

```bash
COPILOT_GITHUB_TOKEN=<生成したトークン> copilot -p "Hello"
```

上記が正常に応答すれば認証・ポリシーいずれも問題なし。エラーの場合は上記3点の確認へ。

---

## フェーズ 1: ディレクトリと設定ファイル

4. **`logs/` ディレクトリ作成**（`.gitkeep` 付き）

5. **`state/` ディレクトリ作成**（`.gitkeep` 付き）  
   - `state/last_run.timestamp` は実行ごとに自動更新される動的ファイル
   - `.gitignore` に `state/last_run.timestamp` を追加（git管理外）

6. **`scripts/config.sh` 作成** — 以下の変数を一元管理:

   | 変数 | 内容 |
   |---|---|
   | `REPO_ROOT` | このリポジトリの絶対パス |
   | `TARGET_DIR` | **レビュー対象SQLの外部ディレクトリ絶対パス**（例: `/path/to/your-app/src/sql`） |
   | `REPORTS_DIR` | `$REPO_ROOT/reports` |
   | `LOGS_DIR` | `$REPO_ROOT/logs` |
   | `STATE_DIR` | `$REPO_ROOT/state` |
   | `TIMESTAMP_FILE` | `$STATE_DIR/last_run.timestamp` |
   | `SQL_CHECK_PROMPT` | `$REPO_ROOT/.github/prompts/sql-check.prompt.md` のパス |
   | `RULES_CSV` | `$REPO_ROOT/rules/sql-antipatterns.csv` のパス |

---

## フェーズ 2: 差分チェックスクリプト（A案コア）

> **Phase 1 完了後に着手**

7. **`scripts/check_diff.sh` 作成** — 変更ファイルを検出して標準出力に返す

   - `TIMESTAMP_FILE` が**存在する**場合:  
     `find $TARGET_DIR -name "*.sql" -newer $TIMESTAMP_FILE` で変更ファイルを列挙
   - `TIMESTAMP_FILE` が**存在しない**場合（初回実行）:  
     `find $TARGET_DIR -name "*.sql"` で全ファイルを列挙
   - 結果が **0件**の場合は呼び出し元に "SKIP" を返し、API呼び出しをスキップ
   - `RULES_CSV`（`rules/sql-antipatterns.csv`）も変更監視対象に含める  
     → ルール追加・変更時は既存ファイルにも新ルールを適用し直す必要があるため、**全ファイルを強制再チェック**
   - `--force` オプション対応: 差分チェックをスキップして全ファイルを返す

---

## フェーズ 3: メインスクリプト

> **Phase 2 完了後に着手**

8. **`scripts/run_sql_review.sh` 作成** — エントリポイント

   - `config.sh` を source
   - `COPILOT_GITHUB_TOKEN` 未設定チェック（未設定なら即終了・終了コード 2）
   - `check_diff.sh` を呼び出して処理対象ファイルリストを取得
   - 対象ファイルが **0件** → 「変更なし、スキップ」をログに記録して正常終了（API呼び出しなし）
   - 対象ファイルが **1件以上** → ファイルごとにループ処理:
     - `sql-check.prompt.md` のフロントマター（`---`で囲まれた部分）を `awk` で除去してプロンプト本文を抽出
     - `rules/sql-antipatterns.csv` と対象 `.sql` ファイルの内容を `cat` で変数展開しプロンプトに直接埋め込む
     - 実行コマンド:
       ```bash
       PROMPT_BODY=$(awk '/^---/{n++; if(n==2){found=1; next}} found{print}' "$SQL_CHECK_PROMPT")
       RULES=$(cat "$RULES_CSV")
       SQL=$(cat "$target_file")
       copilot -p "${PROMPT_BODY}

## ルール定義（CSV）
${RULES}

## チェック対象SQL
${SQL}" --allow-all-tools --allow-all-paths
       ```
     - 出力を `reports/sql-check-report_<ファイル名>_YYYYMMDDHHMMSS.md` に保存
   - 全ファイル処理完了後、`TIMESTAMP_FILE` を `touch` で現在時刻に更新
   - `logs/sql-review_YYYYMMDD.log` に追記（処理件数・スキップ件数・エラー内容を記録）

   **オプション:**
   | オプション | 動作 |
   |---|---|
   | `--dry-run` | API を呼ばず対象ファイルリストとプロンプトのみ出力 |
   | `--force` | `check_diff.sh --force` に渡して全ファイル強制実行 |

   **終了コード:**
   | コード | 意味 |
   |---|---|
   | `0` | 成功（スキップ含む） |
   | `1` | 部分失敗（一部ファイルでエラー） |
   | `2` | 致命的エラー（認証失敗・設定不備など） |

---

## フェーズ 4: cron設定

> **Phase 3 完了後に着手**

9. **`scripts/cron_setup.sh` 作成** — `crontab -e` に追加するエントリのサンプルを出力
   - `COPILOT_GITHUB_TOKEN` の安全な渡し方（`~/.profile` または専用 `.env` ファイル経由）も案内
   - 例:
     ```
     # 毎日午前2時に実行
     0 2 * * * COPILOT_GITHUB_TOKEN=github_pat_xxx /path/to/scripts/run_sql_review.sh >> /path/to/logs/cron.log 2>&1
     ```

---

## フェーズ 5: AIモデル指定機能

> **Phase 4 完了後に追加**

10. **`scripts/config.sh` に `SQL_REVIEW_MODEL` 変数を追加**

    ```bash
    # 使用するAIモデル（空文字 = デフォルトモデル: Claude Sonnet 4.5）
    # 例: SQL_REVIEW_MODEL="gpt-4.1"
    # 環境変数で上書き可能: SQL_REVIEW_MODEL=gpt-4.1 bash run_sql_review.sh
    SQL_REVIEW_MODEL="${SQL_REVIEW_MODEL:-}"
    ```

    > **命名理由**: 公式環境変数 `COPILOT_MODEL`（カスタムプロバイダー向け）と衝突を避けるため `SQL_REVIEW_MODEL` とする。

11. **`scripts/run_sql_review.sh` の `copilot -p` 呼び出し部分を修正**

    ```bash
    MODEL_OPT=""
    [[ -n "${SQL_REVIEW_MODEL:-}" ]] && MODEL_OPT="--model ${SQL_REVIEW_MODEL}"

    copilot -p "..." --allow-all-tools --allow-all-paths ${MODEL_OPT}
    ```

    - `SQL_REVIEW_MODEL` が空の場合は `--model` フラグを付与しない（デフォルトモデルを使用）
    - 無効なモデル名の場合は `copilot` が非ゼロで終了 → 既存の `if ... then ... else log "ERROR" fi` で捕捉済み

    **利用可能なモデル確認方法:**
    - GitHub ホステッドモデル一覧: 対話型セッションで `copilot` → `/model` を実行
    - カスタムプロバイダー設定: `copilot help providers`
    - 公式ドキュメント: [About GitHub Copilot CLI > Model usage](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli#model-usage)

    **使い方（運用時）:**

    | シナリオ | 方法 |
    |---|---|
    | デフォルトモデルを使う | 何もしない（`config.sh` の `SQL_REVIEW_MODEL` は空のまま） |
    | 実行ごとに一時的に変更 | `SQL_REVIEW_MODEL=gpt-4.1 bash scripts/run_sql_review.sh` |
    | 常時特定モデルに固定 | `config.sh` の `SQL_REVIEW_MODEL=""` を `SQL_REVIEW_MODEL="gpt-4.1"` に変更 |
    | cron で固定モデルを使う | `~/.copilot_env` に `export SQL_REVIEW_MODEL=gpt-4.1` を追記 |

---

## 関連ファイル一覧

| ファイル | 種別 | 役割 |
|---|---|---|
| `scripts/config.sh` | 新規 | 全設定変数の一元管理 |
| `scripts/check_diff.sh` | 新規 | 差分チェックのコア（A案） |
| `scripts/run_sql_review.sh` | 新規 | メインエントリポイント |
| `scripts/cron_setup.sh` | 新規 | cron設定サンプル出力 |
| `logs/` | 新規ディレクトリ | 実行ログ保存先 |
| `state/` | 新規ディレクトリ | 差分管理用タイムスタンプ保存 |
| `state/last_run.timestamp` | 動的生成 | 差分比較の基準時刻（git管理外） |
| `.gitignore` | 修正 | `state/last_run.timestamp` を除外追加 |
| `.github/prompts/sql-check.prompt.md` | 既存・変更なし | プロンプト指示のベース |
| `rules/sql-antipatterns.csv` | 既存・変更なし | ルール定義（変更監視対象に追加） |

---

## 検証手順

1. `./scripts/run_sql_review.sh --dry-run`  
   → 処理対象ファイルリストとプロンプト内容を確認

2. `COPILOT_GITHUB_TOKEN=<token> ./scripts/run_sql_review.sh`  
   → **初回実行**（`state/last_run.timestamp` が存在しないため全ファイル対象）

3. `reports/` にレポートが生成・`logs/` にログが追記されることを確認

4. `state/last_run.timestamp` が作成されることを確認

5. **SQLファイルを変更せずに再実行**  
   → 「変更なし、スキップ」になることを確認（差分チェック動作確認）

6. **1ファイルだけ変更して再実行**  
   → 変更ファイルのみ処理されることを確認

7. **`rules/sql-antipatterns.csv` を変更して再実行**  
   → 全ファイルが再チェックされることを確認（ルール変更の全力再チェック動作確認）

8. `crontab -e` でスケジュール登録 → 翌日の自動実行を確認

---

## ユーザー操作フロー

### 初回セットアップ（1回限り）

```
1. リポジトリを clone
2. Copilot CLI をインストール
3. GitHub で Fine-grained PAT を発行
4. scripts/config.sh の TARGET_DIR を自分の環境のパスに書き換える
5. copilot を手動起動して信頼ディレクトリを登録（2箇所）
6. cron_setup.sh を実行して crontab に登録
```

### 日常運用（完全自動）

```
毎日 午前2時（設定した時刻）
  ↓ cron が自動で run_sql_review.sh を起動
  ↓ 前回実行以降に変更された .sql ファイルを検出
  ↓ 変更なし → スキップ（ログのみ記録）
  ↓ 変更あり → Copilot CLI でレビュー実行
  ↓ reports/ にレポートを出力
  ↓ logs/ にログを追記
```

**ユーザーが日常的にやること: なし**（`reports/` を定期的に確認するだけ）

### 手動実行

```bash
# 通常実行（差分のみ）
./scripts/run_sql_review.sh

# 全ファイルを強制再チェック
./scripts/run_sql_review.sh --force

# API を呼ばずに対象ファイルだけ確認
./scripts/run_sql_review.sh --dry-run
```

---

## 決定事項

| 項目 | 決定内容 |
|---|---|
| 非対話実行 | `copilot -p` コマンドを使用（旧 `gh copilot` は廃止済みのため不採用） |
| 認証 | Fine-grained PAT（"Copilot Requests: Read-only"）+ `COPILOT_GITHUB_TOKEN` 環境変数 |
| 差分チェック基準 | `find -newer` によるタイムスタンプ比較（git不要・外部依存なし） |
| ルール変更時の挙動 | `rules/sql-antipatterns.csv` 更新時は全ファイルを強制再チェック |
| タイムスタンプ保存先 | `state/last_run.timestamp`（`.gitignore` で除外） |
| 外部依存 | `copilot`（Copilot CLI）、`bash`、`find`（標準コマンド）のみ |
| 対応OS | Linux / macOS（cron）、Windows は WSL 経由で同スクリプトを流用可 |
