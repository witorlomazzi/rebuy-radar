/**
 * Selector dos snapshots do radar para o usuário final.
 * WITH USER_MODE: respeita CRUD/FLS e o sharing (Private, Owner = dono da conta) — cada
 * vendedor enxerga só a própria carteira; gestores enxergam o time pela hierarquia de papéis.
 */
public inherited sharing class AccountPurchasePatternSelector {

    private static final Set<String> VALID_LEVELS =
        new Set<String>{ 'Em_dia', 'Atencao', 'Risco', 'Critico' };

    @TestVisible
    private static List<Account_Purchase_Pattern__c> testRecords;

    public static List<Account_Purchase_Pattern__c> getVisiblePatterns(String riskLevel, Integer maxRows) {
        if (testRecords != null) {
            return testRecords;
        }
        if (String.isNotBlank(riskLevel) && !VALID_LEVELS.contains(riskLevel)) {
            throw new IllegalArgumentException('Nível de risco inválido: ' + riskLevel);
        }

        if (String.isBlank(riskLevel)) {
            return [
                SELECT Id, Account__c, Account__r.Name, Risk_Level__c, Risk_Score__c,
                       Value_At_Risk__c, Days_Overdue__c, Average_Interval_Days__c,
                       Average_Order_Value__c, Last_Purchase_Date__c,
                       Expected_Next_Purchase_Date__c, Purchases_Analyzed__c
                FROM Account_Purchase_Pattern__c
                WITH USER_MODE
                ORDER BY Risk_Score__c DESC NULLS LAST, Value_At_Risk__c DESC NULLS LAST
                LIMIT :maxRows
            ];
        }
        return [
            SELECT Id, Account__c, Account__r.Name, Risk_Level__c, Risk_Score__c,
                   Value_At_Risk__c, Days_Overdue__c, Average_Interval_Days__c,
                   Average_Order_Value__c, Last_Purchase_Date__c,
                   Expected_Next_Purchase_Date__c, Purchases_Analyzed__c
            FROM Account_Purchase_Pattern__c
            WHERE Risk_Level__c = :riskLevel
            WITH USER_MODE
            ORDER BY Risk_Score__c DESC NULLS LAST, Value_At_Risk__c DESC NULLS LAST
            LIMIT :maxRows
        ];
    }

    public static Account_Purchase_Pattern__c getByAccount(Id accountId) {
        if (accountId == null) {
            return null;
        }
        if (testRecords != null) {
            for (Account_Purchase_Pattern__c p : testRecords) {
                if (p.Account__c == accountId) {
                    return p;
                }
            }
            return null;
        }
        List<Account_Purchase_Pattern__c> found = [
            SELECT Id, Account__c, Account__r.Name, Risk_Level__c, Risk_Score__c,
                   Value_At_Risk__c, Days_Overdue__c, Average_Interval_Days__c,
                   Average_Order_Value__c, Last_Purchase_Date__c,
                   Expected_Next_Purchase_Date__c, Purchases_Analyzed__c
            FROM Account_Purchase_Pattern__c
            WHERE Account__c = :accountId
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return found.isEmpty() ? null : found[0];
    }

    public static List<AggregateResult> getSummaryByLevel() {
        return [
            SELECT Risk_Level__c level, COUNT(Id) total, SUM(Value_At_Risk__c) valueAtRisk
            FROM Account_Purchase_Pattern__c
            WITH USER_MODE
            GROUP BY Risk_Level__c
        ];
    }
}
