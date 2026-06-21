/**
 * @description Utility class for managing the AIM integration scheduled jobs.
 *              Because Salesforce does not support cron intervals shorter than 1 hour,
 *              six staggered scheduled jobs are used to approximate a run every 10 minutes.
 *
 *              Run methods via Anonymous Apex in VS Code or Developer Console
 *              instead of manually configuring scheduled jobs through Setup UI.
 *
 *              Schedule all six jobs:
 *                  AIMSchedulerManager.scheduleAll();
 *
 *              Abort all six jobs:
 *                  AIMSchedulerManager.abortAll();
 *
 *              Check status of all jobs:
 *                  AIMSchedulerManager.getJobStatus();
 *
 *              Run the batch immediately without waiting for schedule:
 *                  AIMSchedulerManager.runNow();
 *
 *              Run from a specific date:
 *                  AIMSchedulerManager.runFrom(Datetime.newInstance(2026, 6, 1, 0, 0, 0));
 *
 * @see AIMScheduler
 * @see AccountBrokenBatch
 */
public class AIMSchedulerManager {

    /**
     * @description The six staggered job definitions that together approximate
     *              a run every 10 minutes throughout the hour.
     *              Format: job name → cron expression (minute offset within each hour).
     */
    private static final Map<String,String> SCHEDULED_JOBS = new Map<String,String>{
        'AIM Sync 00min' => '0 0  * * * ?',
        'AIM Sync 10min' => '0 10 * * * ?',
        'AIM Sync 20min' => '0 20 * * * ?',
        'AIM Sync 30min' => '0 30 * * * ?',
        'AIM Sync 40min' => '0 40 * * * ?',
        'AIM Sync 50min' => '0 50 * * * ?'
    };

    // =========================================================================
    // Public Methods
    // =========================================================================

    /**
     * @description Schedules all six staggered AIM sync jobs to approximate a run
     *              every 10 minutes. Safely aborts any existing jobs with the same
     *              names before scheduling to prevent duplicates.
     *              Uses a single SOQL query before the loop to avoid governor limit violations.
     */
    public static void scheduleAll() {
        Map<String,Id> existingJobIds = queryExistingJobIds();

        for (String jobName : SCHEDULED_JOBS.keySet()) {
            if (existingJobIds.containsKey(jobName)) {
                System.abortJob(existingJobIds.get(jobName));
                System.debug('##Aborted existing job: ' + jobName);
            }
            String jobId = System.schedule(jobName, SCHEDULED_JOBS.get(jobName), new AIMScheduler());
            System.debug('##Scheduled: ' + jobName + ' | Cron: ' + SCHEDULED_JOBS.get(jobName) + ' | Job ID: ' + jobId);
        }
        System.debug('##All 6 AIM Sync jobs scheduled successfully.');
    }

    /**
     * @description Aborts all six AIM sync scheduled jobs.
     *              Safe to call even if some or all jobs are not currently scheduled.
     *              Uses a single SOQL query before the loop to avoid governor limit violations.
     */
    public static void abortAll() {
        Map<String,Id> existingJobIds = queryExistingJobIds();

        for (String jobName : SCHEDULED_JOBS.keySet()) {
            if (existingJobIds.containsKey(jobName)) {
                System.abortJob(existingJobIds.get(jobName));
                System.debug('##Aborted existing job: ' + jobName);
            }
        }
        System.debug('##All AIM Sync scheduled jobs aborted.');
    }

    /**
     * @description Runs the AIM integration batch pipeline immediately without waiting
     *              for the next scheduled trigger. Uses a default lookback of 1 day.
     */
    public static void runNow() {
        System.debug('##Running AIM batch immediately');
        Database.executeBatch(new AccountBrokenBatch());
    }

    /**
     * @description Runs the AIM integration batch pipeline immediately from a specific
     *              start date. Useful for reprocessing a specific date range.
     * @param fromDate The datetime from which to retrieve changed records from AIM.
     */
    public static void runFrom(Datetime fromDate) {
        System.debug('##Running AIM batch from: ' + fromDate);
        Database.executeBatch(new AccountBrokenBatch(fromDate));
    }

    /**
     * @description Logs the status of all six AIM sync scheduled jobs to the debug log.
     *              Reports next fire time, state, and times triggered for each job.
     *              Returns the list of found CronTrigger records.
     * @return List of CronTrigger records for any currently scheduled AIM sync jobs.
     */
    public static List<CronTrigger> getJobStatus() {
        Set<String> jobNames = SCHEDULED_JOBS.keySet();
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name, CronExpression, NextFireTime, State, TimesTriggered
            FROM CronTrigger
            WHERE CronJobDetail.Name IN :jobNames
            ORDER BY CronExpression ASC
        ];

        System.debug('##AIM Sync Job Status (' + jobs.size() + ' of 6 scheduled):');
        for (CronTrigger job : jobs) {
            System.debug(
                '  ' + job.CronJobDetail.Name +
                ' | Next: ' + job.NextFireTime +
                ' | State: ' + job.State +
                ' | Triggered: ' + job.TimesTriggered + 'x'
            );
        }

        Set<String> foundNames = new Set<String>();
        for (CronTrigger job : jobs) {
            foundNames.add(job.CronJobDetail.Name);
        }
        for (String jobName : jobNames) {
            if (!foundNames.contains(jobName)) {
                System.debug('  ' + jobName + ' | NOT SCHEDULED');
            }
        }

        return jobs;
    }

    // =========================================================================
    // Private Helpers
    // =========================================================================

    /**
     * @description Queries all currently scheduled AIM sync jobs in a single SOQL call
     *              and returns them as a map of job name to CronTrigger Id.
     *              Called before loops in scheduleAll() and abortAll() to avoid
     *              SOQL queries inside loops (PMD: OperationWithLimitsInLoop).
     * @return Map of job name to CronTrigger Id for all currently scheduled AIM sync jobs.
     */
    private static Map<String,Id> queryExistingJobIds() {
        Set<String> jobNames = SCHEDULED_JOBS.keySet();
        Map<String,Id> jobMap = new Map<String,Id>();
        for (CronTrigger ct : [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name IN :jobNames
        ]) {
            jobMap.put(ct.CronJobDetail.Name, ct.Id);
        }
        return jobMap;
    }
}