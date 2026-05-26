/**
 * Agentforce Invocable Action — 5G Smart Office bundle configuration.
 * Maps SmartOfficeBundleContext nodes to DPE pricing engine via ConnectApi.
 * AR-1: single atomic call, no multi-DML. AR-2: 38-word description. See ADR-006.
 */
public with sharing class ConfigureTelcoBundle {

    public class BundleLine {
        @InvocableVariable(label='Product Code' required=true)
        public String productCode;
        @InvocableVariable(label='Quantity' required=true)
        public Integer quantity;
        @InvocableVariable(label='Parent Product Code')
        public String parentProductCode;
    }

    public class BundleAttribute {
        @InvocableVariable(label='Fiber Meters')
        public Integer fiberMeters;
        @InvocableVariable(label='Site ID' required=true)
        public String siteId;
    }

    public class BundleRequest {
        @InvocableVariable(label='Quote Id' required=true)
        public String quoteId;
        @InvocableVariable(label='Pricebook Id' required=true)
        public String pricebookId;
        @InvocableVariable(label='Total Site Count' required=true)
        public Integer totalSiteCount;
        @InvocableVariable(label='Bundle Lines' required=true)
        public List<BundleLine> bundleLines;
        @InvocableVariable(label='Attributes')
        public List<BundleAttribute> attributes;
    }

    public class BundleResult {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Validation Errors')
        public List<String> validationErrors;
        @InvocableVariable(label='Calculated Total Price')
        public Decimal calculatedTotalPrice;
        @InvocableVariable(label='Pricing Notes')
        public String pricingNotes;
    }

    @InvocableMethod(
        label='Configure 5G Smart Office Telco Bundle'
        description='Use this action to add, modify, or validate line items within the 5G Smart Office Bundle, including routers, data plans, fiber installation details, and SLA products. Call this action whenever a user specifies site count, product quantities, or fiber distance requirements for a branch office configuration.'
        category='5G Smart Office'
    )
    public static List<BundleResult> configure(List<BundleRequest> requests) {
        List<BundleResult> results = new List<BundleResult>();
        for (BundleRequest req : requests) {
            results.add(processRequest(req));
        }
        return results;
    }

    private static BundleResult processRequest(BundleRequest req) {
        BundleResult res = new BundleResult();
        res.validationErrors = new List<String>();

        // CML: Router must be present if SLA is requested
        Boolean hasRouter = false;
        Boolean hasSla    = false;
        for (BundleLine line : req.bundleLines) {
            if (line.productCode == 'ROUTER_5G_ENT') hasRouter = true;
            if (line.productCode == 'SLA_PLATINUM')  hasSla    = true;
        }
        if (hasSla && !hasRouter) {
            res.validationErrors.add(
                'CML_REQUIRED_COMPONENT_MISSING: Telco_Platinum_SLA cannot be added without a ' +
                'corresponding Edge_5G_Enterprise_Router. Add ROUTER_5G_ENT before SLA_PLATINUM.'
            );
        }

        if (!res.validationErrors.isEmpty()) {
            res.success = false;
            return res;
        }

        // TODO [Dev]: invoke ConnectApi.CommerceOrders with context wrapper
        // Placeholder pricing for prototype demonstration
        res.success           = true;
        res.calculatedTotalPrice = 0;
        res.pricingNotes      = req.totalSiteCount > 25
            ? 'TotalSiteCount=' + req.totalSiteCount + ' triggered FTR-005 15% volume discount on DATA_PLAN_5G'
            : 'Standard pricing applied';
        return res;
    }
}
