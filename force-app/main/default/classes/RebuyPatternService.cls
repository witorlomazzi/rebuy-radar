/**
 * Lógica pura do Rebuy Radar: dado o histórico de compras de uma conta (datas e valores),
 * calcula cadência média, próxima compra esperada, score explicável e nível de risco.
 * Sem SOQL e sem DML — 100% testável em unidade, com data de referência injetável.
 *
 * Score (0-100): percentual do caminho até o limiar crítico.
 *   ratio = diasDesdeAUltimaCompra / cadenciaMedia
 *   score = min(100, ratio / multiplicadorCritico * 100)
 * Nada de caixa-preta: o vendedor consegue explicar o número pro cliente.
 */
public inherited sharing class RebuyPatternService {

    public class PatternResult {
        public Decimal averageIntervalDays;
        public Date lastPurchaseDate;
        public Date expectedNextPurchase;
        public Decimal averageOrderValue;
        public Decimal valueAtRisk;
        public Integer riskScore;
        public String riskLevel;
        public Integer purchasesAnalyzed;
    }

    /**
     * @param purchaseDates datas das compras (qualquer ordem)
     * @param amounts       valor de cada compra (nulos são tratados como zero)
     * @param asOf          data de referência (Date.today() em produção; injetável em teste)
     * @return resultado do cálculo, ou null quando não há cadência mensurável
     *         (menos de 2 compras ou todas no mesmo dia)
     */
    public static PatternResult compute(List<Date> purchaseDates, List<Decimal> amounts, Date asOf) {
        if (purchaseDates == null || purchaseDates.size() < 2) {
            return null;
        }

        List<Date> sortedDates = new List<Date>(purchaseDates);
        sortedDates.sort();
        Date firstPurchase = sortedDates[0];
        Date lastPurchase = sortedDates[sortedDates.size() - 1];

        // Cadência média = intervalo total / número de intervalos.
        Decimal intervalCount = sortedDates.size() - 1;
        Decimal averageInterval = Decimal.valueOf(firstPurchase.daysBetween(lastPurchase)) / intervalCount;
        if (averageInterval <= 0) {
            return null; // todas as compras no mesmo dia: sem cadência mensurável
        }

        Rebuy_Radar_Setting__mdt cfg = RebuyRadarSettings.getActive();

        Decimal totalAmount = 0;
        for (Decimal amount : amounts) {
            totalAmount += (amount == null ? 0 : amount);
        }
        Decimal averageOrderValue = (totalAmount / purchaseDates.size()).setScale(2);

        Decimal daysSinceLast = Decimal.valueOf(lastPurchase.daysBetween(asOf));
        Decimal ratio = daysSinceLast / averageInterval;

        PatternResult result = new PatternResult();
        result.purchasesAnalyzed = purchaseDates.size();
        result.lastPurchaseDate = lastPurchase;
        result.averageIntervalDays = averageInterval.setScale(1);
        result.expectedNextPurchase = lastPurchase.addDays(Integer.valueOf(averageInterval.round()));
        result.averageOrderValue = averageOrderValue;
        result.riskLevel = levelFor(ratio, cfg);
        result.riskScore = scoreFor(ratio, cfg);

        // Valor em risco = ticket médio x ciclos de compra perdidos (mínimo 1 quando fora do "Em dia").
        Integer missedCycles = Integer.valueOf(Math.floor(Double.valueOf(ratio)));
        result.valueAtRisk = result.riskLevel == 'Em_dia'
            ? 0
            : (averageOrderValue * Math.max(missedCycles, 1)).setScale(2);

        return result;
    }

    private static String levelFor(Decimal ratio, Rebuy_Radar_Setting__mdt cfg) {
        if (ratio < cfg.Attention_Multiplier__c) {
            return 'Em_dia';
        }
        if (ratio < cfg.Risk_Multiplier__c) {
            return 'Atencao';
        }
        if (ratio < cfg.Critical_Multiplier__c) {
            return 'Risco';
        }
        return 'Critico';
    }

    private static Integer scoreFor(Decimal ratio, Rebuy_Radar_Setting__mdt cfg) {
        Decimal score = (ratio / cfg.Critical_Multiplier__c) * 100;
        return Integer.valueOf(Math.min(100, Math.max(0, score.round())));
    }
}
