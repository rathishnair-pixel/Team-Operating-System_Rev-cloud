@IsTest
private class ConfigureTelcoBundleTest {

    // ── Happy Path: Router + Data Plan — should pass CML and return success ──
    @IsTest
    static void testHappyPathRouterAndDataPlan() {
        ConfigureTelcoBundle.BundleLine router = new ConfigureTelcoBundle.BundleLine();
        router.productCode = 'ROUTER_5G_ENT';
        router.quantity    = 1;

        ConfigureTelcoBundle.BundleLine dataPlan = new ConfigureTelcoBundle.BundleLine();
        dataPlan.productCode = 'DATA_PLAN_5G';
        dataPlan.quantity    = 1;

        ConfigureTelcoBundle.BundleRequest req = new ConfigureTelcoBundle.BundleRequest();
        req.quoteId       = 'MOCK_QUOTE_001';
        req.pricebookId   = 'MOCK_PB_001';
        req.totalSiteCount = 3;
        req.bundleLines   = new List<ConfigureTelcoBundle.BundleLine>{ router, dataPlan };
        req.attributes    = new List<ConfigureTelcoBundle.BundleAttribute>();

        Test.startTest();
        List<ConfigureTelcoBundle.BundleResult> results =
            ConfigureTelcoBundle.configure(new List<ConfigureTelcoBundle.BundleRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected 1 result');
        System.assertEquals(true, results[0].success, 'Expected success = true for valid Router + Data Plan');
        System.assertEquals(0, results[0].validationErrors.size(), 'Expected no validation errors');
        System.assert(results[0].pricingNotes.contains('Standard pricing'), 'Expected standard pricing note for 3 sites');
    }

    // ── CML Violation: SLA without Router — must return error ──
    @IsTest
    static void testCmlViolationSlaWithoutRouter() {
        ConfigureTelcoBundle.BundleLine dataPlan = new ConfigureTelcoBundle.BundleLine();
        dataPlan.productCode = 'DATA_PLAN_5G';
        dataPlan.quantity    = 1;

        ConfigureTelcoBundle.BundleLine sla = new ConfigureTelcoBundle.BundleLine();
        sla.productCode = 'SLA_PLATINUM';
        sla.quantity    = 1;

        ConfigureTelcoBundle.BundleRequest req = new ConfigureTelcoBundle.BundleRequest();
        req.quoteId        = 'MOCK_QUOTE_002';
        req.pricebookId    = 'MOCK_PB_001';
        req.totalSiteCount = 1;
        req.bundleLines    = new List<ConfigureTelcoBundle.BundleLine>{ dataPlan, sla };
        req.attributes     = new List<ConfigureTelcoBundle.BundleAttribute>();

        Test.startTest();
        List<ConfigureTelcoBundle.BundleResult> results =
            ConfigureTelcoBundle.configure(new List<ConfigureTelcoBundle.BundleRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Expected failure when SLA added without Router');
        System.assertEquals(1, results[0].validationErrors.size(), 'Expected exactly 1 CML validation error');
        System.assert(
            results[0].validationErrors[0].contains('CML_REQUIRED_COMPONENT_MISSING'),
            'Expected CML_REQUIRED_COMPONENT_MISSING error code'
        );
    }

    // ── Volume Discount: 30 sites should trigger discount note ──
    @IsTest
    static void testVolumeDiscountNoteAbove25Sites() {
        ConfigureTelcoBundle.BundleLine router = new ConfigureTelcoBundle.BundleLine();
        router.productCode = 'ROUTER_5G_ENT';
        router.quantity    = 30;

        ConfigureTelcoBundle.BundleLine dataPlan = new ConfigureTelcoBundle.BundleLine();
        dataPlan.productCode = 'DATA_PLAN_5G';
        dataPlan.quantity    = 30;

        ConfigureTelcoBundle.BundleRequest req = new ConfigureTelcoBundle.BundleRequest();
        req.quoteId        = 'MOCK_QUOTE_003';
        req.pricebookId    = 'MOCK_PB_001';
        req.totalSiteCount = 30;
        req.bundleLines    = new List<ConfigureTelcoBundle.BundleLine>{ router, dataPlan };
        req.attributes     = new List<ConfigureTelcoBundle.BundleAttribute>();

        Test.startTest();
        List<ConfigureTelcoBundle.BundleResult> results =
            ConfigureTelcoBundle.configure(new List<ConfigureTelcoBundle.BundleRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Expected success for valid 30-site bundle');
        System.assert(
            results[0].pricingNotes.contains('15% volume discount'),
            'Expected volume discount note for 30 sites'
        );
    }

    // ── Bulk: 200 requests in one invocation — governor limit check ──
    @IsTest
    static void testBulkInvocation() {
        List<ConfigureTelcoBundle.BundleRequest> requests = new List<ConfigureTelcoBundle.BundleRequest>();
        for (Integer i = 0; i < 200; i++) {
            ConfigureTelcoBundle.BundleLine r = new ConfigureTelcoBundle.BundleLine();
            r.productCode = 'ROUTER_5G_ENT';
            r.quantity    = 1;
            ConfigureTelcoBundle.BundleLine d = new ConfigureTelcoBundle.BundleLine();
            d.productCode = 'DATA_PLAN_5G';
            d.quantity    = 1;
            ConfigureTelcoBundle.BundleRequest req = new ConfigureTelcoBundle.BundleRequest();
            req.quoteId        = 'MOCK_Q_' + i;
            req.pricebookId    = 'MOCK_PB';
            req.totalSiteCount = 1;
            req.bundleLines    = new List<ConfigureTelcoBundle.BundleLine>{ r, d };
            req.attributes     = new List<ConfigureTelcoBundle.BundleAttribute>();
            requests.add(req);
        }

        Test.startTest();
        List<ConfigureTelcoBundle.BundleResult> results = ConfigureTelcoBundle.configure(requests);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Expected 200 results for bulk invocation');
        for (ConfigureTelcoBundle.BundleResult res : results) {
            System.assertEquals(true, res.success, 'All bulk requests should succeed');
        }
    }

    // ── Edge: SLA + Router (no Data Plan) — SLA only requires Router in current CML ──
    @IsTest
    static void testSlaWithRouterNoPlan() {
        ConfigureTelcoBundle.BundleLine router = new ConfigureTelcoBundle.BundleLine();
        router.productCode = 'ROUTER_5G_ENT';
        router.quantity    = 1;

        ConfigureTelcoBundle.BundleLine sla = new ConfigureTelcoBundle.BundleLine();
        sla.productCode = 'SLA_PLATINUM';
        sla.quantity    = 1;

        ConfigureTelcoBundle.BundleRequest req = new ConfigureTelcoBundle.BundleRequest();
        req.quoteId        = 'MOCK_QUOTE_004';
        req.pricebookId    = 'MOCK_PB_001';
        req.totalSiteCount = 1;
        req.bundleLines    = new List<ConfigureTelcoBundle.BundleLine>{ router, sla };
        req.attributes     = new List<ConfigureTelcoBundle.BundleAttribute>();

        Test.startTest();
        List<ConfigureTelcoBundle.BundleResult> results =
            ConfigureTelcoBundle.configure(new List<ConfigureTelcoBundle.BundleRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'SLA + Router without DataPlan should pass current CML gate');
        System.assertEquals(0, results[0].validationErrors.size());
    }
}
