import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/manual/conteudo_manual.dart';
import 'package:flutter_test_project/components/manual/dialogo_manual.dart';
import 'package:flutter_test_project/pages/layout_base.dart';

Future<void> _abrirTela(
  WidgetTester tester, {
  Size tamanho = const Size(1400, 900),
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(
      home: LayoutBase(titulo: 'Cadastros', body: SizedBox()),
    ),
  );
}

String _titulo(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('manual-titulo'))).data!;

void main() {
  group('Nomes das páginas', () {
    testWidgets('o cabeçalho mostra os nomes novos e o botão Como usar', (
      tester,
    ) async {
      await _abrirTela(tester);
      expect(find.text('1. Cadastros'), findsOneWidget);
      expect(find.text('2. Disponibilidade'), findsOneWidget);
      expect(find.text('3. Horário'), findsOneWidget);
      expect(find.textContaining('Página'), findsNothing);
      expect(find.text('Como usar'), findsOneWidget);
    });

    testWidgets('janela média: some o título, os nomes continuam', (
      tester,
    ) async {
      await _abrirTela(tester, tamanho: const Size(800, 700));
      expect(tester.takeException(), isNull, reason: 'sem estouro');
      expect(find.text('PROJETO TIMETABLE'), findsNothing);
      expect(find.text('2. Disponibilidade'), findsOneWidget);
      expect(find.text('Como usar'), findsOneWidget);
    });

    testWidgets('janela estreita: botões com o número e o nome na dica', (
      tester,
    ) async {
      await _abrirTela(tester, tamanho: const Size(700, 700));
      expect(tester.takeException(), isNull, reason: 'sem estouro');
      expect(find.text('2'), findsOneWidget);
      expect(find.byTooltip('2. Disponibilidade'), findsOneWidget);
      expect(find.text('Como usar'), findsOneWidget);
    });
  });

  group('Manual (Como usar)', () {
    testWidgets('abre no começo, avança, volta e fecha', (tester) async {
      await _abrirTela(tester);
      await tester.tap(find.byKey(const ValueKey('botao-manual')));
      await tester.pumpAndSettle();

      expect(find.text('Como usar o Projeto Timetable'), findsOneWidget);
      expect(_titulo(tester), 'Por onde começar');
      expect(find.text('1 de ${secoesManual.length}'), findsOneWidget);
      final anterior = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Anterior'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      expect(anterior.onPressed, isNull, reason: 'já está no primeiro');

      await tester.tap(find.byKey(const ValueKey('manual-proximo')));
      await tester.pumpAndSettle();
      expect(_titulo(tester), 'Cadastrar salas');

      await tester.tap(find.byKey(const ValueKey('manual-anterior')));
      await tester.pumpAndSettle();
      expect(_titulo(tester), 'Por onde começar');

      await tester.tap(find.byKey(const ValueKey('manual-fechar')));
      await tester.pumpAndSettle();
      expect(find.text('Como usar o Projeto Timetable'), findsNothing);
    });

    testWidgets('clicar no índice leva ao assunto', (tester) async {
      await _abrirTela(tester);
      await tester.tap(find.byKey(const ValueKey('botao-manual')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('manual-indice-pdf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manual-indice-pdf')));
      await tester.pumpAndSettle();
      expect(_titulo(tester), 'Imprimir o horário');
      expect(find.text('3. Horário'), findsWidgets);
    });

    testWidgets('no último assunto, o botão vira Concluir e fecha', (
      tester,
    ) async {
      await _abrirTela(tester);
      await tester.tap(find.byKey(const ValueKey('botao-manual')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('manual-indice-avisos')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manual-indice-avisos')));
      await tester.pumpAndSettle();

      expect(find.text('Concluir'), findsOneWidget);
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(find.text('Como usar o Projeto Timetable'), findsNothing);
    });

    testWidgets('dá para ler todos os assuntos com Próximo', (tester) async {
      await _abrirTela(tester);
      await tester.tap(find.byKey(const ValueKey('botao-manual')));
      await tester.pumpAndSettle();
      for (var i = 0; i < secoesManual.length; i++) {
        expect(_titulo(tester), secoesManual[i].titulo);
        expect(tester.takeException(), isNull);
        if (i < secoesManual.length - 1) {
          await tester.tap(find.byKey(const ValueKey('manual-proximo')));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('tela estreita: o índice vira uma lista de escolha', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DialogoManual())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assunto'), findsOneWidget);
      expect(find.byKey(const ValueKey('manual-indice-inicio')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('abre no assunto da tela atual', () {
      String id(String? rota) => secoesManual[secaoInicialDaRota(rota)].id;
      expect(id('/'), 'inicio');
      expect(id('/page2'), 'disponibilidade');
      expect(id('/page3'), 'gerar');
      expect(id(null), 'inicio');
    });

    test('textos bem formados: ids únicos, passos e negrito fechado', () {
      final ids = secoesManual.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final s in secoesManual) {
        expect(s.passos, isNotEmpty, reason: s.id);
        for (final t in [...s.passos, if (s.dica != null) s.dica!]) {
          expect('**'.allMatches(t).length.isEven, isTrue, reason: t);
          expect(t.contains('Página'), isFalse, reason: t);
          expect(
            RegExp(r'\*\*[123]\. ').hasMatch(t),
            isFalse,
            reason: 'nome de página sem espaço que não quebra: $t',
          );
        }
      }
    });

    test('negrito entre asteriscos duplos', () {
      final span = textoComNegrito('Clique em **Salvar** agora');
      final partes = span.children!.cast<TextSpan>();
      expect(partes.map((p) => p.text), ['Clique em ', 'Salvar', ' agora']);
      expect(partes[1].style?.fontWeight, FontWeight.w700);
      expect(partes[0].style, isNull);
    });
  });
}
