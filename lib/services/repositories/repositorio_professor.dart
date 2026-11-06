import 'package:flutter_test_project/services/repositories/observar_tabela.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/services/repositories/buscar_todas_linhas.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';

class RepositorioProfessor {
  RepositorioProfessor({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_professor';
  static const String _linkTable = 'tb_professor_materia';

  Stream<List<Professor>> observarTodos() =>
      observarTabela(client: _client, tabela: _table, buscar: buscarTodos);

  Stream<List<ProfessorMateria>> observarLigacoesMaterias() => observarTabela(
    client: _client,
    tabela: _linkTable,
    buscar: buscarTodasLigacoes,
  );

  Future<List<Professor>> buscarTodos() async {
    final data = await _client.from(_table).select().order('id', ascending: true);
    return (data as List)
        .map((row) => Professor.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProfessorMateria>> buscarTodasLigacoes() async {
    final data = await buscarTodasLinhas(
      _client,
      _linkTable,
      ordem: const ['id_professor', 'id_materia'],
    );
    return (data as List)
        .map(
          (row) => ProfessorMateria.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<String>> buscarIdsMaterias(String idProfessor) async {
    final data = await _client
        .from(_linkTable)
        .select('id_materia')
        .eq('id_professor', int.parse(idProfessor));
    return (data as List)
        .map((row) => (row as Map<String, dynamic>)['id_materia'].toString())
        .toList();
  }

  Future<String> adicionar(String nome, {List<String> idsMaterias = const []}) async {
    final row = await _client
        .from(_table)
        .insert({'nome': nome})
        .select('id')
        .single();
    final id = row['id'].toString();
    await definirMaterias(id, idsMaterias);
    return id;
  }

  Future<void> atualizar(
    Professor professor, {
    List<String>? idsMaterias,
  }) async {
    await _client
        .from(_table)
        .update({'nome': professor.nome})
        .eq('id', int.parse(professor.id));
    if (idsMaterias != null) {
      await definirMaterias(professor.id, idsMaterias);
    }
  }

  Future<void> definirMaterias(String idProfessor, List<String> idsMaterias) async {
    final parsedProfessorId = int.parse(idProfessor);
    await _client
        .from(_linkTable)
        .delete()
        .eq('id_professor', parsedProfessorId);

    if (idsMaterias.isEmpty) return;

    await _client.from(_linkTable).insert(
          idsMaterias
              .map(
                (idMateria) => {
                  'id_professor': parsedProfessorId,
                  'id_materia': int.parse(idMateria),
                },
              )
              .toList(),
        );
  }

  /// Aulas, vínculos e o resto ligado a ele saem junto (cascata no banco).
  Future<void> excluir(String id) async {
    await _client.from(_table).delete().eq('id', int.parse(id));
  }
}
