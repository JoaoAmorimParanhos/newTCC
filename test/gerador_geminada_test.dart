import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/services/gerador_horario.dart';

import 'apoio/dados.dart';

ResultadoGeracaoCompleta _gerar({
  Curso? turma,
  required List<CargaCursoMateria> cargas,
  required List<AulaGeminadaCurso> pares,
  List<Professor>? professores,
  List<IndisponibilidadeProfessor> indisponibilidades = const [],
}) {
  return const GeradorHorario().gerarTodos(
    cursos: [turma ?? curso()],
    cargas: cargas,
    professores: professores ?? professoresPadrao,
    ligacoes: ligacoesPadrao,
    indisponibilidades: indisponibilidades,
    aulasGeminadas: pares,
  );
}

/// Horários (dia, período) em que Informática (G1) e Inglês (G2) estão juntos.
List<(int, int)> _horariosJuntos(List<Aula> aulas) {
  final resultado = <(int, int)>[];
  for (final a in aulas.where((a) => a.idMateria == informatica.id)) {
    final outra = aulas.where(
      (b) =>
          b.idMateria == ingles.id &&
          b.indiceDia == a.indiceDia &&
          b.indicePeriodo == a.indicePeriodo,
    );
    if (outra.isNotEmpty) resultado.add((a.indiceDia, a.indicePeriodo));
  }
  resultado.sort((x, y) {
    final dia = x.$1.compareTo(y.$1);
    return dia != 0 ? dia : x.$2.compareTo(y.$2);
  });
  return resultado;
}

/// Agrupa horários juntos em blocos de períodos seguidos no mesmo dia.
List<List<(int, int)>> _blocos(List<(int, int)> horarios) {
  final blocos = <List<(int, int)>>[];
  for (final h in horarios) {
    final ultimo = blocos.isEmpty ? null : blocos.last;
    if (ultimo != null &&
        ultimo.last.$1 == h.$1 &&
        ultimo.last.$2 + 1 == h.$2) {
      ultimo.add(h);
    } else {
      blocos.add([h]);
    }
  }
  return blocos;
}

