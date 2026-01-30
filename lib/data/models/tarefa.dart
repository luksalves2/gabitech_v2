import 'package:equatable/equatable.dart';

/// Atividade model - represents a task/activity linked to a solicitacao
class Tarefa extends Equatable {
  final int id;
  final int? gabinete;
  final int? solicitacao;
  final String? titulo;
  final String? descricao;
  final String? status;
  final String? responsavel;
  final DateTime? createdAt;

  const Tarefa({
    required this.id,
    this.gabinete,
    this.solicitacao,
    this.titulo,
    this.descricao,
    this.status,
    this.responsavel,
    this.createdAt,
  });

  factory Tarefa.fromJson(Map<String, dynamic> json) {
    return Tarefa(
      id: json['id'] as int,
      gabinete: json['gabinete'] as int?,
      solicitacao: json['solicitacao'] as int?,
      titulo: json['titulo'] as String?,
      descricao: json['descricao'] as String?,
      status: json['status'] as String?,
      responsavel: json['responsavel'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gabinete': gabinete,
      'solicitacao': solicitacao,
      'titulo': titulo,
      'descricao': descricao,
      'status': status,
      'responsavel': responsavel,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Tarefa copyWith({
    int? id,
    int? gabinete,
    int? solicitacao,
    String? titulo,
    String? descricao,
    String? status,
    String? responsavel,
    DateTime? createdAt,
  }) {
    return Tarefa(
      id: id ?? this.id,
      gabinete: gabinete ?? this.gabinete,
      solicitacao: solicitacao ?? this.solicitacao,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      status: status ?? this.status,
      responsavel: responsavel ?? this.responsavel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        gabinete,
        solicitacao,
        titulo,
        descricao,
        status,
        responsavel,
        createdAt,
      ];
}

/// Status da tarefa
enum TarefaStatus {
  pendente('pendente', 'Pendente'),
  emAndamento('em_andamento', 'Em Andamento'),
  concluida('concluida', 'Concluída');

  final String value;
  final String label;

  const TarefaStatus(this.value, this.label);

  static TarefaStatus fromValue(String? value) {
    if (value == null) return TarefaStatus.pendente;
    return TarefaStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => TarefaStatus.pendente,
    );
  }
}
