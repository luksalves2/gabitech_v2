import '../datasources/supabase_datasource.dart';
import '../models/tarefa.dart';

/// Repository for Atividade (Tarefa) data
class TarefaRepository {
  final SupabaseDatasource _datasource;

  TarefaRepository(this._datasource);

  /// Get all atividades by solicitacao
  Future<List<Tarefa>> getBySolicitacao(int solicitacaoId) async {
    final data = await _datasource.select(
      table: 'tarefas',
      columns: '*',
      eq: {'solicitacao': solicitacaoId},
      orderBy: 'created_at',
      ascending: false,
    );
    return data.map((json) => Tarefa.fromJson(json)).toList();
  }

  /// Get all atividades by gabinete
  Future<List<Tarefa>> getByGabinete(int gabineteId) async {
    final data = await _datasource.select(
      table: 'tarefas',
      columns: '*',
      eq: {'gabinete': gabineteId},
      orderBy: 'created_at',
      ascending: false,
    );

    return data.map((json) => Tarefa.fromJson(json)).toList();
  }

  /// Create a new atividade
  Future<Tarefa?> create({
    required int gabineteId,
    required int solicitacaoId,
    required String titulo,
    String? descricao,
  }) async {
    final result = await _datasource.insert(
      table: 'tarefas',
      data: {
        'gabinete': gabineteId,
        'solicitacao': solicitacaoId,
        'titulo': titulo,
        if (descricao != null) 'descricao': descricao,
        'status': 'pendente',
      },
    );
    return Tarefa.fromJson(result);
  }

  /// Update atividade status
  Future<Tarefa?> updateStatus(int id, String status) async {
    final result = await _datasource.update(
      table: 'tarefas',
      data: {'status': status},
      eq: {'id': id},
      returnData: true,
    );

    if (result.isEmpty) return null;
    return Tarefa.fromJson(result.first);
  }

  /// Delete atividade
  Future<void> delete(int id) async {
    await _datasource.delete(
      table: 'tarefas',
      eq: {'id': id},
    );
  }
}