void main() {
  group('Aula geminada: aulas divididas em blocos', () {
    test('8 aulas com Bloco 4 = 2 conjuntos de 4 aulas, em dias diferentes', () {
      final r = _gerar(
        cargas: [
          carga(informatica.id, 8, bloco: 4),
          carga(ingles.id, 8, bloco: 4),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
      );

      expect(r.falhas, isEmpty);
      final juntos = _horariosJuntos(r.novasAulas);
      expect(juntos, hasLength(8));

      final blocos = _blocos(juntos);
      expect(blocos.map((b) => b.length), [4, 4]);
      expect(blocos[0].first.$1, isNot(blocos[1].first.$1));
    });

    test('G1 tem uma matéria e G2 a outra, com professores diferentes', () {
      final r = _gerar(
        cargas: [carga(informatica.id, 4), carga(ingles.id, 4)],
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 2)],
      );

      for (final a in r.novasAulas) {
        if (a.idMateria == informatica.id) {
          expect(a.grupo, 1);
          expect(a.idProfessor, ana.id);
        } else {
          expect(a.grupo, 2);
          expect(a.idProfessor, bruno.id);
        }
      }
    });

    test('5 aulas com Bloco 3 = um bloco de 3 e um de 2', () {
      final r = _gerar(
        cargas: [
          carga(informatica.id, 5, bloco: 3),
          carga(ingles.id, 5, bloco: 3),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 5, blocos: 2)],
      );

      expect(r.falhas, isEmpty);
      final tamanhos = _blocos(_horariosJuntos(r.novasAulas))
          .map((b) => b.length)
          .toList()
        ..sort();
      expect(tamanhos, [2, 3]);
    });

    test('4 aulas com Bloco 1 = 4 aulas soltas em 4 dias', () {
      final r = _gerar(
        cargas: [carga(informatica.id, 4), carga(ingles.id, 4)],
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 4)],
      );

      final juntos = _horariosJuntos(r.novasAulas);
      expect(juntos, hasLength(4));
      expect(juntos.map((h) => h.$1).toSet(), hasLength(4));
    });

    test('4 aulas com Bloco 4 = 4 aulas seguidas no mesmo dia', () {
      final r = _gerar(
        cargas: [
          carga(informatica.id, 4, bloco: 4),
          carga(ingles.id, 4, bloco: 4),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 1)],
      );

      final blocos = _blocos(_horariosJuntos(r.novasAulas));
      expect(blocos, hasLength(1));
      expect(blocos.single, hasLength(4));
    });

    test('usa o Bloco da carga, não o número de blocos guardado no par', () {
      // Caso real: Bloco 3 na carga, mas o par antigo guardava "3 blocos"
      // (que virava 1 + 1 + 1). Agora sai 1 bloco de 3 seguidas.
      final r = _gerar(
        cargas: [
          carga(informatica.id, 3, bloco: 3),
          carga(ingles.id, 3, bloco: 3),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 3, blocos: 3)],
      );

      expect(r.falhas, isEmpty);
      final blocos = _blocos(_horariosJuntos(r.novasAulas));
      expect(blocos.map((b) => b.length), [3]);
    });

    test('com Blocos diferentes nos dois componentes, vale o menor', () {
      final r = _gerar(
        cargas: [
          carga(informatica.id, 4, bloco: 2),
          carga(ingles.id, 4, bloco: 4),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 1)],
      );

      expect(r.falhas, isEmpty);
      final blocos = _blocos(_horariosJuntos(r.novasAulas));
      expect(blocos.map((b) => b.length), [2, 2]);
    });

    test('bloco geminado fica inteiro dentro de um turno', () {
      final r = _gerar(
        cargas: [
          carga(informatica.id, 12, bloco: 6),
          carga(ingles.id, 12, bloco: 6),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 12, blocos: 2)],
      );

      expect(r.falhas, isEmpty);
      for (final bloco in _blocos(_horariosJuntos(r.novasAulas))) {
        final manha = bloco.every((h) => h.$2 < 6);
        final tarde = bloco.every((h) => h.$2 >= 6);
        expect(manha || tarde, isTrue, reason: 'bloco $bloco cruza o almoço');
      }
    });

    test('o resto da carga de cada matéria vai sozinho', () {
      final r = _gerar(
        cargas: [carga(informatica.id, 10), carga(ingles.id, 6)],
        pares: [par(informatica.id, ingles.id, aulas: 4, blocos: 2)],
      );

      expect(r.falhas, isEmpty);
      expect(_horariosJuntos(r.novasAulas), hasLength(4));
      expect(
        r.novasAulas.where((a) => a.idMateria == informatica.id),
        hasLength(10),
      );
      expect(r.novasAulas.where((a) => a.idMateria == ingles.id), hasLength(6));
    });

    test('usa a sala padrão do curso nos dois grupos', () {
      final r = _gerar(
        turma: curso(idSala: sala1.id),
        cargas: [carga(informatica.id, 2), carga(ingles.id, 2)],
        pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
      );

      expect(r.novasAulas, isNotEmpty);
      expect(r.novasAulas.every((a) => a.idSala == sala1.id), isTrue);
    });

    test('respeita a indisponibilidade dos professores', () {
      final r = _gerar(
        cargas: [
          carga(informatica.id, 8, bloco: 4),
          carga(ingles.id, 8, bloco: 4),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 8, blocos: 2)],
        indisponibilidades: [
          ...diaInteiroIndisponivel(ana.id, 0),
          ...diaInteiroIndisponivel(bruno.id, 1),
        ],
      );

      expect(r.falhas, isEmpty);
      final dias = _horariosJuntos(r.novasAulas).map((h) => h.$1).toSet();
      expect(dias.contains(0), isFalse);
      expect(dias.contains(1), isFalse);
    });

    test('falha quando o mesmo professor dá as duas matérias', () {
      final r = const GeradorHorario().gerarTodos(
        cursos: [curso()],
        cargas: [carga(informatica.id, 2), carga(ingles.id, 2)],
        professores: [ana],
        // Ana é a única professora das duas matérias.
        ligacoes: [
          ProfessorMateria(idProfessor: ana.id, idMateria: informatica.id),
          ProfessorMateria(idProfessor: ana.id, idMateria: ingles.id),
        ],
        indisponibilidades: const [],
        aulasGeminadas: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
      );

      expect(
        r.falhas.any((f) => f.contains('dois professores diferentes')),
        isTrue,
      );
    });

    test('falha quando falta professor em uma das matérias', () {
      final r = _gerar(
        professores: [ana],
        cargas: [carga(informatica.id, 2), carga(ingles.id, 2)],
        pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
      );

      expect(r.falhas.any((f) => f.contains('falta professor')), isTrue);
      // A Informática não vira aula da turma inteira: fica faltando.
      expect(r.novasAulas, isEmpty);
    });

    test('bloco que não cabe é dividido; o que sobra fica faltando', () {
      // Bruno só pode no 1º período de segunda: o bloco de 2 não cabe,
      // vira 1 + 1; só a primeira metade cabe.
      final r = _gerar(
        cargas: [
          carga(informatica.id, 2, bloco: 2),
          carga(ingles.id, 2, bloco: 2),
        ],
        pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
        indisponibilidades: [
          for (var dia = 0; dia < 5; dia++)
            for (var p = 0; p < 12; p++)
              if (!(dia == 0 && p == 0))
                indisponivel(bruno.id, dia: dia, periodo: p),
        ],
      );

      // Sem nomes, o gerador usa "componente <id>".
      final nomes =
          'componente ${informatica.id} e componente ${ingles.id}';
      expect(
        r.falhas,
        contains(
          'Info 1: Aula dividida de $nomes: 1 horário(s) ficaram em blocos '
          'menores que 2 (o bloco inteiro não coube).',
        ),
      );
      expect(
        r.falhas,
        contains(
          'Info 1: Faltam 1 horário(s) da aula dividida de $nomes '
          '(não couberam com a turma dividida).',
        ),
      );
      // Só o horário que coube, com a turma dividida; nada de aula da
      // turma inteira com o que sobrou.
      expect(_horariosJuntos(r.novasAulas), [(0, 0)]);
      expect(r.novasAulas, hasLength(2));
    });
  });
}
