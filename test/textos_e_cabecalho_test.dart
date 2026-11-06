import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_ajuda_bloco.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_curso.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/pages/layout_base.dart';
import 'package:flutter_test_project/services/exportador_horario_pdf.dart';

import 'apoio/dados.dart';

void main() {
  group('Cabeçalho', () {
    testWidgets('mostra o símbolo do IF no lugar do calendário', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: LayoutBase(titulo: 'x', body: SizedBox()),
        ),
      );

      final simbolo = find.byKey(const ValueKey('simbolo-if'));
      expect(simbolo, findsOneWidget);
      final imagem = tester.widget<Image>(
        find.descendant(of: simbolo, matching: find.byType(Image)),
      );
      expect((imagem.image as AssetImage).assetName, 'assets/images/simbolo_if.png');
      expect(imagem.semanticLabel, 'Instituto Federal');
      expect(find.byIcon(Icons.calendar_month), findsNothing);
      expect(find.text('PROJETO TIMETABLE'), findsOneWidget);
    });
  });

  group('Turnos', () {
    test('rótulos com hífen antes do CT', () {
      expect(PreferenciaPeriodo.values.map((p) => p.rotulo), [
        'Manhã',
        'Tarde',
        'Noite',
        'Manhã - CT: Tarde',
        'Tarde - CT: Manhã',
      ]);
    });
  });

  group('Formulário do curso: textos', () {
    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => mostrarDialogoFormularioCurso(
                  context,
                  titulo: 'Editar curso',
                  materias: materiasPadrao,
                  salas: salasPadrao,
                  nomeInicial: 'Info 1',
                  preferenciaPeriodoInicial: PreferenciaPeriodo.manhaTarde,
                  cargasIniciais: [
                    carga(informatica.id, 4),
                    carga(ingles.id, 4),
                    carga(matematica.id, 4),
                  ],
                  aulasGeminadasIniciais: [
                    par(informatica.id, ingles.id, aulas: 2, blocos: 1),
                  ],
                  idCurso: '1',
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('seções com "Componentes" e "Aulas divididas"', (
      tester,
    ) async {
      await abrir(tester);
      expect(find.text('Componentes, carga e blocos'), findsOneWidget);
      expect(find.text('Aulas divididas'), findsOneWidget);
      expect(find.textContaining('Matéria'), findsNothing);
      expect(find.textContaining('geminada'), findsNothing);
    });

    testWidgets('(?) só uma vez no topo de cada seção, mesmo com várias '
        'linhas', (tester) async {
      await abrir(tester);
      expect(find.byKey(const ValueKey('ajuda-bloco')), findsOneWidget);
      expect(find.byKey(const ValueKey('ajuda-blocos-geminada')), findsOneWidget);
    });

    testWidgets('"Qtd. de aulas" na carga e nos dois campos da aula '
        'dividida', (tester) async {
      await abrir(tester);
      // 3 linhas de carga + A e B da aula dividida.
      expect(
        find.widgetWithText(TextField, 'Qtd. de aulas'),
        findsNWidgets(5),
      );
    });
  });

  group('Botões (?) de Bloco e Blocos', () {
    Future<void> montar(WidgetTester tester, Widget botao) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: botao))),
      );
    }

    testWidgets('Bloco: texto novo, exemplo, mini grade e nota da noite', (
      tester,
    ) async {
      await montar(tester, const BotaoAjudaBloco());
      await tester.tap(find.byTooltip('O que é Bloco?'));
      await tester.pumpAndSettle();

      expect(find.text('O que é "Bloco"?'), findsOneWidget);
      expect(
        find.textContaining(
          'O bloco é a quantidade de aulas de um componente que acontecem '
          'em sequência, no mesmo dia.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Exemplo: Matemática com 4 aulas'), findsOneWidget);
      expect(
        find.text(
          'A turma da noite tem uma limitação de bloco de até 4, pois são '
          '4 horários.',
        ),
        findsOneWidget,
      );
      expect(find.text('Matemática'), findsNWidgets(4));
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.text('O que é "Bloco"?'), findsNothing);
    });

    testWidgets('Blocos da aula dividida mostra os grupos e o G1 livre', (
      tester,
    ) async {
      await montar(tester, const BotaoAjudaBlocosGeminada());
      await tester.tap(find.byTooltip('O que é Blocos?'));
      await tester.pumpAndSettle();

      expect(find.text('O que é "Blocos" na aula dividida?'), findsOneWidget);
      expect(find.text('G1 ADS'), findsNWidgets(2));
      expect(find.text('G2 Programação'), findsNWidgets(4));
      expect(find.text('G1 Livre'), findsNWidgets(2));
    });
  });

  group('PDF: manhã e tarde sempre juntas, exceto a Noite', () {
    final manha = GradeHoraria.periodosManha;
    final tarde = GradeHoraria.periodosTarde;
    final noite = GradeHoraria.periodosNoite;

    for (final preferencia in [
      PreferenciaPeriodo.manha,
      PreferenciaPeriodo.tarde,
      PreferenciaPeriodo.manhaTarde,
      PreferenciaPeriodo.tardeManha,
    ]) {
      test('${preferencia.rotulo}: manhã e tarde', () {
        expect(
          ExportadorHorarioPdf.turnosDoCurso(
            curso(preferencia: preferencia),
            const {},
          ),
          [manha, tarde],
        );
      });
    }

    test('Noite: só a noite', () {
      expect(
        ExportadorHorarioPdf.turnosDoCurso(
          curso(preferencia: PreferenciaPeriodo.noite),
          const {},
        ),
        [noite],
      );
    });

    test('turma da manhã com aula à noite também imprime a noite', () {
      expect(
        ExportadorHorarioPdf.turnosDoCurso(
          curso(preferencia: PreferenciaPeriodo.manha),
          {
            celula(0, 13): [
              aula(
                dia: 0,
                periodo: 13,
                idMateria: matematica.id,
                idProfessor: carla.id,
              ),
            ],
          },
        ),
        [manha, tarde, noite],
      );
    });
  });
}
