import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
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

    /// Vínculos professor–matéria. Sem eles, não confere o vínculo.
    List<ProfessorMateria>? ligacoes,
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
      final nomeMateria = subjectById[load.idMateria] ?? 'Componente';
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
              ? '2 grupos em ${rotuloCelula(entry.key)} sem aula dividida'
              : 'Mais de $limiteGrupos grupos em ${rotuloCelula(entry.key)}',
        );
      }
      if (entry.value.length == 2 &&
          !existeAulaGeminada(
            idCurso: idCurso,
            idMateriaA: entry.value.first.idMateria,
            idMateriaB: entry.value.last.idMateria,
            aulasGeminadas: aulasGeminadas,
          )) {
        problemas.add('Par sem aula dividida cadastrada em ${rotuloCelula(entry.key)}');
      }
    }

    final paresDoCurso = aulasGeminadas
        .where((p) => p.idCurso == idCurso)
        .toList();
    final cargaPorMateria = {
      for (final c in cargas.where((c) => c.idCurso == idCurso))
        c.idMateria: c.quantidadeAulas,
    };

    // Par configurado com mais aulas do que a carga: as contagens abaixo
    // não fazem sentido para ele (o gerador limita pela carga).
    bool passaDaCarga(AulaGeminadaCurso par) =>
        par.quantidadeA > (cargaPorMateria[par.idMateriaA] ?? 0) ||
        par.quantidadeB > (cargaPorMateria[par.idMateriaB] ?? 0);

    // Quantos horários cada par realmente ocupa junto vs. o configurado.
    for (final par in paresDoCurso) {
      final nomeA = subjectById[par.idMateriaA] ?? 'Componente';
      final nomeB = subjectById[par.idMateriaB] ?? 'Componente';
      if (passaDaCarga(par)) {
        problemas.add(
          'Aula dividida $nomeA + $nomeB pede mais aulas do que a carga '
          'dos componentes (ajuste em Cadastros)',
        );
        continue;
      }
      final juntas = porCelula.values
          .where(
            (lista) =>
                lista.length == 2 &&
                par.formaPar(lista.first.idMateria, lista.last.idMateria),
          )
          .length;
      if (juntas != par.juntas) {
        problemas.add(
          'Aula dividida $nomeA + $nomeB: '
          '$juntas/${par.juntas} aulas juntas',
        );
      }
    }

    // Horários com a turma dividida e só a matéria maior (G1 livre).
    // Contados por matéria: a mesma matéria pode ser a maior de dois pares.
    final soMaiorEsperado = <String, int>{};
    final paresDaMaior = <String, List<AulaGeminadaCurso>>{};
    for (final par in paresDoCurso) {
      if (par.periodosSoMaior == 0 || passaDaCarga(par)) continue;
      final maior = par.idMateriaMaior;
      soMaiorEsperado[maior] =
          (soMaiorEsperado[maior] ?? 0) + par.periodosSoMaior;
      paresDaMaior.putIfAbsent(maior, () => []).add(par);
    }
    for (final entry in soMaiorEsperado.entries) {
      final maior = entry.key;
      final soMaior = porCelula.values
          .where(
            (lista) =>
                turmaDivididaComGrupoLivre(lista) &&
                lista.single.idMateria == maior,
          )
          .length;
      if (soMaior == entry.value) continue;
      final nomeMaior = subjectById[maior] ?? 'Componente';
      final pares = paresDaMaior[maior]!;
      final titulo = pares.length == 1
          ? 'Aula dividida ${subjectById[pares.single.idMateriaA] ?? 'Componente'}'
                ' + ${subjectById[pares.single.idMateriaB] ?? 'Componente'}'
          : 'Aulas divididas com $nomeMaior';
      problemas.add(
        '$titulo: $soMaior/${entry.value} aulas só de $nomeMaior '
        '(grupo 1 livre)',
      );
    }

    // Grupo 2 sozinho de matéria que não está em nenhum par da turma.
    for (final entry in porCelula.entries) {
      final lista = entry.value;
      if (!turmaDivididaComGrupoLivre(lista)) continue;
      final idMateria = lista.single.idMateria;
      if (paresDoCurso.any((p) => p.contemMateria(idMateria))) continue;
      problemas.add(
        'Grupo 2 sem aula dividida em ${rotuloCelula(entry.key)} '
        '(${subjectById[idMateria] ?? 'Componente'})',
      );
    }

    for (final aula in courseAulas) {
      final celula = aula.celula;
      final nomeProfessor =
          professorById[aula.idProfessor] ?? 'Professor ${aula.idProfessor}';

      if (estaIndisponivel(indisponibilidades, aula.idProfessor, celula)) {
        problemas.add(
          '$nomeProfessor no horário errado '
          '(${rotuloCelula(celula)})',
        );
      }

      // Professor que deixou de dar a matéria (vínculo tirado na Página 1).
      if (ligacoes != null &&
          !ligacoes.any(
            (l) =>
                l.idProfessor == aula.idProfessor &&
                l.idMateria == aula.idMateria,
          )) {
        problemas.add(
          '$nomeProfessor não está vinculado a '
          '${subjectById[aula.idMateria] ?? 'Componente'} '
          '(${rotuloCelula(celula)})',
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
            '(${rotuloCelula(celula)})',
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
            '$roomLabel ocupada por $otherCourse (${rotuloCelula(celula)})',
          );
        }
      }
    }

    return ValidacaoHorario(problemas: _deduplicar(problemas));
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

