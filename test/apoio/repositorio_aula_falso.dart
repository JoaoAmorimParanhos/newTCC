import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/services/repositories/repositorio_aula.dart';

/// Repositório de aulas em memória: guarda o que a tela salvou ou excluiu,
/// sem acessar o Supabase.
class RepositorioAulaFalso implements RepositorioAula {
  RepositorioAulaFalso([List<Aula> iniciais = const []]) {
    aulas.addAll(iniciais);
  }

  final List<Aula> aulas = [];

  /// Quantas chamadas de [substituirTodas] ainda devem falhar. Como no
  /// banco (transação), a falha não muda nada.
  int falhasAoSubstituir = 0;

  var _proximoId = 1;

  Aula _comNovoId(Aula a) => Aula(
    id: 'nova-${_proximoId++}',
    idCurso: a.idCurso,
    indiceDia: a.indiceDia,
    indicePeriodo: a.indicePeriodo,
    idMateria: a.idMateria,
    idProfessor: a.idProfessor,
    idSala: a.idSala,
    grupo: a.grupo,
  );

  @override
  Stream<List<Aula>> observarTodos() => Stream.value(List.of(aulas));

  @override
  Future<List<Aula>> buscarTodos() async => List.of(aulas);

  @override
  Future<String> adicionar(Aula aula) async {
    final nova = _comNovoId(aula);
    aulas.add(nova);
    return nova.id;
  }

  @override
  Future<void> substituirTodas(List<Aula> novas) async {
    if (falhasAoSubstituir > 0) {
      falhasAoSubstituir--;
      throw Exception('falha simulada ao salvar');
    }
    aulas
      ..clear()
      ..addAll(novas.map(_comNovoId));
  }

  @override
  Future<void> atualizar(Aula aula) async {
    final i = aulas.indexWhere((a) => a.id == aula.id);
    if (i >= 0) {
      final atual = aulas[i];
      // Igual ao banco: atualizar não muda dia nem período.
      aulas[i] = Aula(
        id: atual.id,
        idCurso: atual.idCurso,
        indiceDia: atual.indiceDia,
        indicePeriodo: atual.indicePeriodo,
        idMateria: aula.idMateria,
        idProfessor: aula.idProfessor,
        idSala: aula.idSala,
        grupo: aula.grupo,
      );
    }
  }

  /// Ordem em que as aulas foram gravadas na última chamada de [moverAulas].
  final List<String> ordemDaUltimaMudanca = [];

  /// Se definido, a próxima chamada de [moverAulas] falha depois de gravar
  /// essa quantidade de aulas (simula queda de conexão no meio).
  int? falharMoverDepoisDe;

  @override
  Future<void> moverAulas(
    List<Aula> aulasNaPosicaoNova, {
    required int deslocamentoPeriodos,
  }) async {
    ordemDaUltimaMudanca.clear();
    for (final nova in RepositorioAula.ordemParaMover(
      aulasNaPosicaoNova,
      deslocamentoPeriodos,
    )) {
      if (falharMoverDepoisDe != null &&
          ordemDaUltimaMudanca.length >= falharMoverDepoisDe!) {
        falharMoverDepoisDe = null; // falha uma vez só
        throw Exception('falha simulada no meio do movimento');
      }
      // Mesma regra do banco: UNIQUE (id_curso, dia, período, grupo).
      final colide = aulas.any(
        (a) =>
            a.id != nova.id &&
            a.idCurso == nova.idCurso &&
            a.indiceDia == nova.indiceDia &&
            a.indicePeriodo == nova.indicePeriodo &&
            a.grupo == nova.grupo,
      );
      if (colide) {
        throw Exception(
          'duplicate key tb_aula_curso_dia_periodo_grupo_key (${nova.id})',
        );
      }
      final i = aulas.indexWhere((a) => a.id == nova.id);
      aulas[i] = nova;
      ordemDaUltimaMudanca.add(nova.id);
    }
  }

  @override
  Future<void> excluir(String id) async => aulas.removeWhere((a) => a.id == id);

  @override
  Future<void> excluirPorCurso(String idCurso) async =>
      aulas.removeWhere((a) => a.idCurso == idCurso);
}
