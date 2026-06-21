/**
 * @description Batch class that synchronises Policy data from the external AIM web service
 *              into Salesforce as Opportunity records. Second and final batch in the AIM
 *              integration pipeline, chained from AccountBrokenBatch.finish().
 *
 *              Implements a delta-sync pattern using a configurable start date, with
 *              checkpoint/recovery support via the OpportunityAbortJob__c Custom Setting.
 *              Agent Number exclusions are driven by AIM_Broker_Exclusion__mdt Custom
 *              Metadata records — no code changes are required to add or remove exclusions.
 *
 * @see AIMConnection
 * @see AccountBrokenBatch
 * @see AIM_Broker_Exclusion__mdt
 * @see AIM_Integration_Settings__mdt
 */
public class OpportunityPolicyBatch implements Database.Batchable<Opportunity>, Database.AllowsCallouts, Database.Stateful {

    /** @description Collects all RB Agent IDs from policies in start() for Account lookup in execute(). */
    public Set<String> setRBAgentId {get;set;}

    /** @description The delta date sent to the AIM API — only records changed since this date are returned. */
    public Datetime startDate {get;set;}

    /** @description Checkpoint timestamp (now minus 10 minutes) written to OpportunityAbortJob__c on DML failure. */
    public Datetime startDateCS {get;set;}

    /** @description Flag indicating the OpportunityAbortJob__c Custom Setting should be cleaned up after recovery. */
    public Boolean deleteCS {get;set;}

    /** @description OwnerId loaded from AIM_Integration_Settings__mdt — applied to Opportunities. */
    public String defaultOwnerId {get;set;}

    // =========================================================================
    // Constructors
    // =========================================================================

    /**
     * @description Parameterised constructor — used when chaining from AccountBrokenBatch
     *              or invoking manually with an explicit start date.
     * @param startDateFrom The datetime from which to retrieve changed policy records from AIM.
     */
    public OpportunityPolicyBatch(Datetime startDateFrom) {
        System.debug('##construct OpportunityPolicyBatch with parameters');
        startDate = startDateFrom;
    }

    /**
     * @description No-argument constructor — used for standalone invocation. The start date
     *              is derived from the OpportunityAbortJob__c Custom Setting (recovery) or
     *              defaults to now minus 1 day and 10 minutes.
     */
    public OpportunityPolicyBatch() {
        System.debug('##construct OpportunityPolicyBatch');
    }

    // =========================================================================
    // Batch Interface Methods
    // =========================================================================

    /**
     * @description Authenticates with the AIM web service, retrieves changed Policy records,
     *              and builds Opportunity collections for processing in execute(). Loads
     *              exclusion sets and OwnerId from Custom Metadata.
     * @param bc The BatchableContext provided by the Salesforce batch framework.
     * @return List of Opportunity records to process in execute() chunks.
     */
    public List<Opportunity> start(Database.BatchableContext bc) {
        System.debug('##start OpportunityPolicyBatch');

        setRBAgentId = new Set<String>();
        deleteCS     = false;
        startDateCS  = System.now().addMinutes(-10);

        defaultOwnerId = loadOwnerId();
        startDate      = resolveStartDate();

        schemasDatacontractOrg200407Aimwebs.PolicyChangesGetListResponse response = AIMConnection.getOpportunities(startDate);
        System.debug('##AIM response received: ' + (response != null));

        List<Opportunity> opportunities = new List<Opportunity>();

        if (response == null || response.PolicyChangeList == null || response.PolicyChangeList.Policy == null) {
            return opportunities;
        }

        Set<String> excludedAgentNos = loadAgentExclusions();
        System.debug('##AIM Agent exclusions loaded: ' + excludedAgentNos);

        Map<String,String> contactMap = buildContactMap(response.PolicyChangeList.Policy, excludedAgentNos);

        for (schemasDatacontractOrg200407Aimwebs.Policy pol : response.PolicyChangeList.Policy) {
            if (pol.ReferenceID == null || excludedAgentNos.contains(pol.RBAgentID)) {
                continue;
            }
            opportunities.add(buildOpportunity(pol, contactMap));
            if (pol.RBAgentID != null && pol.RBAgentID != '') {
                setRBAgentId.add(pol.RBAgentID);
            }
        }

        return opportunities;
    }

