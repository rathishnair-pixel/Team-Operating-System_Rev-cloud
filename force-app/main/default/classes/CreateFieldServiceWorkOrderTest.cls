@IsTest
private class CreateFieldServiceWorkOrderTest {

    // ── Happy Path: single site, all fields populated ──
    @IsTest
    static void testCreateSingleWorkOrder() {
        Account acc = new Account(Name = 'FSL Test Account');
        insert acc;

        CreateFieldServiceWorkOrder.WorkOrderRequest req = new CreateFieldServiceWorkOrder.WorkOrderRequest();
        req.orderId      = 'MOCK_ORDER_001';
        req.orderItemId  = 'MOCK_ITEM_001';
        req.siteAddress  = '10 Tech Park, Sydney NSW 2000';
        req.fiberMeters  = 250;
        req.siteId       = 'SITE-SYD-001';
        req.accountId    = acc.Id;

        Test.startTest();
        List<CreateFieldServiceWorkOrder.WorkOrderResult> results =
            CreateFieldServiceWorkOrder.create(
                new List<CreateFieldServiceWorkOrder.WorkOrderRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success, 'Expected success for valid Work Order request');
        System.assertNotEquals(null, results[0].workOrderId, 'Expected workOrderId to be populated');
        System.assertEquals(null, results[0].errorMessage, 'Expected no error message on success');

        WorkOrder wo = [SELECT Subject, Fiber_Meters__c, SlaExitDate, SlaStartDate FROM WorkOrder WHERE Id = :results[0].workOrderId];
        System.assert(wo.Subject.contains('SITE-SYD-001'), 'Work Order subject should contain site ID');
        System.assertEquals(250, wo.Fiber_Meters__c, 'Fiber_Meters__c should be copied from request');
        System.assertEquals(wo.SlaStartDate.addHours(24), wo.SlaExitDate, 'SLA window must be exactly 24 hours');
    }

    // ── Bulk: 50 sites — partial success mode, all valid ──
    @IsTest
    static void testBulkWorkOrderCreation() {
        Account acc = new Account(Name = 'Bulk FSL Account');
        insert acc;

        List<CreateFieldServiceWorkOrder.WorkOrderRequest> requests = new List<CreateFieldServiceWorkOrder.WorkOrderRequest>();
        for (Integer i = 0; i < 50; i++) {
            CreateFieldServiceWorkOrder.WorkOrderRequest req = new CreateFieldServiceWorkOrder.WorkOrderRequest();
            req.orderId     = 'MOCK_ORDER_BULK';
            req.orderItemId = 'MOCK_ITEM_' + i;
            req.siteAddress = 'Site ' + i + ', Melbourne VIC 3000';
            req.fiberMeters = 100 + (i * 10);
            req.siteId      = 'SITE-MEL-' + String.valueOf(i).leftPad(3, '0');
            req.accountId   = acc.Id;
            requests.add(req);
        }

        Test.startTest();
        List<CreateFieldServiceWorkOrder.WorkOrderResult> results = CreateFieldServiceWorkOrder.create(requests);
        Test.stopTest();

        System.assertEquals(50, results.size(), 'Expected 50 results');
        Integer successCount = 0;
        for (CreateFieldServiceWorkOrder.WorkOrderResult res : results) {
            if (res.success) successCount++;
        }
        System.assertEquals(50, successCount, 'All 50 Work Orders should succeed');
    }

    // ── SLA window: verify start and exit times are exactly 24h apart ──
    @IsTest
    static void testSlaWindowIs24Hours() {
        Account acc = new Account(Name = 'SLA Test Account');
        insert acc;

        CreateFieldServiceWorkOrder.WorkOrderRequest req = new CreateFieldServiceWorkOrder.WorkOrderRequest();
        req.orderId     = 'MOCK_ORDER_SLA';
        req.orderItemId = 'MOCK_ITEM_SLA';
        req.siteAddress = '99 George St, Brisbane QLD 4000';
        req.fiberMeters = 150;
        req.siteId      = 'SITE-BNE-001';
        req.accountId   = acc.Id;

        Datetime beforeInsert = System.now();

        Test.startTest();
        List<CreateFieldServiceWorkOrder.WorkOrderResult> results =
            CreateFieldServiceWorkOrder.create(
                new List<CreateFieldServiceWorkOrder.WorkOrderRequest>{ req }
            );
        Test.stopTest();

        WorkOrder wo = [SELECT SlaStartDate, SlaExitDate FROM WorkOrder WHERE Id = :results[0].workOrderId];
        Long diffMillis = wo.SlaStartDate.getTime() - beforeInsert.getTime();
        System.assert(diffMillis >= 0, 'SlaStartDate must be at or after test execution start');
        System.assertEquals(wo.SlaStartDate.addHours(24), wo.SlaExitDate, 'SlaExitDate must be exactly SlaStartDate + 24h');
    }

    // ── Partial failure: invalid accountId on one record ──
    @IsTest
    static void testPartialSuccessOnBadRecord() {
        Account acc = new Account(Name = 'Partial Success Account');
        insert acc;

        CreateFieldServiceWorkOrder.WorkOrderRequest good = new CreateFieldServiceWorkOrder.WorkOrderRequest();
        good.orderId     = 'MOCK_ORDER_GOOD';
        good.orderItemId = 'MOCK_ITEM_GOOD';
        good.siteAddress = '1 Valid St, Sydney NSW 2000';
        good.fiberMeters = 100;
        good.siteId      = 'SITE-GOOD-001';
        good.accountId   = acc.Id;

        CreateFieldServiceWorkOrder.WorkOrderRequest bad = new CreateFieldServiceWorkOrder.WorkOrderRequest();
        bad.orderId     = 'MOCK_ORDER_BAD';
        bad.orderItemId = 'MOCK_ITEM_BAD';
        bad.siteAddress = '2 Invalid St';
        bad.fiberMeters = 100;
        bad.siteId      = 'SITE-BAD-001';
        bad.accountId   = 'INVALID_ACCOUNT_ID'; // will fail insert

        Test.startTest();
        List<CreateFieldServiceWorkOrder.WorkOrderResult> results =
            CreateFieldServiceWorkOrder.create(
                new List<CreateFieldServiceWorkOrder.WorkOrderRequest>{ good, bad }
            );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Expected 2 results for 2 requests');
        System.assertEquals(true,  results[0].success, 'First record should succeed');
        System.assertEquals(false, results[1].success, 'Second record should fail with invalid accountId');
        System.assertNotEquals(null, results[1].errorMessage, 'Error message should be populated for failed record');
    }
}
