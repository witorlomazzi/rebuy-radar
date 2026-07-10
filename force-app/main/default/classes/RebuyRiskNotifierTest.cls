@IsTest
private class RebuyRiskNotifierTest {

    private static Integer counter = 1;

    private static Id fakeId(Schema.SObjectType type) {
        String prefix = type.getDescribe().getKeyPrefix();
        String num = String.valueOf(counter++);
        String suffix = '000000000000'.substring(0, 12 - num.length()) + num;
        return Id.valueOf(prefix + suffix);
    }

    private static Account_Purchase_Pattern__c snapshot(Id accountId, Id ownerId, String level) {
        return new Account_Purchase_Pattern__c(
            Account__c = accountId,
            OwnerId = ownerId,
            Risk_Level__c = level
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
        // Só objetos de setup (User) nesta transação: evita MIXED_DML com a Account do teste.
        // Org é pt-BR: "Usuário Padrão" = Standard User. Fallback ao rótulo em inglês por robustez.
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
    static void detectaSomenteTransicaoParaCritico() {
        Id owner = fakeId(User.SObjectType);
        Id accSobe = fakeId(Account.SObjectType);   // Atencao -> Critico  = transição
        Id accJaCritico = fakeId(Account.SObjectType); // Critico -> Critico = não
        Id accBaseline = fakeId(Account.SObjectType);  // null    -> Critico = não (1a rodada)
        Id accMelhorou = fakeId(Account.SObjectType);  // Risco   -> Em_dia  = não

        Map<Id, String> previous = new Map<Id, String>{
            accSobe => 'Atencao',
            accJaCritico => 'Critico',
            accMelhorou => 'Risco'
        };
        List<Account_Purchase_Pattern__c> novos = new List<Account_Purchase_Pattern__c>{
            snapshot(accSobe, owner, 'Critico'),
            snapshot(accJaCritico, owner, 'Critico'),
            snapshot(accBaseline, owner, 'Critico'),
            snapshot(accMelhorou, owner, 'Em_dia')
        };

        List<RebuyRiskNotifier.Transition> transitions =
            RebuyRiskNotifier.detectTransitions(previous, novos);

        Assert.areEqual(1, transitions.size(), 'só a conta que subiu de Atenção para Crítico');
        Assert.areEqual(accSobe, transitions[0].accountId);
        Assert.areEqual(owner, transitions[0].ownerId);
    }

    @IsTest
    static void detectTransitionsToleraEntradasNulas() {
        Assert.areEqual(0, RebuyRiskNotifier.detectTransitions(null, null).size());
        Assert.areEqual(0,
            RebuyRiskNotifier.detectTransitions(
                new Map<Id, String>(),
                new List<Account_Purchase_Pattern__c>()
            ).size());
    }

    @IsTest
    static void notificaDonoEGestorNaTransicao() {
        User seller = [SELECT Id, ManagerId FROM User WHERE Alias = 'vendzz' LIMIT 1];

        Account conta = new Account(Name = 'ZZTEST-Conta Critica', OwnerId = seller.Id);
        insert conta;

        List<RebuyRiskNotifier.Transition> transitions = new List<RebuyRiskNotifier.Transition>{
            new RebuyRiskNotifier.Transition(conta.Id, seller.Id)
        };

        Test.startTest();
        RebuyRiskNotifier.notifyCritical(transitions);
        Test.stopTest();

        Assert.areEqual(1, RebuyRiskNotifier.lastRecipients.size(), 'uma notificação para a conta');
        Set<String> recipients = RebuyRiskNotifier.lastRecipients[0];
        Assert.isTrue(recipients.contains(String.valueOf(seller.Id)), 'dono da conta notificado');
        Assert.isTrue(recipients.contains(String.valueOf(seller.ManagerId)), 'gestor (manager) notificado');
        Assert.areEqual(2, recipients.size(), 'dono + gestor, sem duplicidade');
    }

    @IsTest
    static void notifyCriticalSemTransicoesNaoDisparaNada() {
        Test.startTest();
        RebuyRiskNotifier.notifyCritical(new List<RebuyRiskNotifier.Transition>());
        RebuyRiskNotifier.notifyCritical(null);
        Test.stopTest();

        Assert.areEqual(0, RebuyRiskNotifier.lastRecipients.size(), 'nenhum envio sem transição');
    }
}
