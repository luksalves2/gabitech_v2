import 'package:equatable/equatable.dart';

/// Model for task/solicitation categories from categorias_tarefas table
class CategoriaTarefa extends Equatable {
  final int id;
  final String nome;
  final String? cor;
  final int gabineteId;
  final DateTime? createdAt;

  const CategoriaTarefa({
    required this.id,
    required this.nome,
    this.cor,
    required this.gabineteId,
    this.createdAt,
  });

  factory CategoriaTarefa.fromJson(Map<String, dynamic> json) {
    return CategoriaTarefa(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      cor: json['cor'] as String?,
      gabineteId: json['gabinete'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'cor': cor,
      'gabinete': gabineteId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, nome, cor, gabineteId, createdAt];
}
