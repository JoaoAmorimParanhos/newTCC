import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_materia.dart';

import 'apoio/dados.dart';

class _Abertura {
  ResultadoFormularioMateria? resultado;
  bool fechou = false;
}

Future<_Abertura> _abrir(
  WidgetTester tester, {
  String? nome,
  List<String> idsIniciais = const [],
}) async {
  final abertura = _Abertura();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              abertura.resultado = await mostrarDialogoFormularioMateria(
                context,
                titulo: 'Editar matéria',
                professores: professoresPadrao,
                nomeInicial: nome,
                idsProfessoresIniciais: idsIniciais,
              );
              abertura.fechou = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return abertura;
}

bool _marcado(WidgetTester tester, String nomeProfessor) => tester
    .widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, nomeProfessor),
    )
    .value!;

void main() {
  group('Formulário da matéria', () {
    testWidgets('mostra todos os professores para selecionar', (tester) async {
      await _abrir(tester);

      for (final p in professoresPadrao) {
        expect(find.widgetWithText(CheckboxListTile, p.nome), findsOneWidget);
      }
    });

    testWidgets('ao editar, já vem com os professores vinculados marcados', (
      tester,
    ) async {
      await _abrir(
        tester,
        nome: 'Matemática',
        idsIniciais: [carla.id, diego.id],
      );

      expect(_marcado(tester, 'Carla'), isTrue);
      expect(_marcado(tester, 'Diego'), isTrue);
      expect(_marcado(tester, 'Ana'), isFalse);
    });

    testWidgets('nova matéria com professores selecionados', (tester) async {
      final abertura = await _abrir(tester);

      await tester.enterText(find.byType(TextField), 'Química');
      await tester.tap(find.text('Ana'));
      await tester.tap(find.text('Bruno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(abertura.resultado!.nome, 'Química');
      expect(
        abertura.resultado!.idsProfessores,
        unorderedEquals([ana.id, bruno.id]),
      );
    });

    testWidgets('desmarcar remove o professor', (tester) async {
      final abertura = await _abrir(
        tester,
        nome: 'Matemática',
        idsIniciais: [carla.id, diego.id],
      );

      await tester.tap(find.text('Diego'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(abertura.resultado!.idsProfessores, [carla.id]);
    });

    testWidgets('exige o nome', (tester) async {
      final abertura = await _abrir(tester);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(abertura.fechou, isFalse);
      expect(find.text('Informe um nome'), findsOneWidget);
    });
  });
}
