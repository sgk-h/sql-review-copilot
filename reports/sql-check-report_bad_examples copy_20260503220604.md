● Read sql-antipatterns.csv
  │ ~/Workspace/sql-review-copilot/rules/sql-antipatterns.csv
  └ 8 lines read

● Read bad_examples copy.sql
  │ ~/Workspace/SQL_Dir/bad_examples copy.sql
  └ 113 lines read

## SQLアンチパターン検出結果

| # | ルールID | 深刻度 | パターン名 | 該当箇所（行番号） | 検出内容 |
|---|----------|--------|------------|-------------------|----------|
| 1 | SQL-002 | medium | SELECT * の使用 | L70-L72 | `products` から全カラム取得しており、不要なI/Oと将来の列追加影響のリスクがある |
| 2 | SQL-002 | medium | SELECT * の使用 | L92 | `orders` から全カラム取得しており、必要列の明示指定になっていない |

### 詳細

#### 1. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT *
FROM   products
WHERE  product_code = '12345';
```

**問題点:**
`SELECT *` はテーブルの全カラムを取得するため、不要なデータの転送・メモリ使用が発生します。さらに、カラム追加時に意図しないデータが返却されるリスクがあります。必要なカラムのみを明示することで、I/O削減やインデックスオンリースキャンの活用が期待できます。

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
`SELECT *` により全カラム取得となっており、不要なデータ転送とメモリ使用が発生します。テーブル定義変更時の影響も受けやすく、保守性・性能の両面で不利です。

**改善案:**
```sql
SELECT order_id, discount
FROM   orders
WHERE  discount IS NULL;
```

※ CSV定義の7ルールに照合した結果、検出は上記2件です。コメント内のJava/Python例は非実行コードのため、実行SQLとしては判定対象外にしました。


Changes   +0 -0
Requests  1 Premium (33s)
Tokens    ↑ 37.1k • ↓ 1.8k • 31.2k (cached) • 1.2k (reasoning)
