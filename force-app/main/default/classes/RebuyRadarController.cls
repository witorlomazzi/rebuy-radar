/**
 * Camada @AuraEnabled do Rebuy Radar. Thin por padrão: sem lógica de negócio aqui.
 * Toda leitura passa pelo selector com WITH USER_MODE.
 */
public with sharing class RebuyRadarController {

    @AuraEnabled(cacheable=true)
    public static List<Account_Purchase_Pattern__c> getRadar(String riskLevel) {
        try {
            return AccountPurchasePatternSelector.getVisiblePatterns(riskLevel, 200);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static RadarSummary getSummary() {
        try {
            RadarSummary summary = new RadarSummary();
            for (AggregateResult row : AccountPurchasePatternSelector.getSummaryByLevel()) {
                String level = (String) row.get('level');
                Integer count = (Integer) row.get('total');
                Decimal atRisk = (Decimal) row.get('valueAtRisk');
                summary.total += count;
                summary.totalValueAtRisk += (atRisk == null ? 0 : atRisk);
                if (level == 'Critico') {
                    summary.critico = count;
                } else if (level == 'Risco') {
                    summary.risco = count;
                } else if (level == 'Atencao') {
                    summary.atencao = count;
                } else if (level == 'Em_dia') {
                    summary.emDia = count;
                }
            }
            return summary;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class RadarSummary {
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer critico = 0;
        @AuraEnabled public Integer risco = 0;
        @AuraEnabled public Integer atencao = 0;
        @AuraEnabled public Integer emDia = 0;
        @AuraEnabled public Decimal totalValueAtRisk = 0;
    }
}
