import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/pages/page1/columns/coluna_curso.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/repositories/repositorio_curso.dart';

import 'apoio/dados.dart';

/// Repositório de curso que responde da memória (sem rede).
class _RepositorioCursoFalso implements RepositorioCurso {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<CargaCursoMateria>> buscarCargas(String idCurso) async => [
    carga(matematica.id, 4),
  ];

  @override
  Future<List<AulaGeminadaCurso>> buscarAulasGeminadas(String idCurso) async =>
      const [];
}

void main() {
  testWidgets('o lápis do curso abre o formulário de edição', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          provedorRepositorioCurso.overrideWithValue(_RepositorioCursoFalso()),
          provedorCursos.overrideWith((ref) => Stream.value([curso()])),
          provedorCargasCurso.overrideWith(
            (ref) => Stream.value([carga(matematica.id, 4)]),
          ),
          provedorAulasGeminadasCurso.overrideWith(
            (ref) => Stream.value(const []),
          ),
          provedorSalas.overrideWith((ref) => Stream.value(salasPadrao)),
          provedorMaterias.overrideWith((ref) => Stream.value(materiasPadrao)),
          provedorAulas.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Row(children: [ColunaCurso()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Singular quando é 1 (antes aparecia "1 componentes").
    expect(find.textContaining('1 componente · 4 aulas'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar curso'), findsOneWidget);
  });
}
