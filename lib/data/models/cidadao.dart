import 'package:equatable/equatable.dart';

/// Cidadao model - represents a citizen
class Cidadao extends Equatable {
  final int id;
  final int? gabinete;
  final String? nome;
  final String? email;
  final String? telefone;
  final String? dataNascimento;
  final String? endereco;
  final String? foto;
  final String? perfil;
  final int? acessor;
  final String? status;
  final String? genero;
  final String? bairro;
  final String? cep;
  final String? rua;
  final String? cidade;
  final String? estado;
  final String? complemento;
  final String? pontoReferencia;
  final String? latitude;
  final String? longitude;
  final String? numeroResidencia;
  final DateTime? createdAt;

  const Cidadao({
    required this.id,
    this.gabinete,
    this.nome,
    this.email,
    this.telefone,
    this.dataNascimento,
    this.endereco,
    this.foto,
    this.perfil,
    this.acessor,
    this.status,
    this.genero,
    this.bairro,
    this.cep,
    this.rua,
    this.cidade,
    this.estado,
    this.complemento,
    this.pontoReferencia,
    this.latitude,
    this.longitude,
    this.numeroResidencia,
    this.createdAt,
  });

  factory Cidadao.fromJson(Map<String, dynamic> json) {
    return Cidadao(
      id: json['id'] as int,
      gabinete: json['gabinete'] as int?,
      nome: json['nome'] as String?,
      email: json['email'] as String?,
      telefone: json['telefone'] as String?,
      dataNascimento: json['data_nascimento'] as String?,
      endereco: json['endereco'] as String?,
      foto: json['foto'] as String?,
      perfil: json['perfil'] as String?,
      acessor: json['acessor'] as int?,
      status: json['status'] as String?,
      genero: json['genero'] as String?,
      bairro: json['bairro'] as String?,
      cep: json['cep'] as String?,
      rua: json['rua'] as String?,
      cidade: json['cidade'] as String?,
      estado: json['estado'] as String?,
      complemento: json['complemento'] as String?,
      pontoReferencia: json['ponto_referencia'] as String?,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      numeroResidencia: json['numero_residencia'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gabinete': gabinete,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'data_nascimento': dataNascimento,
      'endereco': endereco,
      'foto': foto,
      'perfil': perfil,
      'acessor': acessor,
      'status': status,
      'genero': genero,
      'bairro': bairro,
      'cep': cep,
      'rua': rua,
      'cidade': cidade,
      'estado': estado,
      'complemento': complemento,
      'ponto_referencia': pontoReferencia,
      'latitude': latitude,
      'longitude': longitude,
      'numero_residencia': numeroResidencia,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get enderecoCompleto {
    final parts = <String>[];
    if (rua != null && rua!.isNotEmpty) parts.add(rua!);
    if (numeroResidencia != null && numeroResidencia!.isNotEmpty) {
      parts.add(numeroResidencia!);
    }
    if (bairro != null && bairro!.isNotEmpty) parts.add(bairro!);
    if (cidade != null && cidade!.isNotEmpty) parts.add(cidade!);
    if (estado != null && estado!.isNotEmpty) parts.add(estado!);
    return parts.join(', ');
  }

  @override
  List<Object?> get props => [
        id,
        gabinete,
        nome,
        email,
        telefone,
        dataNascimento,
        endereco,
        foto,
        perfil,
        acessor,
        status,
        genero,
        bairro,
        cep,
        rua,
        cidade,
        estado,
        complemento,
        pontoReferencia,
        latitude,
        longitude,
        numeroResidencia,
        createdAt,
      ];
}
