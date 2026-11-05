import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/horario/horario_periodo.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/pages/page3/helpers/formato_horario.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';
import 'package:flutter_test_project/services/arrumacao_grupos.dart';
import 'package:flutter_test_project/services/exportador_horario_pdf.dart';
import 'package:flutter_test_project/services/gerador_horario.dart';
import 'package:flutter_test_project/services/validador_horario.dart';

import 'apoio/dados.dart';

ResultadoGeracaoCompleta _gerar({
  required List<Curso> cursos,
  required List<CargaCursoMateria> cargas,
  List<AulaGeminadaCurso> pares = const [],
  List<IndisponibilidadeProfessor> indisponibilidades = const [],
}) => const GeradorHorario().gerarTodos(
  cursos: cursos,
  cargas: cargas,
  professores: professoresPadrao,
  ligacoes: ligacoesPadrao,
  indisponibilidades: indisponibilidades,
  aulasGeminadas: pares,
);

/// Nenhum horário tem mais de 2 aulas da mesma turma, nenhum professor
/// está em dois lugares e nenhuma sala é usada por duas turmas.
void _semConflitos(List<Aula> aulas) {
  final porTurma = <(String, int, int), int>{};
  final porProfessor = <(String, int, int), int>{};
  final porSala = <(String, int, int), Set<String>>{};
  for (final a in aulas) {
    final k = (a.idCurso, a.indiceDia, a.indicePeriodo);
    porTurma[k] = (porTurma[k] ?? 0) + 1;
    final p = (a.idProfessor, a.indiceDia, a.indicePeriodo);
    porProfessor[p] = (porProfessor[p] ?? 0) + 1;
    if (a.idSala != null) {
      porSala
          .putIfAbsent((a.idSala!, a.indiceDia, a.indicePeriodo), () => {})
          .add(a.idCurso);
    }
  }
  expect(porTurma.values.every((n) => n <= 2), isTrue, reason: 'até 2 grupos');
  expect(porProfessor.values.every((n) => n == 1), isTrue, reason: 'professor');
  expect(porSala.values.every((t) => t.length == 1), isTrue, reason: 'sala');
}

