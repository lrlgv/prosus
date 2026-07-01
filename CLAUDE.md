# ProSUS — Contexto para Claude Code

## O que é
PWA (Progressive Web App) de arquivo único (`index.html`) para gestão de próteses dentárias no SUS. Frontend puro com JS/CSS embarcados. Backend via Google Apps Script + Google Sheets.

## Versão atual
v4.48

## Arquivos
- `index.html` — aplicação completa (único arquivo de produção)
- Deploy: GitHub Pages → https://lrlgv.github.io/prosus (arquivo: `index.html` na raiz do repo)

## Constantes importantes
```js
CLIENT_ID   = '29814188441-tk6mg6ni8r63u5jmncog34ijv719cff0.apps.googleusercontent.com'
SHEET_ID    = '1cWCh7bcDlsBJA9NkmHHPUEgweFYNnVGWO2h3HtuqiNY'
APPS_SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyT3XF5rauK9vOZxPMlzHy4gsGLyhkko_XzI2j2XqQIsU5FSCjnETtWf0Tb462YBvmhyw/exec'
```

## Estrutura do state
```js
const state = {
  accessToken, tokenExpiry, user, connected,
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

## Autenticação (Google OAuth)
- Scopes: `spreadsheets`, `userinfo.email`, `userinfo.profile`
- Login silencioso com `prompt:'none'` + `login_hint` do localStorage
- `prosus_user_email` e `prosus_user_name` salvos no localStorage
- Se token inválido/expirado com "insufficient scopes" → força re-login

## Controle de acesso (isAdmin)
```js
function isAdmin(){
  const stored=(state.config.adminEmails||'').trim();
  if(!stored) return true; // sem config = todos são admin
  const emails=stored.toLowerCase().split(/[,;]/).map(e=>e.trim()).filter(Boolean);
  if(!emails.length) return true;
  const userEmail=(state.user?.email||localStorage.getItem('prosus_user_email')||'').toLowerCase().trim();
  if(!userEmail||userEmail==='undefined'||userEmail==='null') return false;
  return emails.includes(userEmail);
}
```
- Não-admins veem modo leitura em: Etapas, Editar, Cadastro, Dentistas, Protéticos, Tipos de Peça, Contratos, Configurações

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

### Race condition pós-save
Após salvar via Apps Script, aguardar 600ms antes do `loadAll()`:
```js
await new Promise(r=>setTimeout(r,600));
await loadAll();
```

### Upsert
Sempre busca na coluna A da planilha — não depende do state local:
```js
const rows = await fetchSheet(sheet+'!A:A');
const rowIdx = rows.findIndex(r=>r[0]&&r[0].toString().trim()===String(cod));
if(rowIdx>=0){ /* update via Apps Script action:'update' */ }
else { await postSheet(sheet, values); }
```

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
