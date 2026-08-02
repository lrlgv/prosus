# ProSUS — Contexto para Claude Code

## O que é
PWA (Progressive Web App) de arquivo único para gestão de próteses dentárias no SUS. Frontend puro com JS/CSS embarcados.

**A migração para Supabase foi concluída na v7.0.** O antigo app baseado em Google Sheets foi aposentado e mantido apenas como plano de retorno.

| | Produção (atual) | Legado (aposentado) |
|---|---|---|
| Arquivo | `index.html` (raiz) | `legacy/index.html` |
| Versão | **v7.0** | v5.2 |
| Backend | **Supabase** (Postgres + Auth + RLS) | Google Sheets + Apps Script |
| URL | https://lrlgv.github.io/prosus | https://lrlgv.github.io/prosus/legacy/ |

O `legacy/` existe só como rollback rápido nos primeiros dias — **não recebe alterações**. A planilha ficou congelada no estado do cutover (a gravação dupla foi desligada), então o legado só serve para consultar dados antigos, nunca para gravar.

## Arquivos
- `index.html` — a aplicação (Supabase)
- `legacy/index.html` — versão antiga sobre Sheets, congelada, só para rollback
- `beta/index.html` — apenas um redirecionamento para a raiz (a URL `/beta/` foi usada durante os testes)
- `supabase/schema.sql` — schema completo do banco (recriação do zero)
- `supabase/migration_*.sql` — incrementos aplicados em ordem sobre o schema original
- `supabase/limpar_estoque_teste.sql` — zera o módulo de estoque (só para reset de testes)
- `supabase/apps_script_doPost.gs` — Apps Script da planilha; **sem uso desde o cutover**, mantido para o legado
- Deploy: GitHub Pages a partir da branch `main` / raiz

## Constantes importantes
```js
// ambos
CLIENT_ID   = '29814188441-tk6mg6ni8r63u5jmncog34ijv719cff0.apps.googleusercontent.com'

// só no legado
SHEET_ID    = '1cWCh7bcDlsBJA9NkmHHPUEgweFYNnVGWO2h3HtuqiNY'
APPS_SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyT3XF5rauK9vOZxPMlzHy4gsGLyhkko_XzI2j2XqQIsU5FSCjnETtWf0Tb462YBvmhyw/exec'

// aplicação atual
SUPABASE_URL = 'https://cqepzwqmlpgdttuzgihx.supabase.co'
SUPABASE_ANON_KEY = '...'   // chave anon/public — segura no navegador porque o RLS protege os dados
DUAL_WRITE_SHEETS = false   // desligado no cutover v7.0; a planilha não recebe mais nada
```

⚠️ **Não existe backup automático.** O plano gratuito do Supabase não faz backup e a cópia para a planilha foi desligada no cutover. O backup é **manual**: Configurações → 💾 Baixar backup (`baixarBackup()`, só admin) gera um JSON com todas as tabelas de `BACKUP_TABLES`. Antes de qualquer operação que apague dados em massa, rode isso.

O backup é JSON e não planilha de propósito: Excel/Sheets reinterpreta datas e códigos com barra ao abrir e salvar — foi assim que `7457/1` virou data e custou um bug nesta migração. Ao criar uma tabela nova, **acrescente-a em `BACKUP_TABLES`**, senão ela fica fora do backup silenciosamente.

⚠️ **A ferramenta "Migrar dados" foi removida na v7.0** (está no histórico do Git). Com a planilha congelada, rodá-la sobrescreveria dados novos do banco com dados velhos da planilha.

