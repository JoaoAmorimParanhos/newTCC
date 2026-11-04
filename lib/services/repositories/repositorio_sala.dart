import 'package:flutter_test_project/services/repositories/observar_tabela.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/model/sala/sala.dart';

class RepositorioSala {
  RepositorioSala({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_sala';

  Stream<List<Sala>> observarTodos() =>
      observarTabela(client: _client, tabela: _table, buscar: buscarTodos);

  Future<List<Sala>> buscarTodos() async {
    final data = await _client
        .from(_table)
        .select('*, tipo:tb_tipo_sala(id, nome)')
        .order('id', ascending: true);
    return (data as List)
        .map((row) => Sala.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<String> adicionar(int numero, TipoSala tipo) async {
    try {
      final row = await _client
          .from(_table)
          .insert({'numero': numero, 'id_tipo_sala': int.parse(tipo.id)})
          .select('id')
          .single();
      return row['id'].toString();
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const SalaDuplicada();
      rethrow;
    }
  }

  Future<void> atualizar(Sala room) async {
    try {
      await _client
          .from(_table)
          .update(room.toInsertJson())
          .eq('id', int.parse(room.id));
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const SalaDuplicada();
      rethrow;
    }
  }

  /// Aulas e cursos que usavam a sala ficam sem sala (o banco faz isso).
  Future<void> excluir(String id) async {
    await _client.from(_table).delete().eq('id', int.parse(id));
  }
}
