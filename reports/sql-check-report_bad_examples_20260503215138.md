ルール定義を読み込んで、対象SQLの行番号ベースで照合します。検出はCSV定義の7ルールのみに限定して整理します。

● Read sql-antipatterns.csv
  │ ~/Workspace/sql-review-copilot/rules/sql-antipatterns.csv
  └ 8 lines read

● Read bad_examples.sql
  │ ~/Workspace/SQL_Dir/bad_examples.sql
  └ 103 lines read

## SQLアンチパターン検出結果

※ コメント内に記載された埋め込みSQL例（Java/Python）もチェック対象として判定しています。

| # | ルールID | 深刻度 | パターン名 | 該当箇所（行番号） | 検出内容 |
|---|----------|--------|------------|-------------------|----------|
| 1 | SQL-001 | high | IN句での大量データ外部テーブル参照 | L13-L17 | `DELETE` 文で `IN (SELECT ... FROM external_customers)` を使用 |
| 2 | SQL-001 | high | IN句での大量データ外部テーブル参照 | L20-L26 | `SELECT` 文で `IN (SELECT ... FROM external_master_data)` を使用 |
| 3 | SQL-001 | high | IN句での大量データ外部テーブル参照 | L29-L34 | `UPDATE` 文で `IN (SELECT ... FROM external_archive_targets)` を使用 |
| 4 | SQL-002 | medium | SELECT * の使用 | L40 | `SELECT *` を使用 |
| 5 | SQL-002 | medium | SELECT * の使用 | L42-L44 | JOIN を含むクエリで `SELECT *` を使用 |
| 6 | SQL-003 | high | WHERE句なしのDELETE/UPDATE | L50 | `DELETE FROM tmp_batch_work;` に `WHERE` 句がない |
| 7 | SQL-003 | high | WHERE句なしのDELETE/UPDATE | L52 | `DELETE FROM staging_import_data;` に `WHERE` 句がない |
| 8 | SQL-004 | medium | 暗黙の型変換によるインデックス無効化 | L59-L61 | `phone_number` に数値リテラルを比較 |
| 9 | SQL-002 | medium | SELECT * の使用 | L63-L65 | `SELECT *` を使用 |
| 10 | SQL-004 | medium | 暗黙の型変換によるインデックス無効化 | L63-L65 | `product_code` に数値リテラルを比較 |
| 11 | SQL-005 | high | SQLインジェクション脆弱性（文字列結合によるSQL構築） | L73 | Java文字列連結でSQLを構築 |
| 12 | SQL-002 | medium | SELECT * の使用 | L73 | 埋め込みSQLで `SELECT *` を使用 |
| 13 | SQL-005 | high | SQLインジェクション脆弱性（文字列結合によるSQL構築） | L77 | Python文字列連結でSQLを構築 |
| 14 | SQL-002 | medium | SELECT * の使用 | L77 | 埋め込みSQLで `SELECT *` を使用 |
| 15 | SQL-002 | medium | SELECT * の使用 | L83 | `SELECT *` を使用 |
| 16 | SQL-006 | medium | NULLの等価比較 | L83 | `discount = NULL` を使用 |
| 17 | SQL-006 | medium | NULLの等価比較 | L85-L87 | `cancelled_date != NULL` を使用 |
| 18 | SQL-007 | medium | 相関サブクエリのSELECT句使用 | L93-L103 | `SELECT` 句に相関サブクエリを2件使用 |

### 詳細

#### 1. SQL-001 — IN句での大量データ外部テーブル参照（high）

**該当コード:**
```sql
DELETE FROM orders
WHERE customer_id IN (
    SELECT customer_id
    FROM external_customers
);
```

**問題点:**
`IN` 句はサブクエリ結果全体を先に構築してから照合するため、外部テーブルのデータ量増加に伴って性能劣化しやすいです。CSV定義の説明どおり、特に `DELETE` では影響が大きくなります。

**改善案:**
```sql
DELETE FROM orders o
WHERE EXISTS (
    SELECT 1
    FROM external_customers ec
    WHERE ec.customer_id = o.customer_id
);
```

