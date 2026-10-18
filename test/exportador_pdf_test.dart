import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/services/exportador_horario_pdf.dart';

import 'apoio/dados.dart';

Aula _mat(int periodo, {String? idProfessor, String? idSala}) => aula(
  dia: 0,
  periodo: periodo,
  idMateria: matematica.id,
  idProfessor: idProfessor ?? carla.id,
  idSala: idSala,
);

List<(int, int)> _trechos(List<List<Aula>> celulas) => [
  for (final s in agruparAulasSeguidas(celulas)) (s.inicio, s.tamanho),
];

void main() {
  group('PDF: aulas seguidas viram uma só', () {
    test('mesma matéria e professor em horários seguidos ocupa o espaço de 2', () {
      expect(
        _trechos([
          [_mat(0)],
          [_mat(1)],
          [],
          [],
          [],
          [],
        ]),
        [(0, 2), (2, 1), (3, 1), (4, 1), (5, 1)],
      );
    });

    test('professor diferente não junta', () {
      expect(
        _trechos([
          [_mat(0)],
          [_mat(1, idProfessor: diego.id)],
        ]),
        [(0, 1), (1, 1)],
      );
    });

    test('sala diferente não junta', () {
      expect(
        _trechos([
          [_mat(0, idSala: sala1.id)],
          [_mat(1, idSala: lab1.id)],
        ]),
        [(0, 1), (1, 1)],
      );
    });

    test('horário vazio no meio separa', () {
      expect(
        _trechos([
          [_mat(0)],
          [],
          [_mat(2)],
        ]),
        [(0, 1), (1, 1), (2, 1)],
      );
    });

    test('conjunto geminado de 4 horários vira um bloco só', () {
      List<Aula> geminada(int p) => [
        aula(dia: 0, periodo: p, idMateria: informatica.id, idProfessor: ana.id),
        aula(
          dia: 0,
          periodo: p,
          idMateria: ingles.id,
          idProfessor: bruno.id,
          grupo: 2,
        ),
      ];
      final segmentos = agruparAulasSeguidas([
        geminada(0),
        geminada(1),
        geminada(2),
        geminada(3),
        [],
        [],
      ]);
      expect(segmentos.first.tamanho, 4);
      expect(segmentos.first.aulas, hasLength(2));
    });
  });

  test('gera o PDF de uma turma com aulas juntadas', () async {
    final bytes = await const ExportadorHorarioPdf().gerar(
      cursos: [curso(idSala: sala1.id)],
      aulas: [
        _mat(0),
        _mat(1),
        aula(dia: 1, periodo: 6, idMateria: informatica.id, idProfessor: ana.id),
        aula(
          dia: 1,
          periodo: 6,
          idMateria: ingles.id,
          idProfessor: bruno.id,
          grupo: 2,
        ),
      ],
      materias: materiasPadrao,
      professores: professoresPadrao,
      salas: salasPadrao,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
