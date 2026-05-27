/**
 * Invocable wrapper — enqueues TelcoNetworkActivationQueueable from a Flow.
 * Called by Track 2 Record-Triggered Flow on Asset IMEI_Scanned__c = true.
 * No DML here — Queueable owns the callout. SOUL R-04 compliant. See ADR-002.
 */
public with sharing class EnqueueNetworkActivation {

    public class ActivationRequest {
        @InvocableVariable(label='Order Item Id' required=true)
        public Id orderItemId;
    }

    @InvocableMethod(
        label='Enqueue Telco Network Activation'
        description='Use this action to asynchronously trigger the Telco Network Controller API activation for a specific order item after the IMEI has been scanned and confirmed. Enqueues a 3-attempt exponential backoff Queueable. Call this from the IMEI scan confirmation flow, not directly from an order activation trigger.'
        category='5G Smart Office'
    )
    public static void enqueue(List<ActivationRequest> requests) {
        for (ActivationRequest req : requests) {
            System.enqueueJob(new TelcoNetworkActivationQueueable(req.orderItemId, 1));
        }
    }
}
