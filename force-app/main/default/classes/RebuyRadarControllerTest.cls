@IsTest
private class RebuyRadarControllerTest {

    @TestSetup
    static void makeData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 4; i++) {
            accounts.add(new Account(Name = 'Vetra Radar ' + i));
        }
        insert accounts;

        insert new List<Account_Purchase_Pattern__c>{
            pattern(accounts[0].Id, 'Critico', 100, 9000),
            pattern(accounts[1].Id, 'Risco', 80, 4000),
            pattern(accounts[2].Id, 'Atencao', 65, 1500),
            pattern(accounts[3].Id, 'Em_dia', 30, 0)
        };
    }

    private static Account_Purchase_Pattern__c pattern(Id accountId, String level, Integer score, Decimal atRisk) {
        return new Account_Purchase_Pattern__c(
            Account__c = accountId,
            Account_Key__c = accountId,
            Risk_Level__c = level,
            Risk_Score__c = score,
            Value_At_Risk__c = atRisk,
            Average_Interval_Days__c = 30,
            Average_Order_Value__c = 2000,
            Last_Purchase_Date__c = Date.today().addDays(-40),
            Expected_Next_Purchase_Date__c = Date.today().addDays(-10),
            Purchases_Analyzed__c = 3
        );
    }

    @IsTest
    static void radarVemOrdenadoPorScoreDesc() {
        List<Account_Purchase_Pattern__c> radar = RebuyRadarController.getRadar(null);

        Assert.areEqual(4, radar.size());
        Assert.areEqual('Critico', radar[0].Risk_Level__c, 'maior score primeiro');
        Assert.areEqual('Em_dia', radar[3].Risk_Level__c, 'menor score por último');
    }

    @IsTest
    static void filtroPorNivelRetornaSoONivel() {
        List<Account_Purchase_Pattern__c> radar = RebuyRadarController.getRadar('Critico');

        Assert.areEqual(1, radar.size());
        Assert.areEqual('Critico', radar[0].Risk_Level__c);
    }

    @IsTest
    static void nivelInvalidoViraAuraHandledException() {
        try {
            RebuyRadarController.getRadar('DROP TABLE');
            Assert.fail('deveria lançar exceção para nível inválido');
        } catch (AuraHandledException e) {
            Assert.isTrue(true, 'exceção amigável para o front');
        }
    }

    @IsTest
    static void resumoSomaContagensEValorEmRisco() {
        RebuyRadarController.RadarSummary summary = RebuyRadarController.getSummary();

        Assert.areEqual(4, summary.total);
        Assert.areEqual(1, summary.critico);
        Assert.areEqual(1, summary.risco);
        Assert.areEqual(1, summary.atencao);
        Assert.areEqual(1, summary.emDia);
        Assert.areEqual(14500, summary.totalValueAtRisk, '9000 + 4000 + 1500 + 0');
    }

    @IsTest
    static void radarDaContaRetornaOSnapshotDaConta() {
        Account critica = [SELECT Id FROM Account WHERE Name = 'Vetra Radar 0' LIMIT 1];

        Account_Purchase_Pattern__c snapshot = RebuyRadarController.getForAccount(critica.Id);

        Assert.areNotEqual(null, snapshot, 'a conta tem padrão calculado');
        Assert.areEqual('Critico', snapshot.Risk_Level__c);
        Assert.areEqual(critica.Id, snapshot.Account__c);
    }

    @IsTest
    static void radarDaContaSemPadraoRetornaNulo() {
        Account semPadrao = new Account(Name = 'Vetra Sem Padrao');
        insert semPadrao;

        Account_Purchase_Pattern__c snapshot = RebuyRadarController.getForAccount(semPadrao.Id);

        Assert.areEqual(null, snapshot, 'conta sem snapshot não quebra o card');
    }

    @IsTest
    static void radarDaContaComIdNuloRetornaNulo() {
        Assert.areEqual(null, RebuyRadarController.getForAccount(null), 'id nulo não consulta nem quebra');
    }

    @IsTest
    static void radarDaContaUsaStubEmTesteUnitario() {
        Account conta = [SELECT Id FROM Account WHERE Name = 'Vetra Radar 1' LIMIT 1];
        Id outraConta = [SELECT Id FROM Account WHERE Name = 'Vetra Radar 2' LIMIT 1].Id;
        AccountPurchasePatternSelector.testRecords = new List<Account_Purchase_Pattern__c>{
            new Account_Purchase_Pattern__c(Account__c = conta.Id, Risk_Level__c = 'Risco')
        };

        Assert.areEqual('Risco', RebuyRadarController.getForAccount(conta.Id).Risk_Level__c, 'stub casa pela conta');
        Assert.areEqual(null, RebuyRadarController.getForAccount(outraConta), 'sem match no stub retorna nulo');
    }

    @IsTest
    static void usuarioSemPermissaoNaoLeNada() {
        Profile standard = [SELECT Id FROM Profile WHERE Name IN ('Standard User', 'Usuário padrão') LIMIT 1];
        User semAcesso = new User(
            FirstName = 'Sem',
            LastName = 'Acesso',
            Alias = 'semace',
            Email = 'sem.acesso@vetra.example',
            Username = 'sem.acesso.' + System.currentTimeMillis() + '@vetra.example',
            ProfileId = standard.Id,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'pt_BR',
            LocaleSidKey = 'pt_BR',
            TimeZoneSidKey = 'America/Sao_Paulo'
        );
        insert semAcesso;

        System.runAs(semAcesso) {
            try {
                RebuyRadarController.getRadar(null);
                Assert.fail('usuário sem o Permission Set não pode ler o radar');
            } catch (AuraHandledException e) {
                Assert.isTrue(true, 'USER_MODE bloqueou a leitura sem permissão');
            }
        }
    }
}