    /**
     * @description Upserts each chunk of Opportunities, linking them to their parent Account
     *              via RB_Agent_ID__c. On DML failure, aborts the job and writes a recovery
     *              checkpoint to OpportunityAbortJob__c.
     * @param bc    The BatchableContext provided by the Salesforce batch framework.
     * @param scope The chunk of Opportunity records to process in this execution.
     */
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        System.debug('##execute OpportunityPolicyBatch');

        cleanupAbortJobIfNeeded();

        if (scope.isEmpty()) {
            return;
        }

        try {
            Map<String,Id> mapAccount = new Map<String,Id>();
            for (Account acc : [SELECT Id, Broker_No__c FROM Account WHERE Broker_No__c IN :setRBAgentId]) {
                mapAccount.put(acc.Broker_No__c, acc.Id);
            }

            Map<String,Opportunity> mapOpp = new Map<String,Opportunity>();
            for (Opportunity opp : scope) {
                if (mapAccount.get(opp.RB_Agent_ID__c) != null) {
                    opp.AccountId = mapAccount.get(opp.RB_Agent_ID__c);
                }
                mapOpp.put(opp.Reference_ID__c, opp);
            }

            upsert mapOpp.values() Reference_ID__c;

        } catch (DmlException e) {
            System.debug('##Error Executing OpportunityPolicyBatch: ' + e.getMessage());
            System.abortJob(bc.getJobId());
            OpportunityAbortJob__c checkpoint = new OpportunityAbortJob__c();
            checkpoint.Name         = 'OpportunityAbortJob';
            checkpoint.AbortDate__c = startDateCS;
            insert checkpoint;
        }
    }

    /**
     * @description End of the AIM integration pipeline. No further batches are chained.
     * @param bc The BatchableContext provided by the Salesforce batch framework.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('##finish OpportunityPolicyBatch');
    }

    // =========================================================================
    // Private Helper Methods
    // =========================================================================

    /**
     * @description Loads the default OwnerId from AIM_Integration_Settings__mdt.
     *              Logs a warning and returns null if the metadata record is missing,
     *              allowing records to be created owned by the running user.
     * @return The OwnerId string, or null if not configured.
     */
    private String loadOwnerId() {
        List<AIM_Integration_Settings__mdt> settings = [
            SELECT DefaultOwnerID__c
            FROM AIM_Integration_Settings__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        if (!settings.isEmpty() && settings[0].DefaultOwnerID__c != null) {
            return settings[0].DefaultOwnerID__c;
        }
        System.debug('##WARNING: AIM_Integration_Settings__mdt.Default not found or DefaultOwnerID__c is blank. OwnerId will not be set.');
        return null;
    }

    /**
     * @description Determines the startDate for the AIM API call. Checks the
     *              OpportunityAbortJob__c Custom Setting first for recovery scenarios
     *              (taking priority even over a passed-in date), then falls back to
     *              the constructor-provided date or a default lookback window.
     * @return The resolved Datetime to use as the AIM delta query start point.
     */
    private Datetime resolveStartDate() {
        List<OpportunityAbortJob__c> abortJobs = OpportunityAbortJob__c.getAll().values();
        if (!abortJobs.isEmpty()) {
            deleteCS = true;
            System.debug('##Recovery mode: overriding startDate with abort checkpoint');
            return abortJobs.get(0).AbortDate__c.addDays(-1);
        }
        if (startDate != null) {
            return startDate;
        }
        return System.now().addDays(-1).addMinutes(-10);
    }

    /**
     * @description Loads Agent Number exclusion values from AIM_Broker_Exclusion__mdt
     *              where Exclusion_Type__c = 'AgentNo'. Shared metadata with AccountBrokenBatch.
     * @return Set of Agent Number strings to exclude from AIM policy sync.
     */
    private Set<String> loadAgentExclusions() {
        Set<String> excluded = new Set<String>();
        for (AIM_Broker_Exclusion__mdt excl : [
            SELECT Exclusion_Value__c
            FROM AIM_Broker_Exclusion__mdt
            WHERE Exclusion_Type__c = 'AgentNo'
            AND Exclusion_Value__c != null
        ]) {
            excluded.add(excl.Exclusion_Value__c);
        }
        return excluded;
    }

    /**
     * @description Performs a two-pass build of the Contact lookup map used to populate
     *              the Attention__c field on Opportunities. Pass 1 collects NameKeyPk values
     *              from valid policies; Pass 2 queries matching Contacts.
     * @param policies         The full list of Policy objects from the AIM response.
     * @param excludedAgentNos The set of Agent Numbers to skip.
     * @return Map of NameKeyPK__c to Contact Id.
     */
    private Map<String,String> buildContactMap(
        List<schemasDatacontractOrg200407Aimwebs.Policy> policies,
        Set<String> excludedAgentNos
    ) {
        Set<String> attentionSet = new Set<String>();
        for (schemasDatacontractOrg200407Aimwebs.Policy pol : policies) {
            if (pol.ReferenceID != null && !excludedAgentNos.contains(pol.RBAgentID) && pol.NameKeyPk != null) {
                attentionSet.add(String.valueOf(pol.NameKeyPk).trim());
            }
        }

        Map<String,String> contactMap = new Map<String,String>();
        for (Contact con : [SELECT Id, NameKeyPK__c FROM Contact WHERE NameKeyPK__c IN :attentionSet]) {
            contactMap.put(con.NameKeyPK__c, con.Id);
        }
        return contactMap;
    }

    /**
     * @description Builds a single Opportunity record from an AIM Policy response object.
     *              Applies date normalisation and maps the Renewal flag to a Boolean.
     * @param pol        The AIM Policy object from the web service response.
     * @param contactMap Map of NameKeyPK__c to Contact Id for Attention__c lookup.
     * @return A populated Opportunity record ready for upsert.
     */
    private Opportunity buildOpportunity(
        schemasDatacontractOrg200407Aimwebs.Policy pol,
        Map<String,String> contactMap
    ) {
        Date closeDate      = parseAimDate(pol.Effective);
        Date expirationDate = parseAimDate(pol.Expiration);

        if (closeDate == null) {
            closeDate = System.today();
        }

        Boolean renewal = null;
        if (pol.Renewal != null) {
            renewal = pol.Renewal == 'Y';
        }

        Opportunity opp = new Opportunity(
            Name              = String.valueOf(pol.ReferenceID),
            Amount            = pol.Premium,
            Tax_State__c      = pol.TaxState,
            Renewal__c        = renewal,
            RB_Agent_ID__c    = pol.RBAgentID,
            Policy_Number__c  = pol.PolicyNumber,
            Reference_ID__c   = String.valueOf(pol.ReferenceID),
            CloseDate         = closeDate,
            StageName         = pol.Status,
            Market_Co__c      = pol.MarketCompany,
            Coverage__c       = pol.Coverage,
            Team_Dept__c      = pol.TeamDept,
            Producer__c       = pol.Producer,
            Product__c        = pol.Product,
            Insured__c        = pol.Insured,
            Expiration_Date__c = expirationDate,
            Retail_Agt_Bkr__c = pol.RetailAgtBkr,
            NameKeyPk__c      = String.valueOf(pol.NameKeyPk),
            Attention__c      = contactMap.get(String.valueOf(pol.NameKeyPk).trim())
        );
        if (defaultOwnerId != null) {
            opp.OwnerId = defaultOwnerId;
        }
        return opp;
    }

    /**
     * @description Converts an AIM Datetime value to a Salesforce Date, returning null
     *              for default empty date values the AIM system returns instead of null.
     * @param aimDate The raw Datetime value from the AIM response.
     * @return A valid Date, or null if the value represents an empty AIM date.
     */
    private Date parseAimDate(Datetime aimDate) {
        if (aimDate == null) {
            return null;
        }
        String s = String.valueOf(aimDate);
        if (s == '0001-01-01 00:00:00' || s == '0001-01-01T00:00:00' || s == '0001-12-31 16:00:00') {
            return null;
        }
        return Date.valueOf(aimDate);
    }

    /**
     * @description Deletes the OpportunityAbortJob__c Custom Setting recovery record if
     *              deleteCS is true. Resets deleteCS to prevent repeated deletion in
     *              subsequent chunks.
     */
    private void cleanupAbortJobIfNeeded() {
        if (!deleteCS) {
            return;
        }
        List<OpportunityAbortJob__c> abortJobs = OpportunityAbortJob__c.getAll().values();
        if (!abortJobs.isEmpty()) {
            delete abortJobs;
        }
        deleteCS = false;
    }
}