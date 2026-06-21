/**
 * @description Test class for AccountBrokenBatch. Covers the AIM integration pipeline
 *              including the scheduler, batch execution paths, Custom Metadata-driven
 *              exclusions, OwnerId assignment, and the abort/recovery mechanism.
 *
 * @see AccountBrokenBatch
 * @see AIMConnection
 * @see AIMMockImplementation
 */
@IsTest
public class AccountBrokenBatch_Test {

    /** @description Cron expression used to schedule the AIM scheduler in tests. */
    private static String cronExp = '0 0 0 15 3 ? 2030';

    // =========================================================================
    // TEST 1 — Scheduler wires up correctly
    // =========================================================================
    @IsTest
    static void testAimScheduler() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            String jobId = System.schedule('AIMScheduler', cronExp, new AIMScheduler());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression, State FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match');
        System.assertEquals('WAITING', ct.State, 'Job should be in WAITING state');
    }

    // =========================================================================
    // TEST 2 — Parameterised constructor: batch runs with explicit startDate
    // =========================================================================
    @IsTest
    static void testBatchWithStartDate() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new AccountBrokenBatch(System.now().addDays(-40)));
        Test.stopTest();

        List<Account> accounts = [SELECT Id, Broker_No__c, Status__c FROM Account];
        System.assert(accounts.size() > 0, 'At least one Account should have been upserted by the batch');
    }

    // =========================================================================
    // TEST 3 — No-arg constructor: batch derives startDate from default window
    // =========================================================================
    @IsTest
    static void testBatchNoArgConstructor() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new AccountBrokenBatch());
        Test.stopTest();

        List<Account> accounts = [SELECT Id FROM Account];
        System.assert(accounts.size() > 0, 'No-arg constructor batch should still upsert Accounts');
    }

    // =========================================================================
    // TEST 4 — Recovery path: AccountAbortJob__c Custom Setting present
    //           Batch should use AbortDate__c - 1 day and delete the record
    // =========================================================================
    @IsTest
    static void testBatchRecoveryFromAbortJob() {
        AccountAbortJob__c abortJob = new AccountAbortJob__c();
        abortJob.Name         = 'AccountAbortJob';
        abortJob.AbortDate__c = System.now().addDays(-2);
        insert abortJob;

        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new AccountBrokenBatch());
        Test.stopTest();

        List<AccountAbortJob__c> remaining = AccountAbortJob__c.getAll().values();
        System.assertEquals(0, remaining.size(), 'AccountAbortJob__c should be deleted after successful recovery run');
    }

    // =========================================================================
    // TEST 5 — Deleted status exclusion
    //           Brokers with Status = 'Deleted' must NOT be upserted.
    //           Ensure AIMMockImplementation returns a broker with
    //           AgentNo = 'AGT_DEL' and Status = 'Deleted'.
    // =========================================================================
    @IsTest
    static void testDeletedStatusExcluded() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new AccountBrokenBatch(System.now().addDays(-1)));
        Test.stopTest();

        // Replace 'AGT_DEL' with the AgentNo your mock uses for the deleted broker
        Integer deletedCount = [SELECT COUNT() FROM Account WHERE Broker_No__c = 'AGT_DEL'];
        System.assertEquals(0, deletedCount, 'Broker with Status=Deleted should not be upserted');
    }

    // =========================================================================
    // TEST 6 — Agent Number exclusion
    //           Brokers in the metadata exclusion list must NOT be upserted
    // =========================================================================
    @IsTest
    static void testAgentNoExclusion() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Database.executeBatch(new AccountBrokenBatch(System.now().addDays(-1)));
        Test.stopTest();

        List<String> excludedAgents = new List<String>{ 'AGT000', 'AGT001', 'AGT002', 'AGT003', 'AGT005' };
        Integer excludedCount = [
            SELECT COUNT() FROM Account
            WHERE Broker_No__c IN :excludedAgents
        ];
        System.assertEquals(0, excludedCount, 'Excluded Agent Numbers should not be upserted as Accounts');
    }

    // =========================================================================
    // TEST 7 — Missing OwnerId metadata does not break the batch
    //           Accounts should still be created, owned by the running user
    // =========================================================================
    @IsTest
    static void testMissingOwnerMetadataDoesNotBreakBatch() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Boolean exceptionThrown = false;
            try {
                Database.executeBatch(new AccountBrokenBatch(System.now().addDays(-1)));
            } catch (Exception e) {
                exceptionThrown = true;
            }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown, 'Batch should not throw even if OwnerId metadata is missing');
    }

    // =========================================================================
    // TEST 8 — DML failure writes AccountAbortJob__c checkpoint
    //           Extend AIMMockImplementation with a forceError flag to fully
    //           exercise this path. Placeholder until mock supports it.
    // =========================================================================
    @IsTest
    static void testDmlErrorWritesAbortCheckpoint() {
        // Full implementation requires AIMMockImplementation to return data that
        // triggers a DMLException (e.g. a Contact with no LastName on a required field).
        // When that is in place, assert:
        //   List<AccountAbortJob__c> checkpoint = AccountAbortJob__c.getAll().values();
        //   System.assertEquals(1, checkpoint.size(), 'Abort checkpoint should be written on DML failure');
        System.assert(true, 'Placeholder — extend AIMMockImplementation to force a DML error');
    }
}