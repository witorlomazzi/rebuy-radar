@IsTest
private class RebuyManagerDigestTest {

    private static Integer counter = 1;

    private static Id fakeId(Schema.SObjectType type) {
        String prefix = type.getDescribe().getKeyPrefix();
        String num = String.valueOf(counter++);
        String suffix = '000000000000'.substring(0, 12 - num.length()) + num;
        return Id.valueOf(prefix + suffix);
    }

    private static Account_Purchase_Pattern__c crit(Id accountId, Id ownerId, Decimal value) {
        return new Account_Purchase_Pattern__c(
            Account__c = accountId,
            OwnerId = ownerId,
            Risk_Level__c = 'Critico',
            Value_At_Risk__c = value
        );
    }

    private static User newUser(Id profileId, String alias) {
        return new User(
            ProfileId = profileId,
            LastName = alias,
            Email = alias + '@zztest.vetra.com',
            Username = alias + '.' + System.now().getTime() + '@zztest.vetra.com',
            Alias = alias.left(8),
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'pt_BR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'pt_BR'
        );
    }

    @TestSetup
    static void seedUsers() {
        // Só objetos de setup (User) aqui: evita MIXED_DML com Account/pattern dos testes.
        Profile p = [
            SELECT Id FROM Profile
            WHERE Name IN ('Usuário Padrão', 'Standard User')
            ORDER BY Name LIMIT 1
        ];
        User manager = newUser(p.Id, 'gestorzz');
        insert manager;
        User seller = newUser(p.Id, 'vendzz');
        seller.ManagerId = manager.Id;
        insert seller;
    }

    @IsTest
    static void agrupaPorGestorSomaEDefinePiorConta() {
        Id manager = fakeId(User.SObjectType);
        Id ownerA = fakeId(User.SObjectType);
        Id ownerB = fakeId(User.SObjectType);
        Id ownerSemGestor = fakeId(User.SObjectType);

        Id accTop = fakeId(Account.SObjectType);   // maior valor -> alvo do clique
        Id accMid = fakeId(Account.SObjectType);
        Id accLow = fakeId(Account.SObjectType);
        Id accOrfa = fakeId(Account.SObjectType);  // dono sem gestor -> excluída

        // JÁ ordenados por valor DESC, como run() entrega.
        List<Account_Purchase_Pattern__c> criticals = new List<Account_Purchase_Pattern__c>{
            crit(accTop, ownerA, 5000),
            crit(accMid, ownerB, 3000),
            crit(accLow, ownerA, 1000),
            crit(accOrfa, ownerSemGestor, 9999)
        };
        Map<Id, Id> managerByOwner = new Map<Id, Id>{
            ownerA => manager,
            ownerB => manager
            // ownerSemGestor ausente de propósito
        };

        Map<Id, RebuyManagerDigest.ManagerSummary> summaries =
            RebuyManagerDigest.buildSummaries(criticals, managerByOwner);

        Assert.areEqual(1, summaries.size(), 'um gestor no resultado');
        RebuyManagerDigest.ManagerSummary s = summaries.get(manager);
        Assert.areEqual(3, s.criticalCount, 'três contas críticas da equipe (órfã fora)');
        Assert.areEqual(9000, s.valueAtRisk, 'soma 5000+3000+1000');
        Assert.areEqual(accTop, s.topAccountId, 'pior conta = primeira (maior valor)');
        Assert.areEqual(3, s.topAccounts.size(), 'top 3 nomes (Account__r null -> "Conta")');
    }

    @IsTest
    static void buildSummariesToleraNulos() {
        Assert.areEqual(0, RebuyManagerDigest.buildSummaries(null, new Map<Id, Id>()).size());
        Assert.areEqual(0, RebuyManagerDigest.buildSummaries(new List<Account_Purchase_Pattern__c>(), null).size());
    }

