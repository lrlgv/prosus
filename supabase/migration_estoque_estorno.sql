-- ProSUS — estorno de movimentações de estoque
-- Incremento sobre migration_estoque_inativos.sql (que já foi aplicado).
-- Rodar no SQL Editor do Supabase Studio.

-- Remover uma placa de um paciente (ou desfazer uma entrada) deixa de APAGAR a linha:
-- passa a inserir um movimento contrário vinculado ao original. Assim o histórico fica
-- append-only e mostra a sequência real (utilização → devolução), em vez de a saída
-- simplesmente desaparecer como se nunca tivesse existido.
alter table estoque_movimentos
  add column estorno_de bigint references estoque_movimentos(id) on delete set null;

create index estoque_movimentos_estorno_idx on estoque_movimentos (estorno_de);
