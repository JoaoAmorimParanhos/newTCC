import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/pages/page1/columns/coluna_materia.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/texto.dart';

import 'apoio/dados.dart';

void main() {
  group('Trocar duas aulas ao soltar uma em cima da outra', () {
    final mat = aula(id: 'mat', dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id);
    final inf = aula(id: 'inf', dia: 2, periodo: 3, idMateria: informatica.id, idProfessor: ana.id);
    final dividida = [
      aula(id: 'g1', dia: 1, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
      aula(id: 'g2', dia: 1, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
    ];
    final pares = [
      par(informatica.id, ingles.id, aulas: 1, blocos: 1),
    ];

    test('duas aulas comuns trocam', () {
      expect(
        aulaParaTrocar(
          aula: mat,
          destino: inf.celula,
          todasAulas: [mat, inf],
          aulasGeminadas: const [],
        )?.id,
        'inf',
      );
    });

    test('aula dividida não troca (continua precisando de horário vazio)', () {
      final todas = [mat, ...dividida];
      expect(
        aulaParaTrocar(
          aula: mat,
          destino: celula(1, 0),
          todasAulas: todas,
          aulasGeminadas: pares,
        ),
        isNull,
      );
      expect(
        aulaParaTrocar(
          aula: dividida.first,
          destino: mat.celula,
          todasAulas: todas,
          aulasGeminadas: pares,
        ),
        isNull,
      );
    });

    test('pode trocar entre turnos diferentes', () {
      final tarde = aula(id: 't', dia: 3, periodo: 8, idMateria: ingles.id, idProfessor: bruno.id);
      expect(
        validarTrocaAulas(
          a: mat,
          b: tarde,
          todasAulas: [mat, tarde],
          professores: professoresPadrao,
          indisponibilidades: const [],
        ),
        isNull,
      );
    });

    test('recusa se um professor está indisponível no outro horário', () {
      expect(
        validarTrocaAulas(
          a: mat,
          b: inf,
          todasAulas: [mat, inf],
          professores: professoresPadrao,
          indisponibilidades: [indisponivel(ana.id, dia: 0, periodo: 0)],
        ),
        startsWith('Não dá para trocar: Ana está indisponível'),
      );
    });
  });

  group('Formulário do curso: erro junto do campo', () {
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
                  preferenciaPeriodoInicial: PreferenciaPeriodo.manha,
                  cargasIniciais: [
                    carga(matematica.id, 4),
                    carga(informatica.id, 4),
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

    testWidgets('quantidade inválida aparece embaixo da linha certa', (
      tester,
    ) async {
      await abrir(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Qtd. de aulas').at(1),
        '0',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('erro-carga-1')),
          matching: find.text('Quantidade de aulas deve ser um número ≥ 1'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('erro-carga-0')), findsNothing);
      expect(find.text('Corrija a linha 2 dos componentes.'), findsOneWidget);
    });

    testWidgets('nome vazio aparece no campo do nome', (tester) async {
      await abrir(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Nome do curso'), '');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Informe o nome do curso'), findsOneWidget);
      expect(find.text('Corrija o nome do curso.'), findsOneWidget);
    });

    testWidgets('corrigir e salvar de novo tira o erro', (tester) async {
      await abrir(tester);
      final campo = find.widgetWithText(TextField, 'Qtd. de aulas').at(1);
      await tester.enterText(campo, '0');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester.enterText(campo, '3');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar curso'), findsNothing, reason: 'salvou e fechou');
    });
  });

  group('Busca nas colunas da Página 1', () {
    test('ignora maiúsculas e acentos', () {
      expect(correspondeBusca('Matemática', 'matema'), isTrue);
      expect(correspondeBusca('Educação Física', 'fisica'), isTrue);
      expect(correspondeBusca('Inglês', 'mat'), isFalse);
      expect(correspondeBusca('Inglês', '  '), isTrue);
    });

    testWidgets('filtra a lista e avisa quando não acha nada', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            provedorMaterias.overrideWith((ref) => Stream.value(materiasPadrao)),
            provedorProfessorMaterias.overrideWith(
              (ref) => Stream.value(ligacoesPadrao),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Row(children: [ColunaMateria()])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inglês'), findsOneWidget);

      final busca = find.byKey(const ValueKey('busca-Componentes'));
      await tester.enterText(busca, 'matematica');
      await tester.pumpAndSettle();
      expect(find.text('Matemática'), findsOneWidget);
      expect(find.text('Inglês'), findsNothing);

      await tester.enterText(busca, 'xyz');
      await tester.pumpAndSettle();
      expect(find.text('Nada encontrado para "xyz"'), findsOneWidget);

      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(find.text('Inglês'), findsOneWidget);
    });
  });
}
