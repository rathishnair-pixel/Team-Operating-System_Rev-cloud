#!/usr/bin/env bash
# DevOps Pre-Flight Checks — 5G Smart Office (FTR-004/005/006)
# Run once before build starts. Requires: sf CLI authenticated to target org.
# Usage: bash scripts/devops-preflight-5g.sh

ORG_ALIAS="rc-dev"

echo ""
echo "============================================================"
echo " Team OS — 5G Smart Office Pre-Flight Checks"
echo " Org: $ORG_ALIAS"
echo "============================================================"

echo ""
echo "── CHECK 1: Org Edition & Features ──────────────────────"
sf org display --target-org $ORG_ALIAS

echo ""
echo "── CHECK 2: Flow Orchestration feature flag ─────────────"
sf data query \
  --query "SELECT Id, Name FROM PermissionSet WHERE Name LIKE '%FlowOrchestration%' LIMIT 5" \
  --target-org $ORG_ALIAS
echo "Expected: At least one FlowOrchestration PermissionSet returned"
echo "If empty: Feature not enabled — raise case with Salesforce to enable Flow Orchestration"

echo ""
echo "── CHECK 3: BusinessHours record ────────────────────────"
sf data query \
  --query "SELECT Id, Name, IsActive, IsDefault FROM BusinessHours LIMIT 10" \
  --target-org $ORG_ALIAS
echo "Expected: At least one IsActive=true, IsDefault=true record"
echo "If empty: Create BusinessHours in Setup > Business Hours before US-FTR005-002b build"

echo ""
echo "── CHECK 4: Field Service Lightning (FSL) license ───────"
sf data query \
  --query "SELECT Id, Name FROM PermissionSet WHERE Name LIKE '%FieldService%' LIMIT 10" \
  --target-org $ORG_ALIAS
echo "Expected: FieldServiceStandardUser or FieldServiceAdmin PermissionSet returned"
echo "If empty: FSL not licensed — raise with Salesforce licensing team before FTR-006 build"

echo ""
echo "── CHECK 5: FTR-004 Product records in org ──────────────"
sf data query \
  --query "SELECT Id, Name, ProductCode, IsActive FROM Product2 WHERE ProductCode IN ('ROUTER_5G_ENT','DATA_PLAN_5G','FIBER_INSTALL','SLA_PLATINUM') ORDER BY ProductCode" \
  --target-org $ORG_ALIAS
echo "Expected: 4 rows returned. If missing — run FTR-004 product seeding script first"

echo ""
echo "── CHECK 6: Standard Pricebook exists ───────────────────"
sf data query \
  --query "SELECT Id, Name, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1" \
  --target-org $ORG_ALIAS
echo "Expected: 1 active Standard Pricebook row"

echo ""
echo "── CHECK 7: Platform Events deployed ────────────────────"
sf data query \
  --query "SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName = 'Hardware_Fulfillment__e' LIMIT 1" \
  --target-org $ORG_ALIAS
echo "Expected: 1 row. If empty — deploy Hardware_Fulfillment__e metadata before FTR-006 build"

echo ""
echo "── CHECK 8: Custom fields on Asset ─────────────────────"
sf data query \
  --query "SELECT QualifiedApiName FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = 'Asset' AND QualifiedApiName IN ('Network_Activation_Status__c','IMEI_Scanned__c','Activated_DateTime__c') ORDER BY QualifiedApiName" \
  --target-org $ORG_ALIAS
echo "Expected: 3 rows. If missing — deploy Asset custom fields before FTR-006 Track 2 build"

echo ""
echo "── CHECK 9: Named Credential for Telco Network Controller"
sf data query \
  --query "SELECT DeveloperName, Endpoint, PrincipalType FROM NamedCredential WHERE DeveloperName = 'Telco_Network_Controller' LIMIT 1" \
  --target-org $ORG_ALIAS
echo "Expected: 1 row. If missing — provision Named Credential before Track 2 Queueable build"

echo ""
echo "── CHECK 10: Existing Flows on Quote object (>3 = audit) "
sf data query \
  --query "SELECT Id, MasterLabel, ProcessType, Status FROM Flow WHERE ProcessType IN ('AutoLaunchedFlow','RecordTriggeredFlow') AND Status = 'Active'" \
  --target-org $ORG_ALIAS
echo "WARNING: If more than 3 active Flows on Quote → full automation audit required (HIGH-LEVEL.md)"

echo ""
echo "============================================================"
echo " Pre-Flight Complete — review output above before build"
echo "============================================================"