## Estrutura do state
```js
const state = {
  user, allowedUser,   // allowedUser = { email, isAdmin, notificarEstoque, nome }
  connected, dbStatus, // dbStatus/sheetsStatus alimentam as badges do topo
  moldagens:[], baseProva:[], basePrevista:[], provaDentes:[],
  entregas:[], remarcacoes:[], reembase:[],
  proteticos:[], dentistas:[], tiposPeca:[], contratos:[],
  cores:[], tiposPlaca:[],        // [{ nome, ativo }]
  produtos:[], estoqueMovimentos:[],
  filtered:[], currentPage:1, perPage:15,
  distVisible:true, currentDetailCod:null, lastSavedCodigo:null,
  contratoAtivo:null   // { id, inicio, fim, reembaseMes, pecasContratadas }
};
```
No legado ainda existem `accessToken`/`tokenExpiry`/`config.adminEmails` — na versão atual a sessão é do `supabase-js` e a permissão vem de `allowed_users`.

## Estrutura das abas do Sheets (referência histórica)
Mantida porque `SHEET_MAP` ainda usa os nomes das abas como chave, e o legado depende delas.

### Moldagens (A:H)
| Col | Campo |
|-----|-------|
| A | Código (numérico) |
| B | Nome |
| C | Dentista |
| D | Tipo de Peça |
| E | Data (dd/mm/aaaa) |
| F | Distribuição (código do protético) |
| G | Situação |
| H | Observação |

### BaseProvaArmacao (A:H)
| Col | Campo |
|-----|-------|
| A | Código |
| B-E | VLOOKUPs automáticos |
| F | **Previsão** (dd/mm/aaaa) |
| G | **Data real** (dd/mm/aaaa) |
| H | Observação |

### Prova de Dentes (A:H)
| Col | Campo |
|-----|-------|
| A | Código |
| B-E | VLOOKUPs automáticos |
| F | **Previsão** (dd/mm/aaaa) |
| G | **Data real** (dd/mm/aaaa) |
| H | Observação |

### Entregas (A:H)
| Col | Campo |
|-----|-------|
| A | Código |
| B-E | VLOOKUPs automáticos |
| F | **Previsão** (dd/mm/aaaa) |
| G | **Data real** (dd/mm/aaaa) |
| H | Observação |

### Contratos (A:E)
| Col | Campo |
|-----|-------|
| A | ID/nome do contrato |
| B | Início (dd/mm/aaaa) |
| C | Fim (dd/mm/aaaa) |
| D | Reembase/mês |
| E | Peças contratadas |

### Configuracao (A:B)
Chave/valor. Chave `admin_emails` → lista de e-mails separados por `,` ou `;`
**Essa aba não é mais usada** — foi substituída pela tabela `allowed_users`.

## Banco de dados (Supabase)
Uma tabela por aba antiga. As colunas B-E de VLOOKUP das abas de etapas **não existem** no banco (resolvidas por JOIN), então as escritas ficam mais simples.

| Tabela | Origem | Chave |
|---|---|---|
| `moldagens` | Moldagens | `codigo` |
| `base_prova_armacao` / `prova_dentes` / `entregas` / `reembase` | abas homônimas | `codigo` (FK → `moldagens`) |
| `remarcacao` | Remarcacao | `id` (histórico, sempre insere) |
| `proteticos` / `dentistas` / `tipos_peca` / `contratos` | abas homônimas | nome/código |
| `allowed_users` | *(nova)* | `email` |

### Controle de estoque de placas (nativo do banco, nunca existiu no Sheets)
| Tabela | Papel |
|---|---|
| `cores` | Cores das placas (A2, A3…), PK = `nome` |
| `tipos_placa` | Tipos de placa, PK = `nome` |
| `produtos` | Produto = tipo + cor, com `estoque_minimo`. UNIQUE(tipo_placa, cor) |
| `estoque_movimentos` | **Livro-razão**: entradas e saídas. `codigo` preenchido na baixa por prova de dentes |

As três primeiras têm `ativo boolean`. O padrão de exclusão é **excluir-ou-inativar** (`excluirOuInativar()`): tenta o `DELETE`; se alguma FK apontar para o registro o Postgres recusa com código **`23503`**, e aí a aplicação só marca `ativo=false`. Inativos somem dos seletores (`ativos()`), mas continuam visíveis nas listas com botão de reativar, e nada que depende deles é perdido.

