global class AIMScheduler implements Schedulable {
   global void execute(SchedulableContext sc) {
      Database.executeBatch(new AccountBrokenBatch());
   }
}