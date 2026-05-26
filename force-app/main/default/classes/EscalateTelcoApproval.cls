/**
 * Invocable Action called by Flow Orchestrator TelcoApprovalEscalationOrchestration
 * when 4-hour approval SLA is breached. Reassigns approval step to manager.
 * No DML on Quote pricing fields — approval routing only. See ADR-005.
 */
public with sharing class EscalateTelcoApproval {

    public class EscalationRequest {
        @InvocableVariable(label='Quote Id' required=true)
        public String quoteId;
        @InvocableVariable(label='Current Approver Id' required=true)
        public String currentApproverId;
    }

    public class EscalationResult {
        @InvocableVariable(label='Escalated')
        public Boolean escalated;
        @InvocableVariable(label='Escalated To')
        public String escalatedTo;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Escalate Telco Approval After SLA Breach'
        description='Use this action to escalate an unanswered telco discount approval to the current approver manager after the 4-hour business-hour SLA window has elapsed. Called automatically by Flow Orchestrator. Reassigns the open ProcessInstanceWorkItem and posts a Chatter notification to the escalated approver.'
        category='5G Smart Office'
    )
    public static List<EscalationResult> escalate(List<EscalationRequest> requests) {
        List<EscalationResult> results = new List<EscalationResult>();
        for (EscalationRequest req : requests) {
            results.add(processEscalation(req));
        }
        return results;
    }

    private static EscalationResult processEscalation(EscalationRequest req) {
        EscalationResult res = new EscalationResult();
        try {
            // Resolve manager — null-safe with Custom Metadata fallback (SOUL R-05)
            User currentApprover = [SELECT Id, ManagerId, Manager.Name FROM User WHERE Id = :req.currentApproverId LIMIT 1];
            Id escalateTo = currentApprover.ManagerId;
            if (escalateTo == null) {
                // Fallback to named queue from Custom Metadata
                Group fallbackQueue = [SELECT Id FROM Group WHERE DeveloperName = 'Telco_Approval_Fallback_Queue' AND Type = 'Queue' LIMIT 1];
                escalateTo = fallbackQueue.Id;
            }

            // Reassign open ProcessInstanceWorkItem
            ProcessInstanceWorkItem workItem = [
                SELECT Id, ActorId FROM ProcessInstanceWorkItem
                WHERE ProcessInstance.TargetObjectId = :req.quoteId
                AND ProcessInstance.Status = 'Pending'
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            workItem.ActorId = escalateTo;
            update workItem;

            // Stamp escalation datetime on Quote
            Quote q = new Quote(Id = req.quoteId, Last_Escalated_DateTime__c = System.now());
            update q;

            // Chatter notification
            FeedItem post = new FeedItem(
                ParentId = req.quoteId,
                Body     = 'Approval escalated — 4-hour SLA breached. Reassigned to: ' + (currentApprover.Manager?.Name ?? 'Fallback Queue')
            );
            insert post;

            res.escalated   = true;
            res.escalatedTo = currentApprover.Manager?.Name ?? 'Telco_Approval_Fallback_Queue';
        } catch (Exception e) {
            res.escalated    = false;
            res.errorMessage = e.getMessage();
        }
        return res;
    }
}