`estoque_movimentos.produto_id` usa **`ON DELETE RESTRICT`** de propósito: com `CASCADE`, apagar um produto apagaria silenciosamente todo o histórico dele, destruindo a trilha de auditoria.

**O saldo nunca é armazenado** — é sempre derivado do razão (`estoqueAtual(produtoId)` soma entradas menos saídas), então não existe saldo dessincronizado.

**Ajuste manual de saldo** (`submitAjusteEstoque()`): o usuário informa o saldo correto e o sistema grava a diferença como entrada ou saída, com `ajuste=true` e motivo obrigatório na `obs`. Ninguém "seta" o saldo na mão — ele continua derivado do razão. A flag existe para a auditoria separar correção de movimento real, e o histórico tem filtro "só ajustes".

**O razão é append-only: nada é apagado.** Desfazer uma movimentação insere a contrapartida vinculada ao original via `estorno_de` (`estornarMovimento(id)`), preservando a sequência real no histórico — a saída da placa e a devolução aparecem como dois registros. Uma saída estornada deixa de contar como placa em uso no paciente (`foiEstornado()`), mas continua visível no histórico. Estornos não podem ser estornados de novo.

Em `estoque_movimentos`, `data` é quando a movimentação aconteceu (editável, aceita retroativo) e `criado_em` é quando foi lançada no sistema. A diferença entre as duas é o que permite auditar divergência.

FKs de `produtos` para `cores`/`tipos_placa` usam `ON UPDATE CASCADE`, porque esses CRUDs editam a própria PK ao renomear.

## Autenticação

### Legado (Google OAuth com access token)
- Scopes: `spreadsheets`, `userinfo.email`, `userinfo.profile`
- Login silencioso com `prompt:'none'` + `login_hint` do localStorage
- Se token inválido/expirado com "insufficient scopes" → força re-login

### Atual (Google ID Token → Supabase Auth)
- `google.accounts.id` gera um **ID Token**, trocado por sessão Supabase via `sb.auth.signInWithIdToken()`
- Usa **nonce** (`crypto.subtle`), então exige contexto seguro: `https://` ou `http://localhost` — **não funciona em `file://`**
- A sessão é gerenciada e renovada pelo próprio `supabase-js`; não há mais `ensureToken()`/`tokenExpiry` manuais
- Após o login, `afterSupabaseLogin()` consulta `allowed_users` **antes** de liberar qualquer dado

## Controle de acesso

### Legado
`isAdmin()` compara o e-mail logado contra `admin_emails` da aba Configuracao. **Qualquer conta Google consegue logar e ver os dados** em modo leitura.

### Atual (allowlist real + RLS)
Só quem está em `allowed_users` consegue ver qualquer coisa; quem não está cai numa tela de "acesso não autorizado".
```js
function isAdmin(){ return !!state.allowedUser?.isAdmin; }
```
Colunas: `is_admin` (pode editar) e `notificar_estoque` (recebe o banner de estoque mínimo).

**O bloqueio real é no banco, via RLS** — as funções Postgres `is_allowed()` e `is_admin()` comparam `auth.jwt()->>'email'` contra `allowed_users`. O JS é só a camada de UX: mesmo chamando a API direto, ninguém sem permissão lê ou grava nada. (Na produção a checagem é só visual.)

- Não-admins veem modo leitura em: Etapas, Editar, Cadastro, Dentistas, Protéticos, Tipos de Peça, Contratos, Configurações e todas as telas de estoque

## Páginas da aplicação
| ID | Descrição |
|----|-----------|
| `dashboard` | Cards de resumo + gráficos por contrato |
| `resumo` | Resumo do dia (seletor de data) |
| `pacientes` | Consulta/listagem com filtros |
| `pipeline` | Kanban de etapas (Moldagem→BP→PD→Entrega+Reembase) |
| `fechamento` | Fechamento mensal por protético |
| `fechamento-armacao` | Fechamento por armação (peças PPR) |
| `contratos` | CRUD de contratos |
| `cadastro` | Nova moldagem |
| `dentistas` | CRUD de dentistas |
| `proteticos` | CRUD de protéticos |
| `tipopeca` | CRUD de tipos de peça |
| `validacao` | Validação de integridade dos dados |

