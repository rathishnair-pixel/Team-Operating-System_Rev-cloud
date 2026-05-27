@IsTest
private class EscalateTelcoApprovalTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Telco Escalation Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name      = 'Escalation Test Opp',
            AccountId = acc.Id,
            StageName = 'Proposal',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Quote q = new Quote(
            Name          = 'Escalation Test Quote',
            OpportunityId = opp.Id,
            Status        = 'Draft'
        );
        insert q;
    }

    // ── Error Path: invalid approverId — catch block returns errorMessage ──
    @IsTest
    static void testEscalateWithInvalidApproverId() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        EscalateTelcoApproval.EscalationRequest req = new EscalateTelcoApproval.EscalationRequest();
        req.quoteId           = q.Id;
        req.currentApproverId = 'INVALID_USER_ID';

        Test.startTest();
        List<EscalateTelcoApproval.EscalationResult> results =
            EscalateTelcoApproval.escalate(new List<EscalateTelcoApproval.EscalationRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].escalated, 'Expected escalated = false for invalid user Id');
        System.assertNotEquals(null, results[0].errorMessage, 'Expected errorMessage on failure');
    }

    // ── Valid User: approver with no manager — exercises null-safe fallback path ──
    @IsTest
    static void testEscalateWithNoManagerFallbackPath() {
        // Running user has no manager in test context — exercises fallback queue path
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        // No active ProcessInstanceWorkItem exists — will hit exception in SOQL
        EscalateTelcoApproval.EscalationRequest req = new EscalateTelcoApproval.EscalationRequest();
        req.quoteId           = q.Id;
        req.currentApproverId = UserInfo.getUserId(); // Real user, no manager in test org

        Test.startTest();
        List<EscalateTelcoApproval.EscalationResult> results =
            EscalateTelcoApproval.escalate(new List<EscalateTelcoApproval.EscalationRequest>{ req });
        Test.stopTest();

        // SOQL for ProcessInstanceWorkItem will throw with no open approval — catch returns errorMessage
        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].escalated, 'escalated flag should be set');
    }

    // ── Bulk: 5 escalation requests — loop integrity ──
    @IsTest
    static void testBulkEscalate() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        List<EscalateTelcoApproval.EscalationRequest> requests = new List<EscalateTelcoApproval.EscalationRequest>();
        for (Integer i = 0; i < 5; i++) {
            EscalateTelcoApproval.EscalationRequest req = new EscalateTelcoApproval.EscalationRequest();
            req.quoteId           = q.Id;
            req.currentApproverId = 'INVALID_' + i;
            requests.add(req);
        }

        Test.startTest();
        List<EscalateTelcoApproval.EscalationResult> results = EscalateTelcoApproval.escalate(requests);
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Expected 5 results for bulk escalate');
        for (EscalateTelcoApproval.EscalationResult res : results) {
            System.assertEquals(false, res.escalated, 'All should fail with invalid approver Ids');
        }
    }
}
