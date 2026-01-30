import 'cidadao.dart';

/// Model for chat sessions/attendances
class Atendimento {
  final int id;
  final DateTime createdAt;
  final int gabineteId;
  final String telefone;
  final String status; // novo, em atendimento, finalizado
  final int? cidadaoId;
  final bool autorizado;
  final Cidadao? cidadao;
  final String? obsGerais;
  
  // Computed fields for UI
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? lastMessageType; // text, audio, image, video, document
  final bool lastMessageIsFromMe;

  Atendimento({
    required this.id,
    required this.createdAt,
    required this.gabineteId,
    required this.telefone,
    required this.status,
    this.cidadaoId,
    this.autorizado = true,
    this.cidadao,
    this.obsGerais,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastMessageType,
    this.lastMessageIsFromMe = false,
  });

  factory Atendimento.fromJson(Map<String, dynamic> json) {
    return Atendimento(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      gabineteId: json['gabinete'] as int,
      telefone: json['telefone'] as String? ?? '',
      status: json['status'] as String? ?? 'em atendimento',
      cidadaoId: json['cidadao'] as int?,
      autorizado: json['autorizado'] as bool? ?? true,
      obsGerais: json['obs_gerais'] as String?,
      cidadao: json['cidadaos'] != null 
          ? Cidadao.fromJson(json['cidadaos'] as Map<String, dynamic>)
          : null,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null 
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessageType: json['last_message_type'] as String?,
      lastMessageIsFromMe: json['last_message_is_from_me'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'gabinete': gabineteId,
      'telefone': telefone,
      'status': status,
      'cidadao': cidadaoId,
      'autorizado': autorizado,
      if (obsGerais != null) 'obs_gerais': obsGerais,
    };
  }

  /// Get display name (cidadão name or phone number)
  String get displayName {
    if (cidadao?.nome != null && cidadao!.nome!.isNotEmpty) {
      return cidadao!.nome!;
    }
    return _formatPhone(telefone);
  }

  /// Get formatted phone
  String _formatPhone(String phone) {
    // Remove @s.whatsapp.net suffix if present
    String numero = phone.replaceAll(RegExp(r'@.*'), '');
    
    // Remove caracteres não numéricos
    numero = numero.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Se começar com 55 (Brasil), formata
    if (numero.startsWith('55') && numero.length >= 12) {
      final ddd = numero.substring(2, 4);
      final parte1 = numero.substring(4, numero.length - 4);
      final parte2 = numero.substring(numero.length - 4);
      return '($ddd) $parte1-$parte2';
    }
    
    // Formato genérico para outros números
    if (numero.length >= 10) {
      final ddd = numero.substring(0, 2);
      final parte1 = numero.substring(2, numero.length - 4);
      final parte2 = numero.substring(numero.length - 4);
      return '($ddd) $parte1-$parte2';
    }
    
    return numero.isNotEmpty ? numero : phone;
  }

  /// Get formatted phone for display
  String get formattedPhone => _formatPhone(telefone);

  /// Get clean phone number for API calls
  String get cleanPhone => telefone.replaceAll('@s.whatsapp.net', '');

  /// Get initials for avatar
  String get initials {
    if (cidadao?.nome != null && cidadao!.nome!.isNotEmpty) {
      final parts = cidadao!.nome!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return cidadao!.nome![0].toUpperCase();
    }
    return '?';
  }

  /// Get formatted last message time
  String get formattedLastMessageTime {
    if (lastMessageAt == null) return '';
    
    final now = DateTime.now();
    final diff = now.difference(lastMessageAt!);
    
    if (diff.inDays == 0) {
      return '${lastMessageAt!.hour.toString().padLeft(2, '0')}:${lastMessageAt!.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Ontem';
    } else if (diff.inDays < 7) {
      const dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
      return dias[lastMessageAt!.weekday % 7];
    } else {
      return '${lastMessageAt!.day.toString().padLeft(2, '0')}/${lastMessageAt!.month.toString().padLeft(2, '0')}/${lastMessageAt!.year}';
    }
  }

  /// Check if atendimento is active
  bool get isActive => status == 'em atendimento';

  /// Copy with new values
  Atendimento copyWith({
    int? id,
    DateTime? createdAt,
    int? gabineteId,
    String? telefone,
    String? status,
    int? cidadaoId,
    bool? autorizado,
    Cidadao? cidadao,
    String? obsGerais,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? lastMessageType,
    bool? lastMessageIsFromMe,
  }) {
    return Atendimento(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      gabineteId: gabineteId ?? this.gabineteId,
      telefone: telefone ?? this.telefone,
      status: status ?? this.status,
      cidadaoId: cidadaoId ?? this.cidadaoId,
      autorizado: autorizado ?? this.autorizado,
      cidadao: cidadao ?? this.cidadao,
      obsGerais: obsGerais ?? this.obsGerais,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageIsFromMe: lastMessageIsFromMe ?? this.lastMessageIsFromMe,
    );
  }

  /// Formata a prévia da última mensagem no estilo WhatsApp
  String get lastMessagePreview {
    if (lastMessage == null && lastMessageType == null) {
      return 'Nova conversa';
    }

    String prefix = lastMessageIsFromMe ? 'Você: ' : '';
    String content;

    switch (lastMessageType) {
      case 'image':
        content = '📷 Foto';
        break;
      case 'video':
        content = '🎥 Vídeo';
        break;
      case 'audio':
        content = '🎤 Áudio';
        break;
      case 'document':
        content = '📄 Documento';
        break;
      default:
        content = lastMessage ?? '';
    }

    return '$prefix$content';
  }

  /// Se é uma conversa nova (status = 'novo')
  bool get isNew => status == 'novo';

  /// Se está em atendimento (status = 'em atendimento')
  bool get isEmAtendimento => status == 'em atendimento';

  /// Se está finalizado (status = 'finalizado')
  bool get isFinalizado => status == 'finalizado';
}
