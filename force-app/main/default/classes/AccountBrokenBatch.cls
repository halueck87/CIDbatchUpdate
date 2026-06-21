/**
 * @description Batch class that synchronises Broker (Account), Contact, and License data
 *              from the external AIM web service into Salesforce. Implements a delta-sync
 *              pattern using a configurable start date, with checkpoint/recovery support
 *              via the AccountAbortJob__c Custom Setting. On completion, chains to
 *              OpportunityPolicyBatch to continue the AIM integration pipeline.
 *
 *              Exclusions for Agent Numbers and Statuses are driven by
 *              AIM_Broker_Exclusion__mdt Custom Metadata records — no code changes
 *              are required to add or remove exclusions.
 *
 * @see AIMConnection
 * @see OpportunityPolicyBatch
 * @see AIM_Broker_Exclusion__mdt
 * @see AIM_Integration_Settings__mdt
 */
public class AccountBrokenBatch implements Database.Batchable<Account>, Database.AllowsCallouts, Database.Stateful {

    /** @description Map of Contacts keyed by Broker Agent Number, populated in start() for use in execute(). */
    public Map<String,List<Contact>> contacts {get;set;}

    /** @description Map of Licenses keyed by Broker Agent Number, populated in start() for use in execute(). */
    public Map<String,List<License__c>> licenses {get;set;}

    /** @description The delta date sent to the AIM API — only records changed since this date are returned. */
    public Datetime startDate {get;set;}

    /** @description Checkpoint timestamp (now minus 10 minutes) written to AccountAbortJob__c on DML failure. */
    public Datetime startDateCS {get;set;}

    /** @description Flag indicating the AccountAbortJob__c Custom Setting should be cleaned up after recovery. */
    public Boolean deleteCS {get;set;}

    /** @description OwnerId loaded from AIM_Integration_Settings__mdt — applied to Accounts and Contacts. */
    public String defaultOwnerId {get;set;}

    // =========================================================================
    // Constructors
    // =========================================================================

    /**
     * @description Parameterised constructor — used when invoking the batch manually
     *              or chaining from another batch with an explicit start date.
     * @param startDateFrom The datetime from which to retrieve changed broker records from AIM.
     */
    public AccountBrokenBatch(Datetime startDateFrom) {
        System.debug('##construct AccountBrokenBatch with parameters');
        startDate = startDateFrom;
    }

    /**
     * @description No-argument constructor — used for standalone invocation. The start date
     *              is derived from the AccountAbortJob__c Custom Setting (recovery) or defaults
     *              to now minus 1 day and 10 minutes.
     */
    public AccountBrokenBatch() {
        System.debug('##construct AccountBrokenBatch');
    }

    // =========================================================================
    // Batch Interface Methods
    // =========================================================================

    /**
     * @description Authenticates with the AIM web service, retrieves changed Broker records,
     *              and builds Account, Contact, and License__c collections for processing in
     *              execute(). Loads exclusion sets and OwnerId from Custom Metadata.
     * @param bc The BatchableContext provided by the Salesforce batch framework.
     * @return List of Account records to process in execute() chunks.
     */
    public List<Account> start(Database.BatchableContext bc) {
        System.debug('##start AccountBrokenBatch');

        contacts    = new Map<String,List<Contact>>();
        licenses    = new Map<String,List<License__c>>();
        deleteCS    = false;
        startDateCS = System.now().addMinutes(-10);

        defaultOwnerId = loadOwnerId();
        startDate      = resolveStartDate();

        schemasDatacontractOrg200407Aimwebs.BrokerChangesGetListResponse response = AIMConnection.getAccounts(startDate);
        System.debug('##AIM response received: ' + (response != null));

        List<Account> accounts = new List<Account>();

        if (response == null) {
            return accounts;
        }

        if (response.BrokerChangeList == null || response.BrokerChangeList.Broker == null) {
            return accounts;
        }

        ExclusionSets exclusions = loadExclusions();
        System.debug('##AIM Agent exclusions loaded: '  + exclusions.agentNos);
        System.debug('##AIM Status exclusions loaded: ' + exclusions.statuses);

        for (schemasDatacontractOrg200407Aimwebs.Broker bro : response.BrokerChangeList.Broker) {
            if (exclusions.agentNos.contains(bro.AgentNo)) {
                continue;
            }
            if (bro.Status != null && exclusions.statuses.contains(bro.Status.toLowerCase())) {
                System.debug('##Skipping broker ' + bro.AgentNo + ' - ' + bro.Name + ' due to excluded status: ' + bro.Status);
                continue;
            }

            accounts.add(buildAccount(bro));
            buildContacts(bro);
            buildLicenses(bro);
        }

        return accounts;
    }

