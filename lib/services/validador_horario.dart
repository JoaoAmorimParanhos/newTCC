import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';

class ValidacaoHorario {
  const ValidacaoHorario({required this.problemas});

  final List<String> problemas;

  bool get ok => problemas.isEmpty;
}

/// Valida o horário de uma turma e conflitos globais que a envolvem.
class ValidadorHorario {
  const ValidadorHorario();

  ValidacaoHorario validarCurso({
    required String idCurso,
    required List<Aula> todasAulas,
    required List<Curso> cursos,
    required List<CargaCursoMateria> cargas,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<Professor> professores,
    required List<Materia> materias,
    required List<Sala> salas,
    required List<IndisponibilidadeProfessor> indisponibilidades,
  }) {
    final problemas = <String>[];
    final course = cursos.where((c) => c.id == idCurso).firstOrNull;
    if (course == null) return const ValidacaoHorario(problemas: []);

    final courseById = {for (final c in cursos) c.id: c};
    final professorById = {for (final p in professores) p.id: p.nome};
    final subjectById = {for (final s in materias) s.id: s.nome};
    final roomById = {for (final r in salas) r.id: r};

    final courseAulas = todasAulas.where((a) => a.idCurso == idCurso).toList();

    for (final load in cargas.where((l) => l.idCurso == idCurso)) {
      final nomeMateria = subjectById[load.idMateria] ?? 'Matéria';
      final scheduled = courseAulas
          .where((a) => a.idMateria == load.idMateria)
          .length;
      if (scheduled > load.quantidadeAulas) {
        problemas.add('Aulas de $nomeMateria demais');
      } else if (scheduled < load.quantidadeAulas) {
        final missing = load.quantidadeAulas - scheduled;
        problemas.add(
          'Faltam $missing aula(s) de $nomeMateria '
          '($scheduled/${load.quantidadeAulas})',
        );
      }
    }

    final limiteGrupos = maxGruposDoCurso(course, aulasGeminadas);
    final porCelula = aulasPorCelulaDoCurso(courseAulas, idCurso);
    for (final entry in porCelula.entries) {
      if (entry.value.length > limiteGrupos) {
        problemas.add(
          entry.value.length > 1 && limiteGrupos == 1
              ? '2 grupos em ${_rotuloCelula(entry.key)} sem aula geminada'
              : 'Mais de $limiteGrupos grupos em ${_rotuloCelula(entry.key)}',
        );
      }
      if (entry.value.length == 2 &&
          !existeAulaGeminada(
            idCurso: idCurso,
            idMateriaA: entry.value.first.idMateria,
            idMateriaB: entry.value.last.idMateria,
            aulasGeminadas: aulasGeminadas,
          )) {
        problemas.add('Par não geminado em ${_rotuloCelula(entry.key)}');
      }
    }

    // Quantos horários cada par realmente ocupa junto vs. o configurado.
    for (final par in aulasGeminadas.where((p) => p.idCurso == idCurso)) {
      final juntas = porCelula.values
          .where(
            (lista) =>
                lista.length == 2 &&
                par.formaPar(lista.first.idMateria, lista.last.idMateria),
          )
          .length;
      final nomeA = subjectById[par.idMateriaA] ?? 'Matéria';
      final nomeB = subjectById[par.idMateriaB] ?? 'Matéria';
      if (juntas != par.juntas) {
        problemas.add(
          'Aula geminada $nomeA + $nomeB: '
          '$juntas/${par.juntas} aulas juntas',
        );
      }
      // Horários com a turma dividida e só a matéria maior (G1 livre).
      if (par.periodosSoMaior > 0) {
        final soMaior = porCelula.values
            .where(
              (lista) =>
                  turmaDivididaComGrupoLivre(lista) &&
                  lista.single.idMateria == par.idMateriaMaior,
            )
            .length;
        if (soMaior != par.periodosSoMaior) {
          final nomeMaior = subjectById[par.idMateriaMaior] ?? 'Matéria';
          problemas.add(
            'Aula geminada $nomeA + $nomeB: '
            '$soMaior/${par.periodosSoMaior} aulas só de $nomeMaior '
            '(grupo 1 livre)',
          );
        }
      }
    }

    for (final aula in courseAulas) {
      final celula = aula.celula;
      final nomeProfessor =
          professorById[aula.idProfessor] ?? 'Professor ${aula.idProfessor}';

      if (_estaIndisponivel(indisponibilidades, aula.idProfessor, celula)) {
        problemas.add(
          '$nomeProfessor no horário errado '
          '(${_rotuloCelula(celula)})',
        );
      }

      if (!_periodoCompativel(
        course.preferenciaPeriodo,
        celula.indicePeriodo,
      )) {
        problemas.add(
          'Aula fora do período da turma (${_rotuloCelula(celula)})',
        );
      }

      for (final other in todasAulas) {
        if (other.id == aula.id) continue;
        if (other.indiceDia != aula.indiceDia ||
            other.indicePeriodo != aula.indicePeriodo) {
          continue;
        }

        if (other.idProfessor == aula.idProfessor) {
          final otherCourse = courseById[other.idCurso]?.nome ?? 'outro curso';
          problemas.add(
            '$nomeProfessor já está dando aula'
            '${other.idCurso == aula.idCurso ? ' (outro grupo)' : ' no curso $otherCourse'} '
            '(${_rotuloCelula(celula)})',
          );
        }

        final idSala = aula.idSala;
        // Sala: só conflito com outra turma (mesma turma pode dividir a sala).
        if (idSala != null &&
            other.idSala == idSala &&
            other.idCurso != aula.idCurso) {
          final room = roomById[idSala];
          final roomLabel = room?.rotulo ?? 'Sala';
          final otherCourse = courseById[other.idCurso]?.nome ?? 'outra turma';
          problemas.add(
            '$roomLabel ocupada por $otherCourse (${_rotuloCelula(celula)})',
          );
        }
      }
    }

    return ValidacaoHorario(problemas: _deduplicar(problemas));
  }

  bool _periodoCompativel(PreferenciaPeriodo preferencia, int indicePeriodo) {
    final dentroDaGrade =
        indicePeriodo >= 0 && indicePeriodo < GradeHoraria.periodos.length;
    final noite = GradeHoraria.faixaDoPeriodo(indicePeriodo) == 2;
    return switch (preferencia) {
      PreferenciaPeriodo.manhaTarde || PreferenciaPeriodo.tardeManha =>
        dentroDaGrade && !noite,
      PreferenciaPeriodo.noite => dentroDaGrade && noite,
    };
  }

  bool _estaIndisponivel(
    List<IndisponibilidadeProfessor> linhas,
    String idProfessor,
    CelulaGrade celula,
  ) {
    return linhas.any(
      (u) =>
          u.idProfessor == idProfessor &&
          u.indiceDia == celula.indiceDia &&
          u.indicePeriodo == celula.indicePeriodo,
    );
  }

  String _rotuloCelula(CelulaGrade celula) {
    final day = GradeHoraria.dias[celula.indiceDia];
    final period = GradeHoraria.periodos[celula.indicePeriodo];
    return '$day $period';
  }

  List<String> _deduplicar(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in items) {
      if (seen.add(item)) out.add(item);
    }
    return out;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
