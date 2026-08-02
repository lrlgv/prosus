-- ProSUS — exclusão/inativação de cores, tipos de placa e produtos
-- Incremento sobre migration_estoque.sql (que já foi aplicado).
-- Rodar no SQL Editor do Supabase Studio.

-- Cores e tipos de placa passam a poder ser inativados quando não puderem ser
-- excluídos (por estarem em uso por algum produto). Produtos já tinham 'ativo'.
alter table cores add column ativo boolean not null default true;
alter table tipos_placa add column ativo boolean not null default true;

-- Protege o histórico de estoque: com ON DELETE CASCADE, apagar um produto apagava
-- silenciosamente todas as suas movimentações — destruindo a trilha de auditoria.
-- Com RESTRICT, o banco recusa a exclusão e a aplicação inativa o produto no lugar.
alter table estoque_movimentos drop constraint estoque_movimentos_produto_id_fkey;
alter table estoque_movimentos add constraint estoque_movimentos_produto_id_fkey
  foreign key (produto_id) references produtos(id) on delete restrict;
