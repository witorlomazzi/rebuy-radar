@IsTest
private class RebuyPatternBatchTest {

    private static final Integer ACCOUNT_COUNT = 200;

    @TestSetup
    static void makeData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < ACCOUNT_COUNT; i++) {
            accounts.add(new Account(Name = 'Vetra Cliente ' + i));
        }
        insert accounts;

        // 3 compras por conta com cadência de 30 dias; a última há 100 dias: quebra de padrão.
        List<Opportunity> opps = new List<Opportunity>();
        for (Account acc : accounts) {
            for (Integer daysAgo : new List<Integer>{ 160, 130, 100 }) {
                opps.add(new Opportunity(
                    Name = acc.Name + ' pedido ' + daysAgo,
                    AccountId = acc.Id,
                    StageName = 'Closed Won',
                    CloseDate = Date.today().addDays(-daysAgo),
                    Amount = 2000
                ));
            }
        }
        insert opps;
    }

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
    static void calculaCarteiraInteiraEmBulk() {
        useDefaultSettings();

        Test.startTest();
        Database.executeBatch(new RebuyPatternBatch(), 200);
        Test.stopTest();

        List<Account_Purchase_Pattern__c> patterns = [
            SELECT Account__c, Risk_Level__c, Risk_Score__c, Value_At_Risk__c,
                   Average_Interval_Days__c, Purchases_Analyzed__c, OwnerId, Account__r.OwnerId
            FROM Account_Purchase_Pattern__c
        ];
        Assert.areEqual(ACCOUNT_COUNT, patterns.size(), 'um snapshot por conta');
        for (Account_Purchase_Pattern__c p : patterns) {
            Assert.areEqual('Critico', p.Risk_Level__c, '100 dias sem compra com cadencia 30 = critico');
            Assert.areEqual(100, p.Risk_Score__c);
            Assert.areEqual(6000.00, p.Value_At_Risk__c, '2000 x 3 ciclos perdidos');
            Assert.areEqual(30.0, p.Average_Interval_Days__c);
            Assert.areEqual(3, p.Purchases_Analyzed__c);
            Assert.areEqual(p.Account__r.OwnerId, p.OwnerId, 'dono do snapshot = dono da conta');
        }
    }

    @IsTest
    static void rodarDuasVezesNaoDuplicaSnapshots() {
        useDefaultSettings();

        Test.startTest();
        Database.executeBatch(new RebuyPatternBatch(), 200);
        Test.stopTest();
        // Segunda execução síncrona simulada: upsert pela chave externa deve atualizar, não duplicar.
        RebuyPatternBatch batch = new RebuyPatternBatch();
        batch.execute(null, [SELECT Id, OwnerId FROM Account]);

        Assert.areEqual(ACCOUNT_COUNT, [SELECT COUNT() FROM Account_Purchase_Pattern__c],
            'upsert idempotente por Account_Key__c');
    }

    @IsTest
    static void contaComMenosComprasQueOMinimoEIgnorada() {
        useDefaultSettings();
        Account novata = new Account(Name = 'Vetra Cliente Novato');
        insert novata;
        insert new Opportunity(Name = 'unico pedido', AccountId = novata.Id,
            StageName = 'Closed Won', CloseDate = Date.today().addDays(-10), Amount = 500);

        Test.startTest();
        // 2000: em teste o batch precisa caber em UMA invocacao de execute (201 contas no escopo).
        Database.executeBatch(new RebuyPatternBatch(), 2000);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Account_Purchase_Pattern__c WHERE Account__c = :novata.Id],
            'conta com 1 compra nao entra no radar');
    }

    @IsTest
    static void agendamentoNoturnoEDisparoViaSchedulable() {
        useDefaultSettings();

        Test.startTest();
        Id jobId = RebuyPatternBatch.scheduleNightly();
        Test.stopTest();

        Assert.isNotNull(jobId, 'job agendado');
        Assert.areEqual(1, [SELECT COUNT() FROM CronTrigger WHERE Id = :jobId]);
    }
}
