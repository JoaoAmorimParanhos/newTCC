import 'package:flutter_test_project/services/repositories/observar_tabela.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/model/sala/sala.dart';

class RepositorioTipoSala {
  RepositorioTipoSala({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_tipo_sala';

  Stream<List<TipoSala>> observarTodos() =>
      observarTabela(client: _client, tabela: _table, buscar: buscarTodos);

  Future<List<TipoSala>> buscarTodos() async {
    // Em ordem de criação: "Sala de aula" (o padrão) primeiro.
    final data = await _client
        .from(_table)
        .select()
        .order('id', ascending: true);
    return (data as List)
        .map((row) => TipoSala.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<TipoSala> adicionar(String nome) async {
    try {
      final row = await _client
          .from(_table)
          .insert({'nome': nome})
          .select()
          .single();
      return TipoSala.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const TipoSalaDuplicado();
      rethrow;
    }
  }
}
