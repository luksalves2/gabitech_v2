import '../datasources/supabase_datasource.dart';
import '../models/categoria_tarefa.dart';

/// Repository for CategoriaTarefa data (from categorias_tarefas table)
class CategoriaRepository {
  final SupabaseDatasource _datasource;

  CategoriaRepository(this._datasource);

  /// Get all categorias for a gabinete
  Future<List<CategoriaTarefa>> getByGabinete(int gabineteId) async {
    final data = await _datasource.select(
      table: 'categorias_tarefas',
      columns: '*',
      eq: {'gabinete': gabineteId},
      orderBy: 'nome',
      ascending: true,
    );

    return data.map((json) => CategoriaTarefa.fromJson(json)).toList();
  }

  /// Get categoria by ID
  Future<CategoriaTarefa?> getById(int id, {int? gabineteId}) async {
    final eq = <String, dynamic>{'id': id};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }
    
    final data = await _datasource.selectSingle(
      table: 'categorias_tarefas',
      eq: eq,
    );

    if (data == null) return null;
    return CategoriaTarefa.fromJson(data);
  }

  /// Create a new categoria
  Future<CategoriaTarefa> create({
    required int gabineteId,
    required String nome,
    String? cor,
  }) async {
    final result = await _datasource.insert(
      table: 'categorias_tarefas',
      data: {
        'gabinete': gabineteId,
        'nome': nome,
        if (cor != null) 'cor': cor,
      },
    );

    return CategoriaTarefa.fromJson(result);
  }

  /// Update categoria name and/or color
  Future<CategoriaTarefa?> update(int id, String nome, {String? cor, int? gabineteId}) async {
    final eq = <String, dynamic>{'id': id};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }

    final result = await _datasource.update(
      table: 'categorias_tarefas',
      data: {
        'nome': nome,
        if (cor != null) 'cor': cor,
      },
      eq: eq,
      returnData: true,
    );

    if (result.isEmpty) return null;
    return CategoriaTarefa.fromJson(result.first);
  }

  /// Delete categoria
  Future<void> delete(int id, {int? gabineteId}) async {
    final eq = <String, dynamic>{'id': id};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }
    
    await _datasource.delete(
      table: 'categorias_tarefas',
      eq: eq,
    );
  }
}
