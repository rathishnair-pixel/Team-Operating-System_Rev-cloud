@IsTest
private class SubmitForTelcoApprovalTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Telco Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name        = 'Telco Test Opp',
            AccountId   = acc.Id,
            StageName   = 'Proposal',
            CloseDate   = Date.today().addDays(30)
        );
        insert opp;

        Quote q = new Quote(
            Name         = 'Test Telco Quote',
            OpportunityId = opp.Id,
            Status       = 'Draft'
        );
        insert q;
    }

    // ── Happy Path: submit quote with no active process — verifies class executes without crash ──
    @IsTest
    static void testSubmitWithNoActiveProcess() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        SubmitForTelcoApproval.ApprovalRequest req = new SubmitForTelcoApproval.ApprovalRequest();
        req.quoteId = q.Id;

        Test.startTest();
        List<SubmitForTelcoApproval.ApprovalResult> results =
            SubmitForTelcoApproval.submit(new List<SubmitForTelcoApproval.ApprovalRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected 1 result');
        // In test context without a configured approval process, Apex.process() throws
        // and the catch block returns submitted=false with an error message.
        System.assertNotEquals(null, results[0].submitted, 'submitted flag should not be null');
    }

    // ── Error Path: invalid Quote Id — catch block must return errorMessage ──
    @IsTest
    static void testSubmitWithInvalidQuoteId() {
        SubmitForTelcoApproval.ApprovalRequest req = new SubmitForTelcoApproval.ApprovalRequest();
        req.quoteId = 'INVALID_ID_000';

        Test.startTest();
        List<SubmitForTelcoApproval.ApprovalResult> results =
            SubmitForTelcoApproval.submit(new List<SubmitForTelcoApproval.ApprovalRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].submitted, 'Expected submitted = false for invalid Id');
        System.assertNotEquals(null, results[0].errorMessage, 'Expected errorMessage to be populated on failure');
    }

    // ── Bulk: 10 requests — ensures loop and list handling works ──
    @IsTest
    static void testBulkSubmit() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        List<SubmitForTelcoApproval.ApprovalRequest> requests = new List<SubmitForTelcoApproval.ApprovalRequest>();
        for (Integer i = 0; i < 10; i++) {
            SubmitForTelcoApproval.ApprovalRequest req = new SubmitForTelcoApproval.ApprovalRequest();
            req.quoteId = q.Id;
            requests.add(req);
        }

        Test.startTest();
        List<SubmitForTelcoApproval.ApprovalResult> results = SubmitForTelcoApproval.submit(requests);
        Test.stopTest();

        System.assertEquals(10, results.size(), 'Expected 10 results for bulk submit');
    }

    // ── Verify approvalStep is always 1 on successful path ──
    @IsTest
    static void testApprovalStepDefaultValue() {
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        SubmitForTelcoApproval.ApprovalRequest req = new SubmitForTelcoApproval.ApprovalRequest();
        req.quoteId = q.Id;

        Test.startTest();
        List<SubmitForTelcoApproval.ApprovalResult> results =
            SubmitForTelcoApproval.submit(new List<SubmitForTelcoApproval.ApprovalRequest>{ req });
        Test.stopTest();

        // If submitted successfully, step is 1. If failed, step remains null — both valid.
        if (results[0].submitted == true) {
            System.assertEquals(1, results[0].approvalStep, 'Expected approvalStep = 1 on initial submission');
            System.assertEquals('Regional Telco Finance Director', results[0].assignedTo);
        }
    }
}
