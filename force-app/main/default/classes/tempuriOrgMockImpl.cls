@isTest
public class tempuriOrgMockImpl implements WebServiceMock {
	public void doInvoke(
			Object stub,
			Object request,
			Map<String, Object> response,
			String endpoint,
			String soapAction,
			String requestName,
			String responseNS,
			String responseName,
			String responseType) {
       
		System.debug(LoggingLevel.INFO, 'tempuriOrgMockImpl.doInvoke() - ' +
			'\n request: ' + request +
			'\n response: ' + response +
			'\n endpoint: ' + endpoint +
			'\n soapAction: ' + soapAction +
			'\n requestName: ' + requestName +
			'\n responseNS: ' + responseNS +
			'\n responseName: ' + responseName +
			'\n responseType: ' + responseType);

		if(request instanceOf tempuriOrg.BrokerChangesGetList_element) {
			response.put( 'response_x', new tempuriOrg.BrokerChangesGetListResponse_element());
		}
		else if(request instanceOf tempuriOrg.PolicyChangesGetList_element) {
			response.put( 'response_x', new tempuriOrg.PolicyChangesGetListResponse_element());
		}
		else if(request instanceOf tempuriOrg.VerifyDBConnection_element) {
			response.put( 'response_x', new tempuriOrg.VerifyDBConnectionResponse_element());
		}
		else if(request instanceOf tempuriOrg.VerifyWSConnection_element) {
			response.put( 'response_x', new tempuriOrg.VerifyWSConnectionResponse_element());
		}
		else if(request instanceOf tempuriOrg.WSLogIn_element) {
			response.put( 'response_x', new tempuriOrg.WSLogInResponse_element());
		}
		else if(request instanceOf tempuriOrg.WSLogOut_element) {
			response.put( 'response_x', new tempuriOrg.WSLogOutResponse_element());
		}
	}
}