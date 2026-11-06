import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_aula.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/pages/page3/helpers/formato_horario.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';
import 'package:flutter_test_project/pages/page3/widgets/campo_horario_periodo.dart';
import 'package:flutter_test_project/services/arrumacao_grupos.dart';
import 'package:flutter_test_project/services/gerador_horario.dart';
import 'package:flutter_test_project/services/validador_horario.dart';

import 'apoio/dados.dart';

List<Aula> _gerar(Curso turma, List<CargaCursoMateria> cargas,
    {List<AulaGeminadaCurso> pares = const []}) {
  final r = const GeradorHorario().gerarTodos(
    cursos: [turma],
    cargas: cargas,
    professores: professoresPadrao,
    ligacoes: ligacoesPadrao,
    indisponibilidades: const [],
    aulasGeminadas: pares,
  );
  expect(r.falhas, isEmpty);
  return r.novasAulas;
}

List<String> _problemas(
  List<Aula> aulas, {
  List<CargaCursoMateria>? cargas,
  List<AulaGeminadaCurso> pares = const [],
  List<ProfessorMateria>? ligacoes,
}) => const ValidadorHorario()
    .validarCurso(
      idCurso: '1',
      todasAulas: aulas,
      cursos: [curso()],
      cargas: cargas ?? const [],
      aulasGeminadas: pares,
      professores: professoresPadrao,
      materias: materiasPadrao,
      salas: salasPadrao,
      indisponibilidades: const [],
      ligacoes: ligacoes,
    )
    .problemas;

