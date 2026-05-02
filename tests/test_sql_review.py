"""
sql-review-copilot テストスイート

検証項目:
  1. CSVファイルの整合性（パース・必須カラム・値の妥当性）
  2. .prompt.md フロントマターのYAML構文
  3. プロンプトからCSVへの相対パス参照の正当性
  4. サンプルSQL（bad_examples.sql）に全ルールIDの該当パターンが存在するか
  5. サンプルSQL（good_examples.sql）にアンチパターンが含まれないか（基本検証）
"""

import csv
import os
import re
import sys
from pathlib import Path

# プロジェクトルート（tests/ の親ディレクトリ）
ROOT = Path(__file__).resolve().parent.parent

RULES_CSV = ROOT / "rules" / "sql-antipatterns.csv"
PROMPT_CHECK = ROOT / ".github" / "prompts" / "sql-check.prompt.md"
PROMPT_FIX = ROOT / ".github" / "prompts" / "sql-fix.prompt.md"
BAD_SQL = ROOT / "examples" / "bad_examples.sql"
GOOD_SQL = ROOT / "examples" / "good_examples.sql"

REQUIRED_COLUMNS = ["id", "category", "severity", "name", "description",
                     "bad_example", "good_example", "explanation"]
VALID_CATEGORIES = {"performance", "security", "correctness"}
VALID_SEVERITIES = {"high", "medium", "low"}

passed = 0
failed = 0


def ok(msg: str):
    global passed
    passed += 1
    print(f"  ✅ PASS: {msg}")


def ng(msg: str):
    global failed
    failed += 1
    print(f"  ❌ FAIL: {msg}")


# =========================================================
# テスト1: 必要なファイルがすべて存在するか
# =========================================================
print("\n[Test 1] ファイル存在チェック")

for label, path in [
    ("rules/sql-antipatterns.csv", RULES_CSV),
    (".github/prompts/sql-check.prompt.md", PROMPT_CHECK),
    (".github/prompts/sql-fix.prompt.md", PROMPT_FIX),
    ("examples/bad_examples.sql", BAD_SQL),
    ("examples/good_examples.sql", GOOD_SQL),
]:
    if path.exists():
        ok(f"{label} が存在する")
    else:
        ng(f"{label} が見つからない")

# =========================================================
# テスト2: CSVの整合性
# =========================================================
print("\n[Test 2] CSV整合性チェック")

rows = []
try:
    with open(RULES_CSV, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames or []

        # 2-1: 必須カラムの存在
        missing_cols = [c for c in REQUIRED_COLUMNS if c not in headers]
        if not missing_cols:
            ok(f"必須カラムがすべて存在する: {REQUIRED_COLUMNS}")
        else:
            ng(f"カラム不足: {missing_cols}")

        # 2-2: 各行の検証
        for i, row in enumerate(reader, start=2):
            rows.append(row)

            # ID形式
            if re.match(r"^SQL-\d{3}$", row.get("id", "")):
                ok(f"行{i}: ID形式が正しい ({row['id']})")
            else:
                ng(f"行{i}: ID形式が不正 ({row.get('id', '(空)')})")

            # カテゴリ
            cat = row.get("category", "")
            if cat in VALID_CATEGORIES:
                ok(f"行{i}: category が有効値 ({cat})")
            else:
                ng(f"行{i}: category が無効 ({cat}) — 有効値: {VALID_CATEGORIES}")

            # 深刻度
            sev = row.get("severity", "")
            if sev in VALID_SEVERITIES:
                ok(f"行{i}: severity が有効値 ({sev})")
            else:
                ng(f"行{i}: severity が無効 ({sev}) — 有効値: {VALID_SEVERITIES}")

            # 空フィールドチェック
            empty_fields = [c for c in REQUIRED_COLUMNS if not row.get(c, "").strip()]
            if not empty_fields:
                ok(f"行{i}: 全必須フィールドに値が存在する")
            else:
                ng(f"行{i}: 空のフィールド: {empty_fields}")

    # 2-3: IDの一意性
    ids = [r["id"] for r in rows]
    if len(ids) == len(set(ids)):
        ok(f"IDが一意 ({len(ids)}件)")
    else:
        dupes = [x for x in ids if ids.count(x) > 1]
        ng(f"IDに重複あり: {set(dupes)}")

    # 2-4: IDの連番確認
    expected_ids = [f"SQL-{str(i).zfill(3)}" for i in range(1, len(rows) + 1)]
    if ids == expected_ids:
        ok(f"IDが連番 (SQL-001 ~ SQL-{str(len(rows)).zfill(3)})")
    else:
        ng(f"IDが連番でない: 期待={expected_ids}, 実際={ids}")

except Exception as e:
    ng(f"CSVの読み込みに失敗: {e}")

# =========================================================
# テスト3: .prompt.md フロントマター検証
# =========================================================
print("\n[Test 3] プロンプトファイルのフロントマター検証")

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)

for label, path in [
    ("sql-check.prompt.md", PROMPT_CHECK),
    ("sql-fix.prompt.md", PROMPT_FIX),
]:
    content = path.read_text(encoding="utf-8")

    # 3-1: フロントマター存在
    m = FRONTMATTER_RE.match(content)
    if m:
        ok(f"{label}: フロントマターが存在する")
        fm = m.group(1)

        # 3-2: description フィールド
        if "description:" in fm:
            ok(f"{label}: description フィールドあり")
        else:
            ng(f"{label}: description フィールドなし")

        # 3-3: agent フィールド
        if "agent:" in fm:
            ok(f"{label}: agent フィールドあり")
        else:
            ng(f"{label}: agent フィールドなし")

        # 3-4: tools フィールド
        if "tools:" in fm:
            ok(f"{label}: tools フィールドあり")
        else:
            ng(f"{label}: tools フィールドなし（任意）")

    else:
        ng(f"{label}: フロントマターが見つからない")

