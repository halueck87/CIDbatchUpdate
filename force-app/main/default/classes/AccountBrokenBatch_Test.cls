@isTest
public class AccountBrokenBatch_Test {
    
    public static String CRON_EXP = '0 0 0 15 3 ? 2030';
    
    static testMethod void AIMSchedulerTest(){
        System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Test.startTest();
            System.schedule('AIMScheduler',CRON_EXP,new AIMScheduler());
        Test.stopTest();
    }
    
	public static testmethod void test01(){
        Test.startTest();
		System.Test.setMock(WebServiceMock.class, new AIMMockImplementation());
        Database.executeBatch(new AccountBrokenBatch(system.now().addDays(-40),''));
        Test.stopTest();
	}
}