● Read sql-antipatterns.csv
  │ ~/Workspace/sql-review-copilot/rules/sql-antipatterns.csv
  └ 8 lines read

● Read bad_examples copy.sql
  │ ~/Workspace/SQL_Dir/bad_examples copy.sql
  └ 113 lines read

## SQLアンチパターン検出結果

| # | ルールID | 深刻度 | パターン名 | 該当箇所（行番号） | 検出内容 |
|---|----------|--------|------------|-------------------|----------|
| 1 | SQL-002 | medium | SELECT * の使用 | L70-L72 | `products` テーブルに対して `SELECT *` を使用 |
| 2 | SQL-002 | medium | SELECT * の使用 | L92 | `orders` テーブルに対して `SELECT *` を使用 |

### 詳細

#### 1. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT *
FROM   products
WHERE  product_code = '12345';
```

**問題点:**
`SELECT *` はテーブルの全カラムを取得するため、不要なデータの転送・メモリ使用が発生します。加えて、将来カラムが追加された際に意図しないデータが返却されるリスクがあります。必要なカラムのみを明示することで、I/O削減やインデックスオンリースキャンの活用が期待できます。

**改善案:**
```sql
SELECT product_id, product_code, product_name
FROM   products
WHERE  product_code = '12345';
```

#### 2. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT * FROM orders WHERE discount IS NULL;
```

**問題点:**
`SELECT *` は全カラム取得となるため、不要な列まで読み込んでしまいます。このSQLは `IS NULL` を使っており SQL-006 の観点では問題ありませんが、SQL-002 には該当します。

**改善案:**
```sql
SELECT order_id, customer_id, discount
FROM   orders
WHERE  discount IS NULL;
```

※ コメント内の Java/Python 例にも `SELECT *` を含むSQL文字列がありますが、コメントとして記載された参考例のため、本結果では実行対象SQLから除外しました。実コードとして使う場合は SQL-002 の確認対象です。


Changes   +0 -0
Requests  1 Premium (33s)
Tokens    ↑ 37.3k • ↓ 1.6k • 17.7k (cached) • 1.0k (reasoning)
