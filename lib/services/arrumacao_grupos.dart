import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/services/repositories/repositorio_aula.dart';
import 'package:flutter_test_project/services/repositories/repositorio_curso.dart';

// Regras para os grupos continuarem coerentes quando um par de aula
// geminada deixa de existir ou perde aulas por exclusão:
//
// * Aula sozinha no grupo 2 (G1 livre) cuja matéria não está mais em nenhum
//   par da turma vira aula completa (grupo 1).
// * Excluir o grupo 2 de um par que ainda existe deixa o grupo 1 sozinho:
//   ele passa para o grupo 2 e o G1 fica livre (igual a excluir na grade).
// * Duas aulas juntas que não formam mais par ficam como estão; o validador
//   avisa ("Par não geminado") e a pessoa decide qual apagar.

Aula _comGrupo(Aula a, int grupo) => Aula(
  id: a.id,
  idCurso: a.idCurso,
  indiceDia: a.indiceDia,
  indicePeriodo: a.indicePeriodo,
  idMateria: a.idMateria,
  idProfessor: a.idProfessor,
  idSala: a.idSala,
  grupo: grupo,
);

Map<(String, CelulaGrade), List<Aula>> _porCursoECelula(List<Aula> aulas) {
  final mapa = <(String, CelulaGrade), List<Aula>>{};
  for (final a in aulas) {
    mapa.putIfAbsent((a.idCurso, a.celula), () => []).add(a);
  }
  return mapa;
}

bool _materiaEmPar(
  String idCurso,
  String idMateria,
  List<AulaGeminadaCurso> pares,
) => pares.any((p) => p.idCurso == idCurso && p.contemMateria(idMateria));

/// Aulas sozinhas no grupo 2 sem par na turma, já com grupo 1.
List<Aula> aulasQueViramCompletas(
  List<Aula> aulas,
  List<AulaGeminadaCurso> pares,
) {
  return [
    for (final lista in _porCursoECelula(aulas).values)
      if (lista.length == 1 &&
          lista.single.grupo == 2 &&
          !_materiaEmPar(lista.single.idCurso, lista.single.idMateria, pares))
        _comGrupo(lista.single, 1),
  ];
}

/// Depois de excluir [excluidas]: aulas de grupo 1 que ficam sozinhas numa
/// célula onde havia um par (ainda cadastrado), já com grupo 2.
List<Aula> aulasQueVaoParaGrupo2({
  required List<Aula> excluidas,
  required List<Aula> todasAulas,
  required List<AulaGeminadaCurso> pares,
}) {
  final idsExcluidas = {for (final a in excluidas) a.id};
  final resultado = <Aula>[];
  for (final lista in _porCursoECelula(todasAulas).values) {
    if (lista.length != 2) continue;
    final restantes = lista.where((a) => !idsExcluidas.contains(a.id));
    if (restantes.length != 1) continue;
    final sobra = restantes.single;
    if (sobra.grupo != 1) continue;
    if (!_materiaEmPar(sobra.idCurso, sobra.idMateria, pares)) continue;
    resultado.add(_comGrupo(sobra, 2));
  }
  return resultado;
}

/// Lê aulas e pares do banco e transforma em aula completa toda aula de
/// grupo 2 que ficou sem par. Usar depois de excluir matéria ou de mudar
/// os pares de um curso.
Future<void> arrumarGruposSemPar({
  required RepositorioAula repoAula,
  required RepositorioCurso repoCurso,
}) async {
  final aulas = await repoAula.buscarTodos();
  final pares = await repoCurso.buscarTodasAulasGeminadas();
  for (final aula in aulasQueViramCompletas(aulas, pares)) {
    await repoAula.atualizar(aula);
  }
}
