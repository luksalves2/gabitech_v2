import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/mensagem_providers.dart';
import '../../../providers/solicitacao_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/cidadao_providers.dart';
import '../../../data/models/mensagem.dart';
import '../../../data/models/atendimento.dart';
import '../../../data/models/cidadao.dart';
import '../../../data/models/solicitacao.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/cidadao_form_dialog.dart';
import '../../widgets/create_solicitacao_dialog.dart';
import '../../widgets/solicitacao_details_dialog.dart';
import '../../widgets/cached_avatar.dart';

/// State providers for the page
final _searchQueryProvider = StateProvider<String>((ref) => '');
final _messageInputProvider = StateProvider<String>((ref) => '');
final _showInfoPanelProvider = StateProvider<bool>((ref) => true);
final _conversationsTabProvider = StateProvider<int>((ref) => 0); // 0 = Ativas, 1 = Finalizadas

/// Formata telefone para exibição visual
String _formatTelefone(String telefone) {
  // Remove o sufixo @s.whatsapp.net se existir
  String numero = telefone.replaceAll('@s.whatsapp.net', '').trim();
  
  // Remove qualquer caractere não numérico
  numero = numero.replaceAll(RegExp(r'[^\d]'), '');
  
  // Se vazio, retorna vazio
  if (numero.isEmpty) return '';
  
  // Remove o código do país (55) se presente
  if (numero.startsWith('55') && numero.length > 10) {
    numero = numero.substring(2);
  }
  
  // Formata como (DD) XXXXX-XXXX ou (DD) XXXX-XXXX
  if (numero.length == 11) {
    return '(${numero.substring(0, 2)}) ${numero.substring(2, 7)}-${numero.substring(7)}';
  } else if (numero.length == 10) {
    return '(${numero.substring(0, 2)}) ${numero.substring(2, 6)}-${numero.substring(6)}';
  }
  
  return numero;
}

class MensagensPage extends ConsumerStatefulWidget {
  const MensagensPage({super.key});

  @override
  ConsumerState<MensagensPage> createState() => _MensagensPageState();
}

