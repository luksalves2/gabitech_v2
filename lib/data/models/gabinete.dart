import 'package:equatable/equatable.dart';

/// Gabinete model - represents the office/cabinet
class Gabinete extends Equatable {
  final int id;
  final String? usuario;
  final String? nome;
  final String? endereco;
  final String? telefone;
  final String? email;
  final String? logo;
  final List<String>? acessores;
  final String? instanceIdZapi;
  final String? token; // Token da instância UazAPI (campo 'token' na tabela)
  final String? tokenZapi;
  final String? clientTokenZapi;
  final int? prazoSolicitacoes; // Prazo padrão em dias para solicitações
  final DateTime? createdAt;

  const Gabinete({
    required this.id,
    this.usuario,
    this.nome,
    this.endereco,
    this.telefone,
    this.email,
    this.logo,
    this.acessores,
    this.instanceIdZapi,
    this.token,
    this.tokenZapi,
    this.clientTokenZapi,
    this.prazoSolicitacoes,
    this.createdAt,
  });

  factory Gabinete.fromJson(Map<String, dynamic> json) {
    // Handle id field which might come as String or int from database
    int idValue;
    if (json['id'] is int) {
      idValue = json['id'] as int;
    } else if (json['id'] is String) {
      idValue = int.parse(json['id'] as String);
    } else {
      throw Exception('Invalid id type in Gabinete.fromJson');
    }

    // Handle prazoSolicitacoes field which might come as String or int
    int? prazoSolicitacoesValue;
    if (json['prazo_solicitacoes'] != null) {
      if (json['prazo_solicitacoes'] is int) {
        prazoSolicitacoesValue = json['prazo_solicitacoes'] as int;
      } else if (json['prazo_solicitacoes'] is String) {
        prazoSolicitacoesValue = int.tryParse(json['prazo_solicitacoes'] as String);
      }
    }

    return Gabinete(
      id: idValue,
      usuario: json['usuario'] as String?,
      nome: json['nome'] as String?,
      endereco: json['endereco'] as String?,
      telefone: json['telefone'] as String?,
      email: json['email'] as String?,
      logo: json['logo'] as String?,
      acessores: (json['acessores'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      instanceIdZapi: json['instance_id_zapi'] as String?,
      token: json['token'] as String?,
      tokenZapi: json['token_zapi'] as String?,
      clientTokenZapi: json['client_token_zapi'] as String?,
      prazoSolicitacoes: prazoSolicitacoesValue,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario': usuario,
      'nome': nome,
      'endereco': endereco,
      'telefone': telefone,
      'email': email,
      'logo': logo,
      'acessores': acessores,
      'instance_id_zapi': instanceIdZapi,
      'token': token,
      'token_zapi': tokenZapi,
      'client_token_zapi': clientTokenZapi,
      'prazo_solicitacoes': prazoSolicitacoes,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        usuario,
        nome,
        endereco,
        telefone,
        email,
        logo,
        acessores,
        instanceIdZapi,
        token,
        tokenZapi,
        clientTokenZapi,
        prazoSolicitacoes,
        createdAt,
      ];
}
