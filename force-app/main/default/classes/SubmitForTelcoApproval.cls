/**
 * Agentforce Invocable Action — submits a Quote for telco discount approval.
 * AR-4: explicit approval gate entry point for Agentforce routing. See ADR-005.
 * Satisfies WL-4 agent-readiness for FTR-005 approval workflow.
 */
public with sharing class SubmitForTelcoApproval {

    public class ApprovalRequest {
        @InvocableVariable(label='Quote Id' required=true)
        public String quoteId;
    }

    public class ApprovalResult {
        @InvocableVariable(label='Submitted')
        public Boolean submitted;
        @InvocableVariable(label='Approval Step')
        public Integer approvalStep;
        @InvocableVariable(label='Assigned To')
        public String assignedTo;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Submit Quote for Telco Discount Approval'
        description='Use this action to programmatically submit a telco quote for sequential approval when a manual discount greater than 20% has been applied to the core data plan. Routes to Regional Telco Finance Director first, then Network Operations VP. Call this when the customer or rep requests a discounted rate that exceeds the standard threshold.'
        category='5G Smart Office'
    )
    public static List<ApprovalResult> submit(List<ApprovalRequest> requests) {
        List<ApprovalResult> results = new List<ApprovalResult>();
        for (ApprovalRequest req : requests) {
            results.add(processSubmit(req));
        }
        return results;
    }

    private static ApprovalResult processSubmit(ApprovalRequest req) {
        ApprovalResult res = new ApprovalResult();
        try {
            Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
            submitReq.setObjectId(req.quoteId);
            submitReq.setProcessDefinitionNameOrId('Telco_Discount_Approval_Process');
            Approval.ProcessResult result = Approval.process(submitReq);
            res.submitted    = result.isSuccess();
            res.approvalStep = 1;
            // TODO [Dev]: query ProcessInstanceWorkItem for assignedTo name
            res.assignedTo   = 'Regional Telco Finance Director';
        } catch (Exception e) {
            res.submitted     = false;
            res.errorMessage  = e.getMessage();
        }
        return res;
    }
}
