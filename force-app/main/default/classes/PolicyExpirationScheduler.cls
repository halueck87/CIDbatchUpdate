global class PolicyExpirationScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executebatch(new PolicyExpirationBatch());
    }
}