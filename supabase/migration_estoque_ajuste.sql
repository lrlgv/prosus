-- ProSUS — ajuste manual de saldo de estoque
-- Incremento sobre migration_estoque_estorno.sql (que já foi aplicado).
-- Rodar no SQL Editor do Supabase Studio.

-- Marca as movimentações que vieram de um ajuste manual de saldo (correção de
-- cadastro errado, quebra, perda, divergência em contagem física). Continuam sendo
-- entrada ou saída de verdade — a flag existe para a auditoria conseguir separar
-- o que foi movimento real do que foi correção.
alter table estoque_movimentos
  add column ajuste boolean not null default false;
