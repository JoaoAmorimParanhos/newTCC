import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';

/// O que salvar a edição de um curso (Cadastros) faz com a grade (Página 3).
class ImpactoEdicaoCurso {
  const ImpactoEdicaoCurso({
    required this.aulasApagadas,
    required this.componentesRemovidos,
    required this.aulasForaDoTurno,
  });

  /// Aulas de componentes que saíram da carga: o banco apaga ao salvar.
  final int aulasApagadas;

  /// Nomes desses componentes, na ordem em que aparecem na grade.
  final List<String> componentesRemovidos;

  /// Aulas que ficam fora do turno novo (só quando o turno mudou).
  final int aulasForaDoTurno;

  bool get temAviso => aulasApagadas > 0 || aulasForaDoTurno > 0;

  /// Texto para a confirmação, ou null se não há nada a avisar.
  String? get mensagem {
    if (!temAviso) return null;
    final partes = <String>[];
    if (aulasApagadas > 0) {
      partes.add(
        '$aulasApagadas aula(s) de ${componentesRemovidos.join(', ')} '
        'serão apagadas da grade, porque esses componentes saíram da carga.',
      );
    }
    if (aulasForaDoTurno > 0) {
      partes.add(
        '$aulasForaDoTurno aula(s) ficam fora do novo turno. Elas continuam '
        'na grade; use "Gerar" em Horário para refazer o horário.',
      );
    }
    return partes.join('\n\n');
  }
}

ImpactoEdicaoCurso impactoEdicaoCurso({
  required String idCurso,
  required PreferenciaPeriodo turnoAntigo,
  required PreferenciaPeriodo turnoNovo,
  required List<CargaCursoMateria> cargasNovas,
  required List<Aula> aulas,
  required Map<String, String> nomesComponentes,
}) {
  final naCarga = {for (final c in cargasNovas) c.idMateria};
  final doCurso = aulas.where((a) => a.idCurso == idCurso).toList();

  final apagadas = doCurso.where((a) => !naCarga.contains(a.idMateria));
  final removidos = <String>[];
  for (final a in apagadas) {
    final nome = nomesComponentes[a.idMateria] ?? 'Componente';
    if (!removidos.contains(nome)) removidos.add(nome);
  }

  var foraDoTurno = 0;
  if (turnoNovo != turnoAntigo) {
    final periodos = {for (final t in turnoNovo.turnos) ...t};
    foraDoTurno = doCurso
        .where(
          (a) =>
              naCarga.contains(a.idMateria) &&
              !periodos.contains(a.indicePeriodo),
        )
        .length;
  }

  return ImpactoEdicaoCurso(
    aulasApagadas: apagadas.length,
    componentesRemovidos: removidos,
    aulasForaDoTurno: foraDoTurno,
  );
}
