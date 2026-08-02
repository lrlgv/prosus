-- ProSUS — remove remarcações duplicadas pela migração
--
-- A tabela `remarcacao` é histórico puro (não tem chave natural), então a migração
-- sempre INSERE. Rodar "Migrar dados" duas vezes duplicou todas as linhas — foi o que
-- aconteceu: o log mostrou 51 linhas migradas mas 102 no total.
--
-- Este script mantém a ocorrência mais antiga de cada remarcação idêntica
-- (mesmo código, etapa, data e observação) e remove as repetidas.
--
-- Rodar no SQL Editor do Supabase Studio, e SEMPRE depois de uma nova execução
-- da migração, caso ela precise ser repetida.

-- 1) Confira antes quantas linhas serão removidas:
select count(*) as duplicadas_a_remover
from remarcacao a
where exists (
  select 1 from remarcacao b
  where b.id < a.id
    and b.codigo = a.codigo
    and b.etapa is not distinct from a.etapa
    and b.data is not distinct from a.data
    and b.obs is not distinct from a.obs
);

-- 2) Remove as duplicatas (mantém o menor id de cada grupo):
delete from remarcacao a
where exists (
  select 1 from remarcacao b
  where b.id < a.id
    and b.codigo = a.codigo
    and b.etapa is not distinct from a.etapa
    and b.data is not distinct from a.data
    and b.obs is not distinct from a.obs
);

-- 3) Confirmação final:
select count(*) as total_remarcacoes from remarcacao;