#### 2. SQL-001 — IN句での大量データ外部テーブル参照（high）

**該当コード:**
```sql
SELECT order_id, order_date, total_amount
FROM orders
WHERE customer_id IN (
    SELECT customer_id
    FROM external_master_data
    WHERE status = 'active'
);
```

**問題点:**
外部テーブルを `IN` サブクエリで参照しており、CSV定義のとおりデータ量増加時にスキャンコストが悪化します。

**改善案:**
```sql
SELECT o.order_id, o.order_date, o.total_amount
FROM orders o
WHERE EXISTS (
    SELECT 1
    FROM external_master_data emd
    WHERE emd.customer_id = o.customer_id
      AND emd.status = 'active'
);
```

#### 3. SQL-001 — IN句での大量データ外部テーブル参照（high）

**該当コード:**
```sql
UPDATE order_items
SET    is_archived = 1
WHERE  order_id IN (
    SELECT order_id
    FROM   external_archive_targets
);
```

**問題点:**
`UPDATE` に対して外部テーブル由来の `IN` サブクエリを使っており、対象件数増加時に非効率です。

**改善案:**
```sql
UPDATE order_items oi
SET    is_archived = 1
WHERE  EXISTS (
    SELECT 1
    FROM   external_archive_targets eat
    WHERE  eat.order_id = oi.order_id
);
```

#### 4. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT * FROM employees WHERE department_id = 10;
```

**問題点:**
不要な列まで取得し、I/O・メモリ使用量が増えます。テーブル定義変更の影響も受けやすくなります。

**改善案:**
```sql
SELECT employee_id, name
FROM employees
WHERE department_id = 10;
```

#### 5. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT * FROM orders o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_date >= '2026-01-01';
```

**問題点:**
JOIN 時の `SELECT *` は特に取得列が増えやすく、転送量とメモリ使用量が過大になります。

**改善案:**
```sql
SELECT o.order_id, o.order_date, o.total_amount,
       oi.order_id, oi.product_id, oi.quantity
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_date >= '2026-01-01';
```

#### 6. SQL-003 — WHERE句なしのDELETE/UPDATE（high）

**該当コード:**
```sql
DELETE FROM tmp_batch_work;
```

**問題点:**
`WHERE` 句なしの `DELETE` は全行削除になります。CSV定義のとおり、意図的な全件削除なら `TRUNCATE` の方が効率的です。

**改善案:**
```sql
TRUNCATE TABLE tmp_batch_work;
```

#### 7. SQL-003 — WHERE句なしのDELETE/UPDATE（high）

**該当コード:**
```sql
DELETE FROM staging_import_data;
```

**問題点:**
全件削除となり、削除ログを1行ずつ処理するため低速です。

**改善案:**
```sql
TRUNCATE TABLE staging_import_data;
```

#### 8. SQL-004 — 暗黙の型変換によるインデックス無効化（medium）

**該当コード:**
```sql
SELECT employee_id, name
FROM   employees
WHERE  phone_number = 09012345678;
```

**問題点:**
CSV定義どおり、文字列カラムに数値リテラルを比較すると暗黙の型変換が発生し、インデックスが効かなくなる可能性があります。

**改善案:**
```sql
SELECT employee_id, name
FROM employees
WHERE phone_number = '09012345678';
```

