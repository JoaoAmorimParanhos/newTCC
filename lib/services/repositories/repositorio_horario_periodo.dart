import 'package:flutter_test_project/services/repositories/observar_tabela.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/model/horario/horario_periodo.dart';

class RepositorioHorarioPeriodo {
  RepositorioHorarioPeriodo({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_horario_periodo';

  Stream<List<HorarioPeriodo>> observarTodos() =>
      observarTabela(client: _client, tabela: _table, buscar: buscarTodos);

  Future<List<HorarioPeriodo>> buscarTodos() async {
    final data = await _client.from(_table).select();
    return (data as List)
        .map((row) => HorarioPeriodo.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Grava o texto do período (cria a linha se ainda não existir).
  Future<void> salvar(HorarioPeriodo horario) async {
    await _client.from(_table).upsert(horario.toJson(), onConflict: 'periodo');
  }
}
