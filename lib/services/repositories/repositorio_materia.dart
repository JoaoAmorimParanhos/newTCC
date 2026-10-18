import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/model/materia/materia.dart';

class RepositorioMateria {
  RepositorioMateria({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_materia';
  static const String _linkTable = 'tb_professor_materia';

  Stream<List<Materia>> observarTodos() {
    final controller = StreamController<List<Materia>>();
    var closed = false;

    Future<void> emit() async {
      try {
        final data = await buscarTodos();
        if (!closed && !controller.isClosed) {
          controller.add(data);
        }
      } catch (error, stackTrace) {
        if (!closed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    final channel = _client
        .channel('watch:$_table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (_) => unawaited(emit()),
        )
        .subscribe();

    unawaited(emit());

    controller.onCancel = () async {
      closed = true;
      await _client.removeChannel(channel);
      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  Future<List<Materia>> buscarTodos() async {
    final data = await _client.from(_table).select().order('nome');
    return (data as List)
        .map((row) => Materia.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<String> adicionar(
    String nome, {
    List<String> idsProfessores = const [],
  }) async {
    final row = await _client
        .from(_table)
        .insert({'nome': nome})
        .select('id')
        .single();
    final id = row['id'].toString();
    await definirProfessores(id, idsProfessores);
    return id;
  }

  Future<void> atualizar(
    Materia subject, {
    List<String>? idsProfessores,
  }) async {
    await _client
        .from(_table)
        .update({'nome': subject.nome})
        .eq('id', int.parse(subject.id));
    if (idsProfessores != null) {
      await definirProfessores(subject.id, idsProfessores);
    }
  }

  Future<List<String>> buscarIdsProfessores(String idMateria) async {
    final data = await _client
        .from(_linkTable)
        .select('id_professor')
        .eq('id_materia', int.parse(idMateria));
    return (data as List)
        .map((row) => (row as Map<String, dynamic>)['id_professor'].toString())
        .toList();
  }

  /// Substitui os professores vinculados à matéria (mesma tabela que o
  /// formulário de professor usa, vista pelo outro lado).
  Future<void> definirProfessores(
    String idMateria,
    List<String> idsProfessores,
  ) async {
    final parsedSubjectId = int.parse(idMateria);
    await _client.from(_linkTable).delete().eq('id_materia', parsedSubjectId);

    if (idsProfessores.isEmpty) return;

    await _client
        .from(_linkTable)
        .insert(
          idsProfessores
              .map(
                (idProfessor) => {
                  'id_professor': int.parse(idProfessor),
                  'id_materia': parsedSubjectId,
                },
              )
              .toList(),
        );
  }

  Future<void> excluir(String id) async {
    final parsedId = int.parse(id);
    await _client.from('tb_aula').delete().eq('id_materia', parsedId);
    await _client.from('tb_curso_materia').delete().eq('id_materia', parsedId);
    await _client.from(_linkTable).delete().eq('id_materia', parsedId);
    await _client.from(_table).delete().eq('id', parsedId);
  }
}