#### 9. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT *
FROM   products
WHERE  product_code = 12345;
```

**問題点:**
不要列の取得が発生します。

**改善案:**
```sql
SELECT product_code
FROM products
WHERE product_code = '12345';
```

#### 10. SQL-004 — 暗黙の型変換によるインデックス無効化（medium）

**該当コード:**
```sql
SELECT *
FROM   products
WHERE  product_code = 12345;
```

**問題点:**
`product_code` が `VARCHAR(10)` と明記されており、数値リテラル比較は暗黙の型変換を誘発します。

**改善案:**
```sql
SELECT product_code
FROM products
WHERE product_code = '12345';
```

#### 11. SQL-005 — SQLインジェクション脆弱性（文字列結合によるSQL構築）（high）

**該当コード:**
```java
String sql = "SELECT * FROM users WHERE name = '" + userName + "'";
```

**問題点:**
ユーザー入力を文字列連結でSQLに埋め込んでおり、SQLインジェクションの危険があります。

**改善案:**
```java
String sql = "SELECT user_id, name FROM users WHERE name = ?";
PreparedStatement ps = conn.prepareStatement(sql);
ps.setString(1, userName);
```

#### 12. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```java
String sql = "SELECT * FROM users WHERE name = '" + userName + "'";
```

**問題点:**
埋め込みSQLでも `SELECT *` は不要列取得の原因になります。

**改善案:**
```java
String sql = "SELECT user_id, name FROM users WHERE name = ?";
PreparedStatement ps = conn.prepareStatement(sql);
ps.setString(1, userName);
```

#### 13. SQL-005 — SQLインジェクション脆弱性（文字列結合によるSQL構築）（high）

**該当コード:**
```python
cursor.execute("SELECT * FROM users WHERE id = " + user_id)
```

**問題点:**
変数を文字列連結で直接SQLに入れており、SQLインジェクション脆弱性があります。

**改善案:**
```python
cursor.execute(
    "SELECT user_id, name FROM users WHERE id = ?",
    (user_id,)
)
```

#### 14. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```python
cursor.execute("SELECT * FROM users WHERE id = " + user_id)
```

**問題点:**
埋め込みSQLでも `SELECT *` は不要な列取得を招きます。

**改善案:**
```python
cursor.execute(
    "SELECT user_id, name FROM users WHERE id = ?",
    (user_id,)
)
```

#### 15. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT * FROM orders WHERE discount = NULL;
```

**問題点:**
不要な列をすべて取得しています。

**改善案:**
```sql
SELECT order_id
FROM orders
WHERE discount IS NULL;
```

#### 16. SQL-006 — NULLの等価比較（medium）

**該当コード:**
```sql
SELECT * FROM orders WHERE discount = NULL;
```

**問題点:**
`= NULL` は SQL の三値論理で常に `UNKNOWN` となり、意図した結果になりません。

**改善案:**
```sql
SELECT order_id
FROM orders
WHERE discount IS NULL;
```

#### 17. SQL-006 — NULLの等価比較（medium）

**該当コード:**
```sql
SELECT order_id
FROM   orders
WHERE  cancelled_date != NULL;
```

**問題点:**
`!= NULL` も無効です。NULL判定には `IS NOT NULL` を使う必要があります。

**改善案:**
```sql
SELECT order_id
FROM orders
WHERE cancelled_date IS NOT NULL;
```

#### 18. SQL-007 — 相関サブクエリのSELECT句使用（medium）

**該当コード:**
```sql
SELECT
    e.employee_id,
    e.name,
    (SELECT d.department_name
     FROM   departments d
     WHERE  d.department_id = e.department_id) AS dept_name,
    (SELECT COUNT(*)
     FROM   order_items oi
     WHERE  oi.assigned_to = e.employee_id) AS item_count
FROM employees e
WHERE e.is_active = 1;
```

**問題点:**
`SELECT` 句内の相関サブクエリがメインクエリの行ごとに評価され、CSV定義のとおり N+1 的な性能劣化を招きます。このSQLでは 2 件の相関サブクエリが含まれています。

**改善案:**
```sql
SELECT
    e.employee_id,
    e.name,
    d.department_name AS dept_name,
    COALESCE(oi.item_count, 0) AS item_count
FROM employees e
LEFT JOIN departments d
       ON d.department_id = e.department_id
LEFT JOIN (
    SELECT assigned_to, COUNT(*) AS item_count
    FROM order_items
    GROUP BY assigned_to
) oi
       ON oi.assigned_to = e.employee_id
WHERE e.is_active = 1;
```

**チェック済みルール数:** 7件  
**チェック対象SQL文数:** 14件


Changes   +0 -0
Requests  1 Premium (1m 34s)
Tokens    ↑ 36.7k • ↓ 6.6k • 31.2k (cached) • 3.3k (reasoning)
