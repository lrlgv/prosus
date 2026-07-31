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

-- ── CONTROLE DE ACESSO (substitui a aba Configuracao/admin_emails) ──

create table allowed_users (
  email text primary key,
  is_admin boolean not null default false,
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
alter table allowed_users enable row level security;

-- Tabelas de dados: leitura para quem está na allowlist, escrita só para admin.
do $$
declare
  t text;
begin
  foreach t in array array['moldagens','base_prova_armacao','prova_dentes','entregas','reembase','remarcacao','proteticos','dentistas','tipos_peca','contratos']
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
