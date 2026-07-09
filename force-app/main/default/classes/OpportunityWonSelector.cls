/**
 * Selector de compras (Opportunities ganhas) do Rebuy Radar.
 * inherited sharing: adota o contexto do chamador — sem sharing no batch (que recalcula
 * a carteira inteira), com sharing/USER_MODE no controller do usuário final.
 */
public inherited sharing class OpportunityWonSelector {

    @TestVisible
    private static List<Opportunity> testRecords;

    public static List<Opportunity> getWonByAccountIds(Set<Id> accountIds, Date cutoff) {
        if (testRecords != null) {
            return testRecords;
        }
        return [
            SELECT Id, AccountId, Amount, CloseDate
            FROM Opportunity
            WHERE AccountId IN :accountIds
                AND IsWon = true
                AND CloseDate >= :cutoff
            ORDER BY CloseDate ASC
        ];
    }
}