void main() {
  group('Gerador: vários cursos juntos', () {
    test('3 turmas com a mesma sala: sem conflito de sala ou professor', () {
      final turmas = [
        curso(id: '1', nome: 'A', idSala: sala1.id),
        curso(id: '2', nome: 'B', idSala: sala1.id, preferencia: PreferenciaPeriodo.tardeManha),
        curso(id: '3', nome: 'C', idSala: sala1.id, preferencia: PreferenciaPeriodo.noite),
      ];
      final r = _gerar(
        cursos: turmas,
        cargas: [
          for (final t in turmas) ...[
            carga(matematica.id, 4, idCurso: t.id, bloco: 2),
            carga(ingles.id, 2, idCurso: t.id),
          ],
        ],
      );
      _semConflitos(r.novasAulas);
    });

    test('mesma entrada, mesmo resultado (gerar duas vezes dá igual)', () {
      List<String> assinatura() => [
        for (final a in _gerar(
          cursos: [curso()],
          cargas: [carga(matematica.id, 5, bloco: 2), carga(ingles.id, 3)],
        ).novasAulas)
          '${a.idMateria}-${a.indiceDia}-${a.indicePeriodo}-${a.grupo}',
      ];
      expect(assinatura(), assinatura());
    });

    test('turma só da manhã: carga maior que a manhã avisa o que faltou', () {
      // 5 dias × 6 horários = 30 na manhã; 32 aulas não cabem.
      final r = _gerar(
        cursos: [curso(preferencia: PreferenciaPeriodo.manha)],
        cargas: [carga(matematica.id, 16), carga(ingles.id, 16)],
      );
      expect(r.novasAulas.every((a) => a.indicePeriodo < 6), isTrue);
      expect(r.falhas, isNotEmpty);
      expect(r.completo, isFalse);
    });

    test('geminada e aulas comuns da mesma turma não se sobrepõem', () {
      final r = _gerar(
        cursos: [curso()],
        cargas: [
          carga(informatica.id, 4),
          carga(ingles.id, 6),
          carga(matematica.id, 6, bloco: 2),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 4, aulasB: 6, blocos: 2)],
      );
      expect(r.falhas, isEmpty);
      _semConflitos(r.novasAulas);
    });

    test('indisponibilidade da noite é respeitada na turma noturna', () {
      final r = _gerar(
        cursos: [curso(preferencia: PreferenciaPeriodo.noite)],
        cargas: [carga(matematica.id, 4)],
        indisponibilidades: [
          for (var dia = 0; dia < 5; dia++) indisponivel(carla.id, dia: dia, periodo: 12),
        ],
      );
      for (final a in r.novasAulas.where((a) => a.idProfessor == carla.id)) {
        expect(a.indicePeriodo, isNot(12));
      }
    });
  });

  group('Validador: casos que faltavam', () {
    List<String> problemas(List<Aula> aulas, {List<CargaCursoMateria>? cargas}) =>
        const ValidadorHorario()
            .validarCurso(
              idCurso: '1',
              todasAulas: aulas,
              cursos: [curso(idSala: sala1.id), curso(id: '2', nome: 'Info 2')],
              cargas: cargas ?? [carga(matematica.id, 1)],
              aulasGeminadas: const [],
              professores: professoresPadrao,
              materias: materiasPadrao,
              salas: salasPadrao,
              indisponibilidades: const [],
            )
            .problemas;

    test('aula à noite numa turma de dia não gera aviso (edição é livre)', () {
      expect(
        problemas([
          aula(dia: 0, periodo: 14, idMateria: matematica.id, idProfessor: carla.id),
        ]),
        isEmpty,
      );
    });

    test('mensagens repetidas aparecem uma vez só', () {
      final lista = problemas([
        aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        aula(idCurso: '2', dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      ]);
      expect(lista.toSet().length, lista.length);
    });

    test('curso que não existe não quebra', () {
      expect(
        const ValidadorHorario()
            .validarCurso(
              idCurso: '99',
              todasAulas: const [],
              cursos: [curso()],
              cargas: const [],
              aulasGeminadas: const [],
              professores: const [],
              materias: const [],
              salas: const [],
              indisponibilidades: const [],
            )
            .ok,
        isTrue,
      );
    });
  });

  group('Arrastar: limites da grade', () {
    String? mover(Aula a, CelulaGrade destino, {List<Aula> outras = const []}) =>
        validarMoverAulas(
          originais: [a],
          movidas: deslocarAulas([a], origem: a.celula, destino: destino),
          todasAulas: [a, ...outras],
          professores: professoresPadrao,
          indisponibilidades: const [],
        );

    final aulaComum = aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id);

    test('pode ir para a noite', () {
      expect(mover(aulaComum, celula(4, 15)), isNull);
    });

    test('conjunto de 2 não atravessa o jantar (6º T → 1º N)', () {
      final a1 = aula(id: 'a', dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final b1 = aula(id: 'b', dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2);
      final a2 = aula(id: 'c', dia: 0, periodo: 1, idMateria: informatica.id, idProfessor: ana.id);
      final b2 = aula(id: 'd', dia: 0, periodo: 1, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2);
      final todas = [a1, b1, a2, b2];
      final conjunto = aulasQueMovemJunto(
        aula: a1,
        todasAulas: todas,
        aulasGeminadas: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
      );
      expect(conjunto, hasLength(4));
      final motivo = validarMoverAulas(
        originais: conjunto,
        movidas: deslocarAulas(conjunto, origem: a1.celula, destino: celula(0, 11)),
        todasAulas: todas,
        professores: professoresPadrao,
        indisponibilidades: const [],
      );
      expect(motivo, contains('mesmo turno'));
    });

    test('o próprio horário de origem não conta como ocupado', () {
      expect(mover(aulaComum, celula(0, 0)), isNull);
    });
  });

  group('Arrumação dos grupos: casos de borda', () {
    test('duas aulas juntas sem par ficam como estão', () {
      final aulas = [
        aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
        aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id, grupo: 2),
      ];
      expect(aulasQueViramCompletas(aulas, const []), isEmpty);
    });

    test('turmas diferentes não se misturam', () {
      final daTurma2 = aula(
        idCurso: '2',
        dia: 0,
        periodo: 0,
        idMateria: ingles.id,
        idProfessor: bruno.id,
        grupo: 2,
      );
      final r = aulasQueViramCompletas(
        [daTurma2],
        [par(informatica.id, ingles.id, aulas: 1, blocos: 1)], // par da turma 1
      );
      expect(r.single.grupo, 1, reason: 'o par é de outra turma');
    });
  });

  group('Modelos', () {
    test('Sala sem o tipo junto ainda é lida', () {
      final s = Sala.fromJson({'id': 1, 'numero': 3, 'id_tipo_sala': 2});
      expect(s.tipo.id, '2');
      expect(s.numero, 3);
    });

    test('HorarioPeriodo sem texto vira vazio', () {
      expect(HorarioPeriodo.fromJson({'periodo': 1}).texto, '');
    });

    test('turnos de cada opção', () {
      expect(PreferenciaPeriodo.manha.turnos, [GradeHoraria.periodosManha]);
      expect(PreferenciaPeriodo.tardeManha.turnos, [
        GradeHoraria.periodosTarde,
        GradeHoraria.periodosManha,
      ]);
    });

    test('valor desconhecido no banco vira Manhã CT: Tarde', () {
      expect(PreferenciaPeriodo.fromDb('qualquer'), PreferenciaPeriodo.manhaTarde);
      expect(PreferenciaPeriodo.fromDb(null), PreferenciaPeriodo.manhaTarde);
    });
  });

  group('Horário: limites do formato', () {
    test('meia-noite e 23:59 são válidos', () {
      expect(validarHorario('00:00 - 23:59'), isNull);
    });

    test('espaços nas pontas são ignorados', () {
      expect(validarHorario('  07:30 - 08:20  '), isNull);
    });

    test('colar 3 horários pega só os 2 primeiros', () {
      final r = const MascaraHorarioFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '7:30 8:20 9:10'),
      );
      expect(r.text, '07:30 - 08:20');
    });
  });

  test('PDF: altura das linhas nunca passa de 34 nem fica negativa', () {
    for (var linhas = 4; linhas <= 16; linhas++) {
      final h = ExportadorHorarioPdf.alturaLinhaParaCaber(
        quantidadeLinhas: linhas,
        quantidadeSeparadores: 2,
        comSalaPadrao: true,
      );
      expect(h, inInclusiveRange(1, 34));
    }
  });
}
