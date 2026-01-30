import 'package:equatable/equatable.dart';

/// Usuario model - represents the logged user and assessors
class Usuario extends Equatable {
  final String uuid;
  final String? nome;
  final String? email;
  final String? avatar;
  final String? telefone;
  final int? gabinete;
  final String? cargo;
  final String? tipo;
  final bool? status;
  final bool? dashboard;
  final bool? solicitacoes;
  final bool? cidadaos;
  final bool? atividades;
  final bool? transmissoes;
  final bool? atendimento;
  final bool? acessores;
  final DateTime? createdAt;

  const Usuario({
    required this.uuid,
    this.nome,
    this.email,
    this.avatar,
    this.telefone,
    this.gabinete,
    this.cargo,
    this.tipo,
    this.status,
    this.dashboard,
    this.solicitacoes,
    this.cidadaos,
    this.atividades,
    this.transmissoes,
    this.atendimento,
    this.acessores,
    this.createdAt,
  });

  /// Considera o usuário ativo quando a flag 'status' é true; fallback para tipo.
  bool get isAtivo => status ?? (tipo != 'revogado');

  factory Usuario.fromJson(Map<String, dynamic> json) {
    // Handle gabinete field which might come as String or int from database
    int? gabineteValue;
    if (json['gabinete'] != null) {
      if (json['gabinete'] is int) {
        gabineteValue = json['gabinete'] as int;
      } else if (json['gabinete'] is String) {
        gabineteValue = int.tryParse(json['gabinete'] as String);
      }
    }

    return Usuario(
      uuid: json['uuid'] as String,
      nome: json['nome'] as String?,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
      telefone: json['telefone'] as String?,
      gabinete: gabineteValue,
      cargo: json['cargo'] as String?,
      tipo: json['tipo'] as String?,
      status: json['status'] as bool?,
      dashboard: json['dashboard'] as bool?,
      solicitacoes: json['solicitacoes'] as bool?,
      cidadaos: json['cidadaos'] as bool?,
      atividades: json['atividades'] as bool?,
      transmissoes:
          (json['transmissoes'] as bool?) ?? (json['transmissao'] as bool?),
      atendimento:
          (json['atendimento'] as bool?) ?? (json['mensagens'] as bool?),
      acessores: json['acessores'] as bool?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'nome': nome,
      'email': email,
      'avatar': avatar,
      'telefone': telefone,
      'gabinete': gabinete,
      'cargo': cargo,
      'tipo': tipo,
      'status': status,
      'dashboard': dashboard,
      'solicitacoes': solicitacoes,
      'cidadaos': cidadaos,
      'atividades': atividades,
      'transmissao': transmissoes,
      'atendimento': atendimento,
      'acessores': acessores,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Usuario copyWith({
    String? uuid,
    String? nome,
    String? email,
    String? avatar,
    String? telefone,
    int? gabinete,
    String? cargo,
    String? tipo,
    bool? status,
    bool? dashboard,
    bool? solicitacoes,
    bool? cidadaos,
    bool? atividades,
    bool? transmissoes,
    bool? atendimento,
    bool? acessores,
    DateTime? createdAt,
  }) {
    return Usuario(
      uuid: uuid ?? this.uuid,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      telefone: telefone ?? this.telefone,
      gabinete: gabinete ?? this.gabinete,
      cargo: cargo ?? this.cargo,
      tipo: tipo ?? this.tipo,
      status: status ?? this.status,
      dashboard: dashboard ?? this.dashboard,
      solicitacoes: solicitacoes ?? this.solicitacoes,
      cidadaos: cidadaos ?? this.cidadaos,
      atividades: atividades ?? this.atividades,
      transmissoes: transmissoes ?? this.transmissoes,
      atendimento: atendimento ?? this.atendimento,
      acessores: acessores ?? this.acessores,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        uuid,
        nome,
        email,
        avatar,
        telefone,
        gabinete,
        cargo,
        tipo,
        status,
        dashboard,
        solicitacoes,
        cidadaos,
        atividades,
        transmissoes,
        atendimento,
        acessores,
        createdAt,
      ];
}
