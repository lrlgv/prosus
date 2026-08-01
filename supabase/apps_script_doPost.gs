// ProSUS — doPost/doGet atualizados para suportar a migração de dados e a gravação
// dupla (dual-write) pro Supabase. Cole isto no Apps Script da planilha (Extensões →
// Apps Script), substituindo o código atual, e reimplante a Web App (Implantar →
// Gerenciar implantações → editar → Nova versão).
//
// O que mudou em relação ao doPost documentado em documentacao_prosus.md:
// só foi ADICIONADO o bloco `action === 'upsert_by_key'` no topo do doPost, e a
// função doGet é nova. As ações antigas do doPost ('update' por número de linha, e
// o insert padrão) continuam exatamente iguais — a produção atual (index.html na
// raiz do repo) não é afetada por essa mudança.
//
// 'upsert_by_key' é usado pelo beta/index.html (dualWriteSheets) para manter a
// planilha atualizada como backup vivo: procura na coluna A da aba pelo `key`
// informado; se achar, atualiza a linha; se não achar, insere uma linha nova.
//
// doGet é usado pela tela de "Migrar dados" do beta/index.html: devolve o conteúdo
// bruto de uma aba (?sheet=NomeDaAba) como JSON, pra migração ler o Sheets sem
// precisar de login OAuth com escopo de planilha no navegador.

function doGet(e) {
  try {
    if (e.parameter.ping) {
      // Checagem leve de conectividade (usada pelo badge de status do app) —
      // não lê a planilha, só confirma que o Web App está no ar.
      return ContentService.createTextOutput(JSON.stringify({success: true}))
        .setMimeType(ContentService.MimeType.JSON);
    }
    var sheetName = e.parameter.sheet;
    if (!sheetName) throw new Error("Parâmetro 'sheet' não informado.");
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName(sheetName);
    if (!sheet) throw new Error("Aba '" + sheetName + "' não encontrada na planilha.");
    // getDisplayValues() devolve o texto exatamente como aparece na planilha (mesmo
    // comportamento que a Sheets API/FORMATTED_VALUE já usava na produção) — evita
    // que uma célula mal-interpretada pelo Sheets (ex: código de tratamento "7457/1"
    // auto-convertido pra uma data internamente) venha com o valor errado. getValues()
    // devolveria o valor BRUTO (o objeto Date de verdade por trás), o que causava
    // esse bug.
    var values = sheet.getDataRange().getDisplayValues();
    return ContentService.createTextOutput(JSON.stringify({
      success: true,
      values: values
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      error: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    var sheetName = data.sheet;
    var action = data.action;
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName(sheetName);
    if (!sheet) {
      throw new Error("Aba '" + sheetName + "' não encontrada na planilha.");
    }

    if (action === 'upsert_by_key') {
      var key = String(data.key);
      var values = data.values;
      var lastRow = sheet.getLastRow();
      var rowIdx = -1;
      if (lastRow > 0) {
        var colA = sheet.getRange(1, 1, lastRow, 1).getValues();
        for (var i = 0; i < colA.length; i++) {
          if (String(colA[i][0]).trim() === key) { rowIdx = i + 1; break; }
        }
      }
      if (rowIdx > 0) {
        sheet.getRange(rowIdx, 1, 1, values.length).setValues([values]);
        return ContentService.createTextOutput(JSON.stringify({
          success: true,
          message: "Linha " + rowIdx + " atualizada (upsert) na aba " + sheetName
        })).setMimeType(ContentService.MimeType.JSON);
      }
      sheet.appendRow(values);
      return ContentService.createTextOutput(JSON.stringify({
        success: true,
        message: "Linha inserida (upsert) na aba " + sheetName
      })).setMimeType(ContentService.MimeType.JSON);
    }

    // ── ações originais (update / insert) ──
    // Nota: o `postSheet()` do app manda {sheet, row} pro insert simples (o array de
    // valores vai na chave "row", não "values" — por isso o appendRow(row) abaixo).
    var row = data.row;
    var values = data.values;

    if (action === 'update') {
      if (!row || row < 1) {
        throw new Error("A linha informada para atualização é inválida: " + row);
      }
      var range = sheet.getRange(row, 1, 1, values.length);
      range.setValues([values]);
      return ContentService.createTextOutput(JSON.stringify({
        success: true,
        message: "Linha " + row + " atualizada com sucesso na aba " + sheetName
      })).setMimeType(ContentService.MimeType.JSON);
    } else {
      sheet.appendRow(row);
      return ContentService.createTextOutput(JSON.stringify({
        success: true,
        message: "Dados inseridos com sucesso na aba " + sheetName
      })).setMimeType(ContentService.MimeType.JSON);
    }
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      error: error.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function doOptions(e) {
  return ContentService.createTextOutput("")
    .setMimeType(ContentService.MimeType.TEXT);
}
