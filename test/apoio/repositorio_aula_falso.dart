import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/services/repositories/repositorio_aula.dart';

/// Repositório de aulas em memória: guarda o que a tela salvou ou excluiu,
/// sem acessar o Supabase.
class RepositorioAulaFalso implements RepositorioAula {
  RepositorioAulaFalso([List<Aula> iniciais = const []]) {
    aulas.addAll(iniciais);
  }

  final List<Aula> aulas = [];

  /// Quantas chamadas de [adicionarVarias] ainda devem falhar.
  int falhasAoAdicionarVarias = 0;

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
  Stream<List<Aula>> observarPorCurso(String idCurso) =>
      Stream.value(aulas.where((a) => a.idCurso == idCurso).toList());

  @override
  Future<List<Aula>> buscarTodos() async => List.of(aulas);

  @override
  Future<List<Aula>> buscarPorCurso(String idCurso) async =>
      aulas.where((a) => a.idCurso == idCurso).toList();

  @override
  Future<String> adicionar(Aula aula) async {
    final nova = _comNovoId(aula);
    aulas.add(nova);
    return nova.id;
  }

  @override
  Future<void> adicionarVarias(List<Aula> novas) async {
    if (falhasAoAdicionarVarias > 0) {
      falhasAoAdicionarVarias--;
      throw Exception('falha simulada ao salvar');
    }
    aulas.addAll(novas.map(_comNovoId));
  }

  @override
  Future<void> atualizar(Aula aula) async {
    final i = aulas.indexWhere((a) => a.id == aula.id);
    if (i >= 0) aulas[i] = aula;
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

  @override
  Future<void> excluirPorProfessor(String idProfessor) async =>
      aulas.removeWhere((a) => a.idProfessor == idProfessor);

  @override
  Future<void> excluirPorMateria(String idMateria) async =>
      aulas.removeWhere((a) => a.idMateria == idMateria);

  @override
  Future<void> excluirOrfasDoCurso({
    required String idCurso,
    required Set<String> idsMateriasPermitidas,
  }) async => aulas.removeWhere(
    (a) => a.idCurso == idCurso && !idsMateriasPermitidas.contains(a.idMateria),
  );

  @override
  Future<void> limparIdSala(String idSala) async {
    for (var i = 0; i < aulas.length; i++) {
      final a = aulas[i];
      if (a.idSala != idSala) continue;
      aulas[i] = Aula(
        id: a.id,
        idCurso: a.idCurso,
        indiceDia: a.indiceDia,
        indicePeriodo: a.indicePeriodo,
        idMateria: a.idMateria,
        idProfessor: a.idProfessor,
        grupo: a.grupo,
      );
    }
  }

  @override
  Future<void> excluirTodas() async => aulas.clear();
}