    /**
     * @description Upserts each chunk of Accounts, then upserts their related Contacts and
     *              Licenses. On DML failure, aborts the job and writes a recovery checkpoint
     *              to AccountAbortJob__c.
     * @param bc    The BatchableContext provided by the Salesforce batch framework.
     * @param scope The chunk of Account records to process in this execution.
     */
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        System.debug('##execute AccountBrokenBatch');

        cleanupAbortJobIfNeeded();

        if (scope.isEmpty()) {
            return;
        }

        try {
            upsert scope Broker_No__c;
            upsertContacts(scope);
            upsertLicenses(scope);
        } catch (DmlException e) {
            System.debug('##Error Executing AccountBrokenBatch: ' + e.getMessage());
            System.abortJob(bc.getJobId());
            AccountAbortJob__c checkpoint = new AccountAbortJob__c();
            checkpoint.Name         = 'AccountAbortJob';
            checkpoint.AbortDate__c = startDateCS;
            insert checkpoint;
        }
    }

    /**
     * @description Chains to OpportunityPolicyBatch on successful completion,
     *              passing the same startDate forward. Skipped during test execution.
     * @param bc The BatchableContext provided by the Salesforce batch framework.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('##finish AccountBrokenBatch');
        if (!Test.isRunningTest()) {
            Database.executeBatch(new OpportunityPolicyBatch(startDate));
        }
    }

    // =========================================================================
    // Private Helper Methods
    // =========================================================================

    /**
     * @description Loads the default OwnerId from AIM_Integration_Settings__mdt.
     *              Logs a warning and returns null if the metadata record is missing,
     *              allowing records to be created owned by the running user.
     * @return The OwnerId string, or null if not configured.
     */
    private String loadOwnerId() {
        // SOQL used instead of getInstance() — getInstance() throws a TypeException
        // in test context when no matching record exists, whereas SOQL safely returns null.
        List<AIM_Integration_Settings__mdt> settings = [
            SELECT DefaultOwnerID__c
            FROM AIM_Integration_Settings__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        if (!settings.isEmpty() && settings[0].DefaultOwnerID__c != null) {
            return settings[0].DefaultOwnerID__c;
        }
        System.debug('##WARNING: AIM_Integration_Settings__mdt.Default not found or DefaultOwnerID__c is blank. OwnerId will not be set.');
        return null;
    }

    /**
     * @description Determines the startDate for the AIM API call. Checks the
     *              AccountAbortJob__c Custom Setting first for recovery scenarios,
     *              then falls back to the constructor-provided date or a default
     *              lookback window of 1 day and 10 minutes.
     * @return The resolved Datetime to use as the AIM delta query start point.
     */
    private Datetime resolveStartDate() {
        List<AccountAbortJob__c> abortJobs = AccountAbortJob__c.getAll().values();
        if (!abortJobs.isEmpty()) {
            deleteCS = true;
            return abortJobs.get(0).AbortDate__c.addDays(-1);
        }
        if (startDate != null) {
            return startDate;
        }
        return System.now().addDays(-1).addMinutes(-10);
    }

    /**
     * @description Loads Agent Number and Status exclusion values from
     *              AIM_Broker_Exclusion__mdt Custom Metadata records.
     * @return An ExclusionSets instance containing the two exclusion sets.
     */
    private ExclusionSets loadExclusions() {
        ExclusionSets result = new ExclusionSets();
        for (AIM_Broker_Exclusion__mdt excl : [
            SELECT Exclusion_Value__c, Exclusion_Type__c
            FROM AIM_Broker_Exclusion__mdt
            WHERE Exclusion_Value__c != null
        ]) {
            if (excl.Exclusion_Type__c == 'AgentNo') {
                result.agentNos.add(excl.Exclusion_Value__c);
            } else if (excl.Exclusion_Type__c == 'Status') {
                result.statuses.add(excl.Exclusion_Value__c.toLowerCase());
            }
        }
        return result;
    }

    /**
     * @description Builds a single Account record from an AIM Broker response object.
     *              Applies null guards on address fields and filters invalid default dates.
     * @param bro The AIM Broker object from the web service response.
     * @return A populated Account record ready for upsert.
     */
    private Account buildAccount(schemasDatacontractOrg200407Aimwebs.Broker bro) {
        Date expiration      = parseAimDate(bro.Expiration);
        Date approved        = parseAimDate(bro.Approved);
        String physAddress2  = sanitiseString(bro.PhysicalAddress2);
        String mailAddress2  = sanitiseString(bro.MailingAddress2);
        String physAddress1  = bro.PhysicalAddress1 != null ? bro.PhysicalAddress1 : '';
        String mailAddress1  = bro.MailingAddress1  != null ? bro.MailingAddress1  : '';

        Account acc = new Account(
            Name              = bro.Name,
            Broker_No__c      = bro.AgentNo,
            Status__c         = bro.Status,
            Approved__c       = approved,
            Phone             = bro.Phone,
            Fax               = bro.Fax,
            Website           = bro.WebSite,
            Expiration__c     = expiration,
            ShippingStreet    = (physAddress1 + ' ' + physAddress2).trim(),
            ShippingPostalCode = bro.PhysicalZip,
            ShippingCity      = bro.PhysicalCity,
            ShippingState     = bro.PhysicalState,
            BillingStreet     = (mailAddress1 + ' ' + mailAddress2).trim(),
            BillingPostalCode = bro.MailingZip,
            BillingCity       = bro.MailingCity,
            BillingState      = bro.MainingState
        );
        if (defaultOwnerId != null) {
            acc.OwnerId = defaultOwnerId;
        }
        return acc;
    }

    /**
     * @description Builds Contact records from a Broker's ContactsChangeList and stores
     *              them in the stateful contacts map keyed by AgentNo.
     * @param bro The AIM Broker object whose contacts should be processed.
     */
    private void buildContacts(schemasDatacontractOrg200407Aimwebs.Broker bro) {
        if (bro.ContactsChangeList == null || bro.ContactsChangeList.Contact == null) {
            return;
        }

        List<Contact> contactsList = new List<Contact>();
        String emailRegex = '([a-zA-Z0-9_\\-\\.]+)@((\\[a-z]{1,3}\\.[a-z]{1,3}\\.[a-z]{1,3}\\.)|(([a-zA-Z0-9\\-]+\\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})';
        Pattern myPattern = Pattern.compile(emailRegex);

        for (schemasDatacontractOrg200407Aimwebs.Contact con : bro.ContactsChangeList.Contact) {
            if (con.NameKeyPK == null || con.Name == null || con.Name.trim() == '') {
                continue;
            }

            Boolean active   = parseActiveFlag(con.Active, '0');
            String  email    = validateEmail(con.Email, myPattern);
            String  firstName;
            String  lastName;

            String nameTemp = con.Name.trim();
            Integer spaceIdx = nameTemp.indexOf(' ');
            if (spaceIdx != -1) {
                firstName = nameTemp.substring(0, spaceIdx);
                lastName  = nameTemp.substring(spaceIdx);
            } else {
                lastName  = con.Name;
                firstName = null;
            }

            Contact newContact = new Contact(
                NameKeyPK__c  = String.valueOf(con.NameKeyPK),
                FirstName     = firstName,
                LastName      = lastName,
                Title         = con.Position,
                Phone         = con.Phone,
                Ext__c        = con.Ext,
                Active__c     = active,
                Fax           = con.Fax,
                Email         = email,
                MobilePhone   = con.CellPhone,
                OtherPhone    = con.OtherPhone
            );
            if (defaultOwnerId != null) {
                newContact.OwnerId = defaultOwnerId;
            }
            contactsList.add(newContact);
        }

        contacts.put(bro.AgentNo, contactsList.clone());
    }

    /**
     * @description Builds License__c records from a Broker's AgentLicensesChangeList and
     *              stores them in the stateful licenses map keyed by AgentNo.
     * @param bro The AIM Broker object whose licenses should be processed.
     */
    private void buildLicenses(schemasDatacontractOrg200407Aimwebs.Broker bro) {
        if (bro.AgentLicensesChangeList == null || bro.AgentLicensesChangeList.License == null) {
            return;
        }

        List<License__c> licensesList = new List<License__c>();
        for (schemasDatacontractOrg200407Aimwebs.License lic : bro.AgentLicensesChangeList.License) {
            if (lic.LicenseKey_PK == null) {
                continue;
            }
            licensesList.add(new License__c(
                Active__c             = parseActiveFlag(lic.Active, 'Y'),
                State__c              = lic.State,
                Licensed_Individuals__c = lic.LicensedIndividuals,
                Name                  = lic.License,
                External_ID__c        = String.valueOf(lic.LicenseKey_PK),
                Expiration_Date__c    = parseAimDate(lic.DateExpiration)
            ));
        }

        licenses.put(bro.AgentNo, licensesList.clone());
    }

    /**
     * @description Upserts Contact records for all Accounts in the current scope chunk,
     *              linking each Contact to its parent Account via AccountId.
     * @param scope The list of upserted Account records with populated Id fields.
     */
    private void upsertContacts(List<Account> scope) {
        if (contacts.isEmpty()) {
            return;
        }
        Map<String,Contact> contactsInsert = new Map<String,Contact>();
        for (Account acc : scope) {
            List<Contact> accContacts = contacts.get(acc.Broker_No__c);
            if (accContacts == null) {
                continue;
            }
            for (Contact con : accContacts) {
                if (con.LastName == null || con.LastName.trim() == '') {
                    System.debug('##Contact missing LastName: ' + con);
                }
                con.AccountId = acc.Id;
                contactsInsert.put(con.NameKeyPK__c, con);
            }
        }
        upsert contactsInsert.values() NameKeyPK__c;
    }

    /**
     * @description Upserts License__c records for all Accounts in the current scope chunk,
     *              linking each License to its parent Account via Broker__c.
     * @param scope The list of upserted Account records with populated Id fields.
     */
    private void upsertLicenses(List<Account> scope) {
        if (licenses.isEmpty()) {
            return;
        }
        Map<String,License__c> licensesInsert = new Map<String,License__c>();
        for (Account acc : scope) {
            List<License__c> accLicenses = licenses.get(acc.Broker_No__c);
            if (accLicenses == null) {
                continue;
            }
            for (License__c lic : accLicenses) {
                lic.Broker__c = acc.Id;
                licensesInsert.put(lic.External_ID__c, lic);
            }
        }
        upsert licensesInsert.values() External_ID__c;
    }

    /**
     * @description Deletes the AccountAbortJob__c Custom Setting recovery record if deleteCS
     *              is true (i.e. this run was triggered as a recovery). Resets deleteCS to
     *              prevent repeated deletion in subsequent chunks.
     */
    private void cleanupAbortJobIfNeeded() {
        if (!deleteCS) {
            return;
        }
        List<AccountAbortJob__c> abortJobs = AccountAbortJob__c.getAll().values();
        if (!abortJobs.isEmpty()) {
            delete abortJobs;
        }
        deleteCS = false;
    }

    /**
     * @description Converts an AIM Datetime value to a Salesforce Date, returning null
     *              for default "empty" date values the AIM system returns instead of null.
     * @param aimDate The raw Datetime value from the AIM response.
     * @return A valid Date, or null if the value represents an empty AIM date.
     */
    private Date parseAimDate(Datetime aimDate) {
        if (aimDate == null) {
            return null;
        }
        String s = String.valueOf(aimDate);
        if (s == '0001-01-01 00:00:00' || s == '0001-01-01T00:00:00' || s == '0001-12-31 16:00:00') {
            return null;
        }
        return Date.valueOf(aimDate);
    }

    /**
     * @description Maps an AIM active flag string to a Boolean.
     * @param flagValue   The raw flag string from AIM (e.g. '0', 'Y').
     * @param trueValue   The string value that represents active/true in the AIM system.
     * @return True if flagValue matches trueValue, false otherwise, or null if flagValue is null.
     */
    private Boolean parseActiveFlag(String flagValue, String trueValue) {
        if (flagValue == null) {
            return null;
        }
        return flagValue == trueValue;
    }

    /**
     * @description Returns an empty string for null, 'null', or blank address line values
     *              from the AIM response, preventing literal 'null' text in address fields.
     * @param value The raw address string from AIM.
     * @return The original value, or an empty string if null/blank/literal-null.
     */
    private String sanitiseString(String value) {
        if (value == null || value == 'null' || value.trim() == '') {
            return '';
        }
        return value;
    }

    /**
     * @description Validates an email address string against a regex pattern.
     * @param email     The raw email string from AIM.
     * @param myPattern A compiled Pattern for email validation.
     * @return The email string if valid, or null if blank or invalid.
     */
    private String validateEmail(String email, Pattern myPattern) {
        if (String.isBlank(email)) {
            return null;
        }
        Matcher myMatcher = myPattern.matcher(email);
        return myMatcher.matches() ? email : null;
    }

    // =========================================================================
    // Inner Classes
    // =========================================================================

    /**
     * @description Simple container for the two broker exclusion sets loaded from
     *              AIM_Broker_Exclusion__mdt Custom Metadata records.
     */
    private class ExclusionSets {
        /** @description Agent Numbers to exclude from AIM sync. */
        public Set<String> agentNos = new Set<String>();
        /** @description Status values (lowercased) to exclude from AIM sync. */
        public Set<String> statuses = new Set<String>();
    }
}