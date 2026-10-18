import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/pages/page3/page3.dart';
import 'package:flutter_test_project/pages/page3/widgets/celula_horario.dart';
import 'package:flutter_test_project/providers/providers.dart';

import 'apoio/dados.dart';
import 'apoio/repositorio_aula_falso.dart';

/// Abre a página 3 com dados em memória e seleciona o curso "Info 1".
Future<void> _abrirPagina3(
  WidgetTester tester, {
  required RepositorioAulaFalso repo,
  List<Curso>? cursos,
  List<CargaCursoMateria>? cargas,
  List<AulaGeminadaCurso> pares = const [],
  List<ProfessorMateria>? ligacoes,
  Stream<List<Professor>>? professores,
  List<Materia>? materias,
  double alturaTela = 2000,
  bool selecionarCurso = true,
}) async {
  tester.view.physicalSize = Size(1600, alturaTela);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        provedorRepositorioAula.overrideWithValue(repo),
        provedorCursos.overrideWith(
          (ref) => Stream.value(cursos ?? [curso(idSala: sala1.id)]),
        ),
        provedorCargasCurso.overrideWith(
          (ref) => Stream.value(
            cargas ??
                [
                  carga(informatica.id, 4),
                  carga(ingles.id, 4),
                  carga(matematica.id, 4),
                ],
          ),
        ),
        provedorAulasGeminadasCurso.overrideWith((ref) => Stream.value(pares)),
        provedorMaterias.overrideWith(
          (ref) => Stream.value(materias ?? materiasPadrao),
        ),
        provedorProfessores.overrideWith(
          (ref) => professores ?? Stream.value(professoresPadrao),
        ),
        provedorProfessorMaterias.overrideWith(
          (ref) => Stream.value(ligacoes ?? ligacoesPadrao),
        ),
        provedorIndisponibilidades.overrideWith((ref) => Stream.value(const [])),
        provedorSalas.overrideWith((ref) => Stream.value(salasPadrao)),
      ],
      child: const MaterialApp(home: Page3()),
    ),
  );
  await _esperar(tester);

  if (selecionarCurso) {
    await tester.tap(find.text('Info 1'));
    await _esperar(tester);
  }
}

/// Avança animações sem pumpAndSettle (a barra de progresso nunca para).
Future<void> _esperar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Finder _celula(int dia, int periodo) => find.byWidgetPredicate(
  (w) => w is CelulaHorario && w.celula == celula(dia, periodo),
);

Finder _porPrefixo(String prefixo) => find.byWidgetPredicate((w) {
  final key = w.key;
  return key is ValueKey<String> && key.value.startsWith(prefixo);
});

Future<void> _escolher(
  WidgetTester tester,
  String prefixoCampo,
  String opcao,
) async {
  await tester.tap(_porPrefixo(prefixoCampo));
  await _esperar(tester);
  await tester.tap(find.text(opcao).last);
  await _esperar(tester);
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.tap(alvo);
  await _esperar(tester);
}

