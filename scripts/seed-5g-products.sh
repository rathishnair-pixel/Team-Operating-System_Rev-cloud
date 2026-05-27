#!/bin/bash
# DevOps: Seed 5G Smart Office products into target org via SFDMU.
# Run BEFORE deploying FTR-004/005/006 metadata — products must exist first.
# Usage: ./scripts/seed-5g-products.sh [--target-org <alias>]
# Default target org alias: rc-dev
# RCA Data Reality (SOUL DevOps note): Products are DATA not metadata.
# Standard SFDX deploy will NOT create them — this script is mandatory.

set -euo pipefail

TARGET_ORG="${1:-rc-dev}"
SEED_DIR="$(dirname "$0")/../data/seed-5g-products"

echo ""
echo "=============================================="
echo " Team OS — 5G Smart Office Product Seeder"
echo " Target org: $TARGET_ORG"
echo "=============================================="
echo ""

# 1. Verify SFDMU is installed
if ! sf plugins inspect sfdmu > /dev/null 2>&1; then
  echo "[ERROR] SFDMU plugin not installed."
  echo "        Run: sf plugins install sfdmu"
  exit 1
fi
echo "[1/5] SFDMU plugin verified."

# 2. Verify org connection
if ! sf org display --target-org "$TARGET_ORG" > /dev/null 2>&1; then
  echo "[ERROR] Cannot connect to org '$TARGET_ORG'."
  echo "        Run: sf org login web --alias $TARGET_ORG"
  exit 1
fi
echo "[2/5] Org connection verified: $TARGET_ORG"

# 3. Verify Standard Pricebook exists
PB_COUNT=$(sf data query \
  --target-org "$TARGET_ORG" \
  --query "SELECT COUNT() FROM Pricebook2 WHERE IsStandard = true" \
  --result-format csv 2>/dev/null | tail -1)
if [[ "$PB_COUNT" -lt 1 ]]; then
  echo "[ERROR] Standard Pricebook not found. Activate it before seeding."
  exit 1
fi
echo "[3/5] Standard Pricebook present."

# 4. Run SFDMU upsert — Products first, then PricebookEntries
echo "[4/5] Seeding Product2 records..."
sf sfdmu run --target-org "$TARGET_ORG" \
  --sourceusername csvfile \
  --path "$SEED_DIR" \
  2>&1 | grep -E "(Upsert|Error|Success|Warning|Rows)"

# 5. Verify all 4 SKUs are present
echo "[5/5] Verifying seeded products..."
PRODUCT_COUNT=$(sf data query \
  --target-org "$TARGET_ORG" \
  --query "SELECT COUNT() FROM Product2 WHERE ProductCode IN ('EDGE_5G_ROUTER','UNLIMITED_5G_DATA','FIBER_INSTALL','TELCO_PLATINUM_SLA') AND IsActive = true" \
  --result-format csv 2>/dev/null | tail -1)

if [[ "$PRODUCT_COUNT" -lt 4 ]]; then
  echo "[FAIL] Only $PRODUCT_COUNT of 4 expected products found. Check SFDMU output above."
  exit 1
fi

echo ""
echo "=============================================="
echo " [PASS] All 4 5G Smart Office SKUs seeded."
echo " DEP-005 and DEP-008 are now RESOLVED."
echo " You may now deploy FTR-004/005/006 metadata."
echo "=============================================="
echo ""
