import 'package:equatable/equatable.dart';

/// Tipos de notificação
enum TipoNotificacao {
  solicitacaoVencendo,
  solicitacaoVencida,
  cidadaoNaoAtendido,
  novoCidadao,
  novaSolicitacao,
  atividadePendente,
  mensagemNaoLida,
  sistema,
}

/// Prioridade da notificação
enum PrioridadeNotificacao {
  baixa,
  media,
  alta,
  urgente,
}

/// Notificacao model
class Notificacao extends Equatable {
  final int id;
  final String? usuario;
  final int? gabinete;
  final TipoNotificacao tipo;
  final PrioridadeNotificacao prioridade;
  final String titulo;
  final String mensagem;
  final String? rota; // Rota para onde navegar ao clicar
  final Map<String, dynamic>? metadata; // Dados extras (IDs, etc)
  final bool lida;
  final DateTime createdAt;
  final DateTime? lidaEm;

  const Notificacao({
    required this.id,
    this.usuario,
    this.gabinete,
    required this.tipo,
    required this.prioridade,
    required this.titulo,
    required this.mensagem,
    this.rota,
    this.metadata,
    this.lida = false,
    required this.createdAt,
    this.lidaEm,
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) {
    // Handle gabinete field
    int? gabineteValue;
    if (json['gabinete'] != null) {
      if (json['gabinete'] is int) {
        gabineteValue = json['gabinete'];
      } else if (json['gabinete'] is String) {
        gabineteValue = int.tryParse(json['gabinete']);
      }
    }

    return Notificacao(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      usuario: json['usuario'] as String?,
      gabinete: gabineteValue,
      tipo: TipoNotificacao.values.firstWhere(
        (e) => e.name == json['tipo'],
        orElse: () => TipoNotificacao.sistema,
      ),
      prioridade: PrioridadeNotificacao.values.firstWhere(
        (e) => e.name == json['prioridade'],
        orElse: () => PrioridadeNotificacao.media,
      ),
      titulo: json['titulo'] as String,
      mensagem: json['mensagem'] as String,
      rota: json['rota'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      lida: json['lida'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lidaEm: json['lida_em'] != null
          ? DateTime.parse(json['lida_em'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario': usuario,
      'gabinete': gabinete,
      'tipo': tipo.name,
      'prioridade': prioridade.name,
      'titulo': titulo,
      'mensagem': mensagem,
      'rota': rota,
      'metadata': metadata,
      'lida': lida,
      'created_at': createdAt.toIso8601String(),
      'lida_em': lidaEm?.toIso8601String(),
    };
  }

  Notificacao copyWith({
    int? id,
    String? usuario,
    int? gabinete,
    TipoNotificacao? tipo,
    PrioridadeNotificacao? prioridade,
    String? titulo,
    String? mensagem,
    String? rota,
    Map<String, dynamic>? metadata,
    bool? lida,
    DateTime? createdAt,
    DateTime? lidaEm,
  }) {
    return Notificacao(
      id: id ?? this.id,
      usuario: usuario ?? this.usuario,
      gabinete: gabinete ?? this.gabinete,
      tipo: tipo ?? this.tipo,
      prioridade: prioridade ?? this.prioridade,
      titulo: titulo ?? this.titulo,
      mensagem: mensagem ?? this.mensagem,
      rota: rota ?? this.rota,
      metadata: metadata ?? this.metadata,
      lida: lida ?? this.lida,
      createdAt: createdAt ?? this.createdAt,
      lidaEm: lidaEm ?? this.lidaEm,
    );
  }

  @override
  List<Object?> get props => [
        id,
        usuario,
        gabinete,
        tipo,
        prioridade,
        titulo,
        mensagem,
        rota,
        metadata,
        lida,
        createdAt,
        lidaEm,
      ];
}
