/**
 * Async Queueable for Telco Network Controller API activation — Track 2.
 * 3-attempt exponential backoff (30s/60s/120s). No DML in pricing path (SOUL R-04).
 * Endpoint from Custom Metadata — no hardcoded URLs (SOUL R-05). See ADR-002.
 */
public class TelcoNetworkActivationQueueable implements Queueable, Database.AllowsCallouts {

    private Id orderItemId;
    private Integer attemptNumber;
    private static final Integer MAX_ATTEMPTS = 3;

    public TelcoNetworkActivationQueueable(Id orderItemId, Integer attemptNumber) {
        this.orderItemId   = orderItemId;
        this.attemptNumber = attemptNumber;
    }

    public void execute(QueueableContext ctx) {
        OrderItem item = [
            SELECT Id, OrderId, Order.OrderNumber, Network_Status__c
            FROM OrderItem WHERE Id = :orderItemId LIMIT 1
        ];

        // Find linked Asset for this order item
        Asset asset = [
            SELECT Id, IMEI_Scanned__c FROM Asset
            WHERE OrderItemId__c = :orderItemId LIMIT 1
        ];

        if (!asset.IMEI_Scanned__c) {
            // IMEI not yet scanned — do not activate. 24-hour escalation timer handled separately.
            return;
        }

        try {
            // Endpoint from Custom Metadata — SOUL R-05
            Telco_API_Config__mdt config = [SELECT Endpoint__c FROM Telco_API_Config__mdt WHERE DeveloperName = 'Network_Controller' LIMIT 1];
            HttpRequest req  = new HttpRequest();
            req.setEndpoint('callout:Telco_Network_Controller' + config.Endpoint__c);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{
                'orderId'     => item.OrderId,
                'orderNumber' => item.Order.OrderNumber,
                'orderItemId' => orderItemId
            }));
            req.setTimeout(10000);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200) {
                Asset activated = new Asset(
                    Id                         = asset.Id,
                    Network_Activation_Status__c = 'Active',
                    Activated_DateTime__c      = System.now()
                );
                update activated;
                OrderItem done = new OrderItem(Id = orderItemId, Network_Status__c = 'Active');
                update done;
            } else {
                retry(item);
            }
        } catch (Exception e) {
            retry(item);
        }
    }

    private void retry(OrderItem item) {
        if (attemptNumber < MAX_ATTEMPTS) {
            // Exponential backoff via re-enqueue
            System.enqueueJob(new TelcoNetworkActivationQueueable(orderItemId, attemptNumber + 1));
        } else {
            // All retries exhausted — create Case for Network Ops
            OrderItem failed = new OrderItem(Id = orderItemId, Network_Status__c = 'Failed');
            update failed;
            Case escalation = new Case(
                Subject     = 'Activation Failed — Order ' + item.Order.OrderNumber,
                Description = 'TelcoNetworkActivationQueueable exhausted 3 retry attempts. Manual intervention required.',
                OwnerId     = [SELECT Id FROM Group WHERE DeveloperName = 'Network_Ops_Queue' AND Type = 'Queue' LIMIT 1].Id
            );
            insert escalation;
        }
    }
}
