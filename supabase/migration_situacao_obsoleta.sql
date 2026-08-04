-- ProSUS — remove a coluna moldagens.situacao (v7.10)
-- Rodar no SQL Editor do Supabase Studio.
--
-- POR QUE REMOVER
-- A coluna vinha da planilha, onde era preenchida à mão. A aplicação nunca a
-- atualizou ao registrar uma entrega, então ficou congelada em "Pendente" e
-- passou a contradizer, na mesma linha da tela de Consulta, a data de entrega
-- exibida ao lado. Também quebrava o filtro por situação.
--
-- A situação do tratamento agora é DERIVADA de `entregas.entrega`, que é o fato
-- efetivamente registrado — o mesmo princípio já usado no saldo de estoque:
-- não guardar o que pode ser calculado, para não haver duas versões da verdade.
--
-- ⚠️ OPERAÇÃO IRREVERSÍVEL
-- Os valores herdados da planilha estão preservados no backup JSON
-- (prosus-backup-2026-08-02.json contém `situacao` das 1485 moldagens).
-- Ainda assim, o hábito correto antes de qualquer DDL destrutivo é gerar um
-- backup novo: Configurações → 💾 Baixar backup.

alter table moldagens drop column situacao;

-- Conferência: a consulta abaixo deve falhar com "column does not exist",
-- confirmando que a coluna saiu.
-- select situacao from moldagens limit 1;
