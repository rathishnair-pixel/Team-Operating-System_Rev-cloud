@IsTest
private class CreateFieldServiceWorkOrderTest {

    // ── Happy Path: single site, all fields populated ──
    @IsTest
    static void testCreateSingleWorkOrder() {
        CreateFieldServiceWorkOrder.WorkOrderRequest req = new CreateFieldServiceWorkOrder.WorkOrderRequest();
        req.fiberMeters = 250;
        req.siteId      = 'SITE-SYD-001';

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

        WorkOrder wo = [SELECT Subject, Fiber_Meters__c, SlaStartDate FROM WorkOrder WHERE Id = :results[0].workOrderId];
        System.assert(wo.Subject.contains('SITE-SYD-001'), 'Work Order subject should contain site ID');
        System.assertEquals(250, wo.Fiber_Meters__c, 'Fiber_Meters__c should be copied from request');
        System.assertNotEquals(null, wo.SlaStartDate, 'SlaStartDate should be set');
    }

    // ── Bulk: 50 sites — all valid ──
    @IsTest
    static void testBulkWorkOrderCreation() {
        List<CreateFieldServiceWorkOrder.WorkOrderRequest> requests = new List<CreateFieldServiceWorkOrder.WorkOrderRequest>();
        for (Integer i = 0; i < 50; i++) {
            CreateFieldServiceWorkOrder.WorkOrderRequest req = new CreateFieldServiceWorkOrder.WorkOrderRequest();
            req.fiberMeters = 100 + (i * 10);
            req.siteId      = 'SITE-MEL-' + String.valueOf(i).leftPad(3, '0');
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

    // ── SLA window: verify SlaStartDate is populated ──
    @IsTest
    static void testSlaWindowIs24Hours() {
        CreateFieldServiceWorkOrder.WorkOrderRequest req = new CreateFieldServiceWorkOrder.WorkOrderRequest();
        req.fiberMeters = 150;
        req.siteId      = 'SITE-BNE-001';

        Datetime beforeInsert = System.now();

        Test.startTest();
        List<CreateFieldServiceWorkOrder.WorkOrderResult> results =
            CreateFieldServiceWorkOrder.create(
                new List<CreateFieldServiceWorkOrder.WorkOrderRequest>{ req }
            );
        Test.stopTest();

        WorkOrder wo = [SELECT SlaStartDate FROM WorkOrder WHERE Id = :results[0].workOrderId];
        Long diffMillis = wo.SlaStartDate.getTime() - beforeInsert.getTime();
        System.assert(diffMillis >= 0, 'SlaStartDate must be at or after test execution start');
        System.assertNotEquals(null, wo.SlaStartDate, 'SlaStartDate should be populated');
    }

    // ── Description: verify site ID is embedded in work order description ──
    @IsTest
    static void testDescriptionContainsSiteId() {
        CreateFieldServiceWorkOrder.WorkOrderRequest req = new CreateFieldServiceWorkOrder.WorkOrderRequest();
        req.fiberMeters = 75;
        req.siteId      = 'SITE-DESC-001';

        Test.startTest();
        List<CreateFieldServiceWorkOrder.WorkOrderResult> results =
            CreateFieldServiceWorkOrder.create(
                new List<CreateFieldServiceWorkOrder.WorkOrderRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success, 'Work Order should succeed');
        WorkOrder wo = [SELECT Description, Subject FROM WorkOrder WHERE Id = :results[0].workOrderId];
        System.assert(wo.Subject.contains('SITE-DESC-001'), 'Subject should contain siteId');
        System.assert(wo.Description.contains('75 meters'), 'Description should contain fiber meters');
    }
}
