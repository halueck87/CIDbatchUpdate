@isTest
public class OpportunityPolicyBatch_Test {
    
    public static testmethod void test01(){
        Test.startTest();
		Test.setMock(WebServiceMock.class, new AIMMockImplementation());
		Database.executeBatch(new OpportunityPolicyBatch(system.now().addDays(-40),''));
        Test.stopTest();
    }
}