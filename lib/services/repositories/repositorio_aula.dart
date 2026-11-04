import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/services/repositories/observar_tabela.dart';

class RepositorioAula {
  RepositorioAula({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_aula';

  Stream<List<Aula>> observarTodos() =>
      observarTabela(client: _client, tabela: _table, buscar: buscarTodos);

  Future<List<Aula>> buscarTodos() async {
    final data = await _client.from(_table).select();
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

  /// Troca a grade inteira (todas as turmas) por [aulas] numa transação só
  /// (função `substituir_aulas` no banco): se falhar, nada muda.
  Future<void> substituirTodas(List<Aula> aulas) async {
    await _client.rpc(
      'substituir_aulas',
      params: {'novas': aulas.map((aula) => aula.toInsertJson()).toList()},
    );
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
}
