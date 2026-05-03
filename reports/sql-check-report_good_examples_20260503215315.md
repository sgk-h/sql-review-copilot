● Read good_examples.sql
  │ ~/Workspace/SQL_Dir/good_examples.sql
  └ 112 lines read

● Read sql-antipatterns.csv
  │ ~/Workspace/sql-review-copilot/rules/sql-antipatterns.csv
  └ 8 lines read

## SQLアンチパターン検出結果

| # | ルールID | 深刻度 | パターン名 | 該当箇所（行番号） | 検出内容 |
|---|----------|--------|------------|-------------------|----------|
| 1 | SQL-002 | medium | SELECT * の使用 | L91 | `orders` テーブルに対して `SELECT *` を使用し、全カラムを取得している |

### 詳細

#### 1. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT * FROM orders WHERE discount IS NULL;
```

**問題点:**
`SELECT *` はテーブルの全カラムを取得するため、不要なデータの転送・メモリ使用が発生します。加えて、将来カラムが追加された際に意図しないデータが返却されるリスクがあります。  
CSV定義では、必要なカラムのみを明示することで I/O 削減やインデックスオンリースキャンの活用、テーブル定義変更の影響限定が可能とされています。

**改善案:**
```sql
SELECT order_id, discount
FROM   orders
WHERE  discount IS NULL;
```

`SELECT employee_id, name, email ...` のように、CSVの good example と同様に必要なカラムだけを明示してください。

補足として、コメント内の Java/Python サンプルは実行SQLではないため対象外とし、実行対象のSQL 12文を7ルールで照合しました。


Changes   +0 -0
Requests  1 Premium (23s)
Tokens    ↑ 36.8k • ↓ 1.2k • 31.4k (cached) • 752 (reasoning)
