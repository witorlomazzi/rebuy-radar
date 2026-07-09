# Rebuy Radar

Motor de radar de recompra para Salesforce: detecta contas que quebraram o padrão de compra,
calcula o valor em risco e prioriza a carteira para o time de vendas — antes que o cliente
silencioso vire churn.

> **Cenário de demonstração:** este projeto foi construído para a Vetra Distribuidora, uma
> empresa fictícia usada como cenário realista do meu portfólio. Todos os dados são sintéticos.

## O problema
Numa distribuidora B2B, o cliente que compra todo mês e para de comprar só é percebido meses
depois. O vendedor monta a agenda da semana no feeling; o gestor não enxerga a carteira em risco.

## Como funciona
- **Compras = Opportunities ganhas** (funciona com o que a org já tem; sem objeto paralelo de pedido).
- Um batch noturno (`RebuyPatternBatch`) recalcula, por conta, a **cadência média de compra**,
  a **próxima compra esperada**, os **dias em atraso** (fórmula: atualiza sozinha entre batches),
  o **valor em risco** (ticket médio × ciclos perdidos) e um **score 0-100 explicável**
  (percentual do caminho até o limiar crítico — nada de caixa-preta).
- Limiar de cada nível (Em dia / Atenção / Risco / Crítico) é **Custom Metadata**: o admin ajusta
  sem deploy.
- O snapshot (`Account_Purchase_Pattern__c`) tem **Owner = dono da conta** e sharing Private:
  cada vendedor vê a própria carteira, o gestor vê o time pela hierarquia. Simples e nativo.

## Arquitetura
`RebuyPatternBatch` (Schedulable, without sharing documentado) → `RebuyPatternService`
(lógica pura, testável em unidade, data de referência injetável) → Selectors `inherited sharing`
com override `@TestVisible` → LWC de priorização (em desenvolvimento).

## Qualidade
- 12 testes Apex (100% aprovados): cenário bulk com 200 contas, idempotência do upsert por
  chave externa, casos negativos, cálculo validado ponta a ponta.
- Cobertura: Service 98%, Batch 96%.

## Status
Em desenvolvimento ativo (sprint pública no meu processo de portfólio). Próximos incrementos:
controller `WITH USER_MODE`, LWC de lista priorizada, script de seed.

---
Witor Lomazzi — [salesforce.flupdigital.com.br](https://salesforce.flupdigital.com.br)
