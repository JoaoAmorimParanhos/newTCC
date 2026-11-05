import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/pages/page3/helpers/cadastro_da_grade.dart';
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

  /// Grava uma mudança na grade junto com o cadastro do curso (carga e
  /// pares de aula geminada), numa transação só (função
  /// `salvar_aula_e_cadastro` no banco): se falhar, nada muda.
  ///
  /// Exclui [excluir], grava [atualizar] (matéria, professor, sala, grupo),
  /// insere [inserir] e troca a carga e os pares pelo [cadastro]. Devolve o
  /// id da aula inserida.
  Future<String?> salvarComCadastro({
    required String idCurso,
    required CadastroCurso cadastro,
    Aula? inserir,
    List<Aula> atualizar = const [],
    List<String> excluir = const [],
  }) async {
    final id = await _client.rpc(
      'salvar_aula_e_cadastro',
      params: {
        'p_id_curso': int.parse(idCurso),
        'p_inserir': inserir?.toInsertJson(),
        'p_atualizar': [
          for (final a in atualizar)
            {'id': int.parse(a.id), ...a.toInsertJson()},
        ],
        'p_excluir': [for (final id in excluir) int.parse(id)],
        'p_cargas': [for (final c in cadastro.cargas) c.toInsertJson()],
        'p_pares': [
          for (final p in cadastro.pares) p.toInsertJson(idCursoOverride: idCurso),
        ],
      },
    );
    return id?.toString();
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
