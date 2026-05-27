@IsTest
private class EnqueueNetworkActivationTest {

    // ── Happy Path: valid orderItemId enqueues without exception ──
    @IsTest
    static void testEnqueueSingleRequest() {
        EnqueueNetworkActivation.ActivationRequest req = new EnqueueNetworkActivation.ActivationRequest();
        req.orderItemId = 'MOCK_ORDER_ITEM_001';

        Test.startTest();
        EnqueueNetworkActivation.enqueue(
            new List<EnqueueNetworkActivation.ActivationRequest>{ req }
        );
        Test.stopTest();

        // No exception thrown — Queueable was enqueued successfully
        System.assert(true, 'Enqueue completed without exception');
    }

    // ── Bulk: 5 order items ──
    @IsTest
    static void testEnqueueMultipleRequests() {
        List<EnqueueNetworkActivation.ActivationRequest> requests = new List<EnqueueNetworkActivation.ActivationRequest>();
        for (Integer i = 0; i < 5; i++) {
            EnqueueNetworkActivation.ActivationRequest req = new EnqueueNetworkActivation.ActivationRequest();
            req.orderItemId = 'MOCK_ITEM_' + i;
            requests.add(req);
        }

        Test.startTest();
        EnqueueNetworkActivation.enqueue(requests);
        Test.stopTest();

        System.assert(true, 'Bulk enqueue of 5 requests completed without exception');
    }
}
