/**
 * Script de seed: popula a org com dados sintéticos da Vetra Distribuidora.
 * Cenário de demonstração: 30 contas com diferentes padrões de recompra e níveis de risco.
 *
 * Executar uma vez via: sf apex run --file scripts/seed-vetra-data.apex -o witor-dev
 */

List<Account> accounts = new List<Account>();
List<Opportunity> opportunities = new List<Opportunity>();

// Personagens realistas da Vetra
List<Map<String, Object>> personas = new List<Map<String, Object>>{
    new Map<String, Object>{ 'name' => 'Construções Silveira', 'type' => 'Construção', 'risk' => 'critico' },
    new Map<String, Object>{ 'name' => 'Metalúrgica do Vale', 'type' => 'Indústria', 'risk' => 'critico' },
    new Map<String, Object>{ 'name' => 'Logística Expressa BR', 'type' => 'Logística', 'risk' => 'risco' },
    new Map<String, Object>{ 'name' => 'Usinagem Precision Ltda', 'type' => 'Manufatura', 'risk' => 'risco' },
    new Map<String, Object>{ 'name' => 'Incorporadora Goiás', 'type' => 'Construção', 'risk' => 'risco' },
    new Map<String, Object>{ 'name' => 'Serviços Industriais Prime', 'type' => 'Serviços', 'risk' => 'atencao' },
    new Map<String, Object>{ 'name' => 'Distribuição Centro-Oeste', 'type' => 'Distribuição', 'risk' => 'atencao' },
    new Map<String, Object>{ 'name' => 'Fábrica de Componentes XYZ', 'type' => 'Manufatura', 'risk' => 'emdia' },
    new Map<String, Object>{ 'name' => 'Consórcio de Obras', 'type' => 'Construção', 'risk' => 'emdia' },
    new Map<String, Object>{ 'name' => 'Transportes Integrados', 'type' => 'Logística', 'risk' => 'emdia' }
};

// Multiplicar 3x para ter 30 contas com variação
Integer accountCount = 0;
for (Integer i = 0; i < 3; i++) {
    for (Map<String, Object> persona : personas) {
        accounts.add(new Account(
            Name = (String) persona.get('name') + (i > 0 ? ' - Filial ' + (i + 1) : ''),
            Type = (String) persona.get('type'),
            Industry = 'Industrial',
            BillingCountry = 'Brasil',
            BillingState = 'GO'
        ));
    }
}

insert accounts;

// Criar histórico de compras para cada conta simulando diferentes riscos
Map<String, Account> accountsByName = new Map<String, Account>();
for (Account acc : accounts) {
    accountsByName.put(acc.Name, acc);
}

for (Account acc : accounts) {
    String riskLevel = 'emdia'; // padrão

    // Atribuir nível de risco baseado no nome (isso é só pra seed)
    for (Map<String, Object> persona : personas) {
        if (acc.Name.startsWith((String) persona.get('name'))) {
            riskLevel = (String) persona.get('risk');
            break;
        }
    }

    List<Date> purchaseDates = generatePurchaseDates(riskLevel);
    Decimal avgAmount = 2000 + Math.random() * 3000;

    for (Date purchaseDate : purchaseDates) {
        opportunities.add(new Opportunity(
            Name = acc.Name + ' - Pedido ' + purchaseDate.format(),
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = purchaseDate,
            Amount = avgAmount + (Math.random() * 1000)
        ));
    }
}

insert opportunities;

System.debug('✓ Seed completo: ' + accounts.size() + ' contas + ' + opportunities.size() + ' compras');

static List<Date> generatePurchaseDates(String riskLevel) {
    Date today = Date.today();
    List<Date> dates = new List<Date>();

    if (riskLevel == 'critico') {
        // Crítico: última compra há 100+ dias, cadência de 30 dias
        dates.add(today.addDays(-160));
        dates.add(today.addDays(-130));
        dates.add(today.addDays(-100));
    } else if (riskLevel == 'risco') {
        // Risco: última compra há 50+ dias, cadência de 30 dias
        dates.add(today.addDays(-90));
        dates.add(today.addDays(-60));
        dates.add(today.addDays(-50));
    } else if (riskLevel == 'atencao') {
        // Atenção: última compra há 40+ dias, cadência de 30 dias
        dates.add(today.addDays(-100));
        dates.add(today.addDays(-70));
        dates.add(today.addDays(-40));
    } else { // emdia
        // Em dia: última compra há 10-20 dias, cadência de 30 dias
        dates.add(today.addDays(-80));
        dates.add(today.addDays(-50));
        dates.add(today.addDays(-15));
    }

    return dates;
}
