● Read sql-antipatterns.csv
  │ ~/Workspace/sql-review-copilot/rules/sql-antipatterns.csv
  └ 8 lines read

● Read bad_examples.sql
  │ ~/Workspace/SQL_Dir/bad_examples.sql
  └ 103 lines read

## SQLアンチパターン検出結果

| # | ルールID | 深刻度 | パターン名 | 該当箇所（行番号） | 検出内容 |
|---|----------|--------|------------|-------------------|----------|
| 1 | SQL-001 | high | IN句での大量データ外部テーブル参照 | L13-L17 | DELETE文で外部テーブル `external_customers` を `IN (subquery)` で参照 |
| 2 | SQL-001 | high | IN句での大量データ外部テーブル参照 | L20-L26 | SELECT文で外部テーブル `external_master_data` を `IN (subquery)` で参照 |
| 3 | SQL-001 | high | IN句での大量データ外部テーブル参照 | L29-L34 | UPDATE文で外部テーブル `external_archive_targets` を `IN (subquery)` で参照 |
| 4 | SQL-002 | medium | SELECT * の使用 | L40 | `employees` に対して `SELECT *` を使用 |
| 5 | SQL-002 | medium | SELECT * の使用 | L42-L44 | JOINを含む問い合わせで `SELECT *` を使用 |
| 6 | SQL-003 | high | WHERE句なしのDELETE/UPDATE | L50 | `DELETE FROM tmp_batch_work;` が全件削除 |
| 7 | SQL-003 | high | WHERE句なしのDELETE/UPDATE | L52 | `DELETE FROM staging_import_data;` が全件削除 |
| 8 | SQL-004 | medium | 暗黙の型変換によるインデックス無効化 | L59-L61 | `phone_number` を数値リテラル `09012345678` で比較 |
| 9 | SQL-002 | medium | SELECT * の使用 | L63-L65 | `products` に対して `SELECT *` を使用 |
| 10 | SQL-004 | medium | 暗黙の型変換によるインデックス無効化 | L63-L65 | `product_code` を数値リテラル `12345` で比較 |
| 11 | SQL-002 | medium | SELECT * の使用 | L73 | Java埋め込みSQL文字列で `SELECT *` を使用 |
| 12 | SQL-005 | high | SQLインジェクション脆弱性（文字列結合によるSQL構築） | L73-L74 | Java例で `userName` を文字列連結してSQL構築 |
| 13 | SQL-002 | medium | SELECT * の使用 | L77 | Python埋め込みSQL文字列で `SELECT *` を使用 |
| 14 | SQL-005 | high | SQLインジェクション脆弱性（文字列結合によるSQL構築） | L77 | Python例で `user_id` を文字列連結してSQL構築 |
| 15 | SQL-002 | medium | SELECT * の使用 | L83 | `orders` に対して `SELECT *` を使用 |
| 16 | SQL-006 | medium | NULLの等価比較 | L83 | `discount = NULL` を使用 |
| 17 | SQL-006 | medium | NULLの等価比較 | L85-L87 | `cancelled_date != NULL` を使用 |
| 18 | SQL-007 | medium | 相関サブクエリのSELECT句使用 | L93-L103 | SELECT句で相関サブクエリを2箇所使用 |

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
`IN` 句のサブクエリ結果を先に構築してから照合するため、外部テーブルのデータ量増加に伴って性能が劣化します。特にDELETE系バッチでは処理時間悪化が顕著です。

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
外部テーブルを `IN (subquery)` で参照しており、結果セット全体の構築コストが増大します。

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
`IN` による外部テーブル参照で、対象件数増加時にフルスキャン寄りの重い実行計画になりやすいです。

**改善案:**
```sql
UPDATE order_items oi
SET    is_archived = 1
WHERE  EXISTS (
    SELECT 1
    FROM external_archive_targets eat
    WHERE eat.order_id = oi.order_id
);
```

