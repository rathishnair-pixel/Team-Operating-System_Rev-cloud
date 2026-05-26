/**
 * Invocable Action — creates a Field Service Work Order for Track 3 fiber installation.
 * Called from Record-Triggered Flow on Order activation for FIBER_INSTALL order lines.
 * SLA window set to 24hrs. Fiber_Meters__c drives technician prep time. See ADR-003.
 */
public with sharing class CreateFieldServiceWorkOrder {

    public class WorkOrderRequest {
        @InvocableVariable(label='Order Id' required=true)
        public String orderId;
        @InvocableVariable(label='Order Item Id' required=true)
        public String orderItemId;
        @InvocableVariable(label='Site Address' required=true)
        public String siteAddress;
        @InvocableVariable(label='Fiber Meters' required=true)
        public Integer fiberMeters;
        @InvocableVariable(label='Site ID' required=true)
        public String siteId;
        @InvocableVariable(label='Account Id' required=true)
        public String accountId;
    }

    public class WorkOrderResult {
        @InvocableVariable(label='Work Order Id')
        public String workOrderId;
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Create Field Service Work Order for Fiber Installation'
        description='Use this action to create a Field Service Work Order for the fiber drop and site installation when a 5G Smart Office order is activated. Automatically sets the 24-hour SLA window, copies fiber distance from the order line, and schedules technician dispatch. Call this for every site in the order that includes a FIBER_INSTALL line.'
        category='5G Smart Office'
    )
    public static List<WorkOrderResult> create(List<WorkOrderRequest> requests) {
        List<WorkOrder> workOrders = new List<WorkOrder>();
        for (WorkOrderRequest req : requests) {
            Datetime slaStart = System.now();
            workOrders.add(new WorkOrder(
                Subject          = 'Fiber Drop & Splice — Site ' + req.siteId,
                AccountId        = req.accountId,
                Street           = req.siteAddress,
                Fiber_Meters__c  = req.fiberMeters,
                SlaStartDate     = slaStart,
                SlaExitDate      = slaStart.addHours(24),
                Description      = 'Install fiber run of ' + req.fiberMeters + ' meters. ' +
                                   'Splice completion required before Order can be closed. ' +
                                   'Order: ' + req.orderId + ' | OrderItem: ' + req.orderItemId
            ));
        }

        List<WorkOrderResult> results = new List<WorkOrderResult>();
        List<Database.SaveResult> saveResults = Database.insert(workOrders, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            WorkOrderResult res = new WorkOrderResult();
            if (saveResults[i].isSuccess()) {
                res.success     = true;
                res.workOrderId = saveResults[i].getId();
            } else {
                res.success      = false;
                res.errorMessage = saveResults[i].getErrors()[0].getMessage();
            }
            results.add(res);
        }
        return results;
    }
}
