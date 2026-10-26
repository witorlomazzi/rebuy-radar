# Rebuy Radar

Motor de recompra para Salesforce: detecta contas que quebraram o próprio padrão de compra, calcula o valor em risco e prioriza a carteira do time de vendas antes que o cliente silencioso vire churn.

[![CI](https://github.com/witorlomazzi/rebuy-radar/actions/workflows/ci.yml/badge.svg)](https://github.com/witorlomazzi/rebuy-radar/actions/workflows/ci.yml)

> Projeto demonstrativo, com empresa e dados fictícios. A Vetra Distribuidora é uma empresa inventada para dar contexto realista ao cenário. Experiências profissionais reais não são publicadas por confidencialidade.

**Estudo de caso:** [salesforce.flupdigital.com.br/projetos/rebuy-radar.html](https://salesforce.flupdigital.com.br/projetos/rebuy-radar.html) · **Demo no navegador:** [abrir a demo](https://salesforce.flupdigital.com.br/projetos/rebuy-radar.html#demo)

## O problema

Numa distribuidora B2B, o cliente que comprava todo mês e parou só é percebido meses depois. O vendedor monta a agenda no feeling e o gestor não enxerga a carteira em risco. Um limite fixo de dias também não resolve, porque cada cliente tem uma cadência diferente.

## A solução

1. **Cálculo noturno:** `RebuyPatternBatch` analisa as oportunidades ganhas de cada conta na janela configurada e calcula cadência média, próxima compra esperada e dias em atraso.
2. **Score explicável:** cada conta recebe um score de 0 a 100, que representa quanto do caminho até o limiar crítico ela já percorreu. O vendedor consegue explicar: "você compra a cada 30 dias, está há 100 dias sem comprar, 80% do caminho para crítico".
3. **Carteira priorizada:** o LWC `rebuyRadar` lista a carteira em risco por criticidade, e o `rebuyRadarAccount` mostra o cálculo na página da conta.
4. **Alertas sem ruído:** `RebuyRiskNotifier` avisa o dono da conta e o gestor só quando a conta passa para Crítico. `RebuyManagerDigest` envia ao gestor um resumo semanal da equipe.

## Arquitetura

| Camada | Classe | Papel |
|---|---|---|
| Serviço | `RebuyPatternService` | Regra de cadência e score, sem SOQL nem DML |
| Processamento | `RebuyPatternBatch` | Batch e Schedulable; upsert idempotente de `Account_Purchase_Pattern__c` |
| Leitura | `OpportunityWonSelector`, `AccountPurchasePatternSelector` | Consultas isoladas, `inherited sharing` |
| Configuração | `RebuyRadarSettings` | Lê `Rebuy_Radar_Setting__mdt` |
| Notificação | `RebuyRiskNotifier`, `RebuyManagerDigest` | Custom Notifications para vendedor e gestor |
| Interface | `RebuyRadarController`, LWC `rebuyRadar` e `rebuyRadarAccount` | Controller fino, exceções em `AuraHandledException` |

## Decisões técnicas

| Decisão | Por quê | Custo da escolha |
|---|---|---|
| Score baseado na cadência da própria conta | Justificável para o vendedor, sem caixa-preta | Contas com poucas compras ficam fora (mínimo configurável) |
| Um snapshot por conta, com upsert | Reprocessar o batch atualiza em vez de duplicar | Guarda o estado atual, não o histórico de scores |
| `without sharing` só no batch e nas notificações | Rodam em contexto de sistema e precisam ver a carteira inteira | O motivo fica documentado no topo de cada classe |
| Notificar só na transição para Crítico | Evita fadiga de alerta | Uma conta que já está crítica não gera novo aviso |
| Limiares em Custom Metadata | O admin ajusta sem deploy de código | Um registro de configuração para manter |

## Segurança

- O usuário final lê os dados pelo controller `with sharing`, com selectors `inherited sharing`. Cada vendedor vê a própria carteira e o gestor vê a equipe pela hierarquia de papéis.
- O contexto de sistema fica restrito ao batch e às notificações, com a justificativa escrita no código.
- Falha no canal de notificação não invalida o processamento da carteira.

## Testes

- **Apex:** 32 métodos de teste em `RebuyPatternServiceTest`, `RebuyPatternBatchTest`, `RebuyRadarControllerTest`, `RebuyRiskNotifierTest` e `RebuyManagerDigestTest`. Incluem lote de 200 contas, reprocessamento sem duplicar, conta abaixo do mínimo de compras, transição para Crítico e agendamento.
- **Jest:** 7 testes dos LWCs, com wires mockadas, estado vazio e tratamento de erro.
- **CI:** o GitHub Actions roda o Jest e o Salesforce Code Analyzer (PMD) em cada push e pull request. O deploy de validação com testes Apex roda quando o repositório tem uma org de CI configurada.

```bash
npm install --legacy-peer-deps
npm run test:unit
sf apex run test --test-level RunLocalTests --code-coverage --wait 20 -o <sua-org>
```

## Como rodar

```bash
git clone https://github.com/witorlomazzi/rebuy-radar.git
cd rebuy-radar
sf project deploy start -o <sua-org>
sf org assign permset --name Rebuy_Radar_User -o <sua-org>
sf apex run --file scripts/seed-vetra-data.apex -o <sua-org>   # 30 contas e 90 compras fictícias
sf apex run --file scripts/run-batch.apex -o <sua-org>         # calcula os snapshots
```

Configuração em `Setup > Custom Metadata Types > Rebuy Radar Setting > Default`:

| Campo | Padrão | Efeito |
|---|---|---|
| `Analysis_Window_Months__c` | 12 | Meses de histórico analisados |
| `Min_Purchases__c` | 3 | Mínimo de compras para calcular cadência |
| `Attention_Multiplier__c` | 1.2 | Limiar de Atenção |
| `Risk_Multiplier__c` | 1.5 | Limiar de Risco |
| `Critical_Multiplier__c` | 2.0 | Limiar de Crítico |
| `Is_Active__c` | true | Liga ou desliga o recálculo |

## Por onde começar a ler o código

| Arquivo | O que observar |
|---|---|
| `force-app/main/default/classes/RebuyPatternService.cls` | Regra de negócio pura, testável sem banco |
| `force-app/main/default/classes/RebuyPatternBatch.cls` | Upsert idempotente e agendamento noturno |
| `force-app/main/default/classes/RebuyRiskNotifier.cls` | Detecção de transição e justificativa do `without sharing` |
| `force-app/main/default/classes/RebuyManagerDigest.cls` | Agrupamento por gestor e envio único por semana |

## Limitações e próximos passos

- A cadência considera apenas oportunidades ganhas; pedidos fora do Salesforce não entram no cálculo.
- O snapshot guarda o estado atual. Um histórico de scores permitiria mostrar tendência.

---

[Portfólio](https://salesforce.flupdigital.com.br) · [LinkedIn](https://www.linkedin.com/in/witor-hugo-lomazzi-9309651b8/)
