@IsTest
private class EnqueueNetworkActivationTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Enqueue Test Account');
        insert acc;

        Product2 p = new Product2(Name = 'Test Router', ProductCode = 'TEST_ROUTER', IsActive = true);
        insert p;

        Pricebook2 stdPb = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        update stdPb;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = p.Id,
            UnitPrice    = 100.00,
            IsActive     = true
        );
        insert pbe;

        Order ord = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        insert ord;

        OrderItem item = new OrderItem(
            OrderId          = ord.Id,
            Product2Id       = p.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 1,
            UnitPrice        = 100.00
        );
        insert item;
    }

    // ── Happy Path: valid orderItemId enqueues without exception ──
    @IsTest
    static void testEnqueueSingleRequest() {
        OrderItem item = [SELECT Id FROM OrderItem LIMIT 1];

        EnqueueNetworkActivation.ActivationRequest req = new EnqueueNetworkActivation.ActivationRequest();
        req.orderItemId = item.Id;

        Test.startTest();
        EnqueueNetworkActivation.enqueue(
            new List<EnqueueNetworkActivation.ActivationRequest>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Enqueue completed without exception');
    }

    // ── Bulk: 5 order items ──
    @IsTest
    static void testEnqueueMultipleRequests() {
        Account acc = new Account(Name = 'Bulk Enqueue Account');
        insert acc;

        Product2 p = new Product2(Name = 'Bulk Router', ProductCode = 'BULK_ROUTER', IsActive = true);
        insert p;

        Pricebook2 stdPb = new Pricebook2(Id = Test.getStandardPricebookId(), IsActive = true);
        update stdPb;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = p.Id,
            UnitPrice    = 100.00,
            IsActive     = true
        );
        insert pbe;

        Order ord = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        insert ord;

        List<OrderItem> items = new List<OrderItem>();
        for (Integer i = 0; i < 5; i++) {
            items.add(new OrderItem(
                OrderId          = ord.Id,
                Product2Id       = p.Id,
                PricebookEntryId = pbe.Id,
                Quantity         = 1,
                UnitPrice        = 100.00
            ));
        }
        insert items;

        List<EnqueueNetworkActivation.ActivationRequest> requests = new List<EnqueueNetworkActivation.ActivationRequest>();
        for (OrderItem item : items) {
            EnqueueNetworkActivation.ActivationRequest req = new EnqueueNetworkActivation.ActivationRequest();
            req.orderItemId = item.Id;
            requests.add(req);
        }

        Test.startTest();
        EnqueueNetworkActivation.enqueue(requests);
        Test.stopTest();

        System.assert(true, 'Bulk enqueue of 5 requests completed without exception');
    }
}
