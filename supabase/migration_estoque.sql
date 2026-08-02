-- ProSUS — controle de estoque de placas (incremento sobre o schema.sql já aplicado)
-- Rodar no SQL Editor do Supabase Studio. Seguro rodar uma vez só.
-- (O schema.sql completo já contém tudo isto — este arquivo existe porque o schema
-- original já foi aplicado no projeto antes desta funcionalidade existir.)

-- ── CADASTROS BÁSICOS ───────────────────────────────────────────────

create table cores (
  nome text primary key,
  criado_em timestamptz not null default now()
);

create table tipos_placa (
  nome text primary key,
  criado_em timestamptz not null default now()
);

-- Produto = combinação de um tipo de placa com uma cor.
-- ON UPDATE CASCADE porque o CRUD de cores/tipos edita o próprio nome (a PK),
-- mesmo padrão do cadastro de Dentistas.
create table produtos (
  id bigserial primary key,
  tipo_placa text not null references tipos_placa(nome) on update cascade,
  cor text not null references cores(nome) on update cascade,
  estoque_minimo integer not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  unique (tipo_placa, cor)
);

-- ── LIVRO-RAZÃO DE ESTOQUE ──────────────────────────────────────────
-- Única fonte de verdade do saldo: entradas manuais e baixas por paciente
-- convivem aqui. O saldo é sempre derivado (soma entradas - saídas), então
-- nunca fica dessincronizado.
--
-- data      = quando a movimentação de fato aconteceu (editável; permite lançar
--             uma compra recebida ontem, ou usar a data real da prova de dentes)
-- criado_em = quando o registro foi digitado no sistema (automático)
-- A diferença entre as duas é o que permite auditar lançamento retroativo.
create table estoque_movimentos (
  id bigserial primary key,
  produto_id bigint not null references produtos(id) on delete cascade,
  tipo text not null check (tipo in ('entrada','saida')),
  quantidade integer not null check (quantidade > 0),
  data date not null default current_date,
  codigo text references moldagens(codigo) on delete set null, -- preenchido na baixa por prova de dentes
  obs text,
  usuario_email text,
  criado_em timestamptz not null default now()
);

create index estoque_movimentos_produto_idx on estoque_movimentos (produto_id);
create index estoque_movimentos_codigo_idx on estoque_movimentos (codigo);

-- ── NOTIFICAÇÃO DE ESTOQUE MÍNIMO ───────────────────────────────────

alter table allowed_users add column notificar_estoque boolean not null default false;

-- ── RLS (mesmo padrão das demais tabelas) ───────────────────────────

alter table cores enable row level security;
alter table tipos_placa enable row level security;
alter table produtos enable row level security;
alter table estoque_movimentos enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['cores','tipos_placa','produtos','estoque_movimentos']
  loop
    execute format('create policy select_allowed on %I for select using (is_allowed());', t);
    execute format('create policy write_admin on %I for insert with check (is_admin());', t);
    execute format('create policy update_admin on %I for update using (is_admin()) with check (is_admin());', t);
    execute format('create policy delete_admin on %I for delete using (is_admin());', t);
  end loop;
end $$;
