import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_ajuda_bloco.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/pages/page3/helpers/cadastro_da_grade.dart';
import 'package:flutter_test_project/pages/page3/page3.dart';
import 'package:flutter_test_project/pages/page3/widgets/celula_horario.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/exportador_horario_pdf.dart';

import 'apoio/dados.dart';
import 'apoio/repositorio_aula_falso.dart';

// "Redes" só existe nestes testes: matéria cadastrada mas fora da carga.
final _redes = Materia(id: '13', nome: 'Redes');

CadastroCurso _cadastro({
  List<CargaCursoMateria> cargas = const [],
  List<AulaGeminadaCurso> pares = const [],
}) => CadastroCurso(cargas: cargas, pares: pares);

void main() {
  group('Criar aula atualiza a carga', () {
    test('matéria fora da carga entra com 1 aula', () {
      final nova = aula(dia: 0, periodo: 0, idMateria: _redes.id, idProfessor: ana.id);
      final r = cadastroAoCriar(
        _cadastro(cargas: [carga(matematica.id, 2)]),
        nova: nova,
        aulasDoCurso: const [],
        naCelula: const [],
      );
      expect(r.cargaDe(_redes.id)!.quantidadeAulas, 1);
      expect(r.cargaDe(_redes.id)!.tamanhoBloco, 1);
      expect(r.cargaDe(matematica.id)!.quantidadeAulas, 2, reason: 'não muda');
    });

    test('carga completa sobe 1', () {
      final ja = aula(dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id);
      final r = cadastroAoCriar(
        _cadastro(cargas: [carga(matematica.id, 1)]),
        nova: aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        aulasDoCurso: [ja],
        naCelula: const [],
      );
      expect(r.cargaDe(matematica.id)!.quantidadeAulas, 2);
    });

    test('se ainda faltava aula, a carga não muda', () {
      final r = cadastroAoCriar(
        _cadastro(cargas: [carga(matematica.id, 3)]),
        nova: aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
        aulasDoCurso: const [],
        naCelula: const [],
      );
      expect(r.cargaDe(matematica.id)!.quantidadeAulas, 3);
    });
  });

  group('Criar outro grupo atualiza o par (aula antiga + nova)', () {
    test('matérias sem par: cria o par com 1 de cada em 1 bloco', () {
      final antiga = aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final r = cadastroAoCriar(
        _cadastro(cargas: [carga(informatica.id, 2), carga(matematica.id, 2)]),
        nova: aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id, grupo: 2),
        aulasDoCurso: [antiga],
        naCelula: [antiga],
      );
      final par = r.parDe(informatica.id, matematica.id)!;
      expect(par.quantidadeDe(informatica.id), 1);
      expect(par.quantidadeDe(matematica.id), 1);
      expect(par.quantidadeBlocos, 1);
    });

    test('par existente + aula completa: as duas matérias somam 1', () {
      final antiga = aula(dia: 2, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final r = cadastroAoCriar(
        _cadastro(
          cargas: [carga(informatica.id, 4), carga(ingles.id, 4)],
          pares: [par(informatica.id, ingles.id, aulas: 1, aulasB: 3, blocos: 1)],
        ),
        nova: aula(dia: 2, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
        aulasDoCurso: [antiga],
        naCelula: [antiga],
      );
      final p = r.parDe(informatica.id, ingles.id)!;
      expect(p.quantidadeDe(informatica.id), 2);
      expect(p.quantidadeDe(ingles.id), 4);
    });

    test('par existente + G1 livre: só a matéria nova soma 1', () {
      final cauda = aula(dia: 0, periodo: 2, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2);
      final r = cadastroAoCriar(
        _cadastro(
          cargas: [carga(informatica.id, 4), carga(ingles.id, 4)],
          pares: [par(informatica.id, ingles.id, aulas: 1, aulasB: 3, blocos: 1)],
        ),
        nova: aula(dia: 0, periodo: 2, idMateria: informatica.id, idProfessor: ana.id),
        aulasDoCurso: [cauda],
        naCelula: [cauda],
      );
      final p = r.parDe(informatica.id, ingles.id)!;
      expect(p.quantidadeDe(informatica.id), 2);
      expect(p.quantidadeDe(ingles.id), 3);
    });
  });

  group('Excluir aula diminui a carga e o par', () {
    test('carga desce 1 e o bloco não passa da carga', () {
      final ex = aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id);
      final r = cadastroAoExcluir(
        _cadastro(cargas: [carga(matematica.id, 2, bloco: 2)]),
        excluida: ex,
        naCelula: [ex],
      );
      expect(r.cargaDe(matematica.id)!.quantidadeAulas, 1);
      expect(r.cargaDe(matematica.id)!.tamanhoBloco, 1);
    });

    test('carga chegando a 0: a matéria sai da carga e dos pares', () {
      final ex = aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final r = cadastroAoExcluir(
        _cadastro(
          cargas: [carga(informatica.id, 1), carga(ingles.id, 2)],
          pares: [par(informatica.id, ingles.id, aulas: 1, blocos: 1)],
        ),
        excluida: ex,
        naCelula: [ex],
      );
      expect(r.cargaDe(informatica.id), isNull);
      expect(r.pares, isEmpty);
      expect(r.cargaDe(ingles.id)!.quantidadeAulas, 2);
    });

    test('grupo de um par: a quantidade dele no par desce 1', () {
      final g1 = aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final g2 = aula(dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2);
      final r = cadastroAoExcluir(
        _cadastro(
          cargas: [carga(informatica.id, 3), carga(ingles.id, 3)],
          pares: [par(informatica.id, ingles.id, aulas: 2, aulasB: 3, blocos: 1)],
        ),
        excluida: g1,
        naCelula: [g1, g2],
      );
      final p = r.parDe(informatica.id, ingles.id)!;
      expect(p.quantidadeDe(informatica.id), 1);
      expect(p.quantidadeDe(ingles.id), 3);
    });

    test('quantidade no par chegando a 0: o par deixa de existir', () {
      final g1 = aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final g2 = aula(dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2);
      final r = cadastroAoExcluir(
        _cadastro(
          cargas: [carga(informatica.id, 3), carga(ingles.id, 3)],
          pares: [par(informatica.id, ingles.id, aulas: 1, aulasB: 2, blocos: 1)],
        ),
        excluida: g1,
        naCelula: [g1, g2],
      );
      expect(r.pares, isEmpty);
    });

    test('G2 com G1 livre: desce a matéria maior do par', () {
      final cauda = aula(dia: 0, periodo: 2, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2);
      final r = cadastroAoExcluir(
        _cadastro(
          cargas: [carga(informatica.id, 2), carga(ingles.id, 4)],
          pares: [par(informatica.id, ingles.id, aulas: 2, aulasB: 4, blocos: 1)],
        ),
        excluida: cauda,
        naCelula: [cauda],
      );
      expect(r.parDe(informatica.id, ingles.id)!.quantidadeDe(ingles.id), 3);
      expect(r.cargaDe(ingles.id)!.quantidadeAulas, 3);
    });

    test('aula completa não mexe em par nenhum', () {
      final ex = aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final pares = [par(informatica.id, ingles.id, aulas: 1, blocos: 1)];
      final r = cadastroAoExcluir(
        _cadastro(cargas: [carga(informatica.id, 3), carga(ingles.id, 3)], pares: pares),
        excluida: ex,
        naCelula: [ex],
      );
      expect(r.parDe(informatica.id, ingles.id)!.quantidadeDe(informatica.id), 1);
    });
  });

  group('Página 3: criar e excluir mudam a Página 1', () {
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

    Future<void> abrir(
      WidgetTester tester,
      RepositorioAulaFalso repo, {
      List<CargaCursoMateria>? cargas,
      List<AulaGeminadaCurso> pares = const [],
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
                cargas ?? [carga(informatica.id, 2), carga(matematica.id, 2)],
              ),
            ),
            provedorAulasGeminadasCurso.overrideWith((ref) => Stream.value(pares)),
            provedorMaterias.overrideWith(
              (ref) => Stream.value([...materiasPadrao, _redes]),
            ),
            provedorProfessores.overrideWith(
              (ref) => Stream.value(professoresPadrao),
            ),
            provedorProfessorMaterias.overrideWith(
              (ref) => Stream.value([
                ...ligacoesPadrao,
                ligacao(ana.id, _redes.id),
              ]),
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

    testWidgets('matéria fora da carga aparece e entra na carga ao salvar', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso();
      await abrir(tester, repo);

      await tocar(tester, celulaGrade(0, 0));
      await escolher(tester, 'subject-', 'Redes');
      await escolher(tester, 'prof-', 'Ana');
      await tocar(tester, find.text('Salvar'));

      expect(repo.aulas.single.idMateria, _redes.id);
      expect(repo.ultimoCadastro!.cargaDe(_redes.id)!.quantidadeAulas, 1);
    });

    testWidgets('"Adicionar outro grupo" em aula sem par cria o par', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        aula(id: 'i', dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
      ]);
      await abrir(tester, repo);

      await tocar(tester, celulaGrade(0, 0));
      await tocar(tester, find.text('Adicionar outro grupo'));
      expect(find.text('Nova aula — Seg 1º M · Grupo 2'), findsOneWidget);
      await escolher(tester, 'subject-', 'Matemática');
      await escolher(tester, 'prof-', 'Carla');
      await tocar(tester, find.text('Salvar'));

      expect(repo.aulas, hasLength(2));
      expect(repo.aulas.firstWhere((a) => a.id != 'i').grupo, 2);
      final p = repo.ultimoCadastro!.parDe(informatica.id, matematica.id)!;
      expect((p.quantidadeA, p.quantidadeB, p.quantidadeBlocos), (1, 1, 1));
    });

    testWidgets('excluir aula diminui a carga na Página 1', (tester) async {
      final repo = RepositorioAulaFalso([
        aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      ]);
      await abrir(tester, repo);

      await tocar(tester, celulaGrade(0, 0));
      await tocar(tester, find.text('Editar este grupo'));
      await tocar(tester, find.text('Excluir'));
      await tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));

      expect(repo.aulas, isEmpty);
      expect(repo.ultimoCadastro!.cargaDe(matematica.id)!.quantidadeAulas, 1);
    });

    testWidgets('excluir o último G1 de um par: o outro vira aula completa', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        aula(id: 'i', dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
        aula(id: 'e', dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2),
      ]);
      await abrir(
        tester,
        repo,
        cargas: [carga(informatica.id, 2), carga(ingles.id, 2)],
        pares: [par(informatica.id, ingles.id, aulas: 1, blocos: 1)],
      );

      await tocar(tester, celulaGrade(0, 0));
      await tocar(tester, find.text('Grupo 1 — Informática'));
      await tocar(tester, find.text('Excluir'));
      await tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));

      expect(repo.ultimoCadastro!.pares, isEmpty);
      final sobra = repo.aulas.single;
      expect(sobra.id, 'e');
      expect(sobra.grupo, 1, reason: 'sem par, vira turma inteira');
    });

    testWidgets('se o banco falhar, nada muda e o erro aparece', (tester) async {
      final repo = RepositorioAulaFalso()..falhasAoSalvarComCadastro = 1;
      await abrir(tester, repo);

      await tocar(tester, celulaGrade(0, 0));
      await escolher(tester, 'subject-', 'Matemática');
      await escolher(tester, 'prof-', 'Carla');
      await tocar(tester, find.text('Salvar'));

      expect(repo.aulas, isEmpty);
      expect(repo.ultimoCadastro, isNull);
      expect(find.textContaining('falha simulada'), findsOneWidget);
    });
  });

  group('Botões (?) de Bloco e Blocos', () {
    Future<void> montar(WidgetTester tester, Widget botao) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: botao))));
    }

    testWidgets('Bloco explica com exemplo e mini grade', (tester) async {
      await montar(tester, const BotaoAjudaBloco());
      await tester.tap(find.byTooltip('O que é Bloco?'));
      await tester.pumpAndSettle();

      expect(find.text('O que é "Bloco"?'), findsOneWidget);
      expect(find.textContaining('uma atrás da outra'), findsOneWidget);
      expect(find.text('Matemática'), findsNWidgets(4));
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.text('O que é "Bloco"?'), findsNothing);
    });

    testWidgets('Blocos da geminada mostra os grupos e o G1 livre', (
      tester,
    ) async {
      await montar(tester, const BotaoAjudaBlocosGeminada());
      await tester.tap(find.byTooltip('O que é Blocos?'));
      await tester.pumpAndSettle();

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
          ExportadorHorarioPdf.turnosDoCurso(curso(preferencia: preferencia), const {}),
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
              aula(dia: 0, periodo: 13, idMateria: matematica.id, idProfessor: carla.id),
            ],
          },
        ),
        [manha, tarde, noite],
      );
    });
  });

  test('par: mudar a quantidade de uma matéria mantém os blocos', () {
    final p = par(informatica.id, ingles.id, aulas: 4, aulasB: 4, blocos: 2);
    final menor = p.comQuantidade(informatica.id, 1);
    expect((menor.quantidadeA, menor.quantidadeB, menor.quantidadeBlocos), (1, 4, 2));
    final tudoMenor = menor.comQuantidade(ingles.id, 1);
    expect(tudoMenor.quantidadeBlocos, 1, reason: 'blocos não passam do total');
  });

  test('Aula ainda converte para o banco com o grupo', () {
    final a = Aula(
      id: '1',
      idCurso: '2',
      indiceDia: 0,
      indicePeriodo: 15,
      idMateria: '10',
      idProfessor: '20',
      grupo: 2,
    );
    expect(a.toInsertJson()['periodo'], 16);
    expect(a.toInsertJson()['grupo'], 2);
  });
}