class _MensagensPageState extends ConsumerState<MensagensPage> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedMenuProvider.notifier).state = 'mensagens';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: !isDesktop ? const Drawer(child: AppSidebar()) : null,
      body: Row(
        children: [
          // Sidebar (desktop only)
          if (isDesktop) const AppSidebar(),

          // Conversations list
          _ConversationsList(
            searchController: _searchController,
            onSearch: (query) {
              ref.read(_searchQueryProvider.notifier).state = query;
            },
          ),

          // Chat area
          Expanded(
            flex: 2,
            child: _ChatArea(
              messageController: _messageController,
              scrollController: _scrollController,
              onSendMessage: _sendMessage,
              onToggleInfo: () {
                ref.read(_showInfoPanelProvider.notifier).state = 
                    !ref.read(_showInfoPanelProvider);
              },
            ),
          ),

          // Info panel (desktop only, toggleable)
          if (isDesktop)
            Consumer(
              builder: (context, ref, _) {
                final showPanel = ref.watch(_showInfoPanelProvider);
                if (!showPanel) return const SizedBox.shrink();
                return _InfoPanel(
                  onClose: () {
                    ref.read(_showInfoPanelProvider.notifier).state = false;
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final selected = ref.read(selectedAtendimentoProvider);
    if (selected == null) return;

    // Verificar se é a primeira resposta (conversa nova)
    final wasNew = selected.isNew;

    await ref.read(mensagemNotifierProvider.notifier).send(
          atendimentoId: selected.id,
          telefone: selected.telefone,
          mensagem: text,
          cidadaoId: selected.cidadaoId,
        );

    _messageController.clear();
    ref.read(_messageInputProvider.notifier).state = '';

    // Se era uma conversa nova, atualizar status para "em atendimento"
    if (wasNew) {
      // Atualizar o status no banco de dados (igual ao encerrar)
      ref.read(atendimentoNotifierProvider.notifier).updateStatus(selected.id, 'em atendimento');
      
      // Mudar para aba "Atendendo"
      ref.read(_conversationsTabProvider.notifier).state = 1;
    }

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

// ============================================
// CONVERSATIONS LIST
// ============================================

class _ConversationsList extends ConsumerWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  const _ConversationsList({
    required this.searchController,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(_searchQueryProvider);
    final selectedTab = ref.watch(_conversationsTabProvider);
    
    // Tab 0 = Novas (status = 'novo')
    // Tab 1 = Em atendimento (status = 'em atendimento')
    // Tab 2 = Finalizadas (status = 'finalizado')
    String statusFilter;
    if (selectedTab == 0) {
      statusFilter = 'novo';
    } else if (selectedTab == 1) {
      statusFilter = 'em atendimento';
    } else {
      statusFilter = 'finalizado';
    }
    
    final atendimentosAsync = ref.watch(
      atendimentosProvider(AtendimentosParams(
        status: statusFilter,
        searchTerm: searchQuery.isNotEmpty ? searchQuery : null,
      )),
    );
    final selectedAtendimento = ref.watch(selectedAtendimentoProvider);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                // Search bar
                TextField(
                  controller: searchController,
                  onChanged: onSearch,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar conversa...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs - 3 abas
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'Novas',
                    icon: LucideIcons.mailPlus,
                    isSelected: selectedTab == 0,
                    onTap: () {
                      ref.read(_conversationsTabProvider.notifier).state = 0;
                    },
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Atendendo',
                    icon: LucideIcons.messageCircle,
                    isSelected: selectedTab == 1,
                    onTap: () {
                      ref.read(_conversationsTabProvider.notifier).state = 1;
                    },
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Finalizadas',
                    icon: LucideIcons.checkCircle,
                    isSelected: selectedTab == 2,
                    onTap: () {
                      ref.read(_conversationsTabProvider.notifier).state = 2;
                    },
                  ),
                ),
              ],
            ),
          ),

          // Conversations list
          Expanded(
            child: atendimentosAsync.when(
              data: (atendimentos) {
                // Não precisa filtrar - o provider já filtra por status
                if (atendimentos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selectedTab == 0 
                              ? LucideIcons.mailPlus 
                              : selectedTab == 1 
                                  ? LucideIcons.messageCircle 
                                  : LucideIcons.checkCircle,
                          size: 48,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedTab == 0 
                              ? 'Nenhuma conversa nova' 
                              : selectedTab == 1 
                                  ? 'Nenhuma conversa em atendimento' 
                                  : 'Nenhuma conversa finalizada',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: atendimentos.length,
                  itemBuilder: (context, index) {
                    final atendimento = atendimentos[index];
                    final isSelected = selectedAtendimento?.id == atendimento.id;

                    return _ConversationTile(
                      atendimento: atendimento,
                      isSelected: isSelected,
                      showStatusTag: false, // Não mostrar tag nas abas separadas
                      onTap: () {
                        ref.read(selectedAtendimentoProvider.notifier).state =
                            atendimento;
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Erro ao carregar', style: TextStyle(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Atendimento atendimento;
  final bool isSelected;
  final bool showStatusTag;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.atendimento,
    required this.isSelected,
    required this.onTap,
    this.showStatusTag = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
          border: Border(
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
            left: isSelected
                ? BorderSide(color: AppColors.primary, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CachedAvatar(
              radius: 24,
              imageUrl: atendimento.cidadao?.foto,
              name: atendimento.displayName,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          atendimento.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        atendimento.formattedLastMessageTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    atendimento.lastMessagePreview,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// CHAT AREA
// ============================================

class _ChatArea extends ConsumerStatefulWidget {
  final TextEditingController messageController;
  final ScrollController scrollController;
  final VoidCallback onSendMessage;
  final VoidCallback onToggleInfo;

  const _ChatArea({
    required this.messageController,
    required this.scrollController,
    required this.onSendMessage,
    required this.onToggleInfo,
  });

  @override
  ConsumerState<_ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends ConsumerState<_ChatArea> {
  Future<void> _markRead(int atendimentoId) async {
    await ref.read(mensagemNotifierProvider.notifier).marcarComoLidas(atendimentoId);
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen must be inside build() method
    ref.listen<Atendimento?>(selectedAtendimentoProvider, (prev, next) {
      if (next != null && next.id != prev?.id) {
        _markRead(next.id);
      }
    });

    final selectedAtendimento = ref.watch(selectedAtendimentoProvider);

    if (selectedAtendimento == null) {
      return _buildEmptyState();
    }

    // Usa o provider combinado que inclui mensagens pendentes (optimistic update)
    final mensagensAsync = ref.watch(combinedMessagesProvider(selectedAtendimento.id));

    final isFinalized = selectedAtendimento.status == 'finalizado';

    return Container(
      color: const Color(0xFFEFEFEF),
      child: Column(
        children: [
          // Chat header
          _ChatHeader(
            atendimento: selectedAtendimento,
            onToggleInfo: widget.onToggleInfo,
          ),

          // Messages
          Expanded(
            child: Stack(
              children: [
                mensagensAsync.when(
                  data: (mensagens) => _MessagesList(
                    mensagens: mensagens,
                    scrollController: widget.scrollController,
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Erro ao carregar mensagens'),
                  ),
                ),
                // Overlay when finalized
                if (isFinalized)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _FinalizadoOverlay(
                      atendimentoId: selectedAtendimento.id,
                    ),
                  ),
              ],
            ),
          ),

          // Input area (hidden when finalized)
          if (!isFinalized)
            _MessageInput(
              controller: widget.messageController,
              onSend: widget.onSendMessage,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.messageCircle,
              size: 80,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Selecione uma conversa',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha uma conversa na lista ao lado para começar',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  final Atendimento atendimento;
  final VoidCallback onToggleInfo;

  const _ChatHeader({
    required this.atendimento,
    required this.onToggleInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showInfoPanel = ref.watch(_showInfoPanelProvider);
    final isFinalized = atendimento.status == 'finalizado';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CachedAvatar(
            radius: 20,
            imageUrl: atendimento.cidadao?.foto,
            name: atendimento.displayName,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        atendimento.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFinalized) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.textTertiary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Finalizado',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  isFinalized ? 'Atendimento encerrado' : atendimento.status,
                  style: TextStyle(
                    fontSize: 12,
                    color: isFinalized ? AppColors.textTertiary : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          // Toggle info panel button
          IconButton(
            icon: Icon(
              showInfoPanel ? LucideIcons.panelRightClose : LucideIcons.panelRightOpen,
              color: AppColors.textSecondary,
            ),
            onPressed: onToggleInfo,
            tooltip: showInfoPanel ? 'Ocultar painel' : 'Mostrar painel',
          ),
          // More actions
          IconButton(
            icon: const Icon(LucideIcons.moreVertical),
            onPressed: () {},
            tooltip: 'Mais opções',
          ),
        ],
      ),
    );
  }
}

class _MessagesList extends ConsumerWidget {
  final List<Mensagem> mensagens;
  final ScrollController scrollController;

  const _MessagesList({
    required this.mensagens,
    required this.scrollController,
  });

  /// Normaliza telefone removendo caracteres especiais
  String _normalizePhone(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Verifica se a mensagem foi enviada pelo gabinete
  /// Compara o telefone da mensagem com o telefone do gabinete
  bool _isFromGabinete(Mensagem mensagem, String? gabinetePhone) {
    if (gabinetePhone == null || gabinetePhone.isEmpty) {
      // Fallback para o campo isFromMe do banco
      return mensagem.isFromMe;
    }
    
    final normalizedMsgPhone = _normalizePhone(mensagem.telefone);
    final normalizedGabPhone = _normalizePhone(gabinetePhone);
    
    // Se o telefone de quem enviou a mensagem é igual ao telefone do gabinete,
    // então a mensagem foi enviada pelo gabinete
    return normalizedMsgPhone == normalizedGabPhone;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gabineteAsync = ref.watch(currentGabineteProvider);
    
    if (mensagens.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma mensagem ainda',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Scroll to bottom on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return gabineteAsync.when(
      data: (gabinete) {
        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: mensagens.length,
          itemBuilder: (context, index) {
            final mensagem = mensagens[index];
            final isMe = _isFromGabinete(mensagem, gabinete?.telefone);

            return _MessageBubble(
              mensagem: mensagem,
              isMe: isMe,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: mensagens.length,
        itemBuilder: (context, index) {
          final mensagem = mensagens[index];
          return _MessageBubble(
            mensagem: mensagem,
            isMe: mensagem.isFromMe,
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Mensagem mensagem;
  final bool isMe;

  const _MessageBubble({
    required this.mensagem,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    // Cores para mensagens enviadas (azul) e recebidas (branco)
    final sentColor = AppColors.primary; // Azul
    final sentBgColor = AppColors.primary.withValues(alpha: 0.1); // Azul claro de fundo
    final receivedBgColor = Colors.white;
    
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 80 : 0,
        right: isMe ? 0 : 80,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for received messages
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.success.withValues(alpha: 0.2),
              child: Icon(
                LucideIcons.user,
                size: 16,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Message bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? sentBgColor : receivedBgColor,
                border: isMe ? Border.all(color: sentColor.withValues(alpha: 0.3)) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Label enviado/recebido com ícone
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMe ? LucideIcons.send : LucideIcons.messageCircle,
                        size: 10,
                        color: isMe ? sentColor : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMe ? 'Enviada' : 'Recebida',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isMe ? sentColor : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Content based on type
                  _buildContent(context),
                  const SizedBox(height: 6),
                  // Time and status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mensagem.formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? sentColor.withValues(alpha: 0.7) : AppColors.textTertiary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(sentColor),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Avatar for sent messages
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: sentColor.withValues(alpha: 0.2),
              child: Icon(
                LucideIcons.building2,
                size: 16,
                color: sentColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Constrói o ícone de status da mensagem (enviando/enviado/erro)
  Widget _buildStatusIcon(Color sentColor) {
    if (mensagem.isSending) {
      // Enviando - mostra loading
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: sentColor.withValues(alpha: 0.7),
        ),
      );
    } else if (mensagem.hasError) {
      // Erro - mostra X vermelho
      return Icon(
        LucideIcons.alertCircle,
        size: 14,
        color: AppColors.error,
      );
    } else {
      // Enviado - mostra check duplo
      return Icon(
        LucideIcons.checkCheck,
        size: 14,
        color: sentColor,
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    switch (mensagem.tipo) {
      case 'image':
        return _buildImageContent(context);
      case 'audio':
        return _buildAudioContent(context);
      case 'video':
        return _buildVideoContent(context);
      case 'document':
        return _buildDocumentContent(context);
      default:
        return _buildTextContent();
    }
  }

  Widget _buildTextContent() {
    return Text(
      mensagem.mensagem ?? '',
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final url = mensagem.mediaUrl;
    if (url != null) {
      return GestureDetector(
        onTap: () => _showImageViewer(context, url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: 200,
            height: 200,
            errorBuilder: (_, __, ___) => _buildMediaPlaceholder(LucideIcons.image),
          ),
        ),
      );
    }
    return _buildMediaPlaceholder(LucideIcons.image);
  }

  void _showImageViewer(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            // Image
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(40),
                    color: Colors.black54,
                    child: const Icon(LucideIcons.imageOff, color: Colors.white, size: 48),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
            // Download button
            Positioned(
              bottom: 16,
              right: 16,
              child: IconButton(
                onPressed: () => _openUrl(url),
                icon: const Icon(LucideIcons.download, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                tooltip: 'Baixar imagem',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioContent(BuildContext context) {
    final url = mensagem.mediaUrl;
    return GestureDetector(
      onTap: () => url != null ? _showAudioPlayer(context, url) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.play, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Áudio',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                Text(
                  'Toque para ouvir',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Icon(LucideIcons.volume2, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showAudioPlayer(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.music, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Áudio da mensagem',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Clique no botão abaixo para abrir o áudio',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                  label: const Text('Fechar'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openUrl(url);
                  },
                  icon: const Icon(LucideIcons.externalLink),
                  label: const Text('Abrir Áudio'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    final url = mensagem.mediaUrl;
    return GestureDetector(
      onTap: () => url != null ? _showVideoPlayer(context, url) : null,
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Play button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.play, color: Colors.white, size: 24),
            ),
            // Video label
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.video, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    const Text(
                      'Vídeo',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPlayer(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Vídeo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _openUrl(url),
                    icon: const Icon(LucideIcons.externalLink),
                    tooltip: 'Abrir em nova aba',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.video, size: 48, color: AppColors.primary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openUrl(url);
                        },
                        icon: const Icon(LucideIcons.play),
                        label: const Text('Reproduzir Vídeo'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentContent(BuildContext context) {
    final url = mensagem.mediaUrl;
    final fileName = mensagem.mensagem ?? 'Documento';
    
    return GestureDetector(
      onTap: () => url != null ? _showDocumentOptions(context, url, fileName) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(LucideIcons.fileText, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.length > 20 ? '${fileName.substring(0, 20)}...' : fileName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Toque para abrir',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Icon(LucideIcons.download, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showDocumentOptions(BuildContext context, String url, String fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.fileText, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openUrl(url);
                },
                icon: const Icon(LucideIcons.externalLink),
                label: const Text('Abrir Documento'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openUrl(url);
                },
                icon: const Icon(LucideIcons.download),
                label: const Text('Baixar Documento'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildMediaPlaceholder(IconData icon) {
    return Container(
      width: 150,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: AppColors.textTertiary, size: 32),
    );
  }
}

// ============================================
// FINALIZADO OVERLAY
// ============================================

class _FinalizadoOverlay extends ConsumerWidget {
  final int atendimentoId;

  const _FinalizadoOverlay({required this.atendimentoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.checkCircle,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Atendimento finalizado',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Deseja reabrir este atendimento?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(atendimentoNotifierProvider.notifier).reabrir(atendimentoId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Iniciar atendimento',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends ConsumerWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          // Attachment button (+ icon like WhatsApp)
          IconButton(
            icon: Icon(LucideIcons.plus, color: AppColors.textSecondary),
            onPressed: () {
              _showAttachmentMenu(context, ref);
            },
            tooltip: 'Anexar',
          ),
          const SizedBox(width: 4),
          // Text input
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (value) {
                ref.read(_messageInputProvider.notifier).state = value;
              },
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Digite uma mensagem',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Audio button or send button
          Consumer(
            builder: (context, ref, _) {
              final input = ref.watch(_messageInputProvider);
              if (input.isEmpty) {
                return IconButton(
                  icon: Icon(LucideIcons.mic, color: AppColors.textSecondary),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gravação de áudio em breve!')),
                    );
                  },
                  tooltip: 'Gravar áudio',
                );
              }
              return IconButton(
                icon: Icon(LucideIcons.send, color: AppColors.primary),
                onPressed: onSend,
                tooltip: 'Enviar',
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context, WidgetRef ref) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, -220), ancestor: overlay),
        button.localToGlobal(button.size.bottomLeft(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _buildMenuItem(
          icon: LucideIcons.fileText,
          label: 'Documento',
          color: const Color(0xFF5157AE),
          value: 'document',
        ),
        _buildMenuItem(
          icon: LucideIcons.image,
          label: 'Fotos e vídeos',
          color: const Color(0xFFD3396D),
          value: 'media',
        ),
        _buildMenuItem(
          icon: LucideIcons.music,
          label: 'Áudio',
          color: const Color(0xFFEE7E34),
          value: 'audio',
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleAttachmentSelection(context, ref, value);
      }
    });
  }

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required String value,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Future<void> _handleAttachmentSelection(BuildContext context, WidgetRef ref, String type) async {
    final selectedAtendimento = ref.read(selectedAtendimentoProvider);
    if (selectedAtendimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma conversa primeiro')),
      );
      return;
    }

    FileType fileType;
    List<String>? allowedExtensions;
    String mediaType;

    switch (type) {
      case 'document':
        fileType = FileType.custom;
        allowedExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'csv'];
        mediaType = 'document';
        break;
      case 'media':
        fileType = FileType.media;
        mediaType = 'image'; // Will be determined by file
        break;
      case 'audio':
        fileType = FileType.audio;
        mediaType = 'audio';
        break;
      default:
        return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Show sending dialog
        if (context.mounted) {
          _showSendMediaDialog(context, ref, file, selectedAtendimento, mediaType);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar arquivo: $e')),
        );
      }
    }
  }

  void _showSendMediaDialog(
    BuildContext context,
    WidgetRef ref,
    PlatformFile file,
    Atendimento atendimento,
    String mediaType,
  ) {
    final captionController = TextEditingController();
    final extension = file.extension?.toLowerCase() ?? '';
    
    // Determine media type from extension
    String actualMediaType = mediaType;
    if (mediaType == 'image') {
      if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
        actualMediaType = 'video';
      } else {
        actualMediaType = 'image';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getIconForType(actualMediaType),
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text('Enviar ${_getLabelForType(actualMediaType)}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_getIconForType(actualMediaType), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatFileSize(file.size),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Caption input (not for audio)
            if (actualMediaType != 'audio')
              TextField(
                controller: captionController,
                decoration: const InputDecoration(
                  labelText: 'Legenda (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            const SizedBox(height: 8),
            Text(
              'Enviando para: ${atendimento.cidadao?.nome ?? _formatTelefone(atendimento.telefone)}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _sendMedia(
                context,
                ref,
                file,
                atendimento,
                actualMediaType,
                captionController.text,
              );
            },
            icon: const Icon(LucideIcons.send, size: 18),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMedia(
    BuildContext context,
    WidgetRef ref,
    PlatformFile file,
    Atendimento atendimento,
    String mediaType,
    String caption,
  ) async {
    // Verificar se tem bytes do arquivo
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erro: Não foi possível ler o arquivo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final gabinete = await ref.read(currentGabineteProvider.future);
    if (gabinete == null || gabinete.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Token do gabinete não configurado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 1. Criar mensagem pendente (optimistic) IMEDIATAMENTE
    final displayText = caption.isNotEmpty ? caption : '[${_getLabelForType(mediaType)}]';
    final pendingMsg = Mensagem.pending(
      gabineteId: gabinete.id,
      atendimentoId: atendimento.id,
      telefone: gabinete.telefone ?? atendimento.telefone,
      mensagem: displayText,
      tipo: mediaType,
      cidadaoId: atendimento.cidadaoId,
    );

    // Adiciona à lista de pendentes para exibir na UI imediatamente
    ref.read(pendingMessagesProvider.notifier).addPending(atendimento.id, pendingMsg);

    try {
      // 2. Upload para Supabase Storage
      final storageService = ref.read(storageServiceProvider);
      final uploadResult = await storageService.uploadFile(
        gabineteId: gabinete.id,
        fileBytes: file.bytes!,
        fileName: file.name,
        mediaType: mediaType,
      );

      if (!uploadResult.isSuccess) {
        throw Exception(uploadResult.error ?? 'Erro no upload');
      }

      final fileUrl = uploadResult.url!;

      // 2. Enviar via UazAPI
      final uazapiService = ref.read(uazapiServiceProvider);
      final instanceToken = gabinete.token!;
      final telefone = atendimento.telefone;
      
      // Chamar o endpoint correto baseado no tipo de mídia
      dynamic response;
      switch (mediaType) {
        case 'image':
          response = await uazapiService.enviarImagem(
            instanceToken: instanceToken,
            telefone: telefone,
            imageUrl: fileUrl,
            caption: caption.isNotEmpty ? caption : null,
          );
          break;
        case 'video':
          response = await uazapiService.enviarVideo(
            instanceToken: instanceToken,
            telefone: telefone,
            videoUrl: fileUrl,
            caption: caption.isNotEmpty ? caption : null,
          );
          break;
        case 'audio':
          response = await uazapiService.enviarAudio(
            instanceToken: instanceToken,
            telefone: telefone,
            audioUrl: fileUrl,
          );
          break;
        case 'document':
          response = await uazapiService.enviarDocumento(
            instanceToken: instanceToken,
            telefone: telefone,
            documentUrl: fileUrl,
            filename: file.name,
            caption: caption.isNotEmpty ? caption : null,
          );
          break;
        default:
          throw Exception('Tipo de mídia não suportado');
      }

      if (response.isSuccess) {
        // Marca como enviado (API respondeu OK)
        ref.read(pendingMessagesProvider.notifier).markSent(atendimento.id, pendingMsg.tempId!);

        // Não salvar no banco aqui - o n8n já faz o insert via webhook
        // A mensagem pendente será removida automaticamente quando chegar do banco
        Future.delayed(const Duration(seconds: 3), () {
          ref.read(pendingMessagesProvider.notifier).cleanupOldSent(atendimento.id);
          ref.invalidate(atendimentosProvider);
        });
      } else {
        // Marca como erro
        ref.read(pendingMessagesProvider.notifier).markError(atendimento.id, pendingMsg.tempId!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${response.error ?? 'Erro ao enviar pelo WhatsApp'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Marca como erro
      ref.read(pendingMessagesProvider.notifier).markError(atendimento.id, pendingMsg.tempId!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'image':
        return LucideIcons.image;
      case 'video':
        return LucideIcons.video;
      case 'audio':
        return LucideIcons.music;
      case 'document':
        return LucideIcons.fileText;
      default:
        return LucideIcons.file;
    }
  }

  String _getLabelForType(String type) {
    switch (type) {
      case 'image':
        return 'Imagem';
      case 'video':
        return 'Vídeo';
      case 'audio':
        return 'Áudio';
      case 'document':
        return 'Documento';
      default:
        return 'Arquivo';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ============================================
// INFO PANEL (Right sidebar)
// ============================================

class _InfoPanel extends ConsumerWidget {
  final VoidCallback onClose;
  
  const _InfoPanel({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedAtendimento = ref.watch(selectedAtendimentoProvider);

    return Container(
      width: 380, // Wider panel
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.border),
        ),
      ),
      child: selectedAtendimento == null
          ? _buildEmptyPanel()
          : _InfoPanelContent(atendimento: selectedAtendimento, onClose: onClose),
    );
  }

  Widget _buildEmptyPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header alinhado ao topo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Informações',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: onClose,
                tooltip: 'Fechar',
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.user,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Selecione uma conversa',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPanelContent extends ConsumerStatefulWidget {
  final Atendimento atendimento;
  final VoidCallback onClose;

  const _InfoPanelContent({
    required this.atendimento,
    required this.onClose,
  });

  @override
  ConsumerState<_InfoPanelContent> createState() => _InfoPanelContentState();
}

class _InfoPanelContentState extends ConsumerState<_InfoPanelContent> {
  late TextEditingController _obsController;
  bool _salvandoResumo = false;
  Atendimento get atendimento => widget.atendimento;

  @override
  void initState() {
    super.initState();
    _obsController =
        TextEditingController(text: widget.atendimento.obsGerais ?? '');
  }

  @override
  void didUpdateWidget(covariant _InfoPanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.atendimento.id != oldWidget.atendimento.id ||
        widget.atendimento.obsGerais != oldWidget.atendimento.obsGerais) {
      _obsController.text = widget.atendimento.obsGerais ?? '';
    }
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atendimento = widget.atendimento;
    // Buscar cidadão atualizado do provider
    final cidadaoAsync = atendimento.cidadaoId != null
        ? ref.watch(cidadaoProvider(atendimento.cidadaoId!))
        : null;
    
    final cidadao = cidadaoAsync?.valueOrNull ?? atendimento.cidadao;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with close button - aligned to top
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage:
                    cidadao?.foto != null ? NetworkImage(cidadao!.foto!) : null,
                child: cidadao?.foto == null
                    ? Text(
                        atendimento.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      atendimento.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (cidadao != null)
                      Text(
                        _formatTelefone(cidadao.telefone ?? ''),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // Close button
              IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white),
                onPressed: widget.onClose,
                tooltip: 'Fechar painel',
              ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info section
                Text(
                  'INFORMAÇÕES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Phone - Formatado (sempre mostra)
                _InfoItem(
                  icon: LucideIcons.phone,
                  label: _formatPhoneDisplay(atendimento.cleanPhone),
                ),
                
                // Email (sempre mostra)
                _InfoItem(
                  icon: LucideIcons.mail,
                  label: cidadao?.email?.isNotEmpty == true ? cidadao!.email! : '-',
                ),
                
                // Endereço (sempre mostra)
                _InfoItem(
                  icon: LucideIcons.mapPin,
                  label: _getAddressShort(cidadao),
                ),
                
                // Data de nascimento (sempre mostra)
                _InfoItem(
                  icon: LucideIcons.calendar,
                  label: cidadao?.dataNascimento?.isNotEmpty == true ? cidadao!.dataNascimento! : '-',
                ),

                const SizedBox(height: 24),

                // Controle de autorização (somente vereador/admin)
                _AutorizacaoToggle(atendimento: atendimento),

                const SizedBox(height: 12),

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _encerrarAtendimento(context),
                    icon: const Icon(LucideIcons.checkCircle),
                    label: const Text('Encerrar atendimento'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _editarCadastro(context),
                    icon: const Icon(LucideIcons.edit),
                    label: const Text('Editar Cadastro'),
                  ),
                ),

                const SizedBox(height: 24),

                _buildSolicitacoesSection(),

                const SizedBox(height: 24),

                _buildResumoSection(),

                const SizedBox(height: 16),

                _buildAtividadesPendentesSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSolicitacoesSection() {
    if (widget.atendimento.cidadaoId == null) {
      return _sectionCard(
        title: 'SOLICITAÇÕES',
        trailing: _novaSolicitacaoButton(),
        child: Text(
          'Cadastre o cidadão para ver solicitações',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    final solicitacoesAsync = ref.watch(
      solicitacoesByCidadaoProvider(widget.atendimento.cidadaoId!),
    );

    return solicitacoesAsync.when(
      data: (solicitacoes) {
        return _sectionCard(
          title: 'SOLICITAÇÕES',
          trailing: _novaSolicitacaoButton(),
          child: solicitacoes.isEmpty
              ? Text('Nenhuma solicitação',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
              : Column(
                  children: solicitacoes.take(5).map(_buildSolicitacaoCard).toList(),
                ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          Text('Erro ao carregar', style: TextStyle(color: AppColors.error)),
    );
  }

  Widget _buildSolicitacaoCard(Solicitacao s) {
    final statusColor = _statusColor(s.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.titulo ?? 'Sem título',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(s.status ?? 'pendente', statusColor),
                  ],
                ),
                if (s.descricao?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      s.descricao!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _editarSolicitacao(s),
                style:
                    TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Editar'),
              ),
              ElevatedButton(
                onPressed: () => _concluirSolicitacao(s),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(120, 36),
                ),
                child: const Text('Concluir'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _novaSolicitacaoButton() => IconButton(
        icon: const Icon(LucideIcons.plus, size: 18),
        onPressed: () => _criarSolicitacao(context),
        tooltip: 'Nova solicitação',
      );

  Widget _buildResumoSection() {
    return _sectionCard(
      title: 'RESUMO DO ATENDIMENTO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Use para registrar observações importantes da conversa. Fica visível para toda a equipe.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _obsController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Digite um resumo ou observação geral...',
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _salvandoResumo ? null : _salvarResumo,
              icon: _salvandoResumo
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.save),
              label: const Text('Salvar resumo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtividadesPendentesSection() {
    if (widget.atendimento.cidadaoId == null) return const SizedBox.shrink();

    final solicitacoesAsync =
        ref.watch(solicitacoesByCidadaoProvider(widget.atendimento.cidadaoId!));

    return solicitacoesAsync.when(
      data: (solicitacoes) {
        final pendentes = solicitacoes
            .where((s) => (s.status ?? '').toLowerCase() != 'finalizado')
            .toList();

        return _sectionCard(
          title: 'ATIVIDADES PENDENTES',
          child: pendentes.isEmpty
              ? Text('Nenhuma pendência',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
              : Column(
                  children: pendentes.take(3).map((s) {
                    final color = _statusColor(s.status);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.titulo ?? 'Sem título',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  s.status ?? 'Pendente',
                                  style: TextStyle(
                                      color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          _statusChip(s.status ?? 'pendente', color),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _editarSolicitacao(s),
                            child: const Text('Editar'),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          Text('Erro ao carregar', style: TextStyle(color: AppColors.error)),
    );
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'em analise':
      case 'em análise':
        return AppColors.warning;
      case 'em andamento':
      case 'programado':
        return AppColors.info;
      case 'em atraso':
        return AppColors.error;
      case 'finalizado':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  /// Formata telefone para exibição: +55 (47) 99204-9009
  String _formatPhoneDisplay(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length >= 12) {
      // +55 (XX) XXXXX-XXXX
      return '+${cleaned.substring(0, 2)} (${cleaned.substring(2, 4)}) ${cleaned.substring(4, 9)}-${cleaned.substring(9)}';
    } else if (cleaned.length >= 11) {
      // (XX) XXXXX-XXXX
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length >= 10) {
      // (XX) XXXX-XXXX
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
    }
    return phone;
  }

  /// Retorna endereço curto para exibição inline
  String _getAddressShort(Cidadao? cidadao) {
    if (cidadao == null) return '-';
    
    final parts = <String>[];
    
    // Bairro
    if (cidadao.bairro != null && cidadao.bairro!.isNotEmpty) {
      parts.add(cidadao.bairro!);
    }
    
    // Cidade
    if (cidadao.cidade != null && cidadao.cidade!.isNotEmpty) {
      if (cidadao.estado != null && cidadao.estado!.isNotEmpty) {
        parts.add('${cidadao.cidade}/${cidadao.estado}');
      } else {
        parts.add(cidadao.cidade!);
      }
    }
    
    if (parts.isEmpty) return '-';
    return parts.join(', ');
  }


  void _encerrarAtendimento(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encerrar atendimento'),
        content: const Text('Tem certeza que deseja encerrar este atendimento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(atendimentoNotifierProvider.notifier).encerrar(atendimento.id);
    }
  }

  void _editarCadastro(BuildContext context) {
    showCidadaoFormDialog(
      context,
      cidadao: atendimento.cidadao,
      initialPhone: atendimento.cleanPhone,
      initialName: atendimento.displayName,
      onSaved: (cidadao) {
        // Link cidadao to atendimento if not linked yet
        if (atendimento.cidadaoId == null) {
          ref.read(atendimentoNotifierProvider.notifier)
              .linkCidadao(atendimento.id, cidadao.id);
        }
        // Refresh
        ref.invalidate(atendimentosProvider);
        ref.invalidate(atendimentoProvider(atendimento.id));
      },
    );
  }

  void _criarSolicitacao(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateSolicitacaoDialog(
        cidadaoPreSelecionado: widget.atendimento.cidadao,
      ),
    );
  }

  void _editarSolicitacao(Solicitacao solicitacao) {
    showDialog(
      context: context,
      builder: (context) => SolicitacaoDetailsDialog(solicitacao: solicitacao),
    );
  }

  Future<void> _concluirSolicitacao(Solicitacao solicitacao) async {
    await ref
        .read(solicitacaoNotifierProvider.notifier)
        .updateStatus(solicitacao.id, 'finalizado');
    final cidadaoId = solicitacao.cidadaoId ?? atendimento.cidadaoId ?? 0;
    ref.invalidate(solicitacoesByCidadaoProvider(cidadaoId));
  }

  Future<void> _salvarResumo() async {
    final texto = _obsController.text.trim();
    setState(() => _salvandoResumo = true);
    await ref
        .read(atendimentoNotifierProvider.notifier)
        .salvarObsGerais(atendimento.id, texto.isEmpty ? null : texto);
    setState(() => _salvandoResumo = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resumo salvo')),
      );
    }
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle de autorização do atendimento (lock), apenas para vereador/admin
class _AutorizacaoToggle extends ConsumerStatefulWidget {
  final Atendimento atendimento;
  const _AutorizacaoToggle({required this.atendimento});

  @override
  ConsumerState<_AutorizacaoToggle> createState() => _AutorizacaoToggleState();
}

class _AutorizacaoToggleState extends ConsumerState<_AutorizacaoToggle> {
  bool _saving = false;

  bool get _isVereador {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final tipo = user?.tipo?.toLowerCase();
    return tipo == 'vereador' || tipo == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVereador) return const SizedBox.shrink();

    final autorizado = widget.atendimento.autorizado;
    final icon = autorizado ? LucideIcons.unlock : LucideIcons.lock;
    final color = autorizado ? AppColors.success : AppColors.textSecondary;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            autorizado
                ? 'Chat autorizado para equipe'
                : 'Chat bloqueado (somente vereador)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        TextButton(
          onPressed: _saving ? null : () => _openSheet(context, autorizado),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(autorizado ? 'Bloquear' : 'Liberar'),
        ),
      ],
    );
  }

  Future<void> _openSheet(BuildContext context, bool autorizadoAtual) async {
    bool autorizado = autorizadoAtual;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Permissão do chat',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: autorizado,
                    onChanged: (v) => setModalState(() => autorizado = v),
                    title: const Text('Disponível para assessores'),
                    subtitle: const Text(
                      'Quando desligado, somente o vereador vê este atendimento.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await _save(autorizado);
                              },
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save(bool autorizado) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(atendimentoNotifierProvider.notifier)
          .atualizarAutorizado(widget.atendimento.id, autorizado);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
