# ProSUS — Contexto para Claude Code

## O que é
PWA (Progressive Web App) de arquivo único para gestão de próteses dentárias no SUS. Frontend puro com JS/CSS embarcados.

**Existem hoje DUAS versões vivas no repositório** — sempre confirme em qual você está mexendo:

| | Produção | Beta (migração) |
|---|---|---|
| Arquivo | `index.html` (raiz) | `beta/index.html` |
| Versão | **v5.2** | **v6.1-beta** |
| Backend | Google Sheets + Apps Script | **Supabase** (Postgres + Auth + RLS) |
| URL | https://lrlgv.github.io/prosus | https://lrlgv.github.io/prosus/beta/ |

O beta é a evolução que substituirá a produção. **Funcionalidades novas vão só no beta** — a produção está congelada, recebendo no máximo correções.

## Arquivos
- `index.html` — aplicação de produção (Sheets)
- `beta/index.html` — aplicação beta (Supabase), onde o desenvolvimento acontece
- `supabase/schema.sql` — schema completo do banco (recriação do zero)
- `supabase/migration_estoque.sql` — incremento do controle de estoque (o schema já tinha sido aplicado antes dessa feature existir)
- `supabase/apps_script_doPost.gs` — `doPost`/`doGet` do Apps Script, usados pela migração de dados e pela gravação dupla
- Deploy: GitHub Pages a partir da branch `main` / raiz

## Constantes importantes
```js
// ambos
CLIENT_ID   = '29814188441-tk6mg6ni8r63u5jmncog34ijv719cff0.apps.googleusercontent.com'
APPS_SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyT3XF5rauK9vOZxPMlzHy4gsGLyhkko_XzI2j2XqQIsU5FSCjnETtWf0Tb462YBvmhyw/exec'

// só produção
SHEET_ID    = '1cWCh7bcDlsBJA9NkmHHPUEgweFYNnVGWO2h3HtuqiNY'

// só beta
SUPABASE_URL = 'https://cqepzwqmlpgdttuzgihx.supabase.co'
SUPABASE_ANON_KEY = '...'   // chave anon/public — segura no navegador porque o RLS protege os dados
DUAL_WRITE_SHEETS = true    // gravação dupla temporária na planilha antiga (desligar no fim da transição)
```

## Estrutura do state
No **beta**, `accessToken`/`tokenExpiry`/`config.adminEmails` não existem mais (a sessão é do `supabase-js` e o admin vem de `allowed_users`), e há campos novos: `allowedUser`, `dbStatus`, `sheetsStatus`, `cores`, `tiposPlaca`, `produtos`, `estoqueMovimentos`.

```js
const state = {
  accessToken, tokenExpiry, user, connected,   // só produção
  moldagens:[],        // aba Moldagens
  baseProva:[],        // aba BaseProvaArmacao — com data real (col G)
  basePrevista:[],     // aba BaseProvaArmacao — só previsão (col F), sem data real
  provaDentes:[],      // aba Prova de Dentes — com data real (col G)
  pdPrevista:[],       // aba Prova de Dentes — só previsão futura (col F), sem data real
  entregas:[],         // aba Entregas
  remarcacoes:[],      // aba Remarcacao
  reembase:[],         // aba Reembase
  proteticos:[],       // aba Proteticos
  dentistas:[],        // aba Dentistas
  tiposPeca:[],        // aba BaseDados
  contratos:[],        // aba Contratos
  filtered:[], currentPage:1, perPage:15,
  distVisible:true, currentDetailCod:null, lastSavedCodigo:null,
  contratoAtivo:null,  // { id, inicio, fim, reembaseMes, pecasContratadas }
  config:{ adminEmails:'' }
};
```

## Estrutura das abas do Sheets

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
**No beta essa aba não é mais usada** — foi substituída pela tabela `allowed_users`.

## Banco de dados (beta — Supabase)
Uma tabela por aba antiga. As colunas B-E de VLOOKUP das abas de etapas **não existem** no banco (resolvidas por JOIN), então as escritas ficam mais simples.

| Tabela | Origem | Chave |
|---|---|---|
| `moldagens` | Moldagens | `codigo` |
| `base_prova_armacao` / `prova_dentes` / `entregas` / `reembase` | abas homônimas | `codigo` (FK → `moldagens`) |
| `remarcacao` | Remarcacao | `id` (histórico, sempre insere) |
| `proteticos` / `dentistas` / `tipos_peca` / `contratos` | abas homônimas | nome/código |
| `allowed_users` | *(nova)* | `email` |

