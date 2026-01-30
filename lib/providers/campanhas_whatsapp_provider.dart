import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado das campanhas de WhatsApp (mock/local até integrar backend).
final campanhasWhatsappProvider =
    StateNotifierProvider<CampanhasWhatsappNotifier, List<Map<String, dynamic>>>(
  (ref) => CampanhasWhatsappNotifier(),
);

/// Métricas derivadas para cards.
final campanhasWhatsappMetricsProvider = Provider<CampanhasWhatsappMetrics>((ref) {
  final campanhas = ref.watch(campanhasWhatsappProvider);
  final total = campanhas.length;
  final agendadas =
      campanhas.where((c) => c['status'] == 'Agendada').length;
  final enviando =
      campanhas.where((c) => c['status'] == 'Enviando').length;
  final finalizadas =
      campanhas.where((c) => c['status'] == 'Enviado').length;
  final impactados =
      campanhas.fold<int>(0, (s, c) => s + (c['qtd'] as int? ?? 0));

  return CampanhasWhatsappMetrics(
    total: total,
    agendadas: agendadas,
    enviando: enviando,
    finalizadas: finalizadas,
    impactados: impactados,
  );
});

class CampanhasWhatsappMetrics {
  final int total;
  final int agendadas;
  final int enviando;
  final int finalizadas;
  final int impactados;

  const CampanhasWhatsappMetrics({
    required this.total,
    required this.agendadas,
    required this.enviando,
    required this.finalizadas,
    required this.impactados,
  });
}

class CampanhasWhatsappNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  CampanhasWhatsappNotifier()
      : super([
          {
            'id': 1,
            'titulo': 'teste transmissao',
            'mensagem': 'teste transmissao',
            'data': '05/01/2026',
            'hora': '11:48',
            'local': 'Jarivatuba',
            'status': 'Enviado',
            'qtd': 2,
          }
        ]);

  void addDraft() {
    state = [
      {
        'id': DateTime.now().millisecondsSinceEpoch,
        'titulo': 'Nova campanha',
        'mensagem': '—',
        'data': '-',
        'hora': '-',
        'local': '-',
        'status': 'Rascunho',
        'qtd': 0,
      },
      ...state,
    ];
  }

  void addTestCampaign({
    required String titulo,
    required String mensagem,
    required String data,
    required String hora,
    required String local,
    required int qtd,
    String status = 'Agendada',
  }) {
    state = [
      {
        'id': DateTime.now().millisecondsSinceEpoch,
        'titulo': titulo,
        'mensagem': mensagem,
        'data': data,
        'hora': hora,
        'local': local,
        'status': status,
        'qtd': qtd,
      },
      ...state,
    ];
  }
}
