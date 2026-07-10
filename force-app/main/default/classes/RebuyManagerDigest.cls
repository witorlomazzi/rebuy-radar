/**
 * Resumo semanal do gestor (Rebuy Radar).
 *
 * O RebuyRiskNotifier já avisa o VENDEDOR (dono da conta) na hora em que uma conta vira
 * Crítica. Falta a visão do GESTOR: sem abrir conta por conta, ele precisa de um resumo do
 * risco crítico acumulado na carteira da equipe dele. Esta classe roda semanal (Schedulable),
 * agrupa as contas hoje Críticas pelo GESTOR do dono (User.ManagerId) e dispara UMA Custom
 * Notification por gestor com a contagem, o valor total em risco e as piores contas.
 *
 * Anti-fadiga por design: um único envio semanal por gestor, apenas nível Crítico (Atenção não
 * gera aviso), e só se houver ao menos uma conta crítica na equipe. O clique abre a pior conta
 * (maior valor em risco), o ponto de partida natural da ação.
 *
 * without sharing INTENCIONAL: roda em contexto de sistema (agendador) e precisa enxergar a
 * carteira inteira para resolver dono/gestor de qualquer conta. A leitura do usuário final
 * segue protegida no controller (WITH USER_MODE) e pelo sharing do objeto.
 */
