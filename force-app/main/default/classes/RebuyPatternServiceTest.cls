@IsTest
private class RebuyPatternServiceTest {

    private static final Date AS_OF = Date.newInstance(2026, 7, 1);

    private static void useDefaultSettings() {
        RebuyRadarSettings.testOverride = new Rebuy_Radar_Setting__mdt(
            DeveloperName = 'Teste',
            Analysis_Window_Months__c = 12,
            Min_Purchases__c = 3,
            Attention_Multiplier__c = 1.2,
            Risk_Multiplier__c = 1.5,
            Critical_Multiplier__c = 2.0,
            Is_Active__c = true
        );
    }

    @IsTest
    static void contaEmDiaNaoTemValorEmRisco() {
        useDefaultSettings();
        // Cadência de 30 dias, última compra há 20 dias: ratio 0.67.
        List<Date> compras = new List<Date>{ AS_OF.addDays(-80), AS_OF.addDays(-50), AS_OF.addDays(-20) };
        List<Decimal> valores = new List<Decimal>{ 1000, 2000, 3000 };

        RebuyPatternService.PatternResult r = RebuyPatternService.compute(compras, valores, AS_OF);

        Assert.areEqual('Em_dia', r.riskLevel, 'ratio 0.67 deve ficar Em dia');
        Assert.areEqual(0, r.valueAtRisk, 'Em dia nao tem valor em risco');
        Assert.areEqual(30.0, r.averageIntervalDays, 'cadencia media de 30 dias');
        Assert.areEqual(2000.00, r.averageOrderValue, 'ticket medio');
        Assert.areEqual(AS_OF.addDays(-20), r.lastPurchaseDate);
        Assert.areEqual(AS_OF.addDays(10), r.expectedNextPurchase, 'ultima compra + cadencia');
        Assert.areEqual(3, r.purchasesAnalyzed);
        Assert.areEqual(33, r.riskScore, '0.67 / 2.0 * 100 arredondado');
    }

    @IsTest
    static void quebraDePadraoViraCriticoComScoreTravadoEm100() {
        useDefaultSettings();
        // Cadência de 30 dias, última compra há 100 dias: ratio 3.33 (3 ciclos perdidos).
        List<Date> compras = new List<Date>{ AS_OF.addDays(-160), AS_OF.addDays(-130), AS_OF.addDays(-100) };
        List<Decimal> valores = new List<Decimal>{ 2000, 2000, 2000 };

        RebuyPatternService.PatternResult r = RebuyPatternService.compute(compras, valores, AS_OF);

        Assert.areEqual('Critico', r.riskLevel);
        Assert.areEqual(100, r.riskScore, 'score trava em 100');
        Assert.areEqual(6000.00, r.valueAtRisk, 'ticket 2000 x 3 ciclos perdidos');
    }

    @IsTest
    static void atencaoTemPeloMenosUmCicloDeValorEmRisco() {
        useDefaultSettings();
        // Cadência 30, há 40 dias sem compra: ratio 1.33 (Atencao), floor = 1 ciclo.
        List<Date> compras = new List<Date>{ AS_OF.addDays(-100), AS_OF.addDays(-70), AS_OF.addDays(-40) };
        List<Decimal> valores = new List<Decimal>{ 1500, 1500, 1500 };

        RebuyPatternService.PatternResult r = RebuyPatternService.compute(compras, valores, AS_OF);

        Assert.areEqual('Atencao', r.riskLevel);
        Assert.areEqual(1500.00, r.valueAtRisk, 'minimo de 1 ciclo quando fora do Em dia');
    }

    @IsTest
    static void datasForaDeOrdemSaoOrdenadas() {
        useDefaultSettings();
        List<Date> compras = new List<Date>{ AS_OF.addDays(-20), AS_OF.addDays(-80), AS_OF.addDays(-50) };
        List<Decimal> valores = new List<Decimal>{ 1000, 1000, 1000 };

        RebuyPatternService.PatternResult r = RebuyPatternService.compute(compras, valores, AS_OF);

        Assert.areEqual(AS_OF.addDays(-20), r.lastPurchaseDate, 'a mais recente vence apos ordenar');
        Assert.areEqual(30.0, r.averageIntervalDays);
    }

    @IsTest
    static void valoresNulosContamComoZeroNoTicketMedio() {
        useDefaultSettings();
        List<Date> compras = new List<Date>{ AS_OF.addDays(-60), AS_OF.addDays(-30) };
        List<Decimal> valores = new List<Decimal>{ 3000, null };

        RebuyPatternService.PatternResult r = RebuyPatternService.compute(compras, valores, AS_OF);

        Assert.areEqual(1500.00, r.averageOrderValue, 'null tratado como zero');
    }

    @IsTest
    static void semCadenciaMensuravelRetornaNull() {
        useDefaultSettings();
        Assert.isNull(RebuyPatternService.compute(new List<Date>{ AS_OF.addDays(-10) },
            new List<Decimal>{ 100 }, AS_OF), 'uma compra so');
        Assert.isNull(RebuyPatternService.compute(null, null, AS_OF), 'lista nula');
        Assert.isNull(RebuyPatternService.compute(
            new List<Date>{ AS_OF.addDays(-10), AS_OF.addDays(-10) },
            new List<Decimal>{ 100, 100 }, AS_OF), 'todas no mesmo dia');
    }

    @IsTest
    static void configuracaoAtivaVemDaOrgQuandoSemOverride() {
        // A org tem o registro Default ativo (customMetadata deployado com o projeto).
        Rebuy_Radar_Setting__mdt cfg = RebuyRadarSettings.getActive();
        Assert.isTrue(cfg.Is_Active__c, 'deve encontrar uma configuracao ativa');
    }
}
