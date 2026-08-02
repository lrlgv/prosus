-- ProSUS — schema de migração Google Sheets → Supabase (Postgres)
-- Rodar no SQL Editor do Supabase Studio, num projeto novo (free tier).
-- Referência de mapeamento de abas -> tabelas: ver CLAUDE.md / documentacao_prosus.md

-- ── TABELAS PRINCIPAIS ──────────────────────────────────────────────

create table moldagens (
  codigo text primary key,
  nome text not null,
  dentista text,
  tipo text,
  data date,
  dist text,
  situacao text default 'Pendente',
  obs text
);

create table base_prova_armacao (
  codigo text primary key references moldagens(codigo) on delete cascade,
  previsao date,
  data date,
  obs text
);

create table prova_dentes (
  codigo text primary key references moldagens(codigo) on delete cascade,
  previsao date,
  data date,
  obs text
);

create table entregas (
  codigo text primary key references moldagens(codigo) on delete cascade,
  previsao date,
  entrega date,
  obs text
);

create table reembase (
  codigo text primary key references moldagens(codigo) on delete cascade,
  data date,
  obs text
);

create table remarcacao (
  id bigserial primary key,
  codigo text not null references moldagens(codigo) on delete cascade,
  etapa text,
  data date,
  obs text,
  criado_em timestamptz not null default now()
);

create table proteticos (
  codigo text primary key,
  nome text not null,
  paga_armacao boolean default false
);

create table dentistas (
  nome text primary key
);

create table tipos_peca (
  descricao text primary key,
  qtd_pt numeric default 0,
  qtd_ppr numeric default 0
);

create table contratos (
  id text primary key,
  inicio date not null,
  fim date not null,
  reembase_mes numeric default 0,
  pecas_contratadas numeric default 0
);

-- ── CONTROLE DE ESTOQUE DE PLACAS ───────────────────────────────────
-- Entidades nativas do banco (não existem no Sheets, ficam fora da migração).

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

-- Livro-razão: única fonte de verdade do saldo. Entradas manuais e baixas por
-- paciente convivem aqui; o saldo é sempre derivado (entradas - saídas).
--
-- data      = quando a movimentação de fato aconteceu (editável)
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

-- ── CONTROLE DE ACESSO (substitui a aba Configuracao/admin_emails) ──

create table allowed_users (
  email text primary key,
  is_admin boolean not null default false,
  notificar_estoque boolean not null default false, -- recebe aviso de estoque mínimo
  nome text,
  criado_em timestamptz not null default now()
);

-- ── FUNÇÕES DE APOIO PARA AS POLICIES DE RLS ────────────────────────

create or replace function is_allowed() returns boolean as $$
  select exists (
    select 1 from allowed_users where email = auth.jwt()->>'email'
  );
$$ language sql security definer stable;

create or replace function is_admin() returns boolean as $$
  select exists (
    select 1 from allowed_users where email = auth.jwt()->>'email' and is_admin = true
  );
$$ language sql security definer stable;

-- ── RLS ──────────────────────────────────────────────────────────────

alter table moldagens enable row level security;
alter table base_prova_armacao enable row level security;
alter table prova_dentes enable row level security;
alter table entregas enable row level security;
alter table reembase enable row level security;
alter table remarcacao enable row level security;
alter table proteticos enable row level security;
alter table dentistas enable row level security;
alter table tipos_peca enable row level security;
alter table contratos enable row level security;
alter table cores enable row level security;
alter table tipos_placa enable row level security;
alter table produtos enable row level security;
alter table estoque_movimentos enable row level security;
alter table allowed_users enable row level security;

-- Tabelas de dados: leitura para quem está na allowlist, escrita só para admin.
do $$
declare
  t text;
begin
  foreach t in array array['moldagens','base_prova_armacao','prova_dentes','entregas','reembase','remarcacao','proteticos','dentistas','tipos_peca','contratos','cores','tipos_placa','produtos','estoque_movimentos']
  loop
    execute format('create policy select_allowed on %I for select using (is_allowed());', t);
    execute format('create policy write_admin on %I for insert with check (is_admin());', t);
    execute format('create policy update_admin on %I for update using (is_admin()) with check (is_admin());', t);
    execute format('create policy delete_admin on %I for delete using (is_admin());', t);
  end loop;
end $$;

-- allowed_users: qualquer usuário permitido pode ler a própria linha (pra checar status);
-- só admin gerencia a lista (adicionar/remover/promover outros e-mails).
create policy select_own_or_admin on allowed_users for select using (
  email = auth.jwt()->>'email' or is_admin()
);
create policy write_admin on allowed_users for insert with check (is_admin());
create policy update_admin on allowed_users for update using (is_admin()) with check (is_admin());
create policy delete_admin on allowed_users for delete using (is_admin());

-- ── SEED INICIAL ─────────────────────────────────────────────────────
-- Ajustar e-mail(s) reais antes de rodar. O primeiro admin precisa ser inserido
-- manualmente (via Table Editor ou aqui), já que a policy de insert exige is_admin()
-- e ninguém é admin ainda nesse ponto — desabilite RLS temporariamente ou rode como
-- superusuário no SQL Editor (o SQL Editor do Supabase roda com privilégio de owner,
-- então este insert funciona normalmente mesmo com RLS ativo):
-- insert into allowed_users (email, is_admin, nome) values ('seu-email@gmail.com', true, 'Seu Nome');
