# sql-review-copilot

GitHub Copilot Chat を活用した **SQLアンチパターン検出・修正ツール**。

CSVファイルでアンチパターンを一元管理し、VS Code の Copilot Chat からスラッシュコマンドでチェック・修正を実行する。

## 背景

夜間バッチにおいて、IN句で外部テーブルを参照するSQLがフルテーブルスキャンを引き起こし、データ量の増加に比例して処理時間が悪化する問題が発生した。EXISTSへの切り替えで解決したが、同種の問題を未然に防ぐ仕組みとして本ツールを構築した。

## ディレクトリ構成

```
sql-review-copilot/
├── .github/
│   └── prompts/
│       ├── sql-check.prompt.md    # チェック用プロンプト（/sql-check）
│       └── sql-fix.prompt.md      # 修正用プロンプト（/sql-fix）
├── rules/
│   └── sql-antipatterns.csv       # アンチパターン定義
├── examples/
│   ├── bad_examples.sql           # アンチパターンを含むサンプル
│   └── good_examples.sql          # 改善済みサンプル
└── README.md
```

## 前提条件

- VS Code
- GitHub Copilot 拡張機能（Copilot Chat が利用可能であること）

## 使い方

### 1. プロジェクトへの導入

本リポジトリをプロジェクトのルートにコピーする、またはgit submoduleとして追加する。

```bash
# 方法A: ディレクトリごとコピー
cp -r sql-review-copilot/.github/prompts/ <your-project>/.github/prompts/
cp -r sql-review-copilot/rules/ <your-project>/rules/

# 方法B: git submodule
git submodule add <repository-url> sql-review
```

> **注意**: `.github/prompts/` 内の `.prompt.md` ファイルからCSVへの相対パス参照が正しいことを確認してください。

### 2. SQLチェックの実行

1. VS Code で対象の `.sql` ファイルまたはSQL文を含むコードファイルを開く
2. Copilot Chat を開く（`Ctrl+Shift+I` / `Cmd+Shift+I`）
3. `/sql-check` と入力してEnter
4. チェック対象のファイルやコードを指定する

**出力例:**

```
## SQLアンチパターン検出結果

| # | ルールID | 深刻度 | パターン名 | 該当箇所 | 検出内容 |
|---|----------|--------|------------|---------|----------|
| 1 | SQL-001  | high   | IN句での大量データ外部テーブル参照 | L15-L19 | DELETE文でIN句により外部テーブルを参照 |
| 2 | SQL-002  | medium | SELECT * の使用 | L35 | 全カラムを取得している |
```

### 3. SQLの自動修正

1. チェック結果を確認後、`/sql-fix` と入力してEnter
2. 修正対象のファイルやコードを指定する
3. 修正案が提示されるので、確認後に適用する

### 4. 動作確認（examples/ を使用）

初回導入時にアンチパターン検出が正しく動作するか確認する。

1. `examples/bad_examples.sql` を VS Code で開く
2. Copilot Chat で `/sql-check` を実行
3. 7件のアンチパターンが検出されることを確認
4. `/sql-fix` を実行し、修正案が提示されることを確認
5. `examples/good_examples.sql` でチェックが通ることを確認

## ルールの追加方法

`rules/sql-antipatterns.csv` に行を追加するだけで新しいルールが有効になる。

### CSVフォーマット

| カラム | 必須 | 説明 | 例 |
|--------|------|------|----|
| `id` | ○ | 一意識別子 | `SQL-008` |
| `category` | ○ | 分類 | `performance` / `security` / `correctness` |
| `severity` | ○ | 深刻度 | `high` / `medium` / `low` |
| `name` | ○ | パターン名 | `LIKE '%前方一致なし'の使用` |
| `description` | ○ | 問題の説明 | `LIKE句で先頭にワイルドカードを…` |
| `bad_example` | ○ | アンチパターン例 | `WHERE name LIKE '%tanaka'` |
| `good_example` | ○ | 改善例 | `WHERE name LIKE 'tanaka%'` |
| `explanation` | ○ | 詳細な解説 | `先頭ワイルドカードはインデックスを…` |

### 追加手順

1. `rules/sql-antipatterns.csv` をテキストエディタで開く
2. 最終行に新しいルールを追加する（カンマ区切り、ダブルクォートで囲む）
3. 保存後、Copilot Chat で `/sql-check` を実行すれば即座に反映される

### 追加例

```csv
SQL-008,performance,medium,LIKE句の前方ワイルドカード,"LIKE句でパターンの先頭にワイルドカードを使用するとインデックスが利用できずフルスキャンになる。","SELECT * FROM users WHERE name LIKE '%tanaka';","SELECT * FROM users WHERE name LIKE 'tanaka%';","先頭ワイルドカード（%tanaka）はBTreeインデックスの探索が不可能。後方一致が必要な場合はリバースインデックスまたは全文検索インデックスを検討する。"
```

## 初期登録ルール一覧

| ID | カテゴリ | 深刻度 | パターン名 |
|----|----------|--------|------------|
| SQL-001 | performance | high | IN句での大量データ外部テーブル参照 |
| SQL-002 | performance | medium | SELECT * の使用 |
| SQL-003 | performance | high | WHERE句なしのDELETE/UPDATE |
| SQL-004 | performance | medium | 暗黙の型変換によるインデックス無効化 |
| SQL-005 | security | high | SQLインジェクション脆弱性 |
| SQL-006 | correctness | medium | NULLの等価比較 |
| SQL-007 | performance | medium | 相関サブクエリのSELECT句使用 |

## 今後の拡張

- **常時チェック**: `.github/copilot-instructions.md` にルールを組み込み、SQL編集時に自動でCopilotが指摘する
- **pre-commit連携**: コミット時に自動チェックを実行するフック
- **CI/CD統合**: PRレビュー時にCopilot Agentが自動レビュー
