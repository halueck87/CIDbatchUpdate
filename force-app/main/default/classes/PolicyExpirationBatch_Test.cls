@isTest
public class PolicyExpirationBatch_Test {
    public static String CRON_EXP = '0 0 0 15 3 ? 2030';
    
    static testMethod void PolicyExpirationSchedulerTest(){
        Test.startTest();
            System.schedule('PolicyExpirationScheduler',CRON_EXP,new PolicyExpirationScheduler());
        Test.stopTest();
    }
    
    public static testmethod void test01(){
        Opportunity opp = new Opportunity(Name='Test',StageName='Policy Expired',CloseDate=system.today(),Expiration_Date__c=system.today().addDays(-366));
        insert opp;
        Test.startTest();
		Database.executeBatch(new PolicyExpirationBatch());
        Test.stopTest();
        system.assertEquals(0,[Select Id From Opportunity].size());
    }
}