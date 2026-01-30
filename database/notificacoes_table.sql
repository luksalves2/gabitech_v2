-- Tabela de notificações
CREATE TABLE IF NOT EXISTS notificacoes (
  id BIGSERIAL PRIMARY KEY,
  usuario UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  gabinete INTEGER REFERENCES gabinetes(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL CHECK (tipo IN (
    'solicitacaoVencendo',
    'solicitacaoVencida',
    'cidadaoNaoAtendido',
    'novoCidadao',
    'novaSolicitacao',
    'atividadePendente',
    'mensagemNaoLida',
    'sistema'
  )),
  prioridade TEXT NOT NULL DEFAULT 'media' CHECK (prioridade IN (
    'baixa',
    'media',
    'alta',
    'urgente'
  )),
  titulo TEXT NOT NULL,
  mensagem TEXT NOT NULL,
  rota TEXT,
  metadata JSONB,
  lida BOOLEAN DEFAULT FALSE,
  lida_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_notificacoes_usuario ON notificacoes(usuario);
CREATE INDEX IF NOT EXISTS idx_notificacoes_gabinete ON notificacoes(gabinete);
CREATE INDEX IF NOT EXISTS idx_notificacoes_tipo ON notificacoes(tipo);
CREATE INDEX IF NOT EXISTS idx_notificacoes_lida ON notificacoes(lida);
CREATE INDEX IF NOT EXISTS idx_notificacoes_created_at ON notificacoes(created_at DESC);

-- RLS (Row Level Security)
ALTER TABLE notificacoes ENABLE ROW LEVEL SECURITY;

-- Política: usuários podem ver suas próprias notificações
CREATE POLICY notificacoes_select_policy ON notificacoes
  FOR SELECT
  USING (
    auth.uid() = usuario OR
    gabinete IN (
      SELECT gabinete FROM usuarios WHERE uuid = auth.uid()
    )
  );

-- Política: usuários podem atualizar suas próprias notificações
CREATE POLICY notificacoes_update_policy ON notificacoes
  FOR UPDATE
  USING (
    auth.uid() = usuario OR
    gabinete IN (
      SELECT gabinete FROM usuarios WHERE uuid = auth.uid()
    )
  );

-- Política: usuários podem deletar suas próprias notificações
CREATE POLICY notificacoes_delete_policy ON notificacoes
  FOR DELETE
  USING (
    auth.uid() = usuario OR
    gabinete IN (
      SELECT gabinete FROM usuarios WHERE uuid = auth.uid()
    )
  );

-- Política: sistema pode inserir notificações
CREATE POLICY notificacoes_insert_policy ON notificacoes
  FOR INSERT
  WITH CHECK (true);

-- Função para limpar notificações antigas (mais de 30 dias e já lidas)
CREATE OR REPLACE FUNCTION limpar_notificacoes_antigas()
RETURNS void AS $$
BEGIN
  DELETE FROM notificacoes
  WHERE lida = TRUE
    AND created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comentários
COMMENT ON TABLE notificacoes IS 'Notificações do sistema para usuários e gabinetes';
COMMENT ON COLUMN notificacoes.tipo IS 'Tipo da notificação';
COMMENT ON COLUMN notificacoes.prioridade IS 'Prioridade da notificação';
COMMENT ON COLUMN notificacoes.rota IS 'Rota para navegar ao clicar na notificação';
COMMENT ON COLUMN notificacoes.metadata IS 'Dados extras da notificação (IDs, etc)';
