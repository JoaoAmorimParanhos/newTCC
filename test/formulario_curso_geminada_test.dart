import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_curso.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';

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
  PreferenciaPeriodo preferencia = PreferenciaPeriodo.manhaTarde,
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
                preferenciaPeriodoInicial: preferencia,
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

/// Texto "Na grade: ..." embaixo da linha da aula dividida.
String? _resumo(WidgetTester tester, int linha) {
  final achado = find.byKey(ValueKey('gem-resumo-$linha'));
  if (achado.evaluate().isEmpty) return null;
  return tester.widget<Text>(achado).data;
}

Future<void> _adicionarPar(WidgetTester tester) async {
  await tester.tap(find.text('Aula'));
  await tester.pumpAndSettle();
}

/// Escolhe o Bloco da linha [linha] da carga.
Future<void> _escolherBlocoCarga(
  WidgetTester tester,
  int linha,
  int valor,
) async {
  await tester.tap(_porPrefixo('block-$linha-'));
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

// Bloco 4 na carga: a aula dividida fica em blocos de 4 aulas seguidas.
final _cargas8 = [
  carga(informatica.id, 8, bloco: 4),
  carga(ingles.id, 8, bloco: 4),
];

void main() {
  group('Formulário do curso: aula geminada', () {
    testWidgets('editar mostra as aulas e como fica na grade', (tester) async {
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
      expect(
        _resumo(tester, 0),
        'Na grade: 2 blocos de 4 aulas seguidas. '
        'G1: Informática · G2: Inglês.',
      );
    });

    testWidgets('não tem mais o campo Blocos na aula dividida', (tester) async {
      await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
      );

      expect(_porPrefixo('gem-blocos-'), findsNothing);
    });

    testWidgets('cadastrar par novo: 8 aulas com Bloco 4 = 2 blocos', (
      tester,
    ) async {
      final abertura = await _abrir(tester, cargas: _cargas8);

      await _adicionarPar(tester);
      await tester.pumpAndSettle();
      expect(_resumo(tester, 0), isNull, reason: 'sem componentes ainda');
      await _escolherMateria(tester, 'gem-a-0', 'Informática');
      await _escolherMateria(tester, 'gem-b-0', 'Inglês');
      await tester.enterText(find.byKey(const ValueKey('gem-aulas-0')), '8');
      await tester.pumpAndSettle();
      await _salvar(tester);

      final pares = abertura.resultado!.aulasGeminadas;
      expect(pares, hasLength(1));
      expect(pares.single.quantidadePeriodos, 8);
      expect(pares.single.quantidadeBlocos, 2);
    });

    testWidgets('mudar o Bloco da carga muda a aula dividida', (tester) async {
      final abertura = await _abrir(
        tester,
        cargas: [
          carga(informatica.id, 4, bloco: 4),
          carga(ingles.id, 4, bloco: 4),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 1)],
      );
      expect(
        _resumo(tester, 0),
        'Na grade: 1 bloco de 4 aulas seguidas. '
        'G1: Informática · G2: Inglês.',
      );

      await _escolherBlocoCarga(tester, 0, 2);

      expect(
        _resumo(tester, 0),
        'Na grade: 2 blocos de 2 aulas seguidas. '
        'G1: Informática · G2: Inglês.',
      );
      await _salvar(tester);
      expect(abertura.resultado!.aulasGeminadas.single.quantidadeBlocos, 2);
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
      // O de menos aulas fica no G1, livre nos horários que sobram.
      expect(
        _resumo(tester, 0),
        'Na grade: 1 bloco de 4 aulas seguidas. '
        'G1: Informática · G2: Inglês. O G1 fica livre em 2 horário(s).',
      );
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
        find.text('Aulas divididas não podem passar da carga dos componentes'),
        findsOneWidget,
      );
    });

    testWidgets('turma da noite: bloco geminado tem no máximo 4 aulas', (
      tester,
    ) async {
      await _abrir(
        tester,
        cargas: [
          carga(informatica.id, 8, bloco: 6),
          carga(ingles.id, 8, bloco: 6),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
        preferencia: PreferenciaPeriodo.noite,
      );

      expect(
        _resumo(tester, 0),
        'Na grade: 2 blocos de 4 aulas seguidas. '
        'G1: Informática · G2: Inglês.',
      );
    });

    testWidgets('trocar o turno para Noite divide blocos grandes', (
      tester,
    ) async {
      await _abrir(
        tester,
        cargas: [
          carga(informatica.id, 8, bloco: 6),
          carga(ingles.id, 8, bloco: 6),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 6, blocos: 1)],
      );
      expect(_resumo(tester, 0), startsWith('Na grade: 1 bloco de 6 aulas'));

      await tester.tap(_porPrefixo('period-'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Noite').last);
      await tester.pumpAndSettle();

      expect(
        _resumo(tester, 0),
        startsWith('Na grade: 2 blocos (4 + 2 aulas seguidas).'),
      );
    });

    testWidgets('o (?) aparece uma vez no título de cada seção', (
      tester,
    ) async {
      await _abrir(
        tester,
        cargas: [
          carga(informatica.id, 4),
          carga(ingles.id, 4),
          carga(matematica.id, 4),
        ],
        pares: [
          par(informatica.id, ingles.id, aulas: 2, blocos: 1),
          par(informatica.id, matematica.id, aulas: 2, blocos: 1),
        ],
      );

      expect(find.byTooltip('O que é Bloco?'), findsOneWidget);
      expect(find.byTooltip('Como fica a aula dividida?'), findsOneWidget);
    });

    testWidgets('as 5 opções de turno aparecem', (tester) async {
      await _abrir(tester, cargas: _cargas8);
      await tester.tap(_porPrefixo('period-'));
      await tester.pumpAndSettle();
      for (final rotulo in [
        'Manhã',
        'Tarde',
        'Noite',
        'Manhã - CT: Tarde',
        'Tarde - CT: Manhã',
      ]) {
        expect(find.text(rotulo), findsWidgets, reason: rotulo);
      }
    });

    testWidgets('com mais aulas que o turno, o bloco para no turno (6)', (
      tester,
    ) async {
      await _abrir(
        tester,
        cargas: [
          carga(informatica.id, 8, bloco: 6),
          carga(ingles.id, 8, bloco: 6),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
      );

      expect(
        _resumo(tester, 0),
        startsWith('Na grade: 2 blocos (6 + 2 aulas seguidas).'),
      );
    });

    testWidgets('diminuir as aulas ajusta os blocos', (tester) async {
      await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 8)],
      );

      await tester.enterText(find.byKey(const ValueKey('gem-aulas-0')), '3');
      await tester.pumpAndSettle();
      expect(_resumo(tester, 0), startsWith('Na grade: 1 bloco de 3 aulas'));
    });

    testWidgets('editar: trocar as aulas de um par existente', (tester) async {
      final abertura = await _abrir(
        tester,
        cargas: _cargas8,
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
      );

      await tester.enterText(find.byKey(const ValueKey('gem-aulas-0')), '6');
      await tester.pumpAndSettle();
      await _salvar(tester);

      // 6 aulas com Bloco 4 = 4 + 2, como numa aula comum.
      final par0 = abertura.resultado!.aulasGeminadas.single;
      expect(par0.quantidadePeriodos, 6);
      expect(par0.quantidadeBlocos, 2);
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
        find.text('Aulas divididas não podem passar da carga dos componentes'),
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
        find.text('Aula dividida precisa de dois componentes diferentes'),
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
        find.text('Informe os dois componentes da aula dividida'),
        findsOneWidget,
      );
    });
  });
}
