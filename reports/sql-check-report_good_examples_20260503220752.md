● Read sql-antipatterns.csv
  │ ~/Workspace/sql-review-copilot/rules/sql-antipatterns.csv
  └ 8 lines read

● Read good_examples.sql
  │ ~/Workspace/SQL_Dir/good_examples.sql
  └ 112 lines read

## SQLアンチパターン検出結果

| # | ルールID | 深刻度 | パターン名 | 該当箇所（行番号） | 検出内容 |
|---|----------|--------|------------|-------------------|----------|
| 1 | SQL-002 | medium | SELECT * の使用 | L91 | `SELECT * FROM orders WHERE discount IS NULL;` により全カラム取得 |

### 詳細

#### 1. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT * FROM orders WHERE discount IS NULL;
```

**問題点:**
`SELECT *` はテーブルの全カラムを取得するため、不要なデータの転送・メモリ使用が発生します。加えて、カラム追加時に意図しないデータが返却されるリスクがあります。必要なカラムのみを明示的に指定することで、I/O削減やインデックスオンリースキャンの活用、テーブル定義変更時の影響範囲の限定が期待できます。

**改善案:**
```sql
SELECT order_id, discount
FROM   orders
WHERE  discount IS NULL;
```

**補足:**
L78-L85 の Java/Python 例に含まれる SQL 文字列はコメント内の説明例であり、実行対象 SQL としてはカウントしていません。

チェック済みルール数: **7件**  
チェック対象SQL文数: **12件**


Changes   +0 -0
Requests  1 Premium (23s)
Tokens    ↑ 36.8k • ↓ 1.2k • 31.4k (cached) • 776 (reasoning)
