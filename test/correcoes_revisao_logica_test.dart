import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_curso.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/pages/page3/helpers/formato_horario.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';
import 'package:flutter_test_project/pages/page3/page3.dart';
import 'package:flutter_test_project/pages/page3/widgets/celula_horario.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/exportador_horario_pdf.dart';
import 'package:flutter_test_project/services/gerador_horario.dart';
import 'package:flutter_test_project/services/impacto_edicao_curso.dart';

import 'apoio/dados.dart';
import 'apoio/repositorio_aula_falso.dart';

final _par = par(informatica.id, ingles.id, aulas: 2, blocos: 1);

String? _validar({
  required List<Aula> aulas,
  required String idMateria,
  required String idProfessor,
  Aula? existente,
  List<CargaCursoMateria>? cargas,
}) => validarSalvarAula(
  curso: curso(),
  celula: celula(0, 0),
  idMateria: idMateria,
  idProfessor: idProfessor,
  idSala: null,
  existente: existente,
  grupo: existente?.grupo ?? 1,
  cargas: cargas ?? [carga(matematica.id, 2), carga(informatica.id, 4)],
  aulasGeminadas: const [],
  todasAulas: aulas,
  ligacoes: ligacoesPadrao,
  indisponibilidades: const [],
);

/// Abre a Página 3 com dados em memória e seleciona o "Info 1".
Future<void> _abrirPagina3(
  WidgetTester tester, {
  required RepositorioAulaFalso repo,
  List<AulaGeminadaCurso> pares = const [],
  List<IndisponibilidadeProfessor> indisponibilidades = const [],
}) async {
  tester.view.physicalSize = const Size(1600, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        provedorRepositorioAula.overrideWithValue(repo),
        provedorCursos.overrideWith((ref) => Stream.value([curso()])),
        provedorCargasCurso.overrideWith(
          (ref) => Stream.value([
            carga(informatica.id, 4),
            carga(ingles.id, 4),
            carga(matematica.id, 4),
          ]),
        ),
        provedorAulasGeminadasCurso.overrideWith((ref) => Stream.value(pares)),
        provedorMaterias.overrideWith((ref) => Stream.value(materiasPadrao)),
        provedorProfessores.overrideWith(
          (ref) => Stream.value(professoresPadrao),
        ),
        provedorProfessorMaterias.overrideWith(
          (ref) => Stream.value(ligacoesPadrao),
        ),
        provedorIndisponibilidades.overrideWith(
          (ref) => Stream.value(indisponibilidades),
        ),
        provedorSalas.overrideWith((ref) => Stream.value(salasPadrao)),
        provedorHorariosPeriodo.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: Page3()),
    ),
  );
  await _esperar(tester);
  await tester.tap(find.text('Info 1'));
  await _esperar(tester);
}

Future<void> _esperar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.tap(alvo);
  await _esperar(tester);
}

Finder _celula(int dia, int periodo) => find.byWidgetPredicate(
  (w) => w is CelulaHorario && w.celula == celula(dia, periodo),
);

