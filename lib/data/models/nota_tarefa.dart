import 'package:equatable/equatable.dart';

/// Model for notes - linked to solicitacao
class Nota extends Equatable {
  final int id;
  final int? solicitacaoId;
  final String? titulo;
  final String? descricao;
  final String? nomeAutor;
  final String? autor;
  final DateTime createdAt;

  const Nota({
    required this.id,
    this.solicitacaoId,
    this.titulo,
    this.descricao,
    this.nomeAutor,
    this.autor,
    required this.createdAt,
  });

  factory Nota.fromJson(Map<String, dynamic> json) {
    return Nota(
      id: json['id'] as int,
      solicitacaoId: json['solicitacao'] as int?,
      titulo: json['titulo'] as String?,
      descricao: json['descricao'] as String?,
      nomeAutor: json['nome_autor'] as String?,
      autor: json['autor'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'solicitacao': solicitacaoId,
      'titulo': titulo,
      'descricao': descricao,
      'nome_autor': nomeAutor,
      'autor': autor,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, solicitacaoId, titulo, descricao, nomeAutor, autor, createdAt];
}