# =========================================================
# テスト4: プロンプト内のCSV参照パスの検証
# =========================================================
print("\n[Test 4] プロンプト → CSV 相対パス参照の検証")

LINK_RE = re.compile(r"\[.*?\]\((.*?)\)")

for label, path in [
    ("sql-check.prompt.md", PROMPT_CHECK),
    ("sql-fix.prompt.md", PROMPT_FIX),
]:
    content = path.read_text(encoding="utf-8")
    links = LINK_RE.findall(content)
    csv_links = [l for l in links if l.endswith(".csv")]

    if not csv_links:
        ng(f"{label}: CSVへのリンクが見つからない")
        continue

    for link in csv_links:
        resolved = (path.parent / link).resolve()
        if resolved.exists():
            ok(f"{label}: CSVリンク '{link}' → {resolved.name} が存在する")
        else:
            ng(f"{label}: CSVリンク '{link}' → {resolved} が存在しない")

# =========================================================
# テスト5: bad_examples.sql に各ルールIDのパターンが含まれるか
# =========================================================
print("\n[Test 5] bad_examples.sql のルールカバレッジ")

bad_content = BAD_SQL.read_text(encoding="utf-8")

# 各ルールIDのコメントがサンプルに含まれるか
rule_ids = [r["id"] for r in rows]
for rid in rule_ids:
    if rid in bad_content:
        ok(f"bad_examples.sql に {rid} のサンプルが含まれる")
    else:
        ng(f"bad_examples.sql に {rid} のサンプルが見つからない")

# ルール固有のパターンが実際にSQL文として存在するか
PATTERN_CHECKS = {
    "SQL-001": r"\bIN\s*\(\s*SELECT\b",
    "SQL-002": r"\bSELECT\s+\*",
    "SQL-003": r"\bDELETE\s+FROM\s+\w+\s*;",  # WHERE句なしDELETE
    "SQL-004": r"\bphone_number\s*=\s*\d",      # 文字列カラムに数値
    "SQL-006": r"=\s*NULL|!=\s*NULL",
    "SQL-007": r"\(\s*SELECT\b.*?\bFROM\b.*?\bWHERE\b.*?\.\w+\s*=\s*\w+\.\w+\s*\)",
}

for rid, pattern in PATTERN_CHECKS.items():
    if re.search(pattern, bad_content, re.IGNORECASE | re.DOTALL):
        ok(f"bad_examples.sql に {rid} の実SQLパターンが存在する")
    else:
        ng(f"bad_examples.sql に {rid} の実SQLパターンが検出できない")

# =========================================================
# テスト6: good_examples.sql の基本検証
# =========================================================
print("\n[Test 6] good_examples.sql アンチパターン不在チェック")

good_content = GOOD_SQL.read_text(encoding="utf-8")

# IN句サブクエリが存在しないこと
if not re.search(r"\bIN\s*\(\s*SELECT\b", good_content, re.IGNORECASE):
    ok("good_examples.sql に IN (SELECT ...) が含まれない")
else:
    ng("good_examples.sql に IN (SELECT ...) が含まれている")

# = NULL が存在しないこと
if not re.search(r"(?<!\bIS\s)=\s*NULL", good_content, re.IGNORECASE):
    ok("good_examples.sql に '= NULL' が含まれない")
else:
    ng("good_examples.sql に '= NULL' が含まれている")

# WHERE句なしDELETE が存在しないこと（TRUNCATEは許可）
delete_stmts = re.findall(r"\bDELETE\s+FROM\s+\w+\s*(?:WHERE\b|;)", good_content, re.IGNORECASE)
bare_deletes = [s for s in delete_stmts if "WHERE" not in s.upper()]
# good_examples.sql はTRUNCATEに書き換え済み、またはWHERE付きDELETEのはず
if not bare_deletes:
    ok("good_examples.sql にWHERE句なしDELETEが含まれない")
else:
    ng(f"good_examples.sql にWHERE句なしDELETEが存在する: {bare_deletes}")

# EXISTS パターンが存在すること（SQL-001の改善として）
if re.search(r"\bEXISTS\s*\(", good_content, re.IGNORECASE):
    ok("good_examples.sql に EXISTS パターンが含まれる（SQL-001改善）")
else:
    ng("good_examples.sql に EXISTS パターンが見つからない")

# IS NULL が存在すること（SQL-006の改善として）
if re.search(r"\bIS\s+NULL\b", good_content, re.IGNORECASE):
    ok("good_examples.sql に IS NULL が含まれる（SQL-006改善）")
else:
    ng("good_examples.sql に IS NULL が見つからない")

# LEFT JOIN が存在すること（SQL-007の改善として）
if re.search(r"\bLEFT\s+JOIN\b", good_content, re.IGNORECASE):
    ok("good_examples.sql に LEFT JOIN が含まれる（SQL-007改善）")
else:
    ng("good_examples.sql に LEFT JOIN が見つからない")

# =========================================================
# 結果サマリ
# =========================================================
print("\n" + "=" * 60)
print(f"結果: {passed} passed / {failed} failed / {passed + failed} total")
print("=" * 60)

sys.exit(1 if failed > 0 else 0)