void main() {
  group('1. Carga reduzida não trava a edição', () {
    // 3 aulas de Matemática na grade, mas a carga caiu para 2.
    final aulas = [
      aula(id: 'm0', dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      aula(id: 'm1', dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      aula(id: 'm2', dia: 2, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
    ];

    test('trocar o professor de uma aula que já existe é aceito', () {
      expect(
        _validar(
          aulas: aulas,
          existente: aulas.first,
          idMateria: matematica.id,
          idProfessor: diego.id,
        ),
        isNull,
      );
    });

    test('aula nova do componente continua bloqueada', () {
      expect(
        _validar(
          aulas: aulas.skip(1).toList(),
          idMateria: matematica.id,
          idProfessor: diego.id,
        ),
        'Carga completa para este componente (2 aula(s)).',
      );
    });

    test('trocar para um componente com a carga completa é bloqueado', () {
      final info = aula(id: 'i0', dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      expect(
        _validar(
          aulas: [info, ...aulas.skip(1)],
          existente: info,
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
        'Carga completa para este componente (2 aula(s)).',
      );
    });
  });

  group('2. Grupo da aula que sobra ao excluir', () {
    final g1 = aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
    final g2 = aula(dia: 0, periodo: 0, idMateria: ingles.id, idProfessor: bruno.id, grupo: 2);

    test('com o par cadastrado, a que sobra fica no G2 (G1 livre)', () {
      expect(
        grupoDaQueSobra(idCurso: '1', excluida: g2, restante: g1, aulasGeminadas: [_par]),
        2,
      );
    });

    test('sem o par, a que sobra vira aula comum (G1)', () {
      expect(
        grupoDaQueSobra(idCurso: '1', excluida: g1, restante: g2, aulasGeminadas: const []),
        1,
      );
    });

    testWidgets('pela tela: par tirado na Página 1, excluir uma deixa a '
        'outra como aula comum', (tester) async {
      final repo = RepositorioAulaFalso([g1, g2]);
      await _abrirPagina3(tester, repo: repo);

      await _tocar(tester, _celula(0, 0));
      await _tocar(tester, find.text('Grupo 1 — Informática'));
      await _tocar(tester, find.text('Excluir'));
      await _tocar(tester, find.widgetWithText(FilledButton, 'Excluir'));

      final sobra = repo.aulas.single;
      expect(sobra.idMateria, ingles.id);
      expect(sobra.grupo, 1);
    });
  });

  group('4. Aula sozinha no G2 que deixa de ser de aula dividida', () {
    test('troca para componente sem par: vira aula comum (G1)', () {
      expect(
        grupoAoSalvar(
          idCurso: '1',
          idMateria: matematica.id,
          grupoAtual: 2,
          outrasNaCelula: const [],
          aulasGeminadas: [_par],
        ),
        1,
      );
    });

    test('componente de um par: continua no G2', () {
      expect(
        grupoAoSalvar(
          idCurso: '1',
          idMateria: ingles.id,
          grupoAtual: 2,
          outrasNaCelula: const [],
          aulasGeminadas: [_par],
        ),
        2,
      );
    });

    test('com outra aula na célula, o grupo não muda', () {
      expect(
        grupoAoSalvar(
          idCurso: '1',
          idMateria: matematica.id,
          grupoAtual: 2,
          outrasNaCelula: [aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id)],
          aulasGeminadas: const [],
        ),
        2,
      );
    });
  });

  group('5. Aviso do professor atual indisponível', () {
    test('indisponível na Página 2', () {
      expect(
        avisoProfessorNaCelula(
          idProfessor: carla.id,
          celula: celula(0, 0),
          indisponibilidades: [indisponivel(carla.id, dia: 0, periodo: 0)],
          todasAulas: const [],
        ),
        startsWith('O professor atual está indisponível'),
      );
    });

    test('em outra aula no mesmo horário', () {
      expect(
        avisoProfessorNaCelula(
          idProfessor: carla.id,
          celula: celula(0, 0),
          indisponibilidades: const [],
          todasAulas: [
            aula(idCurso: '2', dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
          ],
        ),
        startsWith('O professor atual já está em outra aula'),
      );
    });

    testWidgets('o diálogo mostra o aviso em laranja e não deixa salvar', (
      tester,
    ) async {
      final repo = RepositorioAulaFalso([
        aula(id: 'm', dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      ]);
      await _abrirPagina3(
        tester,
        repo: repo,
        indisponibilidades: [indisponivel(carla.id, dia: 0, periodo: 0)],
      );

      await _tocar(tester, _celula(0, 0));
      expect(find.byKey(const ValueKey('aviso-professor')), findsOneWidget);
      await _tocar(tester, find.text('Salvar'));
      expect(find.text('Professor indisponível neste horário (Disponibilidade).'), findsOneWidget);
      expect(repo.aulas.single.idProfessor, carla.id);
    });
  });

  group('6 e 7. Aviso ao salvar o curso', () {
    final aulas = [
      aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      aula(dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
      aula(dia: 0, periodo: 1, idMateria: informatica.id, idProfessor: ana.id),
    ];
    final nomes = {for (final m in materiasPadrao) m.id: m.nome};

    test('componente tirado da carga: diz quantas aulas serão apagadas', () {
      final impacto = impactoEdicaoCurso(
        idCurso: '1',
        turnoAntigo: PreferenciaPeriodo.manha,
        turnoNovo: PreferenciaPeriodo.manha,
        cargasNovas: [carga(informatica.id, 4)],
        aulas: aulas,
        nomesComponentes: nomes,
      );
      expect(impacto.aulasApagadas, 2);
      expect(impacto.mensagem, contains('2 aula(s) de Matemática serão apagadas'));
    });

    test('turno mudou: avisa as aulas que ficam fora dele', () {
      final impacto = impactoEdicaoCurso(
        idCurso: '1',
        turnoAntigo: PreferenciaPeriodo.manha,
        turnoNovo: PreferenciaPeriodo.noite,
        cargasNovas: [carga(informatica.id, 4), carga(matematica.id, 4)],
        aulas: aulas,
        nomesComponentes: nomes,
      );
      expect(impacto.aulasApagadas, 0);
      expect(impacto.aulasForaDoTurno, 3);
      expect(impacto.mensagem, contains('fora do novo turno'));
    });

    test('nada muda na grade: sem aviso', () {
      final impacto = impactoEdicaoCurso(
        idCurso: '1',
        turnoAntigo: PreferenciaPeriodo.manha,
        turnoNovo: PreferenciaPeriodo.manha,
        cargasNovas: [carga(informatica.id, 4), carga(matematica.id, 4)],
        aulas: aulas,
        nomesComponentes: nomes,
      );
      expect(impacto.mensagem, isNull);
    });
  });

  group('8. Formulário do curso', () {
    Future<_Abertura> abrir(
      WidgetTester tester, {
      Future<bool> Function(ResultadoFormularioCurso)? confirmar,
    }) async {
      final abertura = _Abertura();
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => abertura.resultado =
                    await mostrarDialogoFormularioCurso(
                      context,
                      titulo: 'Editar curso',
                      materias: materiasPadrao,
                      salas: salasPadrao,
                      nomeInicial: 'Info 1',
                      preferenciaPeriodoInicial: PreferenciaPeriodo.manha,
                      cargasIniciais: [carga(matematica.id, 4, bloco: 4)],
                      idCurso: '1',
                      confirmarAntesDeSalvar: confirmar,
                    ),
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

    Finder campoQuantidade() =>
        find.widgetWithText(TextField, 'Qtd. de aulas').first;

    testWidgets('apagar a quantidade para digitar outra mantém o bloco', (
      tester,
    ) async {
      final abertura = await abrir(tester);
      await tester.enterText(campoQuantidade(), '');
      await tester.pump();
      await tester.enterText(campoQuantidade(), '6');
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final c = abertura.resultado!.cargas.single;
      expect((c.quantidadeAulas, c.tamanhoBloco), (6, 4));
    });

    testWidgets('trocar o turno para Noite e voltar não perde o bloco', (
      tester,
    ) async {
      final abertura = await abrir(tester);
      await tester.enterText(campoQuantidade(), '6');
      await tester.pump();
      await tester.tap(find.text('Manhã'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Noite').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Noite'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manhã').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(abertura.resultado!.cargas.single.tamanhoBloco, 4);
    });

    testWidgets('na Noite, o bloco salvo encolhe para 4', (tester) async {
      final abertura = await abrir(tester);
      await tester.enterText(campoQuantidade(), '6');
      await tester.pump();
      await tester.tap(find.text('Manhã'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Noite').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(abertura.resultado!.cargas.single.tamanhoBloco, 4);
    });

    testWidgets('confirmação recusada deixa o formulário aberto', (
      tester,
    ) async {
      var perguntou = false;
      final abertura = await abrir(
        tester,
        confirmar: (_) async {
          perguntou = true;
          return false;
        },
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(perguntou, isTrue);
      expect(find.text('Editar curso'), findsOneWidget);
      expect(abertura.resultado, isNull);
    });
  });

  group('10, 11 e 12. Gerador', () {
    ResultadoGeracao gerar({
      PreferenciaPeriodo turno = PreferenciaPeriodo.manha,
      required List<CargaCursoMateria> cargas,
      List<IndisponibilidadeProfessor> indisponibilidades = const [],
    }) => const GeradorHorario().gerar(
      curso: curso(preferencia: turno),
      cargas: cargas,
      professores: professoresPadrao,
      ligacoes: ligacoesPadrao,
      indisponibilidades: indisponibilidades,
      aulasExistentes: const [],
      nomesMaterias: {for (final m in materiasPadrao) m.id: m.nome},
    );

    test('mantém o mesmo professor nos blocos do componente', () {
      // Carla não pode no começo da manhã de terça: antes o 2º bloco ia
      // para o Diego em vez de procurar outro horário para a Carla.
      final r = gerar(
        cargas: [carga(matematica.id, 4, bloco: 2)],
        indisponibilidades: [
          indisponivel(carla.id, dia: 1, periodo: 0),
          indisponivel(carla.id, dia: 1, periodo: 1),
        ],
      );
      expect(r.novasAulas, hasLength(4));
      expect(r.novasAulas.map((a) => a.idProfessor).toSet(), {carla.id});
    });

    test('bloco que não cabe é dividido em blocos menores (com aviso)', () {
      // Noite, bloco 4, mas a Carla e o Diego nunca podem no 3º horário.
      final r = gerar(
        turno: PreferenciaPeriodo.noite,
        cargas: [carga(matematica.id, 4, bloco: 4)],
        indisponibilidades: [
          for (var dia = 0; dia < 5; dia++) ...[
            indisponivel(carla.id, dia: dia, periodo: 14),
            indisponivel(diego.id, dia: dia, periodo: 14),
          ],
        ],
      );
      expect(r.novasAulas, hasLength(4));
      expect(
        r.falhas,
        contains(
          'Matemática: 4 aula(s) ficaram em blocos menores que 4 '
          '(o bloco inteiro não coube).',
        ),
      );
    });

    test('curso sem carga não conta como falha', () {
      final r = gerar(cargas: const []);
      expect(r.falhas, isEmpty);
      expect(r.completo, isTrue);
    });
  });

  group('13 e 14. PDF', () {
    final mapaSalas = {for (final s in salasPadrao) s.id: s};

    test('imprime a sala só quando é diferente da sala padrão', () {
      Aula comSala(String? id) => aula(
        dia: 0,
        periodo: 0,
        idMateria: matematica.id,
        idProfessor: carla.id,
        idSala: id,
      );
      String sala(Aula a) => ExportadorHorarioPdf.salaParaImprimir(
        a,
        idSalaPadrao: sala1.id,
        salas: mapaSalas,
      );
      expect(sala(comSala(sala1.id)), '');
      expect(sala(comSala(null)), '');
      expect(sala(comSala(lab1.id)), lab1.rotulo);
    });

    test('ordena os nomes sem diferenciar acentos e maiúsculas', () {
      final nomes = ['Zoologia', 'Álgebra', 'algoritmos', 'Biologia']
        ..sort(
          (a, b) => ExportadorHorarioPdf.chaveOrdenacao(a).compareTo(
            ExportadorHorarioPdf.chaveOrdenacao(b),
          ),
        );
      expect(nomes, ['Álgebra', 'algoritmos', 'Biologia', 'Zoologia']);
    });
  });

  group('15 e 16. Campo de horário', () {
    test('colar horário mais curto por cima de um já preenchido', () {
      const antigo = TextEditingValue(
        text: '07:30 - 08:20',
        selection: TextSelection(baseOffset: 0, extentOffset: 13),
      );
      const novo = TextEditingValue(
        text: '9:10 - 9:55',
        selection: TextSelection.collapsed(offset: 11),
      );
      expect(
        const MascaraHorarioFormatter().formatEditUpdate(antigo, novo).text,
        '09:10 - 09:55',
      );
    });

    test('colar só números no fim continua funcionando', () {
      const antigo = TextEditingValue(
        text: '07:30 - ',
        selection: TextSelection.collapsed(offset: 8),
      );
      const novo = TextEditingValue(
        text: '07:30 - 0820',
        selection: TextSelection.collapsed(offset: 12),
      );
      expect(
        const MascaraHorarioFormatter().formatEditUpdate(antigo, novo).text,
        '07:30 - 08:20',
      );
    });

    test('fim antes do início é recusado', () {
      expect(validarHorario('10:00 - 08:00'), 'O fim deve ser depois do início');
      expect(validarHorario('07:30 - 08:20'), isNull);
    });
  });

}

class _Abertura {
  ResultadoFormularioCurso? resultado;
}
