import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/model/aula/aula.dart';

class RepositorioAula {
  RepositorioAula({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_aula';

  Stream<List<Aula>> observarTodos() {
    return _watchTable(fetch: buscarTodos);
  }

  Stream<List<Aula>> observarPorCurso(String idCurso) {
    return _watchTable(fetch: () => buscarPorCurso(idCurso));
  }

  Stream<List<Aula>> _watchTable({
    required Future<List<Aula>> Function() fetch,
  }) {
    final controller = StreamController<List<Aula>>();
    var closed = false;

    Future<void> emit() async {
      try {
        final data = await fetch();
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

  Future<List<Aula>> buscarTodos() async {
    final data = await _client.from(_table).select();
    return (data as List)
        .map((row) => Aula.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Aula>> buscarPorCurso(String idCurso) async {
    final data = await _client
        .from(_table)
        .select()
        .eq('id_curso', int.parse(idCurso));
    return (data as List)
        .map((row) => Aula.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<String> adicionar(Aula aula) async {
    final row = await _client
        .from(_table)
        .insert(aula.toInsertJson())
        .select('id')
        .single();
    return row['id'].toString();
  }

  /// Insere várias aulas em uma única requisição.
  Future<void> adicionarVarias(List<Aula> aulas) async {
    if (aulas.isEmpty) return;
    await _client
        .from(_table)
        .insert(aulas.map((aula) => aula.toInsertJson()).toList());
  }

  /// Ordem segura para gravar um conjunto deslocado: descendo, de baixo
  /// para cima; subindo, de cima para baixo.
  static List<Aula> ordemParaMover(List<Aula> aulas, int deslocamentoPeriodos) {
    final ordenadas = List<Aula>.from(aulas)
      ..sort((a, b) => a.indicePeriodo.compareTo(b.indicePeriodo));
    return deslocamentoPeriodos > 0 ? ordenadas.reversed.toList() : ordenadas;
  }

  Future<void> atualizar(Aula aula) async {
    await _client
        .from(_table)
        .update({
          'id_materia': int.parse(aula.idMateria),
          'id_professor': int.parse(aula.idProfessor),
          'id_sala': aula.idSala == null ? null : int.parse(aula.idSala!),
          'grupo': aula.grupo,
        })
        .eq('id', int.parse(aula.id));
  }

  /// Grava dia e período novos das aulas movidas juntas.
  ///
  /// O banco não deixa duas aulas no mesmo (curso, dia, período, grupo).
  /// Ao deslocar um conjunto no mesmo dia, atualiza primeiro a aula que vai
  /// para um lugar já livre; ver [ordemParaMover].
  Future<void> moverAulas(
    List<Aula> aulasNaPosicaoNova, {
    required int deslocamentoPeriodos,
  }) async {
    for (final aula in ordemParaMover(
      aulasNaPosicaoNova,
      deslocamentoPeriodos,
    )) {
      await _client
          .from(_table)
          .update({
            'dia_semana': aula.indiceDia + 1,
            'periodo': aula.indicePeriodo + 1,
          })
          .eq('id', int.parse(aula.id));
    }
  }

  Future<void> excluir(String id) async {
    await _client.from(_table).delete().eq('id', int.parse(id));
  }

  Future<void> excluirPorCurso(String idCurso) async {
    await _client
        .from(_table)
        .delete()
        .eq('id_curso', int.parse(idCurso));
  }

  Future<void> excluirPorProfessor(String idProfessor) async {
    await _client
        .from(_table)
        .delete()
        .eq('id_professor', int.parse(idProfessor));
  }

  Future<void> excluirPorMateria(String idMateria) async {
    await _client
        .from(_table)
        .delete()
        .eq('id_materia', int.parse(idMateria));
  }

  /// Remove aulas do curso cuja matéria não está mais na carga.
  Future<void> excluirOrfasDoCurso({
    required String idCurso,
    required Set<String> idsMateriasPermitidas,
  }) async {
    final aulas = await buscarPorCurso(idCurso);
    for (final aula in aulas) {
      if (!idsMateriasPermitidas.contains(aula.idMateria)) {
        await excluir(aula.id);
      }
    }
  }

  Future<void> limparIdSala(String idSala) async {
    await _client
        .from(_table)
        .update({'id_sala': null})
        .eq('id_sala', int.parse(idSala));
  }

  Future<void> excluirTodas() async {
    await _client.from(_table).delete().neq('id', 0);
  }
}
