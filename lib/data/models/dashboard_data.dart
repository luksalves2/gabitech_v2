import 'package:equatable/equatable.dart';

/// Dashboard KPIs model
class DashboardData extends Equatable {
  // KPIs principais
  final int novasSolicitacoes;
  final int conversasFinalizadas;
  final int emAtendimento;
  final int cidadaosCadastrados;
  final int solicitacoesAtrasadas;
  final int solicitacoesSemanais;

  // Dados legados (mantidos para compatibilidade)
  final int emAndamento;
  final int concluidos;
  final int emAtraso;
  final int totalCidadaos;
  final int solicitacoesMesAtual;
  final int solicitacoesSemanaAtual;
  final int solicitacoesFinalizadasSemana;
  final int solicitacoesEmAndamentoSemana;
  final int solicitacoesIniciadasSemana;

  // Dados do gráfico semanal
  final List<ChartDataPoint> chartData;

  // Aniversariantes da semana
  final List<Aniversariante> aniversariantes;

  // Mini-listas do dashboard
  final List<SolicitacaoResumo> listaAtrasadas;
  final List<ConversaAguardando> listaConversasAguardando;

  const DashboardData({
    this.novasSolicitacoes = 0,
    this.conversasFinalizadas = 0,
    this.emAtendimento = 0,
    this.cidadaosCadastrados = 0,
    this.solicitacoesAtrasadas = 0,
    this.solicitacoesSemanais = 0,
    this.emAndamento = 0,
    this.concluidos = 0,
    this.emAtraso = 0,
    this.totalCidadaos = 0,
    this.solicitacoesMesAtual = 0,
    this.solicitacoesSemanaAtual = 0,
    this.solicitacoesFinalizadasSemana = 0,
    this.solicitacoesEmAndamentoSemana = 0,
    this.solicitacoesIniciadasSemana = 0,
    this.chartData = const [],
    this.aniversariantes = const [],
    this.listaAtrasadas = const [],
    this.listaConversasAguardando = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      novasSolicitacoes: json['novas_solicitacoes'] as int? ?? 0,
      conversasFinalizadas: json['conversas_finalizadas'] as int? ?? 0,
      emAtendimento: json['em_atendimento'] as int? ?? 0,
      cidadaosCadastrados: json['cidadaos_cadastrados'] as int? ?? 0,
      solicitacoesAtrasadas: json['solicitacoes_atrasadas'] as int? ?? 0,
      solicitacoesSemanais: json['solicitacoes_semanais'] as int? ?? 0,
      emAndamento: json['em_andamento'] as int? ?? 0,
      concluidos: json['concluidos'] as int? ?? 0,
      emAtraso: json['em_atraso'] as int? ?? 0,
      totalCidadaos: json['total_cidadaos'] as int? ?? 0,
      solicitacoesMesAtual: json['solicitacoes_mes_atual'] as int? ?? 0,
      solicitacoesSemanaAtual: json['solicitacoes_semana_atual'] as int? ?? 0,
      solicitacoesFinalizadasSemana:
          json['solicitacoes_finalizadas_semana'] as int? ?? 0,
      solicitacoesEmAndamentoSemana:
          json['solicitacoes_em_andamento_semana'] as int? ?? 0,
      solicitacoesIniciadasSemana:
          json['solicitacoes_iniciadas_semana'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        novasSolicitacoes,
        conversasFinalizadas,
        emAtendimento,
        cidadaosCadastrados,
        solicitacoesAtrasadas,
        solicitacoesSemanais,
        emAndamento,
        concluidos,
        emAtraso,
        totalCidadaos,
        solicitacoesMesAtual,
        solicitacoesSemanaAtual,
        solicitacoesFinalizadasSemana,
        solicitacoesEmAndamentoSemana,
        solicitacoesIniciadasSemana,
        chartData,
        aniversariantes,
        listaAtrasadas,
        listaConversasAguardando,
      ];
}

class ChartDataPoint extends Equatable {
  final String label;
  final double value;
  final DateTime date;

  const ChartDataPoint({
    required this.label,
    required this.value,
    required this.date,
  });

  @override
  List<Object?> get props => [label, value, date];
}

class Aniversariante extends Equatable {
  final int id;
  final String nome;
  final DateTime dataNascimento;
  final String? telefone;
  final String? foto;

  const Aniversariante({
    required this.id,
    required this.nome,
    required this.dataNascimento,
    this.telefone,
    this.foto,
  });

  factory Aniversariante.fromJson(Map<String, dynamic> json) {
    return Aniversariante(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      dataNascimento: DateTime.parse(json['data_nascimento'] as String),
      telefone: json['telefone'] as String?,
      foto: json['foto'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, nome, dataNascimento, telefone, foto];
}

/// Resumo de solicitação para mini-lista (atrasadas / prioridade alta)
class SolicitacaoResumo extends Equatable {
  final int id;
  final String titulo;
  final String? cidadaoNome;
  final String? prioridade;
  final String? prazo;
  final String? status;
  final DateTime? createdAt;

  const SolicitacaoResumo({
    required this.id,
    required this.titulo,
    this.cidadaoNome,
    this.prioridade,
    this.prazo,
    this.status,
    this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, titulo, cidadaoNome, prioridade, prazo, status, createdAt];
}

/// Conversa aguardando resposta para mini-lista
class ConversaAguardando extends Equatable {
  final int id;
  final String? cidadaoNome;
  final String? telefone;
  final String? ultimaMensagem;
  final DateTime? ultimaMensagemEm;
  final int unreadCount;
  final String? foto;

  const ConversaAguardando({
    required this.id,
    this.cidadaoNome,
    this.telefone,
    this.ultimaMensagem,
    this.ultimaMensagemEm,
    this.unreadCount = 0,
    this.foto,
  });

  @override
  List<Object?> get props =>
      [id, cidadaoNome, telefone, ultimaMensagem, ultimaMensagemEm, unreadCount, foto];
}
