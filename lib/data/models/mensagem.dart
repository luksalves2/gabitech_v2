/// Status de envio da mensagem (para optimistic update)
enum MensagemStatus { sending, sent, error }

/// Model for chat messages
class Mensagem {
  final int id;
  final DateTime createdAt;
  final int gabineteId;
  final int? cidadaoId;
  final String? mensagem;
  final String tipo; // text, audio, image, video, document
  final String? idMensagem;
  final String telefone;
  final int? dataMilissegundos;
  final int? atendimentoId;
  final bool isFromMe; // true = enviada pelo sistema, false = recebida
  final String? _mediaUrl; // URL da mídia no storage
  final MensagemStatus status; // Status de envio (optimistic update)
  final String? tempId; // ID temporário para mensagens pendentes

  Mensagem({
    required this.id,
    required this.createdAt,
    required this.gabineteId,
    this.cidadaoId,
    this.mensagem,
    required this.tipo,
    this.idMensagem,
    required this.telefone,
    this.dataMilissegundos,
    this.atendimentoId,
    this.isFromMe = false,
    String? mediaUrl,
    this.status = MensagemStatus.sent,
    this.tempId,
  }) : _mediaUrl = mediaUrl;

  /// Cria uma mensagem pendente (optimistic) para exibição imediata
  factory Mensagem.pending({
    required int gabineteId,
    required int atendimentoId,
    required String telefone,
    required String mensagem,
    String tipo = 'text',
    int? cidadaoId,
    String? mediaUrl,
  }) {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    return Mensagem(
      id: -DateTime.now().millisecondsSinceEpoch, // ID negativo temporário
      createdAt: DateTime.now(),
      gabineteId: gabineteId,
      atendimentoId: atendimentoId,
      telefone: telefone,
      mensagem: mensagem,
      tipo: tipo,
      cidadaoId: cidadaoId,
      isFromMe: true,
      status: MensagemStatus.sending,
      tempId: tempId,
      mediaUrl: mediaUrl,
    );
  }

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    // Supabase devolve created_at em UTC (ex: 2026-01-28T02:35:00Z).
    // Convertemos para horário local antes de exibir.
    final createdAtRaw = json['created_at'] as String;
    final createdAt = DateTime.parse(createdAtRaw).toLocal();

    return Mensagem(
      id: json['id'] as int,
      createdAt: createdAt,
      gabineteId: json['gabinete'] as int,
      cidadaoId: json['cidadao'] as int?,
      mensagem: json['mensagem'] as String?,
      tipo: json['tipo'] as String? ?? 'text',
      idMensagem: json['id_mensagem'] as String?,
      telefone: json['telefone'] as String? ?? '',
      dataMilissegundos: json['data_milissegundos'] as int?,
      atendimentoId: json['atendimento'] as int?,
      isFromMe: json['is_from_me'] as bool? ?? false,
      mediaUrl: json['media_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      // Persistir em UTC para manter consistência no backend
      'created_at': createdAt.toUtc().toIso8601String(),
      'gabinete': gabineteId,
      'cidadao': cidadaoId,
      'mensagem': mensagem,
      'tipo': tipo,
      'id_mensagem': idMensagem,
      'telefone': telefone,
      'data_milissegundos': dataMilissegundos,
      'atendimento': atendimentoId,
      'is_from_me': isFromMe,
      'media_url': _mediaUrl,
    };
  }

  /// Retorna uma cópia com campos alterados
  Mensagem copyWith({
    int? id,
    DateTime? createdAt,
    int? gabineteId,
    int? cidadaoId,
    String? mensagem,
    String? tipo,
    String? idMensagem,
    String? telefone,
    int? dataMilissegundos,
    int? atendimentoId,
    bool? isFromMe,
    String? mediaUrl,
    MensagemStatus? status,
    String? tempId,
  }) {
    return Mensagem(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      gabineteId: gabineteId ?? this.gabineteId,
      cidadaoId: cidadaoId ?? this.cidadaoId,
      mensagem: mensagem ?? this.mensagem,
      tipo: tipo ?? this.tipo,
      idMensagem: idMensagem ?? this.idMensagem,
      telefone: telefone ?? this.telefone,
      dataMilissegundos: dataMilissegundos ?? this.dataMilissegundos,
      atendimentoId: atendimentoId ?? this.atendimentoId,
      isFromMe: isFromMe ?? this.isFromMe,
      mediaUrl: mediaUrl ?? _mediaUrl,
      status: status ?? this.status,
      tempId: tempId ?? this.tempId,
    );
  }

  /// Verifica se a mensagem está sendo enviada (pendente)
  bool get isSending => status == MensagemStatus.sending;

  /// Verifica se houve erro no envio
  bool get hasError => status == MensagemStatus.error;

  /// Get formatted time
  String get formattedTime {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Check if message is media
  bool get isMedia => tipo != 'text';

  /// Get media URL if it's a media message
  String? get mediaUrl {
    // Primeiro verifica o campo media_url
    if (_mediaUrl != null && _mediaUrl!.isNotEmpty) {
      return _mediaUrl;
    }
    // Fallback: verifica se a mensagem é uma URL
    if (isMedia && mensagem != null && mensagem!.startsWith('http')) {
      return mensagem;
    }
    return null;
  }
}
