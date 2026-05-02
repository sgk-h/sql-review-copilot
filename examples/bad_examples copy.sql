-- =============================================================
-- bad_examples.sql - SQLアンチパターンのサンプル集
-- sql-check.prompt.md の動作確認用
-- =============================================================

-- -------------------------------------------------------------
-- SQL-001: IN句での大量データ外部テーブル参照
-- 外部テーブル(external_customers)のデータ量が増加するにつれて
-- フルテーブルスキャンが発生し、処理時間が劣化する
-- -------------------------------------------------------------

-- ケース1: DELETE文でEXISTSを使用
DELETE FROM orders o
WHERE EXISTS (
    SELECT 1
    FROM external_customers ec
    WHERE ec.customer_id = o.customer_id
);  -- Fixed: SQL-001

-- ケース2: SELECT文でEXISTSを使用（EXPORT想定）
SELECT order_id, order_date, total_amount
FROM orders o
WHERE EXISTS (
    SELECT 1
    FROM external_master_data emd
    WHERE emd.customer_id = o.customer_id
    AND   emd.status = 'active'
);  -- Fixed: SQL-001

-- ケース3: UPDATE文でEXISTSを使用
UPDATE order_items oi
SET    is_archived = 1
WHERE  EXISTS (
    SELECT 1
    FROM   external_archive_targets eat
    WHERE  eat.order_id = oi.order_id
);  -- Fixed: SQL-001

-- -------------------------------------------------------------
-- SQL-002: SELECT * の使用
-- -------------------------------------------------------------

SELECT employee_id, name, email
FROM   employees
WHERE  department_id = 10;  -- Fixed: SQL-002

SELECT o.order_id, o.order_date, o.total_amount,
       oi.item_name, oi.quantity, oi.unit_price
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_date >= '2026-01-01';  -- Fixed: SQL-002

-- -------------------------------------------------------------
-- SQL-003: WHERE句なしのDELETE
-- -------------------------------------------------------------

TRUNCATE TABLE tmp_batch_work;  -- Fixed: SQL-003

TRUNCATE TABLE staging_import_data;  -- Fixed: SQL-003

-- -------------------------------------------------------------
-- SQL-004: 暗黙の型変換
-- phone_numberはVARCHAR型だが数値リテラルで比較
-- -------------------------------------------------------------

SELECT employee_id, name
FROM   employees
WHERE  phone_number = '09012345678';  -- Fixed: SQL-004

SELECT *
FROM   products
WHERE  product_code = '12345';  -- Fixed: SQL-004

-- -------------------------------------------------------------
-- SQL-005: SQLインジェクション脆弱性（埋め込みSQL想定）
-- 以下はJava/Pythonコード内でのSQL構築パターン
-- -------------------------------------------------------------

-- Javaでの例（コメントとして記載）:
-- PreparedStatement pstmt = conn.prepareStatement(
--     "SELECT * FROM users WHERE name = ?"
-- );
-- pstmt.setString(1, userName);  -- Fixed: SQL-005

-- Pythonでの例:
-- cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))  -- Fixed: SQL-005

-- -------------------------------------------------------------
-- SQL-006: NULLの等価比較
-- -------------------------------------------------------------

SELECT * FROM orders WHERE discount IS NULL;  -- Fixed: SQL-006

SELECT order_id
FROM   orders
WHERE  cancelled_date IS NOT NULL;  -- Fixed: SQL-006

-- -------------------------------------------------------------
-- SQL-007: 相関サブクエリのSELECT句使用
-- -------------------------------------------------------------

SELECT
    e.employee_id,
    e.name,
    d.department_name AS dept_name,
    COUNT(oi.item_id) AS item_count
FROM   employees e
LEFT JOIN departments d
    ON d.department_id = e.department_id
LEFT JOIN order_items oi
    ON oi.assigned_to = e.employee_id
WHERE  e.is_active = 1
GROUP BY e.employee_id, e.name, d.department_name;  -- Fixed: SQL-007
