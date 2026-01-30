import 'dart:ui' show Color;
import 'package:equatable/equatable.dart';
import 'cidadao.dart';

/// Solicitação status enum - baseado na tabela solicitacoes campo 'status'
enum SolicitacaoStatus {
  todos('todos', 'Todos', Color(0xFF3B82F6)),
  emAnalise('em analise', 'Em Análise', Color(0xFF3B82F6)),
  emAndamento('em andamento', 'Em Andamento', Color(0xFF10B981)),
  aguardandoUsuario('aguardando usuario', 'Aguardando Usuário', Color(0xFFF59E0B)),
  finalizado('finalizado', 'Finalizados', Color(0xFF22C55E)),
  emAtraso('em atraso', 'Em Atraso', Color(0xFFEF4444)),
  programado('programado', 'Programado', Color(0xFF8B5CF6));

  final String value;
  final String label;
  final Color color;

  const SolicitacaoStatus(this.value, this.label, this.color);

  static SolicitacaoStatus fromValue(String? value) {
    if (value == null) return SolicitacaoStatus.todos;
    return SolicitacaoStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => SolicitacaoStatus.todos,
    );
  }
}

/// Prioridade enum
enum Prioridade {
  baixa('Baixa'),
  media('Média'),
  alta('Alta');

  final String label;

  const Prioridade(this.label);

  static Prioridade fromLabel(String? label) {
    if (label == null) return Prioridade.media;
    return Prioridade.values.firstWhere(
      (p) => p.label.toLowerCase() == label.toLowerCase(),
      orElse: () => Prioridade.media,
    );
  }
}

/// Solicitacao model - represents a service request
class Solicitacao extends Equatable {
  final int id;
  final int? gabinete;
  final int? cidadaoId;
  final String? titulo;
  final String? descricao;
  final String? resumo;
  final String? acessor;
  final String? prazo;
  final String? prioridade;
  final String? categoria;
  final String? status;
  final int? categoriaId;
  final String? nomeAcessor;
  final int? statusAtendimento;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final DateTime? createdAt;
  
  // Joined data - cidadão info (to avoid N+1)
  final Cidadao? cidadao;

  const Solicitacao({
    required this.id,
    this.gabinete,
    this.cidadaoId,
    this.titulo,
    this.descricao,
    this.resumo,
    this.acessor,
    this.prazo,
    this.prioridade,
    this.categoria,
    this.status,
    this.categoriaId,
    this.nomeAcessor,
    this.statusAtendimento,
    this.dataInicio,
    this.dataFim,
    this.createdAt,
    this.cidadao,
  });

  SolicitacaoStatus get statusEnum => SolicitacaoStatus.fromValue(status);

  factory Solicitacao.fromJson(Map<String, dynamic> json) {
    // Handle cidadao join - can be null, empty map, or valid data
    // Supabase pode retornar como 'cidadaos' (nome do alias) ou como objeto direto
    Cidadao? cidadao;
    
    // Tenta primeiro com o alias 'cidadaos'
    var cidadaoData = json['cidadaos'];
    
    // Se não encontrou, tenta com o nome da tabela
    if (cidadaoData == null) {
      cidadaoData = json['cidadao_data'];
    }
    
    if (cidadaoData != null && 
        cidadaoData is Map<String, dynamic> && 
        cidadaoData.isNotEmpty && 
        cidadaoData['id'] != null) {
      cidadao = Cidadao.fromJson(cidadaoData);
    }

    return Solicitacao(
      id: json['id'] as int,
      gabinete: json['gabinete'] as int?,
      cidadaoId: json['cidadao'] as int?,
      titulo: json['titulo'] as String?,
      descricao: json['descricao'] as String?,
      resumo: json['resumo'] as String?,
      acessor: json['acessor'] as String?,
      prazo: json['prazo'] as String?,
      prioridade: json['prioridade'] as String?,
      categoria: json['categoria'] as String?,
      status: json['status'] as String?,
      categoriaId: json['categoria_id'] as int?,
      nomeAcessor: json['nome_acessor'] as String?,
      statusAtendimento: json['status_atendimento'] as int?,
      dataInicio: json['data_inicio_atendimento'] != null
          ? DateTime.tryParse(json['data_inicio_atendimento'] as String)
          : null,
      dataFim: json['data_fim_atendimento'] != null
          ? DateTime.tryParse(json['data_fim_atendimento'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      cidadao: cidadao,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gabinete': gabinete,
      'cidadao': cidadaoId,
      'titulo': titulo,
      'descricao': descricao,
      'resumo': resumo,
      'acessor': acessor,
      'prazo': prazo,
      'prioridade': prioridade,
      'categoria': categoria,
      'status': status,
      'categoria_id': categoriaId,
      'nome_acessor': nomeAcessor,
      'status_atendimento': statusAtendimento,
      'data_inicio_atendimento': dataInicio?.toIso8601String(),
      'data_fim_atendimento': dataFim?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Solicitacao copyWith({
    int? id,
    int? gabinete,
    int? cidadaoId,
    String? titulo,
    String? descricao,
    String? resumo,
    String? acessor,
    String? prazo,
    String? prioridade,
    String? categoria,
    String? status,
    int? categoriaId,
    String? nomeAcessor,
    int? statusAtendimento,
    DateTime? dataInicio,
    DateTime? dataFim,
    DateTime? createdAt,
    Cidadao? cidadao,
  }) {
    return Solicitacao(
      id: id ?? this.id,
      gabinete: gabinete ?? this.gabinete,
      cidadaoId: cidadaoId ?? this.cidadaoId,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      resumo: resumo ?? this.resumo,
      acessor: acessor ?? this.acessor,
      prazo: prazo ?? this.prazo,
      prioridade: prioridade ?? this.prioridade,
      categoria: categoria ?? this.categoria,
      status: status ?? this.status,
      categoriaId: categoriaId ?? this.categoriaId,
      nomeAcessor: nomeAcessor ?? this.nomeAcessor,
      statusAtendimento: statusAtendimento ?? this.statusAtendimento,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      createdAt: createdAt ?? this.createdAt,
      cidadao: cidadao ?? this.cidadao,
    );
  }

  @override
  List<Object?> get props => [
        id,
        gabinete,
        cidadaoId,
        titulo,
        descricao,
        resumo,
        acessor,
        prazo,
        prioridade,
        categoria,
        status,
        categoriaId,
        nomeAcessor,
        statusAtendimento,
        dataInicio,
        dataFim,
        createdAt,
      ];
}
