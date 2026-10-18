import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/services/validador_horario.dart';

import 'apoio/dados.dart';

List<String> _problemas({
  required List<Aula> aulas,
  List<CargaCursoMateria>? cargas,
  List<AulaGeminadaCurso> pares = const [],
  List<Curso>? cursos,
  List<IndisponibilidadeProfessor> indisponibilidades = const [],
}) {
  return const ValidadorHorario()
      .validarCurso(
        idCurso: '1',
        todasAulas: aulas,
        cursos: cursos ?? [curso()],
        cargas: cargas ?? const [],
        aulasGeminadas: pares,
        professores: professoresPadrao,
        materias: materiasPadrao,
        salas: salasPadrao,
        indisponibilidades: indisponibilidades,
      )
      .problemas;
}

void main() {
  group('Validador da página 3', () {
    test('grade completa e sem conflitos não tem problemas', () {
      final p = _problemas(
        cargas: [carga(matematica.id, 2)],
        aulas: [
          aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
          aula(dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        ],
      );
      expect(p, isEmpty);
    });

    test('avisa aulas faltando', () {
      final p = _problemas(
        cargas: [carga(matematica.id, 3)],
        aulas: [
          aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        ],
      );
      expect(p, contains('Faltam 2 aula(s) de Matemática (1/3)'));
    });

    test('avisa aulas demais', () {
      final p = _problemas(
        cargas: [carga(matematica.id, 1)],
        aulas: [
          aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
          aula(dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        ],
      );
      expect(p, contains('Aulas de Matemática demais'));
    });

    test('avisa professor em horário indisponível', () {
      final p = _problemas(
        cargas: [carga(matematica.id, 1)],
        aulas: [
          aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        ],
        indisponibilidades: [indisponivel(carla.id, dia: 0, periodo: 0)],
      );
      expect(p, contains('Carla no horário errado (Seg 1º M)'));
    });

    test('avisa professor dando aula em outro curso no mesmo horário', () {
      final p = _problemas(
        cursos: [curso(), curso(id: '2', nome: 'Info 2')],
        cargas: [carga(matematica.id, 1)],
        aulas: [
          aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
          aula(
            idCurso: '2',
            dia: 0,
            periodo: 0,
            idMateria: matematica.id,
            idProfessor: carla.id,
          ),
        ],
      );
      expect(p, contains('Carla já está dando aula no curso Info 2 (Seg 1º M)'));
    });

    test('avisa sala ocupada por outra turma', () {
      final p = _problemas(
        cursos: [curso(), curso(id: '2', nome: 'Info 2')],
        cargas: [carga(matematica.id, 1)],
        aulas: [
          aula(
            dia: 0,
            periodo: 0,
            idMateria: matematica.id,
            idProfessor: carla.id,
            idSala: sala1.id,
          ),
          aula(
            idCurso: '2',
            dia: 0,
            periodo: 0,
            idMateria: informatica.id,
            idProfessor: ana.id,
            idSala: sala1.id,
          ),
        ],
      );
      expect(p, contains('Sala de aula 1 ocupada por Info 2 (Seg 1º M)'));
    });

    test('avisa 2 grupos no mesmo horário sem aula geminada', () {
      final p = _problemas(
        cargas: [carga(informatica.id, 1), carga(ingles.id, 1)],
        aulas: [
          aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
          aula(
            dia: 0,
            periodo: 0,
            idMateria: ingles.id,
            idProfessor: bruno.id,
            grupo: 2,
          ),
        ],
      );
      expect(p, contains('2 grupos em Seg 1º M sem aula geminada'));
    });

    test('avisa par de matérias que não é o geminado', () {
      final p = _problemas(
        cargas: [
          carga(informatica.id, 1),
          carga(ingles.id, 1),
          carga(matematica.id, 1),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 1, blocos: 1)],
        aulas: [
          aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
          aula(
            dia: 0,
            periodo: 0,
            idMateria: matematica.id,
            idProfessor: carla.id,
            grupo: 2,
          ),
        ],
      );
      expect(p, contains('Par não geminado em Seg 1º M'));
    });

    test('avisa quando as aulas juntas não batem com o configurado', () {
      final p = _problemas(
        cargas: [carga(informatica.id, 4), carga(ingles.id, 4)],
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 2)],
        aulas: [
          for (final periodo in [0, 1]) ...[
            aula(
              dia: 0,
              periodo: periodo,
              idMateria: informatica.id,
              idProfessor: ana.id,
            ),
            aula(
              dia: 0,
              periodo: periodo,
              idMateria: ingles.id,
              idProfessor: bruno.id,
              grupo: 2,
            ),
          ],
          // Aulas soltas completam a carga, mas não contam como geminadas.
          aula(dia: 1, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
          aula(dia: 1, periodo: 1, idMateria: informatica.id, idProfessor: ana.id),
          aula(dia: 2, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id),
          aula(dia: 2, periodo: 1, idMateria: ingles.id, idProfessor: bruno.id),
        ],
      );
      expect(p, ['Aula geminada Informática + Inglês: 2/4 aulas juntas']);
    });
  });
}
