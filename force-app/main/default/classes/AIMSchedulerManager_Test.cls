/**
 * @description Test class for AIMSchedulerManager. Covers all public methods including
 *              scheduling, aborting, status checking, and immediate batch execution.
 *
 *              Note: All tests that call scheduleAll() require a WebServiceMock because
 *              Salesforce executes scheduled jobs synchronously within Test.startTest()
 *              and Test.stopTest(), which triggers the AIM web service callout.
 *
 * @see AIMSchedulerManager
 * @see AIMScheduler
 * @see AccountBrokenBatch
 */
@IsTest
public class AIMSchedulerManager_Test {

    // =========================================================================
    // TEST 1 — scheduleAll() creates all six scheduled jobs
    // =========================================================================
    @IsTest
    static void testScheduleAllCreatesAllJobs() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            AIMSchedulerManager.scheduleAll();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'AIM Sync%'
        ];
        System.assertEquals(6, jobs.size(), 'All 6 AIM Sync jobs should be scheduled');
    }

    // =========================================================================
    // TEST 2 — scheduleAll() is idempotent — calling twice does not duplicate jobs
    // =========================================================================
    @IsTest
    static void testScheduleAllIsIdempotent() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            AIMSchedulerManager.scheduleAll();
            AIMSchedulerManager.scheduleAll();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'AIM Sync%'
        ];
        System.assertEquals(6, jobs.size(), 'Calling scheduleAll() twice should not create duplicate jobs');
    }

    // =========================================================================
    // TEST 3 — abortAll() removes all six scheduled jobs
    // =========================================================================
    @IsTest
    static void testAbortAllRemovesAllJobs() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            AIMSchedulerManager.scheduleAll();
            AIMSchedulerManager.abortAll();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'AIM Sync%'
        ];
        System.assertEquals(0, jobs.size(), 'All AIM Sync jobs should be aborted');
    }

    // =========================================================================
    // TEST 4 — abortAll() is safe when no jobs are scheduled
    // =========================================================================
    @IsTest
    static void testAbortAllWhenNoJobsScheduled() {
        Test.startTest();
            Boolean exceptionThrown = false;
            try {
                AIMSchedulerManager.abortAll();
            } catch (Exception e) {
                exceptionThrown = true;
            }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown, 'abortAll() should not throw when no jobs are scheduled');
    }

    // =========================================================================
    // TEST 5 — getJobStatus() returns all scheduled jobs
    // =========================================================================
    @IsTest
    static void testGetJobStatusReturnsScheduledJobs() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            AIMSchedulerManager.scheduleAll();
            List<CronTrigger> jobs = AIMSchedulerManager.getJobStatus();
        Test.stopTest();

        System.assertEquals(6, jobs.size(), 'getJobStatus() should return all 6 scheduled jobs');
    }

    // =========================================================================
    // TEST 6 — getJobStatus() returns empty list when no jobs scheduled
    // =========================================================================
    @IsTest
    static void testGetJobStatusWhenNoJobsScheduled() {
        Test.startTest();
            List<CronTrigger> jobs = AIMSchedulerManager.getJobStatus();
        Test.stopTest();

        System.assertEquals(0, jobs.size(), 'getJobStatus() should return empty list when no jobs are scheduled');
    }

    // =========================================================================
    // TEST 7 — runNow() executes the batch without exception
    // =========================================================================
    @IsTest
    static void testRunNow() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Boolean exceptionThrown = false;
            try {
                AIMSchedulerManager.runNow();
            } catch (Exception e) {
                exceptionThrown = true;
            }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown, 'runNow() should execute without throwing an exception');
    }

    // =========================================================================
    // TEST 8 — runFrom() executes the batch from a specific date without exception
    // =========================================================================
    @IsTest
    static void testRunFrom() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            Boolean exceptionThrown = false;
            try {
                AIMSchedulerManager.runFrom(Datetime.newInstance(2026, 1, 1, 0, 0, 0));
            } catch (Exception e) {
                exceptionThrown = true;
            }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown, 'runFrom() should execute without throwing an exception');
    }

    // =========================================================================
    // TEST 9 — abortAll() then scheduleAll() cleanly reschedules all jobs
    //           Simulates the recommended post-deployment pattern
    // =========================================================================
    @IsTest
    static void testAbortThenReschedule() {
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            AIMSchedulerManager.scheduleAll();
            AIMSchedulerManager.abortAll();
            AIMSchedulerManager.scheduleAll();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'AIM Sync%'
        ];
        System.assertEquals(6, jobs.size(), 'All 6 jobs should be active after abort and reschedule');
    }
}