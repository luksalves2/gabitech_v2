# 🔔 Sistema de Notificações Inteligentes - Gabitech

## Visão Geral

O Gabitech agora possui um sistema completo de notificações inteligentes que monitora automaticamente o sistema e alerta sobre situações que precisam de atenção.

## Funcionalidades

### 1. Tipos de Notificações

- **Solicitação Vencendo**: Alerta quando uma solicitação vai vencer nas próximas 24h
- **Solicitação Vencida**: Alerta urgente para solicitações com prazo já vencido
- **Cidadão Não Atendido**: Avisa quando há cidadãos aguardando atendimento há mais de 1 dia
- **Novo Cidadão**: Notifica quando um novo cidadão é cadastrado
- **Nova Solicitação**: Alerta sobre novas solicitações criadas
- **Atividade Pendente**: Informa sobre atividades com prazo vencido
- **Mensagem Não Lida**: Avisa sobre mensagens do WhatsApp aguardando resposta
- **Sistema**: Avisos gerais do sistema

### 2. Níveis de Prioridade

- **🔴 Urgente**: Situações críticas que precisam de ação imediata (ex: solicitações vencidas)
- **🟠 Alta**: Situações importantes que precisam de atenção em breve
- **🔵 Média**: Informações relevantes mas não urgentes
- **⚪ Baixa**: Informações gerais

### 3. Interface

#### Badge de Notificações
- Sino no canto superior direito da tela
- Mostra contador de notificações não lidas
- Clique para ir à página de notificações

#### Toast (Estilo WhatsApp)
- Aparece no canto superior direito
- Animação suave de entrada/saída
- Auto-dismiss após 5 segundos
- Clique para navegar até o contexto da notificação

#### Página de Notificações
- Lista completa de todas as notificações
- Filtros por tipo e status (lida/não lida)
- Navegação direta ao clicar
- Ações: marcar como lida, excluir, limpar lidas

## Configuração do Banco de Dados

### 1. Criar a tabela de notificações

Execute o SQL em `database/notificacoes_table.sql`:

```sql
-- Cria a tabela
CREATE TABLE notificacoes (
  id BIGSERIAL PRIMARY KEY,
  usuario_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  gabinete_id INTEGER REFERENCES gabinetes(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL,
  prioridade TEXT NOT NULL DEFAULT 'media',
  titulo TEXT NOT NULL,
  mensagem TEXT NOT NULL,
  rota TEXT,
  metadata JSONB,
  lida BOOLEAN DEFAULT FALSE,
  lida_em TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Criar índices
CREATE INDEX idx_notificacoes_usuario_id ON notificacoes(usuario_id);
CREATE INDEX idx_notificacoes_gabinete_id ON notificacoes(gabinete_id);
CREATE INDEX idx_notificacoes_lida ON notificacoes(lida);

-- Habilitar RLS
ALTER TABLE notificacoes ENABLE ROW LEVEL SECURITY;

-- Políticas de acesso (ver SQL completo)
```

### 2. Testar o Sistema

1. Faça login no sistema
2. Vá para `/dev/tests`
3. Clique em "Criar Notificações"
4. Aguarde a criação de 8 notificações de exemplo
5. Observe o badge no sino (canto superior direito)
6. Clique no sino para ver todas as notificações
7. Clique em uma notificação para navegar

## Como Usar no Código

### Criar Notificação Manualmente

```dart
// Obter o serviço
final notificationService = ref.read(notificationServiceProvider);

// Criar notificação
await notificationService.notificarNovaSolicitacao(
  gabineteId: gabinete.id,
  responsavelId: usuario.uuid,
  titulo: 'Nova solicitação: Troca de lâmpadas',
  solicitacaoId: solicitacao.id,
);
```

### Verificações Periódicas

O `NotificationService` possui métodos para verificações automáticas:

