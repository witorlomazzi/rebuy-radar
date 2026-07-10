# Rebuy Radar

Motor de radar de recompra para Salesforce: detecta contas que quebraram o padrão de compra,
calcula o valor em risco e prioriza a carteira para o time de vendas — antes que o cliente
silencioso vire churn.

> **Cenário de demonstração:** este projeto foi construído para a **Vetra Distribuidora**,
> uma empresa fictícia usada como cenário realista do meu portfólio. Todos os dados são sintéticos.

## Lógica do negócio

Numa distribuidora B2B, o cliente que compra todo mês e para de comprar só é percebido meses depois.
O vendedor monta a agenda da semana no feeling; o gestor não enxerga a carteira em risco.

O Rebuy Radar resolve isso em três passos:

1. **Cálculo noturno**: batch (`RebuyPatternBatch`) analisa o histórico de compras de cada conta
   nos últimos 12 meses e calcula cadência média, próxima compra esperada, dias em atraso.
2. **Score explicável**: em vez de caixa-preta, cada conta recebe um **score 0-100** que é explícito —
   percentual do caminho até o limiar crítico. Vendedor consegue explicar: "você compra a cada 30 dias;
   está com 100 dias sem comprar; 80% do caminho para crítico".
3. **Visualização por carteira**: LWC lista a carteira em risco, ordenada por criticidade. Sharing nativa:
   cada vendedor vê só a própria carteira; gestores veem o time pela hierarquia.

## Arquitetura

- **RebuyPatternService**: lógica pura (sem SOQL), testável em unidade com data injetável.
- **RebuyPatternBatch**: `without sharing` para enxergar carteira inteira; upsert idempotente.
- **AccountPurchasePatternSelector**: `WITH USER_MODE` — respeita CRUD/FLS/sharing.
- **RebuyRadarController**: thin wrapper, exceções em `AuraHandledException`.
- **LWC rebuyRadar**: tiles de resumo por nível (cores SLDS), filtro, datatable com conta linkada.

## Qualidade e testes

- **18 testes Apex** (100% aprovados): 7 do service, 5 do batch (bulk 200), 6 do controller.
- **4 testes Jest**: LWC com wires mocadas, estado vazio, tratamento de erro.
- **Cobertura**:
  - RebuyPatternService: 98%
  - RebuyPatternBatch: 96%
  - AccountPurchasePatternSelector: 93%
  - RebuyRadarController: 100%

## Setup

```bash
git clone https://github.com/witorlomazzi/rebuy-radar.git
cd rebuy-radar
npm install --legacy-peer-deps
sf org login web -o witor-dev  # ou já autenticada
sf apex run --file scripts/seed-vetra-data.apex -o witor-dev  # 30 contas + 90 compras
sf apex run --file scripts/run-batch.apex -o witor-dev  # calcula snapshots
npm run test:unit  # Jest
sf apex run test --class-names RebuyPatternServiceTest --class-names RebuyPatternBatchTest --class-names RebuyRadarControllerTest -o witor-dev --wait 10 --code-coverage
```

## CI/CD

GitHub Actions pipeline:
- Pull Request: testes Apex + Jest.
- Merge: deploy via `sf project deploy start`.

## Configuração

`Setup → Custom Metadata Types → Rebuy_Radar_Setting → Default record`:
- **Analysis_Window_Months__c**: meses p/ trás (padrão: 12)
- **Min_Purchases__c**: mínimo de compras (padrão: 3)
- **Attention_Multiplier__c**: limite Atenção (padrão: 1.2)
- **Risk_Multiplier__c**: limite Risco (padrão: 1.5)
- **Critical_Multiplier__c**: limite Crítico (padrão: 2.0)
- **Is_Active__c**: ativar/desativar (padrão: true)

## Status

✅ **Completo**: 7/7 incrementos da sprint entregues. Motor production-ready. LWC funcional.
Batch agendável. Seed com 30 contas + 90 compras.

---

**Witor Lomazzi** — [LinkedIn](https://www.linkedin.com/in/witor-hugo-lomazzi-9309651b8/) | [Portfolio](https://salesforce.flupdigital.com.br)
