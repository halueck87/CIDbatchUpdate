public class AIMConnection{
    private static String userAIM = 'SA';
    private static String passwAIM = 'CID4SQLsa';
    private static String tokenAIM = '';
    
    public static schemasDatacontractOrg200407Aimwebs.BrokerChangesGetListResponse getAccounts(Datetime startDate){
        tempuriOrg.poxNonSSL client = new tempuriOrg.poxNonSSL();
        setToken();
    
        schemasDatacontractOrg200407Aimwebs.BrokerChangesGetListRequest newRequest = new schemasDatacontractOrg200407Aimwebs.BrokerChangesGetListRequest();
        newRequest.BrokerChangeDtime = startDate;
        newRequest.tokenString = tokenAIM;
        
        System.debug('response:  ' + client.BrokerChangesGetList(newRequest));
        return client.BrokerChangesGetList(newRequest);         
    }
    
    public static schemasDatacontractOrg200407Aimwebs.PolicyChangesGetListResponse getOpportunities(Datetime startDate){
        tempuriOrg.poxNonSSL client = new tempuriOrg.poxNonSSL();
        setToken();
    
        schemasDatacontractOrg200407Aimwebs.PolicyChangesGetListRequest newRequest = new schemasDatacontractOrg200407Aimwebs.PolicyChangesGetListRequest();
        newRequest.PolicyChangeDtime = startDate;
        newRequest.tokenString = tokenAIM;
        
        System.debug('response:  ' + client.PolicyChangesGetList(newRequest));
        return client.PolicyChangesGetList(newRequest);
    }
    
    public static void setToken(){
        tempuriOrg.poxNonSSL client = new tempuriOrg.poxNonSSL();
        tokenAIM = client.WSLogIn(EncodingUtil.convertToHex(Crypto.generateDigest('MD5', Blob.valueOf(userAIM))), EncodingUtil.convertToHex(Crypto.generateDigest('MD5', Blob.valueOf(passwAIM))));
        system.debug('##tokenAIM: '+tokenAIM);
    }
}