    @IsTest
    static void bulk200ContasDoisGestores() {
        Id mgr1 = fakeId(User.SObjectType);
        Id mgr2 = fakeId(User.SObjectType);
        Id own1 = fakeId(User.SObjectType);
        Id own2 = fakeId(User.SObjectType);

        List<Account_Purchase_Pattern__c> criticals = new List<Account_Purchase_Pattern__c>();
        for (Integer i = 0; i < 200; i++) {
            Id owner = Math.mod(i, 2) == 0 ? own1 : own2;
            criticals.add(crit(fakeId(Account.SObjectType), owner, 100));
        }
        Map<Id, Id> managerByOwner = new Map<Id, Id>{ own1 => mgr1, own2 => mgr2 };

        Map<Id, RebuyManagerDigest.ManagerSummary> summaries =
            RebuyManagerDigest.buildSummaries(criticals, managerByOwner);

        Assert.areEqual(2, summaries.size(), 'dois gestores');
        Assert.areEqual(100, summaries.get(mgr1).criticalCount);
        Assert.areEqual(100, summaries.get(mgr2).criticalCount);
        Assert.areEqual(10000, summaries.get(mgr1).valueAtRisk, '100 contas x 100');
    }

    @IsTest
    static void runNotificaGestorComResumo() {
        User seller = [SELECT Id, ManagerId FROM User WHERE Alias = 'vendzz' LIMIT 1];

        Account contaAlta = new Account(Name = 'ZZTEST-Metalurgica Aurora', OwnerId = seller.Id);
        Account contaBaixa = new Account(Name = 'ZZTEST-Comercial Bimon', OwnerId = seller.Id);
        insert new List<Account>{ contaAlta, contaBaixa };

        insert new List<Account_Purchase_Pattern__c>{
            new Account_Purchase_Pattern__c(
                Account__c = contaAlta.Id, OwnerId = seller.Id,
                Risk_Level__c = 'Critico', Value_At_Risk__c = 12000
            ),
            new Account_Purchase_Pattern__c(
                Account__c = contaBaixa.Id, OwnerId = seller.Id,
                Risk_Level__c = 'Critico', Value_At_Risk__c = 3000
            ),
            // Atenção NÃO entra no resumo (só crítico).
            new Account_Purchase_Pattern__c(
                Account__c = contaBaixa.Id, OwnerId = seller.Id,
                Risk_Level__c = 'Atencao', Value_At_Risk__c = 999
            )
        };

        Test.startTest();
        RebuyManagerDigest.run();
        Test.stopTest();

        Assert.areEqual(1, RebuyManagerDigest.lastRecipients.size(), 'um resumo para um gestor');
        Assert.isTrue(
            RebuyManagerDigest.lastRecipients[0].contains(String.valueOf(seller.ManagerId)),
            'gestor (manager do dono) notificado'
        );
        String body = RebuyManagerDigest.lastBodies[0];
        Assert.isTrue(body.contains('2 contas'), 'contagem correta no texto: ' + body);
        Assert.isTrue(body.contains('15.000,00'), 'valor total em risco no texto: ' + body);
        Assert.isTrue(body.contains('Aurora'), 'pior conta citada no texto: ' + body);
    }

    @IsTest
    static void runSemCriticosNaoDispara() {
        Test.startTest();
        RebuyManagerDigest.run();
        Test.stopTest();

        Assert.areEqual(0, RebuyManagerDigest.lastRecipients.size(), 'sem crítico, sem resumo');
    }

    @IsTest
    static void formatBRLFormataMoeda() {
        Assert.areEqual('R$ 0,00', RebuyManagerDigest.formatBRL(0));
        Assert.areEqual('R$ 0,00', RebuyManagerDigest.formatBRL(null));
        Assert.areEqual('R$ 999,99', RebuyManagerDigest.formatBRL(999.99));
        Assert.areEqual('R$ 1.000,00', RebuyManagerDigest.formatBRL(1000));
        Assert.areEqual('R$ 144.526,37', RebuyManagerDigest.formatBRL(144526.37));
        Assert.areEqual('R$ 1.234.567,89', RebuyManagerDigest.formatBRL(1234567.89));
    }

    @IsTest
    static void agendaSemanal() {
        Test.startTest();
        String jobId = RebuyManagerDigest.scheduleWeekly();
        Test.stopTest();
        Assert.isNotNull(jobId, 'job agendado');
        CronTrigger ct = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual('0 0 8 ? * MON', ct.CronExpression, 'segunda 8h');
    }
}