void main() {
  group('Turnos do curso', () {
    test('5 opções, gravadas e lidas do banco', () {
      for (final p in PreferenciaPeriodo.values) {
        expect(PreferenciaPeriodo.fromDb(p.toDb()), p);
      }
      expect(PreferenciaPeriodo.values.map((p) => p.rotulo), [
        'Manhã',
        'Tarde',
        'Noite',
        'Manhã - CT: Tarde',
        'Tarde - CT: Manhã',
      ]);
      // Cursos antigos continuam como contraturno.
      expect(PreferenciaPeriodo.fromDb('manha_tarde'), PreferenciaPeriodo.manhaTarde);
      expect(PreferenciaPeriodo.fromDb('tarde_manha'), PreferenciaPeriodo.tardeManha);
    });

    test('bloco máximo: 6 de dia, 4 à noite', () {
      expect(PreferenciaPeriodo.manha.maxAulasPorBloco, 6);
      expect(PreferenciaPeriodo.tarde.maxAulasPorBloco, 6);
      expect(PreferenciaPeriodo.manhaTarde.maxAulasPorBloco, 6);
      expect(PreferenciaPeriodo.noite.maxAulasPorBloco, 4);
    });

    test('Manhã só usa a manhã; Tarde só usa a tarde', () {
      final manha = _gerar(
        curso(preferencia: PreferenciaPeriodo.manha),
        [carga(matematica.id, 10)],
      );
      expect(manha.every((a) => a.indicePeriodo < 6), isTrue);

      final tarde = _gerar(
        curso(preferencia: PreferenciaPeriodo.tarde),
        [carga(matematica.id, 10)],
      );
      expect(
        tarde.every((a) => a.indicePeriodo >= 6 && a.indicePeriodo < 12),
        isTrue,
      );
    });

    test('Manhã - CT: Tarde enche a manhã e o resto vai para a tarde', () {
      final aulas = _gerar(
        curso(preferencia: PreferenciaPeriodo.manhaTarde),
        [carga(matematica.id, 6, bloco: 6), carga(ingles.id, 2, bloco: 2)],
      );
      final daMatematica = aulas.where((a) => a.idMateria == matematica.id);
      expect(daMatematica.every((a) => a.indicePeriodo < 6), isTrue);
    });
  });

  group('Noite: blocos de no máximo 4', () {
    test('carga salva com bloco 6 é dividida e entra toda à noite', () {
      final aulas = _gerar(
        curso(preferencia: PreferenciaPeriodo.noite),
        [carga(matematica.id, 6, bloco: 6)],
      );
      expect(aulas, hasLength(6));
      expect(aulas.every((a) => a.indicePeriodo >= 12), isTrue);
    });

    test('geminada de 5 aulas em 1 bloco também é dividida à noite', () {
      final aulas = _gerar(
        curso(preferencia: PreferenciaPeriodo.noite),
        [carga(informatica.id, 5), carga(ingles.id, 5)],
        pares: [par(informatica.id, ingles.id, aulas: 5, blocos: 1)],
      );
      expect(aulas, hasLength(10));
      expect(aulas.every((a) => a.indicePeriodo >= 12), isTrue);
    });
  });

  group('Validador: geminada', () {
    test('dois pares com a mesma matéria maior não geram falso erro', () {
      // Informática(1)+Inglês(3) e Matemática(1)+Inglês(2): Inglês sozinho
      // no G2 em 2 + 1 = 3 horários.
      final pares = [
        par(informatica.id, ingles.id, aulas: 1, aulasB: 3, blocos: 1),
        par(matematica.id, ingles.id, aulas: 1, aulasB: 2, blocos: 1),
      ];
      final aulas = [
        aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
        aula(dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
        aula(dia: 0, periodo: 1, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
        aula(dia: 0, periodo: 2, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
        aula(dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        aula(dia: 1, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
        aula(dia: 1, periodo: 1, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
      ];
      expect(
        _problemas(
          aulas,
          pares: pares,
          cargas: [
            carga(informatica.id, 1),
            carga(matematica.id, 1),
            carga(ingles.id, 5),
          ],
        ),
        isEmpty,
      );
    });

    test('grupo 2 sozinho sem par é avisado', () {
      final problemas = _problemas(
        [aula(dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2)],
        cargas: [carga(ingles.id, 1)],
      );
      expect(problemas, contains('Grupo 2 sem aula dividida em Seg 1º M (Inglês)'));
    });

    test('par com mais aulas que a carga: aviso único e claro', () {
      final problemas = _problemas(
        const [],
        cargas: [carga(informatica.id, 1), carga(ingles.id, 1)],
        pares: [par(informatica.id, ingles.id, aulas: 3, blocos: 1)],
      );
      expect(
        problemas.where((p) => p.startsWith('Aula dividida')),
        ['Aula dividida Informática + Inglês pede mais aulas do que a carga '
            'dos componentes (ajuste em Cadastros)'],
      );
    });
  });

  group('Validador: outros', () {
    test('professor desvinculado da matéria é avisado', () {
      final problemas = _problemas(
        [aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: ana.id)],
        cargas: [carga(matematica.id, 1)],
        ligacoes: ligacoesPadrao,
      );
      expect(problemas, contains('Ana não está vinculado a Matemática (Seg 1º M)'));
    });

    test('rótulo de célula fora da grade não quebra', () {
      expect(rotuloCelula(celula(0, 0)), 'Seg 1º M');
      expect(rotuloCelula(celula(6, 20)), 'dia 7, período 21');
    });
  });

  group('Arrumação dos grupos', () {
    test('G2 sozinho sem par vira aula completa; com par fica', () {
      final semPar = aula(id: 's', dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2);
      final comPar = aula(id: 'c', dia: 0, periodo: 1, idMateria: informatica.id, idProfessor: ana.id, grupo: 2);
      final resultado = aulasQueViramCompletas(
        [semPar, comPar],
        [par(informatica.id, matematica.id, aulas: 1, blocos: 1)],
      );
      expect(resultado.map((a) => (a.id, a.grupo)), [('s', 1)]);
    });

    test('excluir quem dava o G2 de um par leva o G1 para o G2', () {
      final g1 = aula(id: 'g1', dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final g2 = aula(id: 'g2', dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2);
      final resultado = aulasQueVaoParaGrupo2(
        excluidas: [g2],
        todasAulas: [g1, g2],
        pares: [par(informatica.id, ingles.id, aulas: 1, blocos: 1)],
      );
      expect(resultado.map((a) => (a.id, a.grupo)), [('g1', 2)]);

      // Excluindo quem dava o G1, o G2 já fica certo: nada muda.
      expect(
        aulasQueVaoParaGrupo2(
          excluidas: [g1],
          todasAulas: [g1, g2],
          pares: [par(informatica.id, ingles.id, aulas: 1, blocos: 1)],
        ),
        isEmpty,
      );
    });
  });

  group('Máscara do horário: edição no meio e colar', () {
    TextEditingValue editar(String texto, int cursor) => TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: cursor),
    );

    test('digitar no meio substitui o número seguinte e mantém o cursor', () {
      final r = const MascaraHorarioFormatter().formatEditUpdate(
        editar('07:30 - 08:20', 2),
        editar('075:30 - 08:20', 3),
      );
      expect(r.text, '07:50 - 08:20');
      expect(r.selection.baseOffset, 4);
    });

    test('apagar um separador no meio apaga o número à esquerda dele', () {
      // Cursor depois do ":" de "07:30"; backspace apaga o ":".
      final r = const MascaraHorarioFormatter().formatEditUpdate(
        editar('07:30 - 08:20', 3),
        editar('0730 - 08:20', 2),
      );
      expect(r.text, '03:00 - 82:0');
      expect(r.selection.baseOffset, 1);
    });

    test('colar com hora de 1 dígito completa com zero', () {
      final r = const MascaraHorarioFormatter().formatEditUpdate(
        editar('', 0),
        editar('7:30 - 8:20', 11),
      );
      expect(r.text, '07:30 - 08:20');
      expect(r.selection.baseOffset, r.text.length);
    });
  });

  group('Campo de horário', () {
    Future<List<String>> montar(
      WidgetTester tester, {
      required Future<bool> Function(String) aoSalvar,
      String texto = '',
    }) async {
      final salvos = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 140,
              child: CampoHorarioPeriodo(
                rotulo: '1º M',
                texto: texto,
                aoSalvar: (t) {
                  salvos.add(t);
                  return aoSalvar(t);
                },
              ),
            ),
          ),
        ),
      );
      return salvos;
    }

    testWidgets('Enter salva uma vez só (sem salvar de novo ao perder o foco)', (
      tester,
    ) async {
      final salvos = await montar(tester, aoSalvar: (_) async => true);
      await tester.enterText(find.byType(TextField), '07300820');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(salvos, ['07:30 - 08:20']);
    });

    testWidgets('se não conseguir salvar, volta ao horário gravado', (
      tester,
    ) async {
      await montar(
        tester,
        texto: '13:00 - 13:50',
        aoSalvar: (_) async => false,
      );
      await tester.enterText(find.byType(TextField), '14001450');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '13:00 - 13:50',
      );
    });
  });

  group('Diálogo da aula', () {
    Future<void> abrir(
      WidgetTester tester, {
      String? Function(ResultadoFormularioAula)? validar,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => mostrarDialogoFormularioAula(
                context,
                titulo: 'Editar',
                materias: materiasPadrao,
                salas: salasPadrao,
                professoresDaMateria: (id) => professoresPadrao
                    .where(
                      (p) => ligacoesPadrao.any(
                        (l) => l.idProfessor == p.id && l.idMateria == id,
                      ),
                    )
                    .toList(),
                idMateriaInicial: matematica.id,
                idProfessorInicial: carla.id,
                validar: validar,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('recusa fica no diálogo, sem perder a edição', (tester) async {
      await abrir(tester, validar: (_) => 'Professor indisponível neste horário (Disponibilidade).');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Professor indisponível neste horário (Disponibilidade).'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget, reason: 'continua aberto');
    });

    testWidgets('trocar a matéria não mostra o aviso laranja falso', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.startsWith('subject-');
      }));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inglês').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('O professor atual não está disponível'),
        findsNothing,
      );
    });
  });

  test('a grade continua com 16 períodos', () {
    expect(GradeHoraria.periodos, hasLength(16));
  });
}
