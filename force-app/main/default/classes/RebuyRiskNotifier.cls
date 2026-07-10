/**
 * Leva o resultado do radar até o usuário: quando o recálculo noturno muda uma conta
 * PARA o nível Crítico, dispara uma Custom Notification (sino do Salesforce) para o dono
 * da conta e para o gestor dele (Manager), com link direto para a Conta.
 *
 * Anti-spam por design: só notifica na TRANSIÇÃO para Crítico. Se a conta já estava
 * Crítica, ou se é o primeiro snapshot (sem estado anterior — baseline), não notifica.
 *
 * without sharing INTENCIONAL: roda dentro do batch noturno (contexto de sistema) e
 * precisa resolver dono/gestor de qualquer conta da carteira.
 */
public without sharing class RebuyRiskNotifier {

    private static final String NOTIF_DEVELOPER_NAME = 'Rebuy_Radar_Conta_Critica';
    private static final String CRITICAL_LEVEL = 'Critico';

    /** Uma transição detectada: a conta e seu dono no momento do recálculo. */
    public class Transition {
        public Id accountId;
        public Id ownerId;
        public Transition(Id accountId, Id ownerId) {
            this.accountId = accountId;
            this.ownerId = ownerId;
        }
    }

    // Captura os destinatários de cada envio para asserção em teste (send() não é consultável).
    @TestVisible
    private static List<Set<String>> lastRecipients;

    /**
     * Detecta contas que ACABARAM de virar Crítico neste recálculo.
     * @param previousLevelByAccount nível anterior por conta (null = sem snapshot anterior).
     * @param newPatterns snapshots recém-calculados (com Account__c, Risk_Level__c, OwnerId).
     */
    public static List<Transition> detectTransitions(
        Map<Id, String> previousLevelByAccount,
        List<Account_Purchase_Pattern__c> newPatterns
    ) {
        List<Transition> transitions = new List<Transition>();
        if (newPatterns == null) {
            return transitions;
        }
        for (Account_Purchase_Pattern__c pattern : newPatterns) {
            if (pattern.Risk_Level__c != CRITICAL_LEVEL) {
                continue;
            }
            String previous = previousLevelByAccount == null
                ? null
                : previousLevelByAccount.get(pattern.Account__c);
            // Baseline (previous == null) não conta como transição: evita enxurrada na 1a rodada.
            if (previous == null || previous == CRITICAL_LEVEL) {
                continue;
            }
            transitions.add(new Transition(pattern.Account__c, pattern.OwnerId));
        }
        return transitions;
    }

    /** Dispara uma Custom Notification por conta em transição, ao dono e ao gestor dele. */
    public static void notifyCritical(List<Transition> transitions) {
        lastRecipients = new List<Set<String>>();
        if (transitions == null || transitions.isEmpty()) {
            return;
        }

        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = :NOTIF_DEVELOPER_NAME
            LIMIT 1
        ];
        if (types.isEmpty()) {
            // Tipo de notificação não implantado ainda: não derruba o batch por causa disso.
            System.debug(LoggingLevel.WARN,
                'CustomNotificationType ' + NOTIF_DEVELOPER_NAME + ' ausente; notificações ignoradas.');
            return;
        }
        Id typeId = types[0].Id;

        Set<Id> ownerIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (Transition t : transitions) {
            ownerIds.add(t.ownerId);
            accountIds.add(t.accountId);
        }

        Map<Id, Id> managerByOwner = new Map<Id, Id>();
        for (User u : [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds]) {
            if (u.ManagerId != null) {
                managerByOwner.put(u.Id, u.ManagerId);
            }
        }
        Map<Id, Account> accountsById = new Map<Id, Account>([
            SELECT Id, Name FROM Account WHERE Id IN :accountIds
        ]);

        for (Transition t : transitions) {
            Set<String> recipients = new Set<String>{ String.valueOf(t.ownerId) };
            if (managerByOwner.containsKey(t.ownerId)) {
                recipients.add(String.valueOf(managerByOwner.get(t.ownerId)));
            }

            String accountName = accountsById.containsKey(t.accountId)
                ? accountsById.get(t.accountId).Name
                : 'Conta';

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setNotificationTypeId(typeId);
            notification.setTitle('Conta em risco crítico de recompra');
            notification.setBody(accountName + ' passou para o nível Crítico no Rebuy Radar. Abra a conta para agir a tempo.');
            notification.setTargetId(t.accountId);

            lastRecipients.add(recipients);
            try {
                notification.send(recipients);
            } catch (Exception e) {
                // Uma falha de notificação (ex.: usuário inativo) não pode abortar o recálculo.
                System.debug(LoggingLevel.WARN,
                    'Falha ao notificar conta ' + t.accountId + ': ' + e.getMessage());
            }
        }
    }
}
