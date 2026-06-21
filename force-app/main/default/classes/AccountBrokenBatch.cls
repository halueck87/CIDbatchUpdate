global class AccountBrokenBatch implements Database.Batchable<Account>, Database.AllowsCallouts, Database.Stateful {
    
	global Map<String,List<Contact>> contacts {get;set;}
    global Map<String,List<License__c>> licenses {get;set;}
    global Datetime startDate {get;set;}
    global Datetime startDateCS {get;set;}
    global String emailSend {get;set;}
    global Boolean deleteCS {get;set;}
    
    global AccountBrokenBatch(Datetime startDateFrom,String emailSendFrom){
        system.debug('##construct AccountBrokenBatch with parameters');
        startDate = startDateFrom;
        emailSend = emailSendFrom;
    }
    
    global AccountBrokenBatch(){
        system.debug('##construct AccountBrokenBatch');
    }
    
    global List<Account> start(Database.BatchableContext BC){
        system.debug('##start AccountBrokenBatch');
        contacts = new Map<String,List<Contact>>();
        licenses = new Map<String,List<License__c>>();
        List<Contact> contactsList;
        List<License__c> licensesList;
        List<Account> accounts = new List<Account>();
        deleteCS = false;
        startDateCS = System.now().addMinutes(-10);
        
        if(startDate==null){
            List< AccountAbortJob__c> aa = AccountAbortJob__c.getAll().values();
            if(aa.size()>0){
                startDate = aa.get(0).AbortDate__c.addDays(-1);
                deleteCS = true;
                //delete aa;
                //system.debug('startDateG: '+startDate);
                //system.debug('System.Now: '+system.now().addMinutes(-10));
            }
            else{
                startDate = system.now().addDays(-1).addMinutes(-10);
                //system.debug('startDate: '+startDate);
                //system.debug('startDateCS: '+startDateCS);
            }            
        }
        //system.debug('startDate: '+startDate);
        schemasDatacontractOrg200407Aimwebs.BrokerChangesGetListResponse response = AIMConnection.getAccounts(startDate);
        //system.debug('---responseStart: '+response);
        
        if(response!=null){
            if(emailSend!=null && emailSend!=''){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage(); 
                mail.setToAddresses(new String[] {emailSend}); 
                mail.setSubject('CID Information Broker'); 
                mail.setHtmlBody(response.toString()); 
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
            if(response.BrokerChangeList!=null && response.BrokerChangeList.Broker!=null){
                Date expiration;
                Date approved;
                Boolean active;
                String emailRegex;
                Pattern MyPattern;
                Matcher MyMatcher;
                String email; 
                String physicaladdress2;
                String mailingaddress2;
                String firstname;
                String lastname;
                String nameTemp;
                Set<String> setNOTInclude = new Set<String>();
                setNOTInclude.add('AGT000');
                setNOTInclude.add('AGT001');
                setNOTInclude.add('AGT002');
                setNOTInclude.add('AGT003');
                //setNOTInclude.add('AGT004');
                setNOTInclude.add('AGT005');
                //setNOTInclude.add('AGT006');
                //setNOTInclude.add('AGT007');
                for(schemasDatacontractOrg200407Aimwebs.Broker bro : response.BrokerChangeList.Broker){
                    if(!setNOTInclude.contains(bro.AgentNo)){
                        //system.debug('---bro.Approved: '+bro.Approved);
                        expiration = null;
                        approved = null;
                        physicaladdress2 = '';
                        mailingaddress2 = '';
                        firstname = '';
                        lastname = '';
                        if(bro.Expiration!=null && String.valueOf(bro.Expiration)!='0001-01-01 00:00:00' && String.valueOf(bro.Expiration)!='0001-01-01T00:00:00' && String.valueOf(bro.Expiration)!='0001-12-31 16:00:00') 
                            expiration = Date.valueOf(bro.Expiration);
                        if(bro.Approved!=null && String.valueOf(bro.Approved)!='0001-01-01 00:00:00' && String.valueOf(bro.Approved)!='0001-01-01T00:00:00' && String.valueOf(bro.Approved)!='0001-12-31 16:00:00') 
                            approved = Date.valueOf(bro.Approved);
                        if(bro.PhysicalAddress2!=null && bro.PhysicalAddress2!='null' && bro.PhysicalAddress2!='')
                            physicaladdress2 = bro.PhysicalAddress2;
                        if(bro.MailingAddress2!=null && bro.MailingAddress2!='null' && bro.MailingAddress2!='')
                            mailingaddress2 = bro.MailingAddress2;
                        
                        
                        accounts.add(new Account(
                            OwnerId = '00541000002npp2',// Production
                            //OwnerId = '00563000001JfjF',// Sandbox
                            Name = bro.Name,
                            Broker_No__c = bro.AgentNo,
                            Status__c = bro.Status,
                            Approved__c = approved,
                            Phone = bro.Phone,
                            Fax = bro.Fax,
                            Website = bro.WebSite,
                            Expiration__c = expiration,
                            ShippingStreet = bro.PhysicalAddress1 + ' ' + physicaladdress2,
                            ShippingPostalCode = bro.PhysicalZip,
                            ShippingCity = bro.PhysicalCity,
                            ShippingState = bro.PhysicalState,
                            BillingStreet = bro.MailingAddress1 + ' ' + mailingaddress2,
                            BillingPostalCode = bro.MailingZip,
                            BillingCity = bro.MailingCity,
                            BillingState = bro.MainingState
                        ));
                        
                        if(bro.ContactsChangeList!=null){
                            if(bro.ContactsChangeList.Contact!=null){
                                contactsList = new List<Contact>();
                                for(schemasDatacontractOrg200407Aimwebs.Contact con : bro.ContactsChangeList.Contact){
                                    if(con.NameKeyPK!=null && con.Name!=null && con.Name.trim()!=''){
                                        active = null;
                                        email = null;
                                        if(con.Active!=null){
                                            if(con.Active=='0') active = true;
                                            else active = false;
                                        }
                                        
                                        if(con.Email!=null && con.Email.trim()!=''){
                                            emailRegex = '([a-zA-Z0-9_\\-\\.]+)@((\\[a-z]{1,3}\\.[a-z]{1,3}\\.[a-z]{1,3}\\.)|(([a-zA-Z0-9\\-]+\\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})';
                                            MyPattern = Pattern.compile(emailRegex);
                                            MyMatcher = MyPattern.matcher(con.Email);
                                            if (MyMatcher.matches()) {
                                                email = con.Email;
                                            }
                                        }
 
                                        if(con.Name!=null){
                                            if(con.Name.trim()!=''){
                                                nameTemp = con.Name.trim();
                                                system.debug(nameTemp);
                                                if(nameTemp.indexOf(' ')!=-1){
                                                    firstname = nameTemp.substring(0,nameTemp.indexOf(' '));
                                                    lastname = nameTemp.substring(nameTemp.indexOf(' '));
                                                }
                                                else{
                                                    lastname = con.Name;
                                                    firstname = null;
                                                }
                                            }
                                        }
                                        

                                        contactsList.add(new Contact(
                                            OwnerId = '00541000002npp2',// Production
                                            //OwnerId = '00563000001JfjF',// Sandbox
                                            NameKeyPK__c = String.valueOf(con.NameKeyPK),
                                            FirstName = firstname,
                                            LastName = lastname,
                                            Title = con.Position,
                                            Phone = con.Phone,
                                            Ext__c = con.Ext,
                                            Active__c = active,
                                            Fax = con.Fax,
                                            Email = email,
                                            MobilePhone = con.CellPhone,
                                            OtherPhone = con.OtherPhone
                                        ));
                                    }
                                }
                                contacts.put(bro.AgentNo,contactsList.clone());
                            }
                        }
                        
                        if(bro.AgentLicensesChangeList!=null){
                            if(bro.AgentLicensesChangeList.License!=null){
                                licensesList = new List<License__c>();
                                for(schemasDatacontractOrg200407Aimwebs.License lic : bro.AgentLicensesChangeList.License){
                                    if(lic.LicenseKey_PK!=null){
                                        expiration = null;
                                        active = null;
                                        if(lic.Active!=null){
                                            if(lic.Active=='Y') active = true;
                                            else active = false;
                                        }
                                        if(lic.DateExpiration!=null && String.valueOf(lic.DateExpiration)!='0001-01-01 00:00:00' && String.valueOf(lic.DateExpiration)!='0001-12-31 16:00:00') expiration = Date.valueOf(lic.DateExpiration);
                                    
                                        licensesList.add(new License__c(
                                            Active__c = active,
                                            State__c = lic.State,
                                            Licensed_Individuals__c = lic.LicensedIndividuals,
                                            Name = lic.License,
                                            External_ID__c = String.valueOf(lic.LicenseKey_PK),
                                            Expiration_Date__c = expiration
                                        ));
                                    }
                                }
                                licenses.put(bro.AgentNo,licensesList.clone());
                            }
                        }
                    }
                }
            }
        }
        
        return accounts;
    }
    
    global void execute(Database.BatchableContext BC, List<Account> scope){
        system.debug('##execute AccountBrokenBatch');
        if(deleteCS){
            List< AccountAbortJob__c> aa = AccountAbortJob__c.getAll().values();
            if(aa.size()>0){
                delete aa;                
            }
            deleteCS = false;
            //system.debug('startDateG2: '+startDate);
            //system.debug('System.Now2: '+system.now().addMinutes(-10));
        }

        if(scope.size()>0){
            try{
                upsert scope Broker_No__c;

                if(contacts.size()>0){
                    Map<String,Contact> contactsInsert = new Map<String,Contact>();
                    for(Account acc : scope){
                        if(contacts.get(acc.Broker_No__c)!=null){
                            for(Contact conTemp : contacts.get(acc.Broker_No__c)){
                                if(conTemp.LastName==null || conTemp.LastName.trim()=='') system.debug(conTemp);
                                conTemp.AccountId = acc.Id;
                                contactsInsert.put(conTemp.NameKeyPK__c,conTemp);
                            }
                        }
                    }
                    upsert contactsInsert.values() NameKeyPK__c;
                }
                
                if(licenses.size()>0){
                    Map<String,License__c> licensesInsert = new Map<String,License__c>();
                    for(Account acc : scope){
                        if(licenses.get(acc.Broker_No__c)!=null){
                            for(License__c licTemp : licenses.get(acc.Broker_No__c)){
                                licTemp.Broker__c = acc.Id;
                                licensesInsert.put(licTemp.External_ID__c,licTemp);
                            }
                        }
                    }
                    
                    upsert licensesInsert.values() External_ID__c;                    
                }
			}catch(DMLException e){
                system.debug('##Error Executing AccountBrokenBatch: '+e.getMessage());
                system.abortJob(BC.getJobId());
                AccountAbortJob__c aa = new AccountAbortJob__c();
                aa.Name = 'AccountAbortJob';
                aa.AbortDate__c = startDateCS;
                insert aa;
        	}
        }              
	}

    global void finish(Database.BatchableContext BC){
        system.debug('##finish AccountBrokenBatch');
        if(!Test.isRunningTest()) Database.executeBatch(new OpportunityPolicyBatch(startDate,emailSend));
    }
}