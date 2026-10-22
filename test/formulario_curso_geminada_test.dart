import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_curso.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';

import 'apoio/dados.dart';

/// Abre o formulário do curso e guarda o que ele devolve ao salvar.
class _Abertura {
  ResultadoFormularioCurso? resultado;
  bool fechou = false;
}

Future<_Abertura> _abrir(
  WidgetTester tester, {
  List<CargaCursoMateria> cargas = const [],
  List<AulaGeminadaCurso> pares = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final abertura = _Abertura();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              abertura.resultado = await mostrarDialogoFormularioCurso(
                context,
                titulo: 'Editar curso',
                materias: materiasPadrao,
                salas: salasPadrao,
                nomeInicial: 'Info 1',
                cargasIniciais: cargas,
                aulasGeminadasIniciais: pares,
                idCurso: '1',
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

Finder _porPrefixo(String prefixo) => find.byWidgetPredicate((w) {
  final key = w.key;
  return key is ValueKey<String> && key.value.startsWith(prefixo);
});

int? _blocosSelecionados(WidgetTester tester, int linha) => tester
    .widget<DropdownButtonFormField<int>>(_porPrefixo('gem-blocos-$linha-'))
    .initialValue;

/// Abre o campo Blocos da linha e lê as opções do menu (fora dos botões).
Future<List<String>> _opcoesBlocos(WidgetTester tester, int linha) async {
  await tester.tap(_porPrefixo('gem-blocos-$linha-'));
  await tester.pumpAndSettle();
  final opcoes = tester
      .elementList(find.byType(DropdownMenuItem<int>))
      .where(
        (e) =>
            e.findAncestorWidgetOfExactType<DropdownButtonFormField<int>>() ==
            null,
      )
      .map((e) => '${(e.widget as DropdownMenuItem<int>).value}')
      .toList();
  // Fecha o menu tocando fora dele.
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
  return opcoes;
}

Future<void> _adicionarPar(WidgetTester tester) async {
  await tester.tap(find.text('Aula'));
  await tester.pumpAndSettle();
}

Future<void> _escolherBlocos(WidgetTester tester, int linha, int valor) async {
  await tester.tap(_porPrefixo('gem-blocos-$linha-'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$valor').last);
  await tester.pumpAndSettle();
}

Future<void> _escolherMateria(
  WidgetTester tester,
  String prefixo,
  String nome,
) async {
  await tester.tap(_porPrefixo(prefixo));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nome).last);
  await tester.pumpAndSettle();
}

Future<void> _salvar(WidgetTester tester) async {
  await tester.tap(find.text('Salvar'));
  await tester.pumpAndSettle();
}

final _cargas8 = [carga(informatica.id, 8), carga(ingles.id, 8)];

void main() {
  group('Formulário do curso: aula geminada', () {
    testWidgets('editar mostra aulas e blocos já cadastrados', (tester) async {
      await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
      );

      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('gem-aulas-0')))
            .controller!
            .text,
        '8',
      );
      expect(_blocosSelecionados(tester, 0), 2);
    });

    testWidgets('cadastrar par novo: 8 aulas em 2 blocos', (tester) async {
      final abertura = await _abrir(tester, cargas: _cargas8);

      await _adicionarPar(tester);
      await tester.pumpAndSettle();
      await _escolherMateria(tester, 'gem-a-0', 'Informática');
      await _escolherMateria(tester, 'gem-b-0', 'Inglês');
      await tester.enterText(find.byKey(const ValueKey('gem-aulas-0')), '8');
      await tester.pumpAndSettle();
      await _escolherBlocos(tester, 0, 2);
      await _salvar(tester);

      final pares = abertura.resultado!.aulasGeminadas;
      expect(pares, hasLength(1));
      expect(pares.single.quantidadePeriodos, 8);
      expect(pares.single.quantidadeBlocos, 2);
      expect(pares.single.tamanhosBlocos, [4, 4]);
    });

    testWidgets('cargas diferentes: Informática 2 e Inglês 4', (tester) async {
      final abertura = await _abrir(tester, cargas: _cargas8);

      await _adicionarPar(tester);
      await tester.pumpAndSettle();
      await _escolherMateria(tester, 'gem-a-0', 'Informática');
      await _escolherMateria(tester, 'gem-b-0', 'Inglês');
      await tester.enterText(find.byKey(const ValueKey('gem-aulas-0')), '2');
      await tester.enterText(find.byKey(const ValueKey('gem-aulas-b-0')), '4');
      await tester.pumpAndSettle();
      // Blocos vão até a matéria maior (4 horários).
      expect(await _opcoesBlocos(tester, 0), ['1', '2', '3', '4']);
      await _salvar(tester);

      final salvo = abertura.resultado!.aulasGeminadas.single;
      expect(salvo.quantidadeDe(informatica.id), 2);
      expect(salvo.quantidadeDe(ingles.id), 4);
      expect(salvo.periodosOcupados, 4);
    });

    testWidgets('editar par com cargas diferentes mostra as duas', (
      tester,
    ) async {
      await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 2, aulasB: 4, blocos: 1)],
      );
      String texto(String chave) => tester
          .widget<TextField>(find.byKey(ValueKey(chave)))
          .controller!
          .text;
      expect(texto('gem-aulas-0'), '2');
      expect(texto('gem-aulas-b-0'), '4');
    });

    testWidgets('Aulas de B não pode passar da carga de B', (tester) async {
      final abertura = await _abrir(
        tester,
        cargas: [carga(informatica.id, 8), carga(ingles.id, 3)],
      );

      await _adicionarPar(tester);
      await tester.pumpAndSettle();
      await _escolherMateria(tester, 'gem-a-0', 'Informática');
      await _escolherMateria(tester, 'gem-b-0', 'Inglês');
      await tester.enterText(find.byKey(const ValueKey('gem-aulas-0')), '2');
      await tester.enterText(find.byKey(const ValueKey('gem-aulas-b-0')), '4');
      await tester.pumpAndSettle();
      await _salvar(tester);

      expect(abertura.resultado, isNull);
      expect(
        find.text('Aulas geminadas não podem passar da carga das matérias'),
        findsOneWidget,
      );
    });

    testWidgets('blocos vão no máximo até o número de aulas', (tester) async {
      await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 1)],
      );

      expect(await _opcoesBlocos(tester, 0), ['1', '2', '3', '4']);
    });

    testWidgets('com mais de 6 aulas, 1 bloco não é oferecido (um turno)', (
      tester,
    ) async {
      await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
      );

      final opcoes = await _opcoesBlocos(tester, 0);
      expect(opcoes.first, '2');
      expect(opcoes.last, '8');
    });

    testWidgets('diminuir as aulas ajusta os blocos', (tester) async {
      await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 8)],
      );

      await tester.enterText(find.byKey(const ValueKey('gem-aulas-0')), '3');
      await tester.pumpAndSettle();
      expect(_blocosSelecionados(tester, 0), 3);
    });

    testWidgets('editar: trocar aulas e blocos de um par existente', (
      tester,
    ) async {
      final abertura = await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
      );

      await tester.enterText(find.byKey(const ValueKey('gem-aulas-0')), '6');
      await tester.pumpAndSettle();
      await _escolherBlocos(tester, 0, 3);
      await _salvar(tester);

      final par0 = abertura.resultado!.aulasGeminadas.single;
      expect(par0.quantidadePeriodos, 6);
      expect(par0.quantidadeBlocos, 3);
      expect(par0.tamanhosBlocos, [2, 2, 2]);
    });

    testWidgets('editar: remover o par', (tester) async {
      final abertura = await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
      );

      await tester.tap(find.byTooltip('Remover par'));
      await tester.pumpAndSettle();
      await _salvar(tester);

      expect(abertura.resultado!.aulasGeminadas, isEmpty);
    });

    testWidgets('não deixa as aulas passarem da carga das matérias', (
      tester,
    ) async {
      final abertura = await _abrir(
        tester,
        cargas: [carga(informatica.id, 8), carga(ingles.id, 4)],
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 2)],
      );

      await tester.enterText(find.byKey(const ValueKey('gem-aulas-0')), '6');
      await tester.pumpAndSettle();
      await _salvar(tester);

      expect(abertura.fechou, isFalse);
      expect(
        find.text('Aulas geminadas não podem passar da carga das matérias'),
        findsOneWidget,
      );
    });

    testWidgets('não deixa usar a mesma matéria dos dois lados', (
      tester,
    ) async {
      final abertura = await _abrir(tester, cargas: _cargas8);

      await _adicionarPar(tester);
      await tester.pumpAndSettle();
      await _escolherMateria(tester, 'gem-a-0', 'Informática');
      await _escolherMateria(tester, 'gem-b-0', 'Informática');
      await _salvar(tester);

      expect(abertura.fechou, isFalse);
      expect(
        find.text('Aula geminada precisa de duas matérias diferentes'),
        findsOneWidget,
      );
    });

    testWidgets('exige as duas matérias do par', (tester) async {
      final abertura = await _abrir(tester, cargas: _cargas8);

      await _adicionarPar(tester);
      await tester.pumpAndSettle();
      await _escolherMateria(tester, 'gem-a-0', 'Informática');
      await _salvar(tester);

      expect(abertura.fechou, isFalse);
      expect(
        find.text('Informe as duas matérias da aula geminada'),
        findsOneWidget,
      );
    });
  });
}
