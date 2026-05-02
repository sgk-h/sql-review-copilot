-- =============================================================
-- bad_examples.sql - SQLアンチパターンのサンプル集
-- sql-check.prompt.md の動作確認用
-- =============================================================

-- -------------------------------------------------------------
-- SQL-001: IN句での大量データ外部テーブル参照
-- 外部テーブル(external_customers)のデータ量が増加するにつれて
-- フルテーブルスキャンが発生し、処理時間が劣化する
-- -------------------------------------------------------------

-- ケース1: DELETE文でIN句を使用
DELETE FROM orders
WHERE customer_id IN (
    SELECT customer_id
    FROM external_customers
);

-- ケース2: SELECT文でIN句を使用（EXPORT想定）
SELECT order_id, order_date, total_amount
FROM orders
WHERE customer_id IN (
    SELECT customer_id
    FROM external_master_data
    WHERE status = 'active'
);

-- ケース3: UPDATE文でIN句を使用
UPDATE order_items
SET    is_archived = 1
WHERE  order_id IN (
    SELECT order_id
    FROM   external_archive_targets
);

-- -------------------------------------------------------------
-- SQL-002: SELECT * の使用
-- -------------------------------------------------------------

SELECT * FROM employees WHERE department_id = 10;

SELECT * FROM orders o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_date >= '2026-01-01';

-- -------------------------------------------------------------
-- SQL-003: WHERE句なしのDELETE
-- -------------------------------------------------------------

DELETE FROM tmp_batch_work;

DELETE FROM staging_import_data;

-- -------------------------------------------------------------
-- SQL-004: 暗黙の型変換
-- phone_numberはVARCHAR型だが数値リテラルで比較
-- -------------------------------------------------------------

SELECT employee_id, name
FROM   employees
WHERE  phone_number = 09012345678;

SELECT *
FROM   products
WHERE  product_code = 12345;  -- product_code は VARCHAR(10)

-- -------------------------------------------------------------
-- SQL-005: SQLインジェクション脆弱性（埋め込みSQL想定）
-- 以下はJava/Pythonコード内でのSQL構築パターン
-- -------------------------------------------------------------

-- Javaでの例（コメントとして記載）:
-- String sql = "SELECT * FROM users WHERE name = '" + userName + "'";
-- stmt.executeQuery(sql);

-- Pythonでの例:
-- cursor.execute("SELECT * FROM users WHERE id = " + user_id)

-- -------------------------------------------------------------
-- SQL-006: NULLの等価比較
-- -------------------------------------------------------------

SELECT * FROM orders WHERE discount = NULL;

SELECT order_id
FROM   orders
WHERE  cancelled_date != NULL;

-- -------------------------------------------------------------
-- SQL-007: 相関サブクエリのSELECT句使用
-- -------------------------------------------------------------

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