Telas do módulo de estoque:

| ID | Descrição |
|----|-----------|
| `estoque` | Entrada de estoque + saldo atual + histórico de movimentações com filtros |
| `ajuste` | Ajuste manual de saldo (tela própria, `renderAjuste()`) |
| `produtos` | CRUD de produtos (tipo de placa + cor + estoque mínimo) |
| `tiposplaca` | CRUD de tipos de placa |
| `cores` | CRUD de cores |

## Funções principais
```
navigate(page)           — navega entre páginas
loadAll()                — carrega todas as abas do Sheets
fetchSheet(range)        — lê intervalo do Sheets via API REST
postSheet(sheet, row)    — insere linha via Apps Script
isAdmin()                — verifica permissão do usuário logado
showDetail(cod)          — abre modal de detalhe do paciente
renderDetailEtapas(cod)  — renderiza aba Etapas no modal
renderDetailEditar(cod)  — renderiza aba Editar no modal
renderDetailInfo(cod)    — renderiza aba Informações no modal
submitEtapaUnica(cod, tipo) — salva etapa individual (bp/pd/ent/rb/rem)
upsert(sheet, arr, values)  — insert ou update na planilha (sempre busca col A)
renderValidacao()        — analisa integridade dos dados
renderResumo(dataSel)    — resumo do dia (data opcional)
exportarTabela(id, titulo)  — copia tabela TSV para clipboard
setHoje(inputId)         — preenche campo de data com hoje
```

Específicas da arquitetura Supabase:
```
sb                       — cliente Supabase (NÃO chamar de `supabase`: colide com o global da lib e quebra o script inteiro)
sbSelectAll(table, orderBy) — lê tabela inteira paginando de 1000 em 1000
fetchSheet(range)        — adapter: lê do Supabase e devolve array posicional no formato antigo das colunas
postSheet(sheet, row)    — adapter: insert no Supabase (+ gravação dupla no Sheets)
upsertRow(sheet, matchKey, row) — update-ou-insert real (substituiu o upsert por número de linha)
SHEET_MAP                — mapa aba antiga → tabela + ordem posicional das colunas
migrarDadosDoSheets()    — migração Sheets → Supabase (Configurações, só admin)
estoqueAtual(produtoId)  — saldo derivado do livro-razão
produtosAbaixoMinimo()   — produtos no/abaixo do estoque mínimo
renderEstoqueBanner()    — banner de aviso no topo
adicionarPlacaPaciente(cod) / removerPlacaPaciente(id, cod) — baixa/estorno na prova de dentes
tsParaDataLocal(ts)      — timestamptz (UTC) → data local aaaa-mm-dd
```

⚠️ As tabelas de estoque **ficam fora** de `SHEET_MAP`/`MIGRATION_ORDER`/`dualWriteSheets` — são nativas do banco e não têm aba correspondente no Sheets. Usam `sb.from(...)` direto.

## Padrões e convenções importantes

### Datas
- Planilha: `dd/mm/aaaa`
- Input HTML: `aaaa-mm-dd`
- `toInput(d)` → converte dd/mm/aaaa → aaaa-mm-dd
- `fromInput(v)` → converte aaaa-mm-dd → dd/mm/aaaa
- **Nunca usar `new Date().toISOString()`** — causa bug de timezone UTC. Usar:
  ```js
  const d=new Date();
  const str=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
  ```

### Filtro de linhas inválidas
Todos os arrays filtram linhas com `#N/A` ou código não-numérico:
```js
r[0] && !r[0].toString().includes('#') && /^\d/.test(r[0].toString().trim())
```

### Race condition pós-save (só no legado)
Após salvar via Apps Script, aguardar 600ms antes do `loadAll()`:
```js
await new Promise(r=>setTimeout(r,600));
await loadAll();
```
**Isso não existe mais** — o upsert do Postgres é atômico, sem passo intermediário de "descobrir a linha", então `loadAll()` é chamado direto.

