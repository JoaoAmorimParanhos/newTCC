import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';
import 'package:flutter_test_project/pages/page3/page3.dart';
import 'package:flutter_test_project/pages/page3/widgets/celula_horario.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/gerador_horario.dart';
import 'package:flutter_test_project/services/validador_horario.dart';

import 'apoio/dados.dart';
import 'apoio/repositorio_aula_falso.dart';

// Par do exemplo pedido: Informática com 2 aulas e Inglês com 4.
// Ocupa 4 horários seguidos: 2 com os dois grupos e 2 só com Inglês no G2
// (G1 livre).
final _par24 = par(informatica.id, ingles.id, aulas: 2, aulasB: 4, blocos: 1);
final _cargas24 = [carga(informatica.id, 2), carga(ingles.id, 4)];

List<Aula> _gerar(
  List<AulaGeminadaCurso> pares,
  List<CargaCursoMateria> cargas,
) {
  final r = const GeradorHorario().gerarTodos(
    cursos: [curso(idSala: sala1.id)],
    cargas: cargas,
    professores: professoresPadrao,
    ligacoes: ligacoesPadrao,
    indisponibilidades: const [],
    aulasGeminadas: pares,
  );
  expect(r.falhas, isEmpty);
  return r.novasAulas;
}

List<String> _problemas(List<Aula> aulas, {List<AulaGeminadaCurso>? pares}) =>
    const ValidadorHorario()
        .validarCurso(
          idCurso: '1',
          todasAulas: aulas,
          cursos: [curso(idSala: sala1.id)],
          cargas: _cargas24,
          aulasGeminadas: pares ?? [_par24],
          professores: professoresPadrao,
          materias: materiasPadrao,
          salas: salasPadrao,
          indisponibilidades: const [],
        )
        .problemas;

