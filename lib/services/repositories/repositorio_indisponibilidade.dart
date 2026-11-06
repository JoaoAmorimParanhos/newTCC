import 'package:flutter_test_project/services/repositories/observar_tabela.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/services/repositories/buscar_todas_linhas.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';

class RepositorioIndisponibilidade {
  RepositorioIndisponibilidade({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_professor_indisponibilidade';

  Stream<List<IndisponibilidadeProfessor>> observarTodos() =>
      observarTabela(client: _client, tabela: _table, buscar: buscarTodos);

  Future<List<IndisponibilidadeProfessor>> buscarTodos() async {
    final data = await buscarTodasLinhas(_client, _table, ordem: const ['id']);
    return (data as List)
        .map(
          (row) => IndisponibilidadeProfessor.fromJson(
            row as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> adicionar({
    required String idProfessor,
    required CelulaGrade celula,
  }) async {
    await _client.from(_table).insert({
      'id_professor': int.parse(idProfessor),
      'dia_semana': celula.indiceDia + 1,
      'periodo': celula.indicePeriodo + 1,
    });
  }

  Future<void> excluirPorProfessorCelula({
    required String idProfessor,
    required CelulaGrade celula,
  }) async {
    await _client
        .from(_table)
        .delete()
        .eq('id_professor', int.parse(idProfessor))
        .eq('dia_semana', celula.indiceDia + 1)
        .eq('periodo', celula.indicePeriodo + 1);
  }
}