### Upsert
Legado — sempre busca na coluna A da planilha, não depende do state local:
```js
const rows = await fetchSheet(sheet+'!A:A');
const rowIdx = rows.findIndex(r=>r[0]&&r[0].toString().trim()===String(cod));
if(rowIdx>=0){ /* update via Apps Script action:'update' */ }
else { await postSheet(sheet, values); }
```
Atual — `upsertRow(sheet, matchKey, row)` faz update e, se não afetou nenhuma linha, insere.

### Armadilhas já conhecidas (todas custaram bug)
- **Nome do cliente Supabase**: use `sb`, nunca `supabase` — a lib declara esse global e a colisão quebra o parse do `<script>` inteiro (todas as funções viram "not defined").
- **Limite de 1000 linhas**: o PostgREST corta em ~1000 registros por consulta, **sem erro**. Sempre pagine (`sbSelectAll`), senão tabelas grandes vêm truncadas silenciosamente.
- **Leitura do Sheets no Apps Script**: use `getDisplayValues()`, não `getValues()`. Códigos de tratamento com barra (`7457/1`) são auto-convertidos para data pelo Sheets, e `getValues()` devolve o valor bruto errado.
- **`criado_em` vem em UTC**: não fatie os 10 primeiros caracteres para obter a data — use `tsParaDataLocal()`, senão registros feitos à noite mostram o dia seguinte.
- **Contexto seguro**: o login usa `crypto.subtle`, então testar exige servidor local (`http://localhost`/`127.0.0.1`) ou HTTPS — abrir o arquivo direto (`file://`) não funciona. A origem também precisa estar autorizada no Google Cloud Console.

### Fechamento por armação
Filtra por tipo de peça contendo "PPR" (`/PPR/i`). Não usa mais flag `pagaArmacao` do protético.

### Contrato ativo
Entregas seguem o contrato da **moldagem** (não da data de entrega).

## Verificação de sintaxe (rodar antes de qualquer deploy)
```bash
python3 -c "
import re
content = open('index.html').read()
scripts = re.findall(r'<script>(.*?)</script>', content, re.DOTALL)
open('/tmp/test.js','w').write(scripts[-1])
" && node --check /tmp/test.js && echo "✅ OK"
```
Se `python3`/`node` não estiverem disponíveis na máquina, validar ao menos o balanceamento de `{}`, `()` e crases do último bloco `<script>` como alternativa.

## Convenção de versão
**Toda alteração incrementa a versão** e ela é informada ao usuário. Atualizar nos dois lugares do arquivo editado:
- comentário do topo (linha ~4): `<!-- ProSUS vX.Y - descrição curta -->`
- rodapé da sidebar: `<div style="...">vX.Y</div>`

## Migração para Supabase — concluída (v7.0)
- ✅ Schema, RLS e allowlist aplicados; dados históricos migrados e conferidos
- ✅ Login, leitura e escrita validados com usuário final
- ✅ Cutover feito: o app sobre Supabase virou a raiz; o antigo foi para `legacy/`
- ✅ Gravação dupla desligada — a planilha ficou congelada no estado do cutover
- ✅ Ferramenta de migração removida (rodá-la agora sobrescreveria dados novos com os velhos da planilha)

### Backup (v7.1)
Manual, pela própria interface: **Configurações → 💾 Baixar backup**. Gera `prosus-backup-AAAA-MM-DD.json` com todas as tabelas, mais um bloco `_meta` com data, autor e a contagem de linhas de cada tabela — que serve para conferir a integridade do arquivo depois.

Como depende de alguém clicar, convém combinar uma periodicidade com o usuário. Para restaurar, os dados de cada tabela estão em `dump["nome_da_tabela"]` como array de objetos, prontos para reinserir na ordem das FKs (`moldagens` primeiro).

A badge "Planilha" no topo some sozinha com `DUAL_WRITE_SHEETS=false`; só a badge "Banco" aparece.
