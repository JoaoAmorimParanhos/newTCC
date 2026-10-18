import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/services/gerador_horario.dart';
import 'package:flutter_test_project/services/validador_horario.dart';

import 'apoio/dados.dart';

ResultadoGeracaoCompleta _gerar({
  List<Curso>? cursos,
  required List<CargaCursoMateria> cargas,
  List<Professor>? professores,
  List<IndisponibilidadeProfessor> indisponibilidades = const [],
}) {
  return const GeradorHorario().gerarTodos(
    cursos: cursos ?? [curso()],
    cargas: cargas,
    professores: professores ?? professoresPadrao,
    ligacoes: ligacoesPadrao,
    indisponibilidades: indisponibilidades,
  );
}

void main() {
  group('Gerador (matérias comuns)', () {
    test('aloca toda a carga em blocos do tamanho pedido', () {
      final r = _gerar(cargas: [carga(matematica.id, 10, bloco: 2)]);

      expect(r.falhas, isEmpty);
      expect(r.novasAulas, hasLength(10));
      // 5 blocos de 2, um por dia, com períodos seguidos.
      for (var dia = 0; dia < 5; dia++) {
        final doDia = r.novasAulas.where((a) => a.indiceDia == dia).toList();
        expect(doDia, hasLength(2));
        expect(
          (doDia[0].indicePeriodo - doDia[1].indicePeriodo).abs(),
          1,
        );
      }
    });

    test('carga maior que 5 blocos repete o dia em vez de falhar', () {
      final r = _gerar(cargas: [carga(matematica.id, 8)]);

      expect(r.falhas, isEmpty);
      expect(r.novasAulas, hasLength(8));
    });

    test('"Manhã, depois tarde" começa pela manhã', () {
      final r = _gerar(cargas: [carga(matematica.id, 2, bloco: 2)]);
      expect(r.novasAulas.every((a) => a.indicePeriodo < 6), isTrue);
    });

    test('"Tarde, depois manhã" começa pela tarde', () {
      final r = _gerar(
        cursos: [curso(preferencia: PreferenciaPeriodo.tardeManha)],
        cargas: [carga(matematica.id, 2, bloco: 2)],
      );
      expect(r.novasAulas.every((a) => a.indicePeriodo >= 6), isTrue);
    });

    test('bloco nunca cruza o almoço', () {
      final r = _gerar(cargas: [carga(matematica.id, 12, bloco: 4)]);

      expect(r.falhas, isEmpty);
      for (var dia = 0; dia < 5; dia++) {
        final periodos = r.novasAulas
            .where((a) => a.indiceDia == dia)
            .map((a) => a.indicePeriodo)
            .toList();
        if (periodos.isEmpty) continue;
        final manha = periodos.where((p) => p < 6).length;
        expect(manha % 4, 0, reason: 'dia $dia: $periodos');
      }
    });

    test('professor não fica em duas turmas no mesmo horário', () {
      final r = _gerar(
        cursos: [curso(id: '1'), curso(id: '2', nome: 'Info 2')],
        professores: [carla],
        cargas: [
          carga(matematica.id, 6, idCurso: '1'),
          carga(matematica.id, 6, idCurso: '2'),
        ],
      );

      expect(r.falhas, isEmpty);
      final horarios = r.novasAulas
          .map((a) => '${a.indiceDia}-${a.indicePeriodo}')
          .toList();
      expect(horarios.toSet(), hasLength(horarios.length));
    });

    test('duas turmas não usam a mesma sala no mesmo horário', () {
      final r = _gerar(
        cursos: [
          curso(id: '1', idSala: sala1.id),
          curso(id: '2', nome: 'Info 2', idSala: sala1.id),
        ],
        cargas: [
          carga(matematica.id, 5, idCurso: '1'),
          carga(informatica.id, 5, idCurso: '2'),
        ],
      );

      final usos = r.novasAulas
          .map((a) => '${a.idSala}-${a.indiceDia}-${a.indicePeriodo}')
          .toList();
      expect(usos.toSet(), hasLength(usos.length));
    });

    test('respeita a indisponibilidade do professor', () {
      final r = _gerar(
        professores: [carla],
        cargas: [carga(matematica.id, 4)],
        indisponibilidades: diaInteiroIndisponivel(carla.id, 0),
      );

      expect(r.falhas, isEmpty);
      expect(r.novasAulas.any((a) => a.indiceDia == 0), isFalse);
    });

    test('usa outro professor da matéria quando o primeiro está ocupado', () {
      final r = _gerar(
        professores: [carla, diego],
        cargas: [carga(matematica.id, 2)],
        indisponibilidades: [
          for (var dia = 0; dia < 5; dia++) ...diaInteiroIndisponivel(carla.id, dia),
        ],
      );

      expect(r.falhas, isEmpty);
      expect(r.novasAulas.every((a) => a.idProfessor == diego.id), isTrue);
    });

    test('avisa quando a matéria não tem professor', () {
      final r = _gerar(
        professores: [ana],
        cargas: [carga(matematica.id, 2)],
      );
      expect(r.falhas.single, contains('nenhum professor vinculado'));
    });

    test('avisa quando o curso não tem carga', () {
      final r = _gerar(cargas: const []);
      expect(r.falhas.single, contains('sem carga'));
    });

    test('o horário gerado passa no validador da página 3', () {
      final turma = curso(idSala: sala1.id);
      final cargas = [
        carga(informatica.id, 8),
        carga(ingles.id, 6),
        carga(matematica.id, 6, bloco: 2),
      ];
      final pares = [par(informatica.id, ingles.id, aulas: 4, blocos: 2)];
      final r = const GeradorHorario().gerarTodos(
        cursos: [turma],
        cargas: cargas,
        professores: professoresPadrao,
        ligacoes: ligacoesPadrao,
        indisponibilidades: const [],
        aulasGeminadas: pares,
      );
      expect(r.falhas, isEmpty);

      // O validador compara ids de aula; dá um id único a cada uma.
      var n = 0;
      final aulas = [
        for (final a in r.novasAulas)
          aula(
            id: 'g${n++}',
            dia: a.indiceDia,
            periodo: a.indicePeriodo,
            idMateria: a.idMateria,
            idProfessor: a.idProfessor,
            idSala: a.idSala,
            grupo: a.grupo,
          ),
      ];
      final v = const ValidadorHorario().validarCurso(
        idCurso: turma.id,
        todasAulas: aulas,
        cursos: [turma],
        cargas: cargas,
        aulasGeminadas: pares,
        professores: professoresPadrao,
        materias: materiasPadrao,
        salas: salasPadrao,
        indisponibilidades: const [],
      );
      expect(v.problemas, isEmpty);
    });
  });
}