void main() {
  group('Página 3: edição pela grade', () {
    testWidgets('criar aula numa célula vazia', (tester) async {
      final repo = RepositorioAulaFalso();
      await _abrirPagina3(tester, repo: repo);

      await _tocar(tester, _celula(0, 0));
      expect(find.text('Nova aula — Seg 1º M · Grupo 1'), findsOneWidget);
      await _escolher(tester, 'subject-', 'Matemática');
      await _escolher(tester, 'prof-', 'Carla');
      await _tocar(tester, find.text('Salvar'));

      final salva = repo.aulas.single;
      expect(salva.idMateria, matematica.id);
      expect(salva.idProfessor, carla.id);
      expect(salva.indiceDia, 0);
      expect(salva.indicePeriodo, 0);
      expect(salva.grupo, 1);
      expect(salva.idSala, sala1.id, reason: 'usa a sala padrão do curso');
    });

    testWidgets('editar professor e sala de uma aula', (tester) async {
      final existente = aula(
        id: 'a1',
        dia: 0,
        periodo: 0,
        idMateria: matematica.id,
        idProfessor: carla.id,
        idSala: sala1.id,
      );
      final repo = RepositorioAulaFalso([existente]);
      await _abrirPagina3(tester, repo: repo);

      await _tocar(tester, _celula(0, 0));
      expect(find.text('Editar — Seg 1º M · Grupo 1'), findsOneWidget);
      await _escolher(tester, 'prof-', 'Diego');
      await _escolher(tester, 'room-', 'Laboratório de informática 1');
      await _tocar(tester, find.text('Salvar'));

      final editada = repo.aulas.single;
      expect(editada.id, 'a1');
      expect(editada.idProfessor, diego.id);
      expect(editada.idSala, lab1.id);
    });

    testWidgets('editar a matéria de uma aula', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(
          id: 'a1',
          dia: 0,
          periodo: 0,
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
      ]);
      await _abrirPagina3(tester, repo: repo);

      await _tocar(tester, _celula(0, 0));
      await _escolher(tester, 'subject-', 'Informática');
      await _escolher(tester, 'prof-', 'Ana');
      await _tocar(tester, find.text('Salvar'));

      expect(repo.aulas.single.idMateria, informatica.id);
      expect(repo.aulas.single.idProfessor, ana.id);
    });

    testWidgets('excluir uma aula', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(
          id: 'a1',
          dia: 0,
          periodo: 0,
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
      ]);
      await _abrirPagina3(tester, repo: repo);

      await _tocar(tester, _celula(0, 0));
      await _tocar(tester, find.text('Excluir'));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));

      expect(repo.aulas, isEmpty);
    });

    testWidgets('cancelar não muda nada', (tester) async {
      final repo = RepositorioAulaFalso();
      await _abrirPagina3(tester, repo: repo);

      await _tocar(tester, _celula(0, 0));
      await _escolher(tester, 'subject-', 'Matemática');
      await _tocar(tester, find.text('Cancelar'));

      expect(repo.aulas, isEmpty);
    });

    testWidgets('adicionar o 2º grupo de uma aula geminada', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(
          id: 'a1',
          dia: 0,
          periodo: 0,
          idMateria: informatica.id,
          idProfessor: ana.id,
        ),
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
      );

      await _tocar(tester, _celula(0, 0));
      await _tocar(tester, find.text('Adicionar 2º grupo'));
      expect(find.text('Nova aula — Seg 1º M · Grupo 2'), findsOneWidget);
      await _escolher(tester, 'subject-', 'Inglês');
      await _escolher(tester, 'prof-', 'Bruno');
      await _tocar(tester, find.text('Salvar'));

      expect(repo.aulas, hasLength(2));
      final nova = repo.aulas.firstWhere((a) => a.id != 'a1');
      expect(nova.idMateria, ingles.id);
      expect(nova.grupo, 2);
    });

    testWidgets('no 2º grupo só aparece a matéria do par', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
      );

      await _tocar(tester, _celula(0, 0));
      await _tocar(tester, find.text('Adicionar 2º grupo'));
      await _tocar(tester, _porPrefixo('subject-'));

      expect(find.text('Inglês'), findsWidgets);
      expect(find.text('Matemática'), findsNothing);
    });

    testWidgets('com 2 grupos, pergunta qual editar', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
        aula(
          dia: 0,
          periodo: 0,
          idMateria: ingles.id,
          idProfessor: bruno.id,
          grupo: 2,
        ),
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
      );

      await _tocar(tester, _celula(0, 0));
      expect(find.text('Qual grupo editar?'), findsOneWidget);
      await _tocar(tester, find.text('Grupo 2 — Inglês'));
      expect(find.text('Editar — Seg 1º M · Grupo 2'), findsOneWidget);
    });

    testWidgets('bloqueia salvar quando a carga já está completa', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        aula(dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        cargas: [carga(matematica.id, 1)],
      );

      await _tocar(tester, _celula(0, 0));
      await _escolher(tester, 'subject-', 'Matemática');
      await _escolher(tester, 'prof-', 'Diego');
      await _tocar(tester, find.text('Salvar'));

      expect(repo.aulas, hasLength(1));
      expect(
        find.text('Erro: Carga completa para esta matéria (1 aula(s)).'),
        findsOneWidget,
      );
    });

    testWidgets('não oferece professor ocupado em outra turma', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        aula(
          idCurso: '2',
          dia: 0,
          periodo: 0,
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        cursos: [curso(), curso(id: '2', nome: 'Info 2')],
      );

      await _tocar(tester, _celula(0, 0));
      await _escolher(tester, 'subject-', 'Matemática');
      await _tocar(tester, _porPrefixo('prof-'));

      expect(find.text('Diego'), findsWidgets);
      expect(find.text('Carla'), findsNothing);
    });

    testWidgets('limpar a grade apaga só as aulas do curso', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        aula(
          idCurso: '2',
          dia: 0,
          periodo: 0,
          idMateria: matematica.id,
          idProfessor: diego.id,
        ),
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        cursos: [curso(), curso(id: '2', nome: 'Info 2')],
      );

      await _tocar(tester, find.byTooltip('Limpar grade'));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));

      expect(repo.aulas.single.idCurso, '2');
      expect(find.text('Grade de "Info 1" limpa.'), findsOneWidget);
    });
  });

  group('Página 3: arrastar aulas', () {
    Future<void> arrastar(WidgetTester tester, Finder de, Finder para) async {
      final gesto = await tester.startGesture(tester.getCenter(de));
      await tester.pump(const Duration(milliseconds: 50));
      await gesto.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesto.moveTo(tester.getCenter(para));
      await tester.pump();
      await gesto.up();
      await _esperar(tester);
    }

    Finder textoNaCelula(int dia, int periodo, String texto) =>
        find.descendant(of: _celula(dia, periodo), matching: find.text(texto));

    testWidgets('arrastar aula comum para uma célula vazia', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(
          id: 'mat',
          dia: 0,
          periodo: 0,
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
      ]);
      await _abrirPagina3(tester, repo: repo);

      await arrastar(
        tester,
        textoNaCelula(0, 0, 'Matemática'),
        _celula(2, 3),
      );

      final movida = repo.aulas.single;
      expect(movida.id, 'mat');
      expect((movida.indiceDia, movida.indicePeriodo), (2, 3));
    });

    testWidgets('soltar numa célula ocupada é recusado com mensagem', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        aula(id: 'mat', dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        aula(id: 'inf', dia: 2, periodo: 3, idMateria: informatica.id, idProfessor: ana.id),
      ]);
      await _abrirPagina3(tester, repo: repo);

      await arrastar(
        tester,
        textoNaCelula(0, 0, 'Matemática'),
        _celula(2, 3),
      );

      final mat = repo.aulas.firstWhere((a) => a.id == 'mat');
      expect((mat.indiceDia, mat.indicePeriodo), (0, 0));
      expect(
        find.textContaining('Não foi possível mover. Horário ocupado'),
        findsOneWidget,
      );
    });

    testWidgets('aula geminada anda em conjunto (2º–5º, o 1º fica vazio)', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        for (final p in [0, 1, 2, 3]) ...[
          aula(
            id: 'inf-$p',
            dia: 0,
            periodo: p,
            idMateria: informatica.id,
            idProfessor: ana.id,
          ),
          aula(
            id: 'ing-$p',
            dia: 0,
            periodo: p,
            idMateria: ingles.id,
            idProfessor: bruno.id,
            grupo: 2,
          ),
        ],
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 1)],
      );

      // Pega o 2º M e solta no 3º M.
      await arrastar(
        tester,
        textoNaCelula(0, 1, 'Informática'),
        _celula(0, 2),
      );

      expect(repo.aulas, hasLength(8));
      expect(repo.aulas.map((a) => a.indicePeriodo).toSet(), {1, 2, 3, 4});
      expect(repo.aulas.where((a) => a.indicePeriodo == 0), isEmpty);
      for (final p in [1, 2, 3, 4]) {
        final naCelula = repo.aulas.where((a) => a.indicePeriodo == p);
        expect(naCelula.map((a) => a.grupo).toSet(), {1, 2});
      }
    });

    testWidgets('conjunto geminado não cabe onde há aula no meio', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        for (final p in [0, 1]) ...[
          aula(id: 'inf-$p', dia: 0, periodo: p, idMateria: informatica.id, idProfessor: ana.id),
          aula(
            id: 'ing-$p',
            dia: 0,
            periodo: p,
            idMateria: ingles.id,
            idProfessor: bruno.id,
            grupo: 2,
          ),
        ],
        aula(id: 'mat', dia: 1, periodo: 1, idMateria: matematica.id, idProfessor: carla.id),
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
      );

      await arrastar(
        tester,
        textoNaCelula(0, 0, 'Informática'),
        _celula(1, 0),
      );

      expect(repo.aulas.where((a) => a.indiceDia == 1), hasLength(1));
      expect(
        find.textContaining('precisa de 2 horário(s) vazios seguidos'),
        findsOneWidget,
      );
    });
  });

  group('Página 3: robustez', () {
    testWidgets('se o movimento falhar no meio, o conjunto volta inteiro', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        for (final p in [0, 1, 2, 3]) ...[
          aula(id: 'inf-$p', dia: 0, periodo: p, idMateria: informatica.id, idProfessor: ana.id),
          aula(
            id: 'ing-$p',
            dia: 0,
            periodo: p,
            idMateria: ingles.id,
            idProfessor: bruno.id,
            grupo: 2,
          ),
        ],
      ])..falharMoverDepoisDe = 3;
      await _abrirPagina3(
        tester,
        repo: repo,
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 1)],
      );

      // Tenta mover o conjunto inteiro para quarta.
      final gesto = await tester.startGesture(
        tester.getCenter(
          find.descendant(of: _celula(0, 0), matching: find.text('Informática')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesto.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesto.moveTo(tester.getCenter(_celula(2, 0)));
      await tester.pump();
      await gesto.up();
      await _esperar(tester);

      expect(repo.aulas.every((a) => a.indiceDia == 0), isTrue);
      expect(repo.aulas.map((a) => a.indicePeriodo).toSet(), {0, 1, 2, 3});
      expect(find.textContaining('falha simulada'), findsOneWidget);
    });

    testWidgets('muitos problemas não estouram a tela (painel rola)', (
      tester,
    ) async {
      // 50 matérias na carga e nenhuma aula: 50 avisos de "Faltam", numa
      // tela baixa. Sem a rolagem, a lista passaria da altura disponível.
      final muitas = [
        for (var i = 0; i < 50; i++) Materia(id: '${100 + i}', nome: 'Matéria $i'),
      ];
      await _abrirPagina3(
        tester,
        repo: RepositorioAulaFalso(),
        materias: muitas,
        cargas: [for (final m in muitas) carga(m.id, 4)],
        alturaTela: 1000,
      );

      expect(find.text('50 problema(s)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Página 3: gerar horários', () {
    Future<void> gerar(WidgetTester tester) async {
      await _tocar(tester, find.widgetWithText(TextButton, 'Gerar'));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Gerar'));
    }

    testWidgets('gera e substitui a grade', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(id: 'velha', dia: 4, periodo: 11, idMateria: matematica.id, idProfessor: carla.id),
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        cargas: [carga(informatica.id, 8), carga(ingles.id, 8)],
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
      );

      await gerar(tester);

      expect(repo.aulas.any((a) => a.id == 'velha'), isFalse);
      expect(repo.aulas, hasLength(16));
      expect(find.textContaining('Horários gerados: 16'), findsOneWidget);
    });

    testWidgets('se nada couber, mantém a grade atual', (tester) async {
      final existente = aula(
        id: 'a1',
        dia: 0,
        periodo: 0,
        idMateria: matematica.id,
        idProfessor: carla.id,
      );
      final repo = RepositorioAulaFalso([existente]);
      await _abrirPagina3(
        tester,
        repo: repo,
        cargas: [carga(matematica.id, 2)],
        ligacoes: const [],
      );

      await gerar(tester);

      expect(repo.aulas.single.id, 'a1');
      expect(
        find.textContaining('grade atual mantida'),
        findsOneWidget,
      );
    });

    testWidgets('se salvar falhar, restaura a grade anterior', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        aula(dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      ])..falhasAoAdicionarVarias = 1;
      await _abrirPagina3(
        tester,
        repo: repo,
        cargas: [carga(matematica.id, 4)],
      );

      await gerar(tester);

      expect(repo.aulas, hasLength(2));
      expect(
        repo.aulas.map((a) => '${a.indiceDia}-${a.indicePeriodo}').toSet(),
        {'0-0', '1-0'},
      );
      expect(find.textContaining('grade anterior restaurada'), findsOneWidget);
    });

    testWidgets('"Gerar" fica bloqueado enquanto os dados carregam', (
      tester,
    ) async {
      final carregando = StreamController<List<Professor>>();
      addTearDown(carregando.close);
      await _abrirPagina3(
        tester,
        repo: RepositorioAulaFalso(),
        professores: carregando.stream,
      );

      final botao = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Gerar'),
      );
      expect(botao.onPressed, isNull);
    });
  });
}
