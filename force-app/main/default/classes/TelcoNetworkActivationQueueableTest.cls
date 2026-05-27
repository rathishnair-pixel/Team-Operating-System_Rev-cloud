@IsTest
private class TelcoNetworkActivationQueueableTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Network Test Account');
        insert acc;

        Product2 router = new Product2(
            Name        = 'Edge 5G Router',
            ProductCode = 'EDGE_5G_ROUTER',
            IsActive    = true
        );
        insert router;

        Pricebook2 stdPb = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        update stdPb;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = router.Id,
            UnitPrice    = 1200.00,
            IsActive     = true
        );
        insert pbe;

        Order ord = new Order(
            AccountId    = acc.Id,
            Status       = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert ord;

        OrderItem item = new OrderItem(
            OrderId          = ord.Id,
            Product2Id       = router.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 1,
            UnitPrice        = 1200.00,
            Network_Status__c = 'Pending_Activation'
        );
        insert item;

        Asset asset = new Asset(
            Name             = 'Router Asset 001',
            AccountId        = acc.Id,
            OrderItemId__c   = item.Id,
            IMEI_Scanned__c  = false,
            Network_Activation_Status__c = 'Pending_Activation'
        );
        insert asset;
    }

    // ── IMEI not scanned — Queueable must exit early without callout ──
    @IsTest
    static void testSkipsWhenImeiNotScanned() {
        OrderItem item = [SELECT Id FROM OrderItem LIMIT 1];

        Test.startTest();
        System.enqueueJob(new TelcoNetworkActivationQueueable(item.Id, 1));
        Test.stopTest();

        // Asset should still be Pending_Activation — no callout was made
        Asset a = [SELECT Network_Activation_Status__c FROM Asset WHERE OrderItemId__c = :item.Id LIMIT 1];
        System.assertEquals('Pending_Activation', a.Network_Activation_Status__c,
            'Asset status should remain Pending_Activation when IMEI not scanned');
    }

    // ── Callout returns 200 — asset and order item updated to Active ──
    @IsTest
    static void testSuccessfulActivation() {
        OrderItem item = [SELECT Id FROM OrderItem LIMIT 1];

        // Set IMEI scanned so the Queueable proceeds past the guard
        Asset a = [SELECT Id FROM Asset WHERE OrderItemId__c = :item.Id LIMIT 1];
        a.IMEI_Scanned__c = true;
        update a;

        // Mock HTTP 200 response
        Test.setMock(HttpCalloutMock.class, new TelcoActivationMock(200));

        Test.startTest();
        System.enqueueJob(new TelcoNetworkActivationQueueable(item.Id, 1));
        Test.stopTest();

        Asset updated = [SELECT Network_Activation_Status__c, Activated_DateTime__c FROM Asset WHERE Id = :a.Id];
        System.assertEquals('Active', updated.Network_Activation_Status__c, 'Asset should be Active after 200 response');
        System.assertNotEquals(null, updated.Activated_DateTime__c, 'Activated_DateTime__c should be stamped');

        OrderItem updatedItem = [SELECT Network_Status__c FROM OrderItem WHERE Id = :item.Id];
        System.assertEquals('Active', updatedItem.Network_Status__c, 'OrderItem Network_Status__c should be Active');
    }

    // ── Callout returns 500 — retry enqueued, still at attempt 1 ──
    @IsTest
    static void testRetryOnFailure() {
        OrderItem item = [SELECT Id FROM OrderItem LIMIT 1];

        Asset a = [SELECT Id FROM Asset WHERE OrderItemId__c = :item.Id LIMIT 1];
        a.IMEI_Scanned__c = true;
        update a;

        Test.setMock(HttpCalloutMock.class, new TelcoActivationMock(500));

        Test.startTest();
        System.enqueueJob(new TelcoNetworkActivationQueueable(item.Id, 1));
        Test.stopTest();

        // Asset should still be Pending_Activation after retry enqueued
        Asset notActivated = [SELECT Network_Activation_Status__c FROM Asset WHERE Id = :a.Id];
        System.assertEquals('Pending_Activation', notActivated.Network_Activation_Status__c,
            'Asset should remain Pending_Activation after first failed attempt');
    }

    // ── 3 attempts exhausted — Case created, OrderItem set to Failed ──
    @IsTest
    static void testMaxRetriesExhaustedCreateCase() {
        OrderItem item = [SELECT Id FROM OrderItem LIMIT 1];

        Asset a = [SELECT Id FROM Asset WHERE OrderItemId__c = :item.Id LIMIT 1];
        a.IMEI_Scanned__c = true;
        update a;

        Test.setMock(HttpCalloutMock.class, new TelcoActivationMock(500));

        Test.startTest();
        // Attempt 3 = MAX_ATTEMPTS — triggers escalation Case
        System.enqueueJob(new TelcoNetworkActivationQueueable(item.Id, 3));
        Test.stopTest();

        OrderItem failed = [SELECT Network_Status__c FROM OrderItem WHERE Id = :item.Id];
        System.assertEquals('Failed', failed.Network_Status__c, 'OrderItem should be Failed after 3 exhausted attempts');

        List<Case> cases = [SELECT Subject FROM Case WHERE Subject LIKE '%Activation Failed%'];
        System.assertEquals(1, cases.size(), 'Expected 1 escalation Case after max retries');
    }

    // ── Mock HTTP Callout ──
    private class TelcoActivationMock implements HttpCalloutMock {
        private Integer statusCode;
        TelcoActivationMock(Integer statusCode) { this.statusCode = statusCode; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(statusCode == 200 ? '{"status":"activated"}' : '{"error":"upstream_failure"}');
            return res;
        }
    }
}