#### 4. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT * FROM employees WHERE department_id = 10;
```

**問題点:**
不要なカラムまで取得し、I/O・メモリ使用量が増えます。テーブル定義変更時の影響も受けやすくなります。

**改善案:**
```sql
SELECT employee_id, name, email
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
JOIN時の `SELECT *` は取得列がさらに増えやすく、転送量とメモリ使用量が大きくなります。

**改善案:**
```sql
SELECT o.order_id, o.order_date, o.total_amount,
       oi.order_item_id, oi.product_id, oi.quantity
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
WHERE句なしのDELETEは全件削除になり、1行ずつ削除ログを書きながら処理するため低速です。

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
全件削除をDELETEで実行しており、性能・安全性の両面でリスクがあります。

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
`phone_number` が文字列型なのに数値リテラルで比較しており、暗黙の型変換でインデックスが使えなくなる恐れがあります。

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
不要列まで取得しており、転送量と保守コストが増えます。

**改善案:**
```sql
SELECT product_id, product_name, product_code
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
`product_code` がVARCHAR想定なのに数値で比較しており、暗黙の型変換が発生します。

**改善案:**
```sql
SELECT product_id, product_name, product_code
FROM products
WHERE product_code = '12345';
```

#### 11. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```java
String sql = "SELECT * FROM users WHERE name = '" + userName + "'";
```

**問題点:**
埋め込みSQLでも `SELECT *` は不要列取得の問題を招きます。

**改善案:**
```java
String sql = "SELECT user_id, name, email FROM users WHERE name = ?";
```

#### 12. SQL-005 — SQLインジェクション脆弱性（文字列結合によるSQL構築）（high）

**該当コード:**
```java
String sql = "SELECT * FROM users WHERE name = '" + userName + "'";
stmt.executeQuery(sql);
```

**問題点:**
ユーザー入力を文字列連結しており、入力がSQL構文として解釈される危険があります。

**改善案:**
```java
String sql = "SELECT user_id, name, email FROM users WHERE name = ?";
PreparedStatement ps = conn.prepareStatement(sql);
ps.setString(1, userName);
ps.executeQuery();
```

#### 13. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```python
cursor.execute("SELECT * FROM users WHERE id = " + user_id)
```

**問題点:**
埋め込みSQLでも `SELECT *` により不要列取得が発生します。

**改善案:**
```python
cursor.execute(
    "SELECT user_id, name, email FROM users WHERE id = %s",
    (user_id,)
)
```

#### 14. SQL-005 — SQLインジェクション脆弱性（文字列結合によるSQL構築）（high）

**該当コード:**
```python
cursor.execute("SELECT * FROM users WHERE id = " + user_id)
```

**問題点:**
`user_id` を文字列結合しており、SQLインジェクション脆弱性があります。プリペアドステートメント相当のパラメータバインドが必要です。

**改善案:**
```python
cursor.execute(
    "SELECT user_id, name, email FROM users WHERE id = %s",
    (user_id,)
)
```

#### 15. SQL-002 — SELECT * の使用（medium）

**該当コード:**
```sql
SELECT * FROM orders WHERE discount = NULL;
```

**問題点:**
不要列取得に加え、意図しない列増加の影響を受けます。

**改善案:**
```sql
SELECT order_id, customer_id, discount
FROM orders
WHERE discount IS NULL;
```

#### 16. SQL-006 — NULLの等価比較（medium）

**該当コード:**
```sql
SELECT * FROM orders WHERE discount = NULL;
```

**問題点:**
`= NULL` はSQLの三値論理上 `UNKNOWN` となり、意図したNULL判定になりません。

**改善案:**
```sql
SELECT order_id, customer_id, discount
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
`!= NULL` も正しく評価されません。NULL比較には `IS NOT NULL` を使う必要があります。

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
SELECT句の相関サブクエリは、メインクエリの各行ごとに実行されやすく、N+1的な性能劣化を招きます。このSQLは相関サブクエリを2箇所含みます。

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
Requests  1 Premium (1m 11s)
Tokens    ↑ 36.3k • ↓ 5.0k • 31.0k (cached) • 1.7k (reasoning)
