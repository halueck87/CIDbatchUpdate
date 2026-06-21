global class PolicyExpirationBatch implements Database.Batchable<sObject>{
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('##start PolicyExpirationBatch');
        return Database.getQueryLocator('Select Id, Name, Expiration_Date__c, StageName  From Opportunity WHERE Expiration_Date__c < LAST_N_DAYS:365 AND StageName NOT IN (\'Policy In Force\',\'Binder Issued\') ORDER BY Expiration_Date__c ASC');
    }
    
    global void execute(Database.BatchableContext BC, List<Opportunity> scope){
        system.debug('##execute PolicyExpirationBatch');
        try{ delete scope; }catch(DMLException e){ system.debug('##Error in PolicyExpirationBatch: '+e.getMessage()); system.abortJob(BC.getJobId()); }
    }
    
    global void finish(Database.BatchableContext BC){
        system.debug('##finish PolicyExpirationBatch');
    }
}