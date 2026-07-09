/**
 * Batch noturno do Rebuy Radar: recalcula o padrão de recompra de todas as contas com
 * histórico mínimo de compras na janela configurada e faz upsert do snapshot
 * (Account_Purchase_Pattern__c) usando Account_Key__c como chave externa (idempotente).
 *
 * without sharing INTENCIONAL: o motor precisa enxergar a carteira inteira para recalcular.
 * A leitura do usuário final é protegida no controller (WITH USER_MODE) e pelo sharing do
 * objeto (Private, Owner = dono da conta).
 */
public without sharing class RebuyPatternBatch implements Database.Batchable<SObject>, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext context) {
        Date cutoff = cutoffDate();
        return Database.getQueryLocator([
            SELECT Id, OwnerId
            FROM Account
            WHERE Id IN (
                SELECT AccountId FROM Opportunity
                WHERE IsWon = true AND CloseDate >= :cutoff
            )
        ]);
    }

    public void execute(Database.BatchableContext context, List<Account> scope) {
        Rebuy_Radar_Setting__mdt cfg = RebuyRadarSettings.getActive();
        Date cutoff = cutoffDate();
        Date asOf = Date.today();

        Map<Id, Account> accountsById = new Map<Id, Account>(scope);
        Map<Id, List<Opportunity>> oppsByAccount = new Map<Id, List<Opportunity>>();
        for (Opportunity opp : OpportunityWonSelector.getWonByAccountIds(accountsById.keySet(), cutoff)) {
            if (!oppsByAccount.containsKey(opp.AccountId)) {
                oppsByAccount.put(opp.AccountId, new List<Opportunity>());
            }
            oppsByAccount.get(opp.AccountId).add(opp);
        }

        List<Account_Purchase_Pattern__c> patterns = new List<Account_Purchase_Pattern__c>();
        for (Id accountId : oppsByAccount.keySet()) {
            List<Opportunity> purchases = oppsByAccount.get(accountId);
            if (purchases.size() < cfg.Min_Purchases__c) {
                continue;
            }

            List<Date> purchaseDates = new List<Date>();
            List<Decimal> amounts = new List<Decimal>();
            for (Opportunity purchase : purchases) {
                purchaseDates.add(purchase.CloseDate);
                amounts.add(purchase.Amount);
            }

            RebuyPatternService.PatternResult result =
                RebuyPatternService.compute(purchaseDates, amounts, asOf);
            if (result == null) {
                continue;
            }

            patterns.add(new Account_Purchase_Pattern__c(
                Account__c = accountId,
                Account_Key__c = accountId,
                OwnerId = accountsById.get(accountId).OwnerId,
                Last_Purchase_Date__c = result.lastPurchaseDate,
                Average_Interval_Days__c = result.averageIntervalDays,
                Expected_Next_Purchase_Date__c = result.expectedNextPurchase,
                Average_Order_Value__c = result.averageOrderValue,
                Value_At_Risk__c = result.valueAtRisk,
                Risk_Score__c = result.riskScore,
                Risk_Level__c = result.riskLevel,
                Purchases_Analyzed__c = result.purchasesAnalyzed
            ));
        }

        if (!patterns.isEmpty()) {
            upsert patterns Account_Key__c;
        }
    }

    public void finish(Database.BatchableContext context) {
        // Sem encadeamento: uma execução por noite basta.
    }

    // Schedulable: permite System.schedule direto desta classe.
    public void execute(SchedulableContext context) {
        Database.executeBatch(new RebuyPatternBatch(), 200);
    }

    /** Agenda a execução noturna (3h). Rodar uma vez via Anonymous Apex. */
    public static Id scheduleNightly() {
        return System.schedule('Rebuy Radar - recalculo noturno', '0 0 3 * * ?', new RebuyPatternBatch());
    }

    private static Date cutoffDate() {
        Rebuy_Radar_Setting__mdt cfg = RebuyRadarSettings.getActive();
        return Date.today().addMonths(-Integer.valueOf(cfg.Analysis_Window_Months__c));
    }
}