public without sharing class RebuyManagerDigest implements Schedulable {

    private static final String NOTIF_DEVELOPER_NAME = 'Rebuy_Radar_Resumo_Gestor';
    private static final String CRITICAL_LEVEL = 'Critico';
    private static final Integer TOP_ACCOUNTS_IN_BODY = 3;

    /** Resumo do risco crítico da equipe de um gestor. */
    public class ManagerSummary {
        public Id managerId;
        public Integer criticalCount = 0;
        public Decimal valueAtRisk = 0;
        public List<String> topAccounts = new List<String>();
        // Pior conta da equipe (maior valor em risco) — alvo do clique da notificação.
        public Id topAccountId;
    }

    // Captura os envios para asserção em teste e smoke (send() não é consultável).
    @TestVisible
    private static List<Set<String>> lastRecipients;
    @TestVisible
    private static List<String> lastBodies;

    /**
     * Monta um resumo por gestor a partir das contas hoje Críticas.
     * @param criticalPatterns snapshots Críticos JÁ ordenados por Value_At_Risk__c DESC
     *        (assim a primeira conta de cada gestor é a pior, e o topo do body sai correto).
     * @param managerByOwner gestor de cada dono (donos sem gestor ficam de fora).
     */
    public static Map<Id, ManagerSummary> buildSummaries(
        List<Account_Purchase_Pattern__c> criticalPatterns,
        Map<Id, Id> managerByOwner
    ) {
        Map<Id, ManagerSummary> byManager = new Map<Id, ManagerSummary>();
        if (criticalPatterns == null || managerByOwner == null) {
            return byManager;
        }

        for (Account_Purchase_Pattern__c pattern : criticalPatterns) {
            Id managerId = managerByOwner.get(pattern.OwnerId);
            if (managerId == null) {
                continue; // dono sem gestor: ninguém para resumir
            }

            ManagerSummary summary = byManager.get(managerId);
            if (summary == null) {
                summary = new ManagerSummary();
                summary.managerId = managerId;
                summary.topAccountId = pattern.Account__c; // 1a (maior valor) = alvo do clique
                byManager.put(managerId, summary);
            }

            summary.criticalCount++;
            Decimal value = pattern.Value_At_Risk__c == null ? 0 : pattern.Value_At_Risk__c;
            summary.valueAtRisk += value;

            if (summary.topAccounts.size() < TOP_ACCOUNTS_IN_BODY) {
                String accountName = pattern.Account__r == null ? null : pattern.Account__r.Name;
                summary.topAccounts.add(accountName == null ? 'Conta' : accountName);
            }
        }
        return byManager;
    }

    /** Dispara uma Custom Notification de resumo por gestor. */
    public static void notifyManagers(Map<Id, ManagerSummary> summariesByManager) {
        lastRecipients = new List<Set<String>>();
        lastBodies = new List<String>();
        if (summariesByManager == null || summariesByManager.isEmpty()) {
            return;
        }

        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = :NOTIF_DEVELOPER_NAME
            LIMIT 1
        ];
        if (types.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                'CustomNotificationType ' + NOTIF_DEVELOPER_NAME + ' ausente; resumo do gestor ignorado.');
            return;
        }
        Id typeId = types[0].Id;

        for (ManagerSummary summary : summariesByManager.values()) {
            if (summary.criticalCount == 0) {
                continue; // guarda: sem crítico, sem aviso
            }

            String body = buildBody(summary);
            Set<String> recipients = new Set<String>{ String.valueOf(summary.managerId) };

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(typeId);
            notification.setTitle('Resumo semanal: risco crítico na sua equipe');
            notification.setBody(body);
            notification.setTargetId(summary.topAccountId);

            lastRecipients.add(recipients);
            lastBodies.add(body);
            try {
                notification.send(recipients);
            } catch (Exception e) {
                // Falha de notificação (ex.: gestor inativo) não pode abortar os demais envios.
                System.debug(LoggingLevel.WARN,
                    'Falha ao notificar gestor ' + summary.managerId + ': ' + e.getMessage());
            }
        }
    }

    /** Texto do resumo: contagem, valor total em risco e as piores contas. */
    @TestVisible
    private static String buildBody(ManagerSummary summary) {
        String plural = summary.criticalCount == 1 ? 'conta' : 'contas';
        String body = 'Sua equipe tem ' + summary.criticalCount + ' ' + plural
            + ' em risco crítico de recompra, somando ' + formatBRL(summary.valueAtRisk) + ' em risco.';
        if (!summary.topAccounts.isEmpty()) {
            body += ' Principais: ' + String.join(summary.topAccounts, ', ') + '.';
        }
        body += ' Abra o Rebuy Radar para priorizar.';
        return body;
    }

    /** Formata Decimal como moeda pt-BR (R$ 1.234,56) sem depender de locale do runtime. */
    @TestVisible
    private static String formatBRL(Decimal value) {
        Decimal amount = (value == null ? 0 : value).setScale(2);
        String digits = String.valueOf(amount.abs());
        List<String> parts = digits.split('\\.');
        String intPart = parts[0];
        String decPart = parts.size() > 1 ? (parts[1] + '00').substring(0, 2) : '00';

        String grouped = '';
        Integer count = 0;
        for (Integer i = intPart.length() - 1; i >= 0; i--) {
            grouped = intPart.substring(i, i + 1) + grouped;
            count++;
            if (Math.mod(count, 3) == 0 && i > 0) {
                grouped = '.' + grouped;
            }
        }
        String sign = amount < 0 ? '-' : '';
        return 'R$ ' + sign + grouped + ',' + decPart;
    }

    /** Pipeline completo: lê os Críticos, resolve gestores e notifica. */
    public static void run() {
        List<Account_Purchase_Pattern__c> criticals = [
            SELECT Account__c, Account__r.Name, OwnerId, Value_At_Risk__c
            FROM Account_Purchase_Pattern__c
            WHERE Risk_Level__c = :CRITICAL_LEVEL
            ORDER BY Value_At_Risk__c DESC NULLS LAST
        ];
        if (criticals.isEmpty()) {
            notifyManagers(new Map<Id, ManagerSummary>());
            return;
        }

        Set<Id> ownerIds = new Set<Id>();
        for (Account_Purchase_Pattern__c pattern : criticals) {
            ownerIds.add(pattern.OwnerId);
        }
        Map<Id, Id> managerByOwner = new Map<Id, Id>();
        for (User u : [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds AND ManagerId != null]) {
            managerByOwner.put(u.Id, u.ManagerId);
        }

        notifyManagers(buildSummaries(criticals, managerByOwner));
    }

    // Schedulable: permite System.schedule direto desta classe.
    public void execute(SchedulableContext context) {
        run();
    }

    /** Agenda o resumo semanal (segunda, 8h). Rodar uma vez via Anonymous Apex. */
    public static Id scheduleWeekly() {
        return System.schedule(
            'Rebuy Radar - resumo semanal do gestor',
            '0 0 8 ? * MON',
            new RebuyManagerDigest()
        );
    }
}
