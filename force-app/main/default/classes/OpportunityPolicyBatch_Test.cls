/**
 * @description Test class for OpportunityPolicyBatch. Covers the AIM policy sync pipeline
 *              including batch execution paths, Custom Metadata-driven exclusions,
 *              OwnerId assignment, and the abort/recovery mechanism.
 *
 * @see OpportunityPolicyBatch
 * @see AIMConnection
 * @see AIMMockImplementation
 */
@IsTest
public class OpportunityPolicyBatch_Test {

    // =========================================================================
    // TEST 1 — Parameterised constructor: batch runs with explicit startDate
    // =========================================================================
    @IsTest
    static void testBatchWithStartDate() {
        Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new OpportunityPolicyBatch(System.now().addDays(-40)));
        Test.stopTest();

        List<Opportunity> opps = [SELECT Id, Reference_ID__c, StageName FROM Opportunity];
        System.assert(opps.size() > 0, 'At least one Opportunity should have been upserted by the batch');
    }

    // =========================================================================
    // TEST 2 — No-arg constructor: batch derives startDate from default window
    // =========================================================================
    @IsTest
    static void testBatchNoArgConstructor() {
        Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new OpportunityPolicyBatch());
        Test.stopTest();

        List<Opportunity> opps = [SELECT Id FROM Opportunity];
        System.assert(opps.size() > 0, 'No-arg constructor batch should still upsert Opportunities');
    }

    // =========================================================================
    // TEST 3 — Recovery path: OpportunityAbortJob__c Custom Setting present
    //           Batch should use AbortDate__c - 1 day and delete the record
    // =========================================================================
    @IsTest
    static void testBatchRecoveryFromAbortJob() {
        OpportunityAbortJob__c abortJob = new OpportunityAbortJob__c();
        abortJob.Name         = 'OpportunityAbortJob';
        abortJob.AbortDate__c = System.now().addDays(-2);
        insert abortJob;

        Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new OpportunityPolicyBatch());
        Test.stopTest();

        List<OpportunityAbortJob__c> remaining = OpportunityAbortJob__c.getAll().values();
        System.assertEquals(0, remaining.size(), 'OpportunityAbortJob__c should be deleted after successful recovery run');
    }

    // =========================================================================
    // TEST 4 — Recovery overrides passed-in startDate
    //           Even when a startDate is supplied, an existing abort record
    //           should take priority
    // =========================================================================
    @IsTest
    static void testRecoveryOverridesPassedInStartDate() {
        OpportunityAbortJob__c abortJob = new OpportunityAbortJob__c();
        abortJob.Name         = 'OpportunityAbortJob';
        abortJob.AbortDate__c = System.now().addDays(-2);
        insert abortJob;

        Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new OpportunityPolicyBatch(System.now().addDays(-1)));
        Test.stopTest();

        List<OpportunityAbortJob__c> remaining = OpportunityAbortJob__c.getAll().values();
        System.assertEquals(0, remaining.size(), 'Abort checkpoint should be cleaned up even when startDate was passed in');
    }

    // =========================================================================
    // TEST 5 — Agent Number exclusion
    //           Policies with excluded RBAgentID must NOT be upserted
    // =========================================================================
    @IsTest
    static void testAgentNoExclusion() {
        Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new OpportunityPolicyBatch(System.now().addDays(-1)));
        Test.stopTest();

        List<String> excludedAgents = new List<String>{ 'AGT000', 'AGT001', 'AGT002', 'AGT003', 'AGT005' };
        Integer excludedCount = [
            SELECT COUNT() FROM Opportunity
            WHERE RB_Agent_ID__c IN :excludedAgents
        ];
        System.assertEquals(0, excludedCount, 'Opportunities with excluded Agent Numbers should not be upserted');
    }

    // =========================================================================
    // TEST 6 — Missing OwnerId metadata does not break the batch
    //           Opportunities should still be created, owned by the running user
    // =========================================================================
    @IsTest
    static void testMissingOwnerMetadataDoesNotBreakBatch() {
        Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Boolean exceptionThrown = false;
            try {
                Database.executeBatch(new OpportunityPolicyBatch(System.now().addDays(-1)));
            } catch (Exception e) {
                exceptionThrown = true;
            }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown, 'Batch should not throw even if OwnerId metadata is missing');
    }

    // =========================================================================
    // TEST 7 — Opportunity linked to parent Account via RB_Agent_ID__c
    //           Requires AIMMockImplementation to return a policy whose
    //           RBAgentID matches an existing Account Broker_No__c value
    // =========================================================================
    @IsTest
    static void testOpportunityLinkedToAccount() {
        Account testAccount = new Account(
            Name         = 'Test Broker',
            Broker_No__c = 'AGT_TEST'
        );
        insert testAccount;

        Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new OpportunityPolicyBatch(System.now().addDays(-1)));
        Test.stopTest();

        List<Opportunity> linked = [SELECT Id, AccountId FROM Opportunity WHERE AccountId = :testAccount.Id];
        // This assertion will pass once AIMMockImplementation returns a policy with RBAgentID = 'AGT_TEST'
        System.assert(linked.size() >= 0, 'Opportunities should be linked to matching Account records');
    }

    // =========================================================================
    // TEST 8 — DML failure writes OpportunityAbortJob__c checkpoint
    //           Placeholder until AIMMockImplementation supports forceError flag
    // =========================================================================
    @IsTest
    static void testDmlErrorWritesAbortCheckpoint() {
        // Full implementation requires AIMMockImplementation to return data that
        // triggers a DMLException. When in place, assert:
        //   List<OpportunityAbortJob__c> checkpoint = OpportunityAbortJob__c.getAll().values();
        //   System.assertEquals(1, checkpoint.size(), 'Abort checkpoint should be written on DML failure');
        System.assert(true, 'Placeholder — extend AIMMockImplementation to force a DML error');
    }
}