### Controle de estoque de placas (v6.1-beta — nativo do banco, não existe no Sheets)
| Tabela | Papel |
|---|---|
| `cores` | Cores das placas (A2, A3…), PK = `nome` |
| `tipos_placa` | Tipos de placa, PK = `nome` |
| `produtos` | Produto = tipo + cor, com `estoque_minimo`. UNIQUE(tipo_placa, cor) |
| `estoque_movimentos` | **Livro-razão**: entradas e saídas. `codigo` preenchido na baixa por prova de dentes |

**O saldo nunca é armazenado** — é sempre derivado do razão (`estoqueAtual(produtoId)` soma entradas menos saídas). Por isso remover um movimento devolve a quantidade ao estoque, e não existe saldo dessincronizado.

Em `estoque_movimentos`, `data` é quando a movimentação aconteceu (editável, aceita retroativo) e `criado_em` é quando foi lançada no sistema. A diferença entre as duas é o que permite auditar divergência.

FKs de `produtos` para `cores`/`tipos_placa` usam `ON UPDATE CASCADE`, porque esses CRUDs editam a própria PK ao renomear.

## Autenticação

### Produção (Google OAuth com access token)
- Scopes: `spreadsheets`, `userinfo.email`, `userinfo.profile`
- Login silencioso com `prompt:'none'` + `login_hint` do localStorage
- Se token inválido/expirado com "insufficient scopes" → força re-login

### Beta (Google ID Token → Supabase Auth)
- `google.accounts.id` gera um **ID Token**, trocado por sessão Supabase via `sb.auth.signInWithIdToken()`
- Usa **nonce** (`crypto.subtle`), então exige contexto seguro: `https://` ou `http://localhost` — **não funciona em `file://`**
- A sessão é gerenciada e renovada pelo próprio `supabase-js`; não há mais `ensureToken()`/`tokenExpiry` manuais
- Após o login, `afterSupabaseLogin()` consulta `allowed_users` **antes** de liberar qualquer dado

## Controle de acesso

### Produção
`isAdmin()` compara o e-mail logado contra `admin_emails` da aba Configuracao. **Qualquer conta Google consegue logar e ver os dados** em modo leitura.

### Beta (allowlist real + RLS)
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

Só no **beta** (v6.1-beta):

| ID | Descrição |
|----|-----------|
| `estoque` | Entrada de estoque + saldo atual + histórico de movimentações com filtros |
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

Só no **beta**:
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

### Race condition pós-save (só produção)
Após salvar via Apps Script, aguardar 600ms antes do `loadAll()`:
```js
await new Promise(r=>setTimeout(r,600));
await loadAll();
```
**No beta isso não existe mais** — o upsert do Postgres é atômico, sem passo intermediário de "descobrir a linha", então `loadAll()` é chamado direto.

### Upsert
Produção — sempre busca na coluna A da planilha, não depende do state local:
```js
const rows = await fetchSheet(sheet+'!A:A');
const rowIdx = rows.findIndex(r=>r[0]&&r[0].toString().trim()===String(cod));
if(rowIdx>=0){ /* update via Apps Script action:'update' */ }
else { await postSheet(sheet, values); }
```
Beta — `upsertRow(sheet, matchKey, row)` faz update e, se não afetou nenhuma linha, insere.

### Armadilhas específicas do beta (todas já custaram bug)
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
Trocar o caminho por `beta/index.html` quando estiver mexendo no beta.
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

## Estado da migração para Supabase
- ✅ Schema, RLS e allowlist aplicados; dados históricos migrados
- ✅ Login, leitura e escrita validados no beta
- ⏳ **Gravação dupla ativa** (`DUAL_WRITE_SHEETS=true`): o Supabase é a fonte de verdade, e a planilha antiga segue recebendo cópia como backup vivo, porque o plano gratuito do Supabase não tem backup automático. Desligar após o período de validação.
- ⏳ Beta em teste com usuário final antes de substituir a produção
- Badges no topo do beta mostram o estado das duas conexões (Banco / Planilha); a badge "Planilha" some sozinha quando a gravação dupla for desligada
