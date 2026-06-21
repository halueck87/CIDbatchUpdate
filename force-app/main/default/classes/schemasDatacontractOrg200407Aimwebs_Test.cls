@isTest
private class schemasDatacontractOrg200407Aimwebs_Test {
	
	@isTest static void coverGeneratedCodeTypes() {
        schemasMicrosoftCom200310Serializat c = new schemasMicrosoftCom200310Serializat();
		Test.setMock(WebServiceMock.class, new tempuriOrgMockImpl());
		tempuriOrg parentObject = new tempuriOrg();
		new schemasDatacontractOrg200407Aimwebs.ArrayOfBroker();
		new schemasDatacontractOrg200407Aimwebs.ArrayOfContact();
		new schemasDatacontractOrg200407Aimwebs.ArrayOfInvoice();
		new schemasDatacontractOrg200407Aimwebs.ArrayOfInvoicePayments();
		new schemasDatacontractOrg200407Aimwebs.ArrayOfLicense();
		new schemasDatacontractOrg200407Aimwebs.ArrayOfPolicy();
		new schemasDatacontractOrg200407Aimwebs.Broker();
		new schemasDatacontractOrg200407Aimwebs.BrokerChangesGetListRequest();
		new schemasDatacontractOrg200407Aimwebs.BrokerChangesGetListResponse();
		new schemasDatacontractOrg200407Aimwebs.Contact();
		new schemasDatacontractOrg200407Aimwebs.Invoice();
		new schemasDatacontractOrg200407Aimwebs.InvoicePayments();
		new schemasDatacontractOrg200407Aimwebs.License();
		new schemasDatacontractOrg200407Aimwebs.Policy();
		new schemasDatacontractOrg200407Aimwebs.PolicyChangesGetListRequest();
		new schemasDatacontractOrg200407Aimwebs.PolicyChangesGetListResponse();
		//new schemasDatacontractOrg200407Aimwebs1.Status();
		new tempuriOrg.BrokerChangesGetList_element();
		new tempuriOrg.BrokerChangesGetListResponse_element();
		new tempuriOrg.PolicyChangesGetList_element();
		new tempuriOrg.PolicyChangesGetListResponse_element();
		new tempuriOrg.VerifyDBConnection_element();
		new tempuriOrg.VerifyDBConnectionResponse_element();
		new tempuriOrg.VerifyWSConnection_element();
		new tempuriOrg.VerifyWSConnectionResponse_element();
		new tempuriOrg.WSLogIn_element();
		new tempuriOrg.WSLogInResponse_element();
		new tempuriOrg.WSLogOut_element();
		new tempuriOrg.WSLogOutResponse_element();
	}
	@isTest static void coverCodeForBrokerChangesGetList(){
		Test.setMock(WebServiceMock.class, new tempuriOrgMockImpl());
		tempuriOrg.poxNonSSL testObject = new tempuriOrg.poxNonSSL();
		System.assertEquals(null, testObject.BrokerChangesGetList(null));
	}
	@isTest static void coverCodeForPolicyChangesGetList(){
		Test.setMock(WebServiceMock.class, new tempuriOrgMockImpl());
		tempuriOrg.poxNonSSL testObject = new tempuriOrg.poxNonSSL();
		System.assertEquals(null, testObject.PolicyChangesGetList(null));
	}
	@isTest static void coverCodeForVerifyDBConnection(){
		Test.setMock(WebServiceMock.class, new tempuriOrgMockImpl());
		tempuriOrg.poxNonSSL testObject = new tempuriOrg.poxNonSSL();
		System.assertEquals(null, testObject.VerifyDBConnection(null));
	}
	@isTest static void coverCodeForVerifyWSConnection(){
		Test.setMock(WebServiceMock.class, new tempuriOrgMockImpl());
		tempuriOrg.poxNonSSL testObject = new tempuriOrg.poxNonSSL();
		System.assertEquals(null, testObject.VerifyWSConnection());
	}
	@isTest static void coverCodeForWSLogIn(){
		Test.setMock(WebServiceMock.class, new tempuriOrgMockImpl());
		tempuriOrg.poxNonSSL testObject = new tempuriOrg.poxNonSSL();
		System.assertEquals(null, testObject.WSLogIn(null, null));
	}
	@isTest static void coverCodeForWSLogOut(){
		Test.setMock(WebServiceMock.class, new tempuriOrgMockImpl());
		tempuriOrg.poxNonSSL testObject = new tempuriOrg.poxNonSSL();
		System.assertEquals(null, testObject.WSLogOut(null));
	}
}