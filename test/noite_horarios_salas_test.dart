import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_numero.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/horario/horario_periodo.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/pages/page3/page3.dart';
import 'package:flutter_test_project/pages/page3/widgets/campo_horario_periodo.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/exportador_horario_pdf.dart';
import 'package:flutter_test_project/services/gerador_horario.dart';
import 'package:flutter_test_project/services/repositories/repositorio_horario_periodo.dart';
import 'package:flutter_test_project/services/validador_horario.dart';

import 'apoio/dados.dart';
import 'apoio/repositorio_aula_falso.dart';

/// Guarda os horários em memória, sem Supabase.
class _RepositorioHorarioFalso implements RepositorioHorarioPeriodo {
  final Map<int, String> salvos = {};

  @override
  Stream<List<HorarioPeriodo>> observarTodos() => Stream.value([
    for (final e in salvos.entries)
      HorarioPeriodo(indicePeriodo: e.key, texto: e.value),
  ]);

  @override
  Future<List<HorarioPeriodo>> buscarTodos() async => [];

  @override
  Future<void> salvar(HorarioPeriodo horario) async {
    salvos[horario.indicePeriodo] = horario.texto;
  }
}

void main() {
  group('Noite', () {
    test('a grade tem 16 períodos: 6 manhã, 6 tarde e 4 noite', () {
      expect(GradeHoraria.periodos, hasLength(16));
      expect(GradeHoraria.periodosNoite, [12, 13, 14, 15]);
      expect(GradeHoraria.periodos[12], '1º N');
      expect(GradeHoraria.faixaDoPeriodo(11), 1);
      expect(GradeHoraria.faixaDoPeriodo(12), 2);
      expect(GradeHoraria.periodosNaMesmaFaixa(11, 12), isFalse);
    });

    test('turma noturna só recebe aulas na noite', () {
      final r = const GeradorHorario().gerarTodos(
        cursos: [curso(preferencia: PreferenciaPeriodo.noite)],
        cargas: [carga(matematica.id, 6, bloco: 2), carga(ingles.id, 4)],
        professores: professoresPadrao,
        ligacoes: ligacoesPadrao,
        indisponibilidades: const [],
      );
      expect(r.falhas, isEmpty);
      expect(r.novasAulas, hasLength(10));
      for (final a in r.novasAulas) {
        expect(a.indicePeriodo, inInclusiveRange(12, 15));
      }
    });

    test('bloco de 4 cabe inteiro na noite', () {
      final r = const GeradorHorario().gerarTodos(
        cursos: [curso(preferencia: PreferenciaPeriodo.noite)],
        cargas: [carga(matematica.id, 4, bloco: 4)],
        professores: professoresPadrao,
        ligacoes: ligacoesPadrao,
        indisponibilidades: const [],
      );
      expect(r.falhas, isEmpty);
      expect(r.novasAulas.map((a) => a.indicePeriodo).toSet(), {12, 13, 14, 15});
    });

    test('turma diurna não usa a noite', () {
      final r = const GeradorHorario().gerarTodos(
        cursos: [curso()],
        cargas: [carga(matematica.id, 12)],
        professores: professoresPadrao,
        ligacoes: ligacoesPadrao,
        indisponibilidades: const [],
      );
      for (final a in r.novasAulas) {
        expect(a.indicePeriodo, lessThan(12));
      }
    });

    test('validador avisa aula de dia em turma noturna (e vice-versa)', () {
      List<String> problemas(Curso turma, int periodo) => const ValidadorHorario()
          .validarCurso(
            idCurso: '1',
            todasAulas: [
              aula(dia: 0, periodo: periodo, idMateria: matematica.id, idProfessor: carla.id),
            ],
            cursos: [turma],
            cargas: [carga(matematica.id, 1)],
            aulasGeminadas: const [],
            professores: professoresPadrao,
            materias: materiasPadrao,
            salas: salasPadrao,
            indisponibilidades: const [],
          )
          .problemas;

      final noturna = curso(preferencia: PreferenciaPeriodo.noite);
      expect(problemas(noturna, 0), contains('Aula fora do período da turma (Seg 1º M)'));
      expect(problemas(noturna, 12), isEmpty);
      expect(problemas(curso(), 12), contains('Aula fora do período da turma (Seg 1º N)'));
    });

    group('PDF: quais turnos aparecem', () {
      Map<CelulaGrade, List<Aula>> comAulaEm(List<int> periodos) => {
        for (final p in periodos)
          celula(0, p): [
            aula(dia: 0, periodo: p, idMateria: matematica.id, idProfessor: carla.id),
          ],
      };
      final manha = GradeHoraria.periodosManha;
      final tarde = GradeHoraria.periodosTarde;
      final noite = GradeHoraria.periodosNoite;

      test('turma diurna sem aula à noite: só manhã e tarde', () {
        expect(
          ExportadorHorarioPdf.turnosDoCurso(curso(), comAulaEm([0, 7])),
          [manha, tarde],
        );
      });

      test('turma diurna com aula à noite: aparece o Jantar e a noite', () {
        expect(
          ExportadorHorarioPdf.turnosDoCurso(curso(), comAulaEm([0, 14])),
          [manha, tarde, noite],
        );
      });

      test('turma noturna: só a noite', () {
        expect(
          ExportadorHorarioPdf.turnosDoCurso(
            curso(preferencia: PreferenciaPeriodo.noite),
            comAulaEm([12]),
          ),
          [noite],
        );
      });

      test('turma noturna com aula de dia: o turno da aula também aparece', () {
        expect(
          ExportadorHorarioPdf.turnosDoCurso(
            curso(preferencia: PreferenciaPeriodo.noite),
            comAulaEm([8, 12]),
          ),
          [tarde, noite],
        );
      });
    });

    test('PDF: grade com e sem noite cabe na página A4 deitada', () {
      for (final (linhas, separadores) in [(12, 1), (16, 2), (4, 0)]) {
        for (final comSala in [false, true]) {
          final linha = ExportadorHorarioPdf.alturaLinhaParaCaber(
            quantidadeLinhas: linhas,
            quantidadeSeparadores: separadores,
            comSalaPadrao: comSala,
          );
          // margens 24+24, título 24, sala 18, espaço 12, cabeçalho 18,
          // separadores de 14.
          final total =
              48 + 24 + (comSala ? 18 : 0) + 12 + 18 + separadores * 14 +
              linhas * linha;
          expect(total, lessThanOrEqualTo(595.28));
        }
      }
      // Sem a noite as linhas continuam com a altura de antes.
      expect(
        ExportadorHorarioPdf.alturaLinhaParaCaber(
          quantidadeLinhas: 12,
          quantidadeSeparadores: 1,
          comSalaPadrao: true,
        ),
        34,
      );
    });

    test('PDF com turma noturna e horários é gerado', () async {
      final bytes = await const ExportadorHorarioPdf().gerar(
        cursos: [curso(preferencia: PreferenciaPeriodo.noite)],
        aulas: [
          aula(dia: 0, periodo: 12, idMateria: matematica.id, idProfessor: carla.id),
        ],
        materias: materiasPadrao,
        professores: professoresPadrao,
        salas: salasPadrao,
        horarios: {12: '19:00 – 19:45'},
      );
      expect(bytes, isNotEmpty);
    });
  });

  group('Horários dos períodos (Página 3)', () {
    Future<void> abrir(
      WidgetTester tester,
      _RepositorioHorarioFalso repoHorarios,
    ) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            provedorRepositorioAula.overrideWithValue(RepositorioAulaFalso()),
            provedorRepositorioHorarioPeriodo.overrideWithValue(repoHorarios),
            provedorCursos.overrideWith(
              (ref) => Stream.value([
                curso(),
                curso(id: '2', nome: 'Info 2'),
              ]),
            ),
            provedorCargasCurso.overrideWith((ref) => Stream.value(const [])),
            provedorAulasGeminadasCurso.overrideWith(
              (ref) => Stream.value(const []),
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
          ],
          child: const MaterialApp(home: Page3()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    Finder campo(int indicePeriodo) => find.descendant(
      of: find.byKey(ValueKey('horario-$indicePeriodo')),
      matching: find.byType(TextField),
    );

    testWidgets('editar o texto salva o horário do período', (tester) async {
      final repo = _RepositorioHorarioFalso();
      await abrir(tester, repo);
      await tester.tap(find.text('Info 1'));
      await tester.pump(const Duration(milliseconds: 300));

      // 16 períodos editáveis, inclusive os da noite.
      expect(find.byType(CampoHorarioPeriodo), findsNWidgets(16));

      await tester.enterText(campo(0), '07:30 – 08:20');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.salvos, {0: '07:30 – 08:20'});
    });

    testWidgets('o horário vale para todas as turmas', (tester) async {
      final repo = _RepositorioHorarioFalso()..salvos[12] = '19:00 – 19:45';
      await abrir(tester, repo);

      for (final turma in ['Info 1', 'Info 2']) {
        await tester.tap(find.text(turma));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.widget<TextField>(campo(12)).controller!.text,
          '19:00 – 19:45',
        );
      }
    });

    testWidgets('aceita qualquer texto, sem validar', (tester) async {
      final repo = _RepositorioHorarioFalso();
      await abrir(tester, repo);
      await tester.tap(find.text('Info 1'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(campo(6), '7:50 até 8:00 (?)');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.salvos[6], '7:50 até 8:00 (?)');
    });
  });

  group('Tipos de sala', () {
    testWidgets('criar o tipo "Quadra" no diálogo e salvar a sala', (
      tester,
    ) async {
      final criados = <String>[];
      DadosSala? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await mostrarDialogoNumero(
                  context,
                  titulo: 'Nova sala',
                  tipos: const [tipoSalaAula, tipoLaboratorio],
                  aoCriarTipo: (nome) async {
                    criados.add(nome);
                    return TipoSala(id: '9', nome: nome);
                  },
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Novo tipo de sala'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Novo tipo (ex.: Quadra)'),
        'Quadra',
      );
      await tester.tap(find.byTooltip('Criar tipo'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Número'), '1');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(criados, ['Quadra']);
      expect(resultado!.tipo, const TipoSala(id: '9', nome: 'Quadra'));
      expect(resultado!.numero, 1);
    });

    testWidgets('os tipos que já existem continuam na lista', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => mostrarDialogoNumero(
                context,
                titulo: 'Nova sala',
                tipos: const [tipoSalaAula, tipoLaboratorio, tipoQuadra],
                aoCriarTipo: (nome) async => TipoSala(id: '9', nome: nome),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<TipoSala>));
      await tester.pumpAndSettle();

      expect(find.text('Laboratório de informática'), findsWidgets);
      expect(find.text('Quadra'), findsWidgets);
    });
  });
}
