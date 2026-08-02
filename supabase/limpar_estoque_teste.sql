-- ProSUS — limpeza dos dados de TESTE do controle de estoque
--
-- ⚠️ APAGA TODO o estoque: movimentações, produtos, tipos de placa e cores.
-- Use apenas para zerar os testes antes do uso real. Depois que o usuário final
-- começar a lançar dados de verdade, NÃO rode isto.
--
-- Não toca em nada de pacientes (moldagens, etapas, entregas) nem na lista de
-- usuários (allowed_users) — só nas tabelas do módulo de estoque.
--
-- Rodar no SQL Editor do Supabase Studio.

truncate table estoque_movimentos, produtos, cores, tipos_placa restart identity;

-- Conferência: as quatro devem voltar 0.
select 'cores' as tabela, count(*) from cores
union all select 'tipos_placa', count(*) from tipos_placa
union all select 'produtos', count(*) from produtos
union all select 'estoque_movimentos', count(*) from estoque_movimentos;