```dart
final service = ref.read(notificationServiceProvider);

// Executar todas as verificações
await service.executarVerificacoesPeriodicas();

// Ou individual
await service.verificarSolicitacoesVencendo();
await service.verificarSolicitacoesVencidas();
await service.verificarCidadaosNaoAtendidos();
```

### Marcar Como Lida

```dart
final notifier = ref.read(notificacaoNotifierProvider.notifier);
await notifier.marcarComoLida(notificacaoId);
```

## Integrações Futuras

### 1. Cron Job / Scheduled Tasks
Configurar tarefas agendadas para executar verificações periódicas:
- A cada hora: verificar solicitações vencendo
- Todo dia às 9h: verificar cidadãos não atendidos
- A cada 30 min: verificar mensagens não lidas

### 2. Supabase Realtime
Implementar subscriptions para notificações em tempo real:

```dart
final subscription = supabase
  .from('notificacoes')
  .stream(primaryKey: ['id'])
  .eq('usuario_id', userId)
  .listen((data) {
    // Mostrar toast quando nova notificação chegar
  });
```

### 3. Push Notifications
Integrar com Firebase Cloud Messaging para notificações mobile.

### 4. E-mail/SMS
Enviar notificações críticas por e-mail ou SMS.

## Exemplos de Uso Real

### Quando uma solicitação é criada:

```dart
final solicitacao = await solicitacaoRepo.create(...);

// Notificar automaticamente
await notificationService.notificarNovaSolicitacao(
  gabineteId: gabinete.id,
  responsavelId: solicitacao.responsavel?.uuid,
  titulo: solicitacao.titulo,
  solicitacaoId: solicitacao.id,
);
```

### Quando um cidadão é cadastrado:

```dart
final cidadao = await cidadaoRepo.create(...);

await notificationService.notificarNovoCidadao(
  gabineteId: gabinete.id,
  nomeCidadao: cidadao.nome,
  cidadaoId: cidadao.id,
);
```

### Notificação de sistema customizada:

```dart
await notificationService.notificarSistema(
  gabineteId: gabinete.id,
  titulo: 'Manutenção Programada',
  mensagem: 'O sistema estará em manutenção amanhã das 2h às 4h',
  prioridade: PrioridadeNotificacao.alta,
);
```

## Dicas de UX

1. **Navegação Contextual**: Sempre defina a `rota` para que o usuário possa ir direto ao contexto
2. **Mensagens Claras**: Seja específico nas mensagens (ex: "5 solicitações vencidas" ao invés de "Veja suas solicitações")
3. **Prioridade Adequada**: Use prioridades corretas para não dessensibilizar o usuário
4. **Limpeza Automática**: Configure a função SQL para limpar notificações antigas automaticamente
5. **Agrupamento**: Considere agrupar notificações similares (ex: "3 novas solicitações" ao invés de 3 notificações separadas)

## Personalização

### Adicionar Novo Tipo de Notificação

1. Adicione o tipo no enum:
```dart
enum TipoNotificacao {
  // ... existentes
  novoTipo,
}
```

2. Adicione no SQL constraint:
```sql
ALTER TABLE notificacoes DROP CONSTRAINT notificacoes_tipo_check;
ALTER TABLE notificacoes ADD CONSTRAINT notificacoes_tipo_check
  CHECK (tipo IN ('solicitacaoVencendo', 'solicitacaoVencida', ..., 'novoTipo'));
```

3. Adicione ícone e label na UI:
```dart
IconData _getIconByType(TipoNotificacao tipo) {
  switch (tipo) {
    // ... existentes
    case TipoNotificacao.novoTipo:
      return LucideIcons.iconName;
  }
}
```

## Performance

- Índices criados para queries eficientes
- RLS configurada para segurança
- Caching de contadores
- Lazy loading de notificações antigas

## Segurança

- Row Level Security (RLS) habilitada
- Usuários só veem suas próprias notificações ou do gabinete
- Validação de tipos e prioridades no banco
- Proteção contra SQL injection via prepared statements

---

**Desenvolvido com ❤️ para Gabitech CRM**
