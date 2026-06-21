global class OpportunityPolicyBatch implements Database.Batchable<Opportunity>, Database.AllowsCallouts, Database.Stateful {

    global Set<String> setRBAgentId {get;set;}
    global Datetime startDate {get;set;}
    global Datetime startDateCS {get;set;}
    global Boolean deleteCS {get;set;}
    global String emailSend {get;set;}
    
    global OpportunityPolicyBatch(Datetime startDateFrom,String emailSendFrom){
        system.debug('##construct OpportunityPolicyBatch with parameters');
        startDate = startDateFrom;
        emailSend = emailSendFrom;
    }
    
    global OpportunityPolicyBatch(){
        system.debug('##construct OpportunityPolicyBatch');
    }
    
    global List<Opportunity> start(Database.BatchableContext BC){
        system.debug('##start OpportunityPolicyBatch');
        List<Opportunity> opportunities = new List<Opportunity>();
        setRBAgentId = new Set<String>();
        deleteCS = false;        
        startDateCS = System.now().addMinutes(-10);
        
        if(startDate==null){
            List<OpportunityAbortJob__c> aa = OpportunityAbortJob__c.getAll().values();
            if(aa.size()>0){
                startDate = aa.get(0).AbortDate__c.addDays(-1);
                deleteCS = true;
                //delete aa;
                system.debug('startDateG: '+startDate);
                //system.debug('System.Now: '+system.now().addDays(-1).addMinutes(-10));
            }
            else{
                //system.debug('System.Now: '+system.now().addDays(-1).addHours(-12).addMinutes(-10));
                startDate = system.now().addDays(-1).addMinutes(-10);
            }  
        }
        else{
            List<OpportunityAbortJob__c> aa = OpportunityAbortJob__c.getAll().values();
            if(aa.size()>0){
                startDate = aa.get(0).AbortDate__c.addDays(-1);
                deleteCS = true;
                //delete aa;
                //system.debug('startDateG: '+startDate);
                //system.debug('System.Now: '+system.now().addMinutes(-10));
            }
        }
        schemasDatacontractOrg200407Aimwebs.PolicyChangesGetListResponse response = AIMConnection.getOpportunities(startDate);
        system.debug('RESPONSE: '+response);
        if(response!=null){
            if(emailSend!=null && emailSend!=''){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage(); 
                mail.setToAddresses(new String[] {emailSend}); 
                mail.setSubject('CID Information Policy'); 
                mail.setHtmlBody(response.toString()); 
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
            if(response.PolicyChangeList!=null && response.PolicyChangeList.Policy!=null){
                Date closeDate;
                Date expirationDate;
                Boolean renewal;            
                Set<String> setNOTInclude = new Set<String>();
                setNOTInclude.add('AGT000');
                setNOTInclude.add('AGT001');
                setNOTInclude.add('AGT002');
                setNOTInclude.add('AGT003');
                //setNOTInclude.add('AGT004');
                setNOTInclude.add('AGT005');
                //setNOTInclude.add('AGT006');
                //setNOTInclude.add('AGT007');
                Set<String> attentionSet = new Set<String>();
                for(schemasDatacontractOrg200407Aimwebs.Policy pol : response.PolicyChangeList.Policy){
                    if(pol.ReferenceID!=null && !setNOTInclude.contains(pol.RBAgentID)){
                        if(pol.NameKeyPk!=null) attentionSet.add(String.valueOf(pol.NameKeyPk).trim());
                    }
                }
                Map<String,String> contactMap = new Map<String,String>();
                for(Contact conAux : [Select Id, NameKeyPK__c From Contact WHERE NameKeyPK__c IN: attentionSet]) contactMap.put(conAux.NameKeyPK__c,conAux.Id);
                    
                for(schemasDatacontractOrg200407Aimwebs.Policy pol : response.PolicyChangeList.Policy){
                    if(pol.ReferenceID!=null && !setNOTInclude.contains(pol.RBAgentID)){
                        closeDate = null;
                        renewal = null;
                        expirationDate = null;
                        if(pol.Effective!=null && String.valueOf(pol.Effective)!='0001-01-01 00:00:00' && String.valueOf(pol.Effective)!='0001-01-01T00:00:00' && String.valueOf(pol.Effective)!='0001-12-31 16:00:00') 
                            closeDate = Date.valueOf(pol.Effective);
                        else 
                            closeDate = system.today();
                        if(pol.Expiration!=null && String.valueOf(pol.Expiration)!='0001-01-01 00:00:00' && String.valueOf(pol.Expiration)!='0001-01-01T00:00:00' && String.valueOf(pol.Expiration)!='0001-12-31 16:00:00') 
                            expirationDate = Date.valueOf(pol.Expiration);
                        
                        if(pol.Renewal!=null){
                            if(pol.Renewal=='Y') renewal = true;
                            else renewal = false;
                        }
                        
                        opportunities.add(new Opportunity(
                            OwnerId = '00541000002npp2',// Production
                            //OwnerId = '00563000001JfjF',// Sandbox
                            Amount = pol.Premium,
                            Name = String.valueOf(pol.ReferenceID),
                            Tax_State__c = pol.TaxState,
                            Renewal__c = renewal,
                            RB_Agent_ID__c = pol.RBAgentID,
                            Policy_Number__c = pol.PolicyNumber,
                            Reference_ID__c = String.valueOf(pol.ReferenceID),
                            CloseDate = closeDate,
                            StageName = pol.Status,
                            Market_Co__c = pol.MarketCompany,
                            Coverage__c = pol.Coverage,
                            Team_Dept__c = pol.TeamDept,
                            Producer__c = pol.Producer,
                            Product__c = pol.Product,
                            Insured__c = pol.Insured,
                            Expiration_Date__c = expirationDate,
                            Retail_Agt_Bkr__c = pol.RetailAgtBkr,
                            NameKeyPk__c = String.valueOf(pol.NameKeyPk), //ADD CHANGE
                            Attention__c = contactMap.get(String.valueOf(pol.NameKeyPk).trim()) //ADD CHANGE
                        ));
                        
                        if(pol.RBAgentID!=null && pol.RBAgentID!='') setRBAgentId.add(pol.RBAgentID);
                    }
                }
            }
        }
        
        return opportunities;
    }
    
    global void execute(Database.BatchableContext BC, List<Opportunity> scope){
        system.debug('##execute OpportunityPolicyBatch');
        if(deleteCS){
            List<OpportunityAbortJob__c> aa = OpportunityAbortJob__c.getAll().values();
            if(aa.size()>0){
                delete aa;                
            }
            deleteCS = false;
        }
        
        if(scope.size()>0){
            try{
                Map<String,Id> mapAccount = new Map<String,Id>();
                for(Account acc : [Select Id, Broker_No__c From Account WHERE Broker_No__c IN: setRBAgentId]) mapAccount.put(acc.Broker_No__c,acc.Id);
                
                Map<String,Opportunity> mapOpp = new Map<String,Opportunity>();
                for(Opportunity opp : scope){
                    if(mapAccount.get(opp.RB_Agent_ID__c)!=null) opp.AccountId = mapAccount.get(opp.RB_Agent_ID__c);
                    
                    mapOpp.put(opp.Reference_ID__c,opp);
                }
                
                upsert mapOpp.values() Reference_ID__c;
                
			}catch(DMLException e){
                system.debug('##Error Executing OpportunityPolicyBatch: '+e.getMessage());
                system.abortJob(BC.getJobId());
                OpportunityAbortJob__c aa = new OpportunityAbortJob__c();
                aa.Name = 'OpportunitytAbortJob';
                aa.AbortDate__c = startDateCS;
                insert aa;
        	}
        }
	}

    global void finish(Database.BatchableContext BC){
        system.debug('##finish OpportunityPolicyBatch');
    }
}