/// Conjunto geminado já montado em Seg 1º–4º M: 2 juntas + 2 só Inglês.
List<Aula> _conjuntoSeg() => [
  aula(id: 'i0', dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
  aula(id: 'e0', dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
  aula(id: 'i1', dia: 0, periodo: 1, idMateria: informatica.id, idProfessor: ana.id),
  aula(id: 'e1', dia: 0, periodo: 1, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
  aula(id: 'e2', dia: 0, periodo: 2, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
  aula(id: 'e3', dia: 0, periodo: 3, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
];

void main() {
  group('Geminada com cargas diferentes: gerador', () {
    test('A = 2 e B = 4: 2 horários juntos e 2 só com B no grupo 2', () {
      final aulas = _gerar([_par24], _cargas24);

      expect(aulas.where((a) => a.idMateria == informatica.id), hasLength(2));
      expect(aulas.where((a) => a.idMateria == ingles.id), hasLength(4));

      final porCelula = aulasPorCelulaDoCurso(aulas, '1');
      expect(porCelula, hasLength(4), reason: 'ocupa max(A, B) horários');

      // Todos no mesmo dia e seguidos.
      final celulas = porCelula.keys.toList()
        ..sort((a, b) => a.indicePeriodo.compareTo(b.indicePeriodo));
      expect(celulas.map((c) => c.indiceDia).toSet(), hasLength(1));
      for (var i = 1; i < celulas.length; i++) {
        expect(celulas[i].indicePeriodo, celulas[i - 1].indicePeriodo + 1);
      }

      // Os 2 primeiros com os dois grupos; os 2 últimos só G2 (G1 livre).
      final listas = [for (final c in celulas) porCelula[c]!];
      for (final lista in listas.take(2)) {
        expect(lista.map((a) => (a.grupo, a.idMateria)), [
          (1, informatica.id),
          (2, ingles.id),
        ]);
      }
      for (final lista in listas.skip(2)) {
        expect(turmaDivididaComGrupoLivre(lista), isTrue);
        expect(lista.single.idMateria, ingles.id);
      }
    });

    test('a matéria maior fica no G2 mesmo quando é a matéria A', () {
      final aulas = _gerar(
        [par(informatica.id, ingles.id, aulas: 4, aulasB: 2, blocos: 1)],
        [carga(informatica.id, 4), carga(ingles.id, 2)],
      );
      final sozinhas = aulasPorCelulaDoCurso(aulas, '1').values
          .where((l) => l.length == 1)
          .toList();
      expect(sozinhas, hasLength(2));
      for (final l in sozinhas) {
        expect(l.single.idMateria, informatica.id);
        expect(l.single.grupo, 2);
      }
    });

    test('em 2 blocos, cada bloco leva parte das aulas juntas', () {
      final aulas = _gerar(
        [par(informatica.id, ingles.id, aulas: 2, aulasB: 4, blocos: 2)],
        _cargas24,
      );
      final porCelula = aulasPorCelulaDoCurso(aulas, '1');
      final dias = porCelula.keys.map((c) => c.indiceDia).toSet();
      expect(dias, hasLength(2), reason: 'blocos em dias diferentes');
      for (final dia in dias) {
        final doDia = porCelula.entries.where((e) => e.key.indiceDia == dia);
        expect(doDia.where((e) => e.value.length == 2), hasLength(1));
        expect(doDia.where((e) => e.value.length == 1), hasLength(1));
      }
    });

    test('nunca passa de 2 grupos por horário', () {
      final aulas = _gerar([_par24], _cargas24);
      for (final lista in aulasPorCelulaDoCurso(aulas, '1').values) {
        expect(lista.length, lessThanOrEqualTo(2));
      }
    });

    test('a grade gerada não tem avisos no validador', () {
      expect(_problemas(_gerar([_par24], _cargas24)), isEmpty);
    });
  });

  group('Geminada com cargas diferentes: validador', () {
    test('avisa quando falta horário só com a matéria maior', () {
      final aulas = _conjuntoSeg()..removeWhere((a) => a.id == 'e3');
      expect(
        _problemas(aulas),
        contains(
          'Aula geminada Informática + Inglês: 1/2 aulas só de Inglês '
          '(grupo 1 livre)',
        ),
      );
    });

    test('conjunto completo não tem avisos', () {
      expect(_problemas(_conjuntoSeg()), isEmpty);
    });
  });

  group('Geminada com cargas diferentes: arrastar', () {
    test('arrastar qualquer parte move o conjunto inteiro, com o G1 livre', () {
      final todas = _conjuntoSeg();
      final pela = todas.firstWhere((a) => a.id == 'e3');
      final movem = aulasQueMovemJunto(
        aula: pela,
        todasAulas: todas,
        aulasGeminadas: [_par24],
      );
      expect(movem.map((a) => a.id).toSet(), {'i0', 'e0', 'i1', 'e1', 'e2', 'e3'});
    });

    test('não deixa soltar uma aula no grupo livre', () {
      final avulsa = aula(
        id: 'm',
        dia: 1,
        periodo: 0,
        idMateria: matematica.id,
        idProfessor: carla.id,
      );
      final todas = [..._conjuntoSeg(), avulsa];
      final motivo = validarMoverAulas(
        originais: [avulsa],
        movidas: deslocarAulas(
          [avulsa],
          origem: avulsa.celula,
          destino: celula(0, 2),
        ),
        todasAulas: todas,
        professores: professoresPadrao,
        indisponibilidades: const [],
      );
      expect(motivo, startsWith('Horário dividido'));
    });

    test('o conjunto inteiro pode ir para outro dia vazio', () {
      final todas = _conjuntoSeg();
      final pela = todas.first;
      final originais = aulasQueMovemJunto(
        aula: pela,
        todasAulas: todas,
        aulasGeminadas: [_par24],
      );
      final movidas = deslocarAulas(
        originais,
        origem: pela.celula,
        destino: celula(2, 0),
      );
      expect(
        validarMoverAulas(
          originais: originais,
          movidas: movidas,
          todasAulas: todas,
          professores: professoresPadrao,
          indisponibilidades: const [],
        ),
        isNull,
      );
      expect(movidas.where((a) => a.grupo == 2 && a.idMateria == ingles.id), hasLength(4));
    });
  });

  group('Geminada: grupos pela tela (clicar)', () {
    Future<void> esperar(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> tocar(WidgetTester tester, Finder alvo) async {
      await tester.tap(alvo);
      await esperar(tester);
    }

    Finder celulaGrade(int dia, int periodo) => find.byWidgetPredicate(
      (w) => w is CelulaHorario && w.celula == celula(dia, periodo),
    );

    Finder porPrefixo(String prefixo) => find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> && key.value.startsWith(prefixo);
    });

    Future<void> escolher(WidgetTester tester, String campo, String opcao) async {
      await tocar(tester, porPrefixo(campo));
      await tocar(tester, find.text(opcao).last);
    }

    Future<void> abrir(WidgetTester tester, RepositorioAulaFalso repo) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            provedorRepositorioAula.overrideWithValue(repo),
            provedorCursos.overrideWith(
              (ref) => Stream.value([curso(idSala: sala1.id)]),
            ),
            provedorCargasCurso.overrideWith((ref) => Stream.value(_cargas24)),
            provedorAulasGeminadasCurso.overrideWith(
              (ref) => Stream.value([_par24]),
            ),
            provedorMaterias.overrideWith((ref) => Stream.value(materiasPadrao)),
            provedorProfessores.overrideWith(
              (ref) => Stream.value(professoresPadrao),
            ),
            provedorProfessorMaterias.overrideWith(
              (ref) => Stream.value(ligacoesPadrao),
            ),
            provedorIndisponibilidades.overrideWith(
              (ref) => Stream.value(const []),
            ),
            provedorSalas.overrideWith((ref) => Stream.value(salasPadrao)),
            provedorHorariosPeriodo.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: const MaterialApp(home: Page3()),
        ),
      );
      await esperar(tester);
      await tocar(tester, find.text('Info 1'));
    }

    Future<void> excluirGrupo(WidgetTester tester, String rotulo) async {
      await tocar(tester, find.text(rotulo));
      await tocar(tester, find.text('Excluir'));
      await tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));
    }

    testWidgets('horário só com o G2 mostra o G1 livre', (tester) async {
      await abrir(tester, RepositorioAulaFalso(_conjuntoSeg()));
      expect(
        find.descendant(of: celulaGrade(0, 2), matching: find.text('Livre')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: celulaGrade(0, 0), matching: find.text('Livre')),
        findsNothing,
      );
    });

    testWidgets('excluir o G1: a aula fica no G2 com o G1 livre', (tester) async {
      final repo = RepositorioAulaFalso(_conjuntoSeg());
      await abrir(tester, repo);

      await tocar(tester, celulaGrade(0, 0));
      await excluirGrupo(tester, 'Grupo 1 — Informática');

      final naCelula = aulasNaCelula(repo.aulas, '1', celula(0, 0));
      expect(naCelula.single.id, 'e0');
      expect(turmaDivididaComGrupoLivre(naCelula), isTrue);
    });

    testWidgets('excluir o G2: a que sobra passa para o G2 (G1 livre)', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso(_conjuntoSeg());
      await abrir(tester, repo);

      await tocar(tester, celulaGrade(0, 1));
      await excluirGrupo(tester, 'Grupo 2 — Inglês');

      final naCelula = aulasNaCelula(repo.aulas, '1', celula(0, 1));
      expect(naCelula.single.id, 'i1');
      expect(naCelula.single.idMateria, informatica.id);
      expect(turmaDivididaComGrupoLivre(naCelula), isTrue);
    });

    testWidgets('excluir também o grupo que sobrou deixa o horário vazio', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso(_conjuntoSeg());
      await abrir(tester, repo);

      // Seg 3º M já tem só o G2 (Inglês) com o G1 livre.
      await tocar(tester, celulaGrade(0, 2));
      await tocar(tester, find.text('Editar este grupo'));
      await tocar(tester, find.text('Excluir'));
      await tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));

      expect(aulasNaCelula(repo.aulas, '1', celula(0, 2)), isEmpty);
    });

    testWidgets('clicar no horário com G1 livre deixa adicionar o outro grupo', (
      tester,
    ) async {
      // Informática ainda tem carga livre (1 de 2 usada).
      final repo = RepositorioAulaFalso(
        _conjuntoSeg()..removeWhere((a) => a.id == 'i1'),
      );
      await abrir(tester, repo);

      await tocar(tester, celulaGrade(0, 2));
      await tocar(tester, find.text('Adicionar 2º grupo'));
      expect(find.text('Nova aula — Seg 3º M · Grupo 1'), findsOneWidget);
      await escolher(tester, 'subject-', 'Informática');
      await escolher(tester, 'prof-', 'Ana');
      await tocar(tester, find.text('Salvar'));

      final naCelula = aulasNaCelula(repo.aulas, '1', celula(0, 2));
      expect(naCelula.map((a) => (a.grupo, a.idMateria)), [
        (1, informatica.id),
        (2, ingles.id),
      ]);
    });
  });

  group('Geminada com cargas diferentes: arrastar pela tela', () {
    Future<void> esperar(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Finder celulaGrade(int dia, int periodo) => find.byWidgetPredicate(
      (w) => w is CelulaHorario && w.celula == celula(dia, periodo),
    );

    Finder textoNaCelula(int dia, int periodo, String texto) =>
        find.descendant(of: celulaGrade(dia, periodo), matching: find.text(texto));

    Future<void> abrir(
      WidgetTester tester,
      RepositorioAulaFalso repo, {
      List<AulaGeminadaCurso>? pares,
      List<CargaCursoMateria>? cargas,
    }) async {
      tester.view.physicalSize = const Size(1600, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            provedorRepositorioAula.overrideWithValue(repo),
            provedorCursos.overrideWith((ref) => Stream.value([curso()])),
            provedorCargasCurso.overrideWith(
              (ref) => Stream.value(
                cargas ?? [..._cargas24, carga(matematica.id, 4)],
              ),
            ),
            provedorAulasGeminadasCurso.overrideWith(
              (ref) => Stream.value(pares ?? [_par24]),
            ),
            provedorMaterias.overrideWith((ref) => Stream.value(materiasPadrao)),
            provedorProfessores.overrideWith(
              (ref) => Stream.value(professoresPadrao),
            ),
            provedorProfessorMaterias.overrideWith(
              (ref) => Stream.value(ligacoesPadrao),
            ),
            provedorIndisponibilidades.overrideWith(
              (ref) => Stream.value(const []),
            ),
            provedorSalas.overrideWith((ref) => Stream.value(salasPadrao)),
            provedorHorariosPeriodo.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: const MaterialApp(home: Page3()),
        ),
      );
      await esperar(tester);
      await tester.tap(find.text('Info 1'));
      await esperar(tester);
    }

    Future<void> arrastar(WidgetTester tester, Finder de, Finder para) async {
      final gesto = await tester.startGesture(tester.getCenter(de));
      await tester.pump(const Duration(milliseconds: 50));
      await gesto.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesto.moveTo(tester.getCenter(para));
      await tester.pump();
      await gesto.up();
      await esperar(tester);
    }

    /// (id → (dia, período, grupo)) de todas as aulas.
    Map<String, (int, int, int)> posicoes(RepositorioAulaFalso repo) => {
      for (final a in repo.aulas) a.id: (a.indiceDia, a.indicePeriodo, a.grupo),
    };

    /// Posições esperadas do conjunto de [_conjuntoSeg] começando em
    /// [dia]/[inicio]: 2 horários juntos + 2 só com Inglês no G2.
    Map<String, (int, int, int)> conjuntoEm(int dia, int inicio) => {
      'i0': (dia, inicio, 1),
      'e0': (dia, inicio, 2),
      'i1': (dia, inicio + 1, 1),
      'e1': (dia, inicio + 1, 2),
      'e2': (dia, inicio + 2, 2),
      'e3': (dia, inicio + 3, 2),
    };

    testWidgets('puxar pela parte com 2 grupos leva o conjunto para outro dia', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso(_conjuntoSeg());
      await abrir(tester, repo);

      await arrastar(tester, textoNaCelula(0, 0, 'Informática'), celulaGrade(2, 0));

      expect(posicoes(repo), conjuntoEm(2, 0));
      expect(find.textContaining('Não foi possível mover'), findsNothing);
    });

    testWidgets('puxar pela parte só com o G2 também leva o conjunto inteiro', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso(_conjuntoSeg());
      await abrir(tester, repo);

      // Seg 4º M (só Inglês) → Qua 5º M: o conjunto vai para Qua 2º–5º M.
      await arrastar(tester, textoNaCelula(0, 3, 'Inglês'), celulaGrade(2, 4));

      expect(posicoes(repo), conjuntoEm(2, 1));
    });

    testWidgets('descer 1 horário no mesmo dia (sobrepondo a posição antiga)', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso(_conjuntoSeg());
      await abrir(tester, repo);

      await arrastar(tester, textoNaCelula(0, 0, 'Informática'), celulaGrade(0, 1));

      expect(posicoes(repo), conjuntoEm(0, 1));
    });

    testWidgets('subir 1 horário no mesmo dia', (tester) async {
      final repo = RepositorioAulaFalso([
        for (final a in _conjuntoSeg())
          Aula(
            id: a.id,
            idCurso: a.idCurso,
            indiceDia: a.indiceDia,
            indicePeriodo: a.indicePeriodo + 2,
            idMateria: a.idMateria,
            idProfessor: a.idProfessor,
            grupo: a.grupo,
          ),
      ]);
      await abrir(tester, repo);

      await arrastar(tester, textoNaCelula(0, 5, 'Inglês'), celulaGrade(0, 4));

      expect(posicoes(repo), conjuntoEm(0, 1));
    });

    testWidgets('conjunto vai para a noite (4 horários cabem certinho)', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso(_conjuntoSeg());
      await abrir(tester, repo);

      await arrastar(
        tester,
        textoNaCelula(0, 0, 'Informática'),
        celulaGrade(1, GradeHoraria.inicioNoite),
      );

      expect(posicoes(repo), conjuntoEm(1, GradeHoraria.inicioNoite));
    });

    testWidgets('recusa quando a parte só do G2 passaria do turno', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso(_conjuntoSeg());
      await abrir(tester, repo);

      // Começar no 4º M levaria a parte só com Inglês para 1º T.
      await arrastar(tester, textoNaCelula(0, 0, 'Informática'), celulaGrade(3, 3));

      expect(posicoes(repo), conjuntoEm(0, 0));
      expect(
        find.textContaining('precisa de 4 horário(s) seguidos no mesmo turno'),
        findsOneWidget,
      );
    });

    testWidgets('recusa quando a parte só do G2 cairia em horário ocupado', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        ..._conjuntoSeg(),
        aula(id: 'mat', dia: 2, periodo: 3, idMateria: matematica.id, idProfessor: carla.id),
      ]);
      await abrir(tester, repo);

      await arrastar(tester, textoNaCelula(0, 0, 'Informática'), celulaGrade(2, 0));

      expect(posicoes(repo)..remove('mat'), conjuntoEm(0, 0));
      expect(find.textContaining('Horário ocupado'), findsOneWidget);
    });

    testWidgets('soltar aula comum no G1 livre é recusado', (tester) async {
      final repo = RepositorioAulaFalso([
        ..._conjuntoSeg(),
        aula(id: 'mat', dia: 3, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      ]);
      await abrir(tester, repo);

      await arrastar(tester, textoNaCelula(3, 0, 'Matemática'), textoNaCelula(0, 2, 'Livre'));

      expect(posicoes(repo)['mat'], (3, 0, 1));
      expect(posicoes(repo)..remove('mat'), conjuntoEm(0, 0));
      expect(find.textContaining('Horário dividido'), findsOneWidget);
    });

    testWidgets('puxar o conjunto em cima de outro horário com G1 livre é recusado', (
      tester,
    ) async {
      // Outro conjunto do mesmo par na Qua: o 1º conjunto não pode cair nele.
      final outro = [
        for (final a in _conjuntoSeg())
          Aula(
            id: 'q-${a.id}',
            idCurso: a.idCurso,
            indiceDia: 2,
            indicePeriodo: a.indicePeriodo,
            idMateria: a.idMateria,
            idProfessor: a.idMateria == informatica.id ? ana.id : bruno.id,
            grupo: a.grupo,
          ),
      ];
      final repo = RepositorioAulaFalso([..._conjuntoSeg(), ...outro]);
      await abrir(
        tester,
        repo,
        cargas: [carga(informatica.id, 4), carga(ingles.id, 8)],
      );

      await arrastar(tester, textoNaCelula(0, 0, 'Informática'), celulaGrade(2, 2));

      expect(
        {for (final e in posicoes(repo).entries) if (!e.key.startsWith('q-')) e.key: e.value},
        conjuntoEm(0, 0),
      );
      expect(find.textContaining('Não foi possível mover'), findsOneWidget);
    });

    testWidgets('matéria A maior (A = 4, B = 2): o conjunto também anda junto', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        aula(id: 'e0', dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id),
        aula(id: 'i0', dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id, grupo: 2),
        aula(id: 'e1', dia: 0, periodo: 1, idMateria: ingles.id, idProfessor: bruno.id),
        aula(id: 'i1', dia: 0, periodo: 1, idMateria: informatica.id, idProfessor: ana.id, grupo: 2),
        aula(id: 'i2', dia: 0, periodo: 2, idMateria: informatica.id, idProfessor: ana.id, grupo: 2),
        aula(id: 'i3', dia: 0, periodo: 3, idMateria: informatica.id, idProfessor: ana.id, grupo: 2),
      ]);
      await abrir(
        tester,
        repo,
        pares: [par(informatica.id, ingles.id, aulas: 4, aulasB: 2, blocos: 1)],
        cargas: [carga(informatica.id, 4), carga(ingles.id, 2)],
      );

      await arrastar(tester, textoNaCelula(0, 2, 'Informática'), celulaGrade(4, 2));

      expect(posicoes(repo), {
        'e0': (4, 0, 1),
        'i0': (4, 0, 2),
        'e1': (4, 1, 1),
        'i1': (4, 1, 2),
        'i2': (4, 2, 2),
        'i3': (4, 3, 2),
      });
    });

    testWidgets('se a gravação cair no meio, o conjunto volta inteiro', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso(_conjuntoSeg())..falharMoverDepoisDe = 3;
      await abrir(tester, repo);

      await arrastar(tester, textoNaCelula(0, 0, 'Informática'), celulaGrade(2, 0));

      expect(posicoes(repo), conjuntoEm(0, 0));
    });
  });
}
