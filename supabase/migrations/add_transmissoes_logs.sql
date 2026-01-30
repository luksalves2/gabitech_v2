-- Migração: Adicionar campos de log da API na tabela transmissoes
-- Esses campos armazenam as estatísticas de envio retornadas pela API de campanhas

-- Adicionar colunas de log na tabela transmissoes
ALTER TABLE transmissoes
ADD COLUMN IF NOT EXISTS log_delivered INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS log_failed INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS log_played INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS log_read INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS log_success INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS log_total INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS api_updated_at TIMESTAMP WITH TIME ZONE;

-- Comentários para documentação
COMMENT ON COLUMN transmissoes.log_delivered IS 'Quantidade de mensagens entregues (da API)';
COMMENT ON COLUMN transmissoes.log_failed IS 'Quantidade de mensagens que falharam (da API)';
COMMENT ON COLUMN transmissoes.log_played IS 'Quantidade de áudios reproduzidos (da API)';
COMMENT ON COLUMN transmissoes.log_read IS 'Quantidade de mensagens lidas (da API)';
COMMENT ON COLUMN transmissoes.log_success IS 'Quantidade de mensagens enviadas com sucesso (da API)';
COMMENT ON COLUMN transmissoes.log_total IS 'Total de mensagens na campanha (da API)';
COMMENT ON COLUMN transmissoes.api_updated_at IS 'Última atualização dos dados da API';

-- Índice para busca por id_campanha (usado na sincronização)
CREATE INDEX IF NOT EXISTS idx_transmissoes_id_campanha ON transmissoes(id_campanha);

-- Função para atualizar transmissao com dados da API
CREATE OR REPLACE FUNCTION sync_transmissao_from_api(
  p_id_campanha TEXT,
  p_status TEXT,
  p_log_delivered INTEGER DEFAULT NULL,
  p_log_failed INTEGER DEFAULT NULL,
  p_log_played INTEGER DEFAULT NULL,
  p_log_read INTEGER DEFAULT NULL,
  p_log_success INTEGER DEFAULT NULL,
  p_log_total INTEGER DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  v_status_sistema TEXT;
BEGIN
  -- Mapear status da API para status do sistema
  CASE LOWER(p_status)
    WHEN 'done', 'finished', 'completed' THEN v_status_sistema := 'Enviado';
    WHEN 'running', 'sending', 'ativo' THEN v_status_sistema := 'Enviando';
    WHEN 'scheduled', 'pending' THEN v_status_sistema := 'Agendada';
    WHEN 'failed', 'error' THEN v_status_sistema := 'Falha';
    WHEN 'paused' THEN v_status_sistema := 'Pausado';
    ELSE v_status_sistema := p_status;
  END CASE;

  -- Atualizar a transmissão
  UPDATE transmissoes
  SET
    status = v_status_sistema,
    log_delivered = COALESCE(p_log_delivered, log_delivered),
    log_failed = COALESCE(p_log_failed, log_failed),
    log_played = COALESCE(p_log_played, log_played),
    log_read = COALESCE(p_log_read, log_read),
    log_success = COALESCE(p_log_success, log_success),
    log_total = COALESCE(p_log_total, log_total),
    api_updated_at = NOW()
  WHERE id_campanha = p_id_campanha;
END;
$$ LANGUAGE plpgsql;

-- Permissões RLS (ajustar conforme sua política de segurança)
-- ALTER TABLE transmissoes ENABLE ROW LEVEL SECURITY;

-- Exemplo de uso da função:
-- SELECT sync_transmissao_from_api(
--   'minha-campanha',
--   'done',
--   10,  -- delivered
--   2,   -- failed
--   0,   -- played
--   8,   -- read
--   10,  -- success
--   12   -- total
-- );
