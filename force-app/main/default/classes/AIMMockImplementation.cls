@isTest
global class AIMMockImplementation implements WebServiceMock  {
    
    global void doInvoke(Object stub,Object request,Map<String, Object> response,String endpoint,String soapAction,String requestName,String responseNS,String responseName,String responseType) {
        if(request instanceOf tempuriOrg.WSLogIn_element) {
            tempuriOrg.WSLogInResponse_element respElement = new tempuriOrg.WSLogInResponse_element();
            respElement.WSLogInResult = 'key';
            response.put('response_x', respElement);
        }
        else if(request instanceOf tempuriOrg.BrokerChangesGetList_element) {
            schemasDatacontractOrg200407Aimwebs.License testLicense = new schemasDatacontractOrg200407Aimwebs.License();
            testLicense.License = '54321';
            testLicense.LicenseKey_PK = 123;
            testLicense.Active = '0';
            
            List<schemasDatacontractOrg200407Aimwebs.License> testListLicense = new List<schemasDatacontractOrg200407Aimwebs.License>();
            testListLicense.add(testLicense);
            
            schemasDatacontractOrg200407Aimwebs.ArrayOfLicense testArrLicense = new schemasDatacontractOrg200407Aimwebs.ArrayOfLicense();
            testArrLicense.License = testListLicense;
            
            schemasDatacontractOrg200407Aimwebs.Contact testContact = new schemasDatacontractOrg200407Aimwebs.Contact();
            testContact.Name = 'Test Test';
            testContact.NameKeyPK = 123;
            testContact.Email = 'test@gmail.com';
            testContact.Active = '0';
            
            List<schemasDatacontractOrg200407Aimwebs.Contact> testListContact = new List<schemasDatacontractOrg200407Aimwebs.Contact>();
            testListContact.add(testContact);
            
            schemasDatacontractOrg200407Aimwebs.ArrayOfContact testArrContact = new schemasDatacontractOrg200407Aimwebs.ArrayOfContact();
            testArrContact.Contact = testListContact;
            
            schemasDatacontractOrg200407Aimwebs.Broker testBroker = new schemasDatacontractOrg200407Aimwebs.Broker();
            testBroker.AgentNo = '1234';
            testBroker.Name = 'Test';
            testBroker.Phone = '123456789';
            testBroker.Expiration = system.now();
            testBroker.ContactsChangeList = testArrContact;
            testBroker.AgentLicensesChangeList = testArrLicense;
            
            List<schemasDatacontractOrg200407Aimwebs.Broker> testListBroker = new List<schemasDatacontractOrg200407Aimwebs.Broker>();
            testListBroker.add(testBroker);
                
            schemasDatacontractOrg200407Aimwebs.ArrayOfBroker testArrBroker = new schemasDatacontractOrg200407Aimwebs.ArrayOfBroker();
            testArrBroker.Broker = testListBroker;
                
            schemasDatacontractOrg200407Aimwebs.BrokerChangesGetListResponse test = new schemasDatacontractOrg200407Aimwebs.BrokerChangesGetListResponse();
            test.BrokerChangeList = testArrBroker;
            
            tempuriOrg.BrokerChangesGetListResponse_element respElement = new tempuriOrg.BrokerChangesGetListResponse_element();
            respElement.BrokerChangesGetListResult = test;
            response.put('response_x', respElement);
        }
        else if(request instanceOf tempuriOrg.PolicyChangesGetList_element) {
            schemasDatacontractOrg200407Aimwebs.Policy testPolicy = new schemasDatacontractOrg200407Aimwebs.Policy();
            testPolicy.ReferenceID = 123;
            testPolicy.PolicyNumber = '1234';
            testPolicy.QuoteID = '123456789';
            testPolicy.Renewal = '0';
            testPolicy.Status = 'Pending Cancel';
            testPolicy.NameKeyPk = 0;
            
            List<schemasDatacontractOrg200407Aimwebs.Policy> testListPolicy = new List<schemasDatacontractOrg200407Aimwebs.Policy>();
            testListPolicy.add(testPolicy);
                
            schemasDatacontractOrg200407Aimwebs.ArrayOfPolicy testArrPolicy = new schemasDatacontractOrg200407Aimwebs.ArrayOfPolicy();
            testArrPolicy.Policy = testListPolicy;
                
            schemasDatacontractOrg200407Aimwebs.PolicyChangesGetListResponse test = new schemasDatacontractOrg200407Aimwebs.PolicyChangesGetListResponse();
            test.PolicyChangeList = testArrPolicy;
            
            tempuriOrg.PolicyChangesGetListResponse_element respElement = new tempuriOrg.PolicyChangesGetListResponse_element();
            respElement.PolicyChangesGetListResult = test;
            response.put('response_x', respElement);
        }
    }
}