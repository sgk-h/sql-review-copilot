-- =============================================================
-- good_examples.sql - 改善されたSQLのサンプル集
-- 各アンチパターンに対する正しい書き方
-- =============================================================

-- -------------------------------------------------------------
-- SQL-001: EXISTS を使用（IN句の改善）
-- マッチ時点でスキャンが停止するため高速
-- -------------------------------------------------------------

-- ケース1: DELETE文でEXISTS使用
DELETE FROM orders o
WHERE EXISTS (
    SELECT 1
    FROM   external_customers ec
    WHERE  ec.customer_id = o.customer_id
);

-- ケース2: SELECT文でEXISTS使用
SELECT order_id, order_date, total_amount
FROM   orders o
WHERE  EXISTS (
    SELECT 1
    FROM   external_master_data emd
    WHERE  emd.customer_id = o.customer_id
    AND    emd.status = 'active'
);

-- ケース3: UPDATE文でEXISTS使用
UPDATE order_items oi
SET    is_archived = 1
WHERE  EXISTS (
    SELECT 1
    FROM   external_archive_targets eat
    WHERE  eat.order_id = oi.order_id
);

-- -------------------------------------------------------------
-- SQL-002: 必要なカラムのみを明示的に指定
-- -------------------------------------------------------------

SELECT employee_id, name, email
FROM   employees
WHERE  department_id = 10;

SELECT o.order_id, o.order_date, o.total_amount,
       oi.item_name, oi.quantity, oi.unit_price
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_date >= '2026-01-01';

-- -------------------------------------------------------------
-- SQL-003: TRUNCATE（全行削除の場合）またはWHERE句付きDELETE
-- -------------------------------------------------------------

TRUNCATE TABLE tmp_batch_work;

DELETE FROM staging_import_data
WHERE  import_date < '2026-01-01';

-- -------------------------------------------------------------
-- SQL-004: 型を一致させてインデックスを活用
-- -------------------------------------------------------------

SELECT employee_id, name
FROM   employees
WHERE  phone_number = '09012345678';

SELECT product_id, product_name
FROM   products
WHERE  product_code = '12345';

-- -------------------------------------------------------------
-- SQL-005: パラメータバインドを使用
-- （コード内でのプリペアドステートメント例）
-- -------------------------------------------------------------

-- Java:
-- PreparedStatement pstmt = conn.prepareStatement(
--     "SELECT * FROM users WHERE name = ?"
-- );
-- pstmt.setString(1, userName);

-- Python:
-- cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

-- -------------------------------------------------------------
-- SQL-006: IS NULL / IS NOT NULL を使用
-- -------------------------------------------------------------

SELECT * FROM orders WHERE discount IS NULL;

SELECT order_id
FROM   orders
WHERE  cancelled_date IS NOT NULL;

-- -------------------------------------------------------------
-- SQL-007: JOINに書き換え
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
GROUP BY e.employee_id, e.name, d.department_name;
