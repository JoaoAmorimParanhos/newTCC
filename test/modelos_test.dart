import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/horario/horario_periodo.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/sala/sala.dart';

void main() {
  group('Aula', () {
    test('converte dia e período do banco (1–5, 1–12) para 0–4, 0–11', () {
      final aula = Aula.fromJson({
        'id': 7,
        'id_curso': 1,
        'dia_semana': 1,
        'periodo': 12,
        'id_materia': 10,
        'id_professor': 20,
        'id_sala': null,
        'grupo': 2,
      });
      expect(aula.indiceDia, 0);
      expect(aula.indicePeriodo, 11);
      expect(aula.grupo, 2);
      expect(aula.idSala, isNull);
    });

    test('grava de volta no formato do banco', () {
      final json = Aula(
        id: '0',
        idCurso: '1',
        indiceDia: 4,
        indicePeriodo: 0,
        idMateria: '10',
        idProfessor: '20',
        idSala: '30',
      ).toInsertJson();
      expect(json, {
        'id_curso': 1,
        'dia_semana': 5,
        'periodo': 1,
        'id_materia': 10,
        'id_professor': 20,
        'id_sala': 30,
        'grupo': 1,
      });
    });

    test('grupo ausente no banco vira 1', () {
      final aula = Aula.fromJson({
        'id': 1,
        'id_curso': 1,
        'dia_semana': 2,
        'periodo': 3,
        'id_materia': 10,
        'id_professor': 20,
      });
      expect(aula.grupo, 1);
    });
  });

  group('AulaGeminadaCurso', () {
    test('lê aulas e blocos do banco', () {
      final par = AulaGeminadaCurso.fromJson({
        'id_curso': 1,
        'id_materia_a': 10,
        'id_materia_b': 11,
        'quantidade_periodos': 8,
        'quantidade_blocos': 2,
      });
      expect(par.quantidadePeriodos, 8);
      expect(par.quantidadeBlocos, 2);
      expect(par.tamanhosBlocos, [4, 4]);
    });

    test('sem a coluna de blocos, mantém aulas soltas (blocos = aulas)', () {
      final par = AulaGeminadaCurso.fromJson({
        'id_curso': 1,
        'id_materia_a': 10,
        'id_materia_b': 11,
        'quantidade_periodos': 3,
      });
      expect(par.quantidadeBlocos, 3);
      expect(par.tamanhosBlocos, [1, 1, 1]);
    });

    test('grava aulas e blocos', () {
      final json = AulaGeminadaCurso(
        idCurso: '1',
        idMateriaA: '11',
        idMateriaB: '10',
        quantidadePeriodos: 8,
        quantidadeBlocos: 2,
      ).toInsertJson();
      expect(json, {
        'id_curso': 1,
        'id_materia_a': 10,
        'id_materia_b': 11,
        'quantidade_periodos': 8,
        'quantidade_periodos_b': 8,
        'quantidade_blocos': 2,
      });
    });

    test('cargas diferentes: A = 2 e B = 4 ocupam 4 horários', () {
      final par = AulaGeminadaCurso(
        idCurso: '1',
        idMateriaA: '10',
        idMateriaB: '11',
        quantidadePeriodos: 2,
        quantidadePeriodosB: 4,
        quantidadeBlocos: 1,
      );
      expect(par.juntas, 2);
      expect(par.periodosOcupados, 4);
      expect(par.periodosSoMaior, 2);
      expect(par.idMateriaMaior, '11');
      expect(par.idMateriaMenor, '10');
      expect(par.tamanhosBlocos, [4]);
      expect(par.juntasPorBloco, [2]);
    });

    test('cargas diferentes em 2 blocos dividem as juntas também', () {
      final par = AulaGeminadaCurso(
        idCurso: '1',
        idMateriaA: '10',
        idMateriaB: '11',
        quantidadePeriodos: 1,
        quantidadePeriodosB: 4,
        quantidadeBlocos: 2,
      );
      expect(par.tamanhosBlocos, [2, 2]);
      expect(par.juntasPorBloco, [1, 0]);
    });

    test('ao ordenar o par pelo id, as quantidades trocam junto', () {
      final par = AulaGeminadaCurso(
        idCurso: '1',
        idMateriaA: '11',
        idMateriaB: '10',
        quantidadePeriodos: 4,
        quantidadePeriodosB: 2,
      );
      expect(par.idMateriaA, '10');
      expect(par.quantidadeA, 2);
      expect(par.quantidadeB, 4);
      expect(par.toInsertJson()['quantidade_periodos'], 2);
      expect(par.toInsertJson()['quantidade_periodos_b'], 4);
    });

    test('lê quantidade_periodos_b; sem a coluna, B = A', () {
      final diferente = AulaGeminadaCurso.fromJson({
        'id_curso': 1,
        'id_materia_a': 10,
        'id_materia_b': 11,
        'quantidade_periodos': 2,
        'quantidade_periodos_b': 4,
        'quantidade_blocos': 1,
      });
      expect(diferente.quantidadeA, 2);
      expect(diferente.quantidadeB, 4);

      final antigo = AulaGeminadaCurso.fromJson({
        'id_curso': 1,
        'id_materia_a': 10,
        'id_materia_b': 11,
        'quantidade_periodos': 3,
        'quantidade_blocos': 1,
      });
      expect(antigo.quantidadeB, 3);
    });

    test('ordena as matérias do par pelo id', () {
      final par = AulaGeminadaCurso(
        idCurso: '1',
        idMateriaA: '11',
        idMateriaB: '10',
      );
      expect(par.idMateriaA, '10');
      expect(par.idMateriaB, '11');
      expect(par.formaPar('11', '10'), isTrue);
      expect(par.formaPar('10', '12'), isFalse);
    });

    test('limita blocos entre 1 e o número de aulas', () {
      expect(
        AulaGeminadaCurso(
          idCurso: '1',
          idMateriaA: '10',
          idMateriaB: '11',
          quantidadePeriodos: 4,
          quantidadeBlocos: 9,
        ).quantidadeBlocos,
        4,
      );
      expect(
        AulaGeminadaCurso(
          idCurso: '1',
          idMateriaA: '10',
          idMateriaB: '11',
          quantidadePeriodos: 4,
          quantidadeBlocos: 0,
        ).quantidadeBlocos,
        1,
      );
    });
  });

  group('dividirEmBlocos', () {
    test('divide o mais igual possível, maiores primeiro', () {
      expect(dividirEmBlocos(8, 2), [4, 4]);
      expect(dividirEmBlocos(5, 2), [3, 2]);
      expect(dividirEmBlocos(4, 4), [1, 1, 1, 1]);
      expect(dividirEmBlocos(4, 1), [4]);
      expect(dividirEmBlocos(7, 3), [3, 2, 2]);
    });

    test('blocos acima do total viram aulas soltas', () {
      expect(dividirEmBlocos(2, 5), [1, 1]);
    });

    test('sem aulas, sem blocos', () {
      expect(dividirEmBlocos(0, 2), isEmpty);
    });
  });

  test('CargaCursoMateria usa bloco 1 quando a coluna falta', () {
    final c = CargaCursoMateria.fromJson({
      'id_curso': 1,
      'id_materia': 10,
      'quantidade_aulas': 4,
    });
    expect(c.tamanhoBloco, 1);
  });

  test('Curso lê preferência de período e aceita valor antigo "tarde"', () {
    final c = Curso.fromJson({
      'id': 1,
      'nome': 'Info',
      'periodo_preferencia': 'tarde',
    });
    expect(c.preferenciaPeriodo, PreferenciaPeriodo.tardeManha);
    expect(c.turnoCompartilhado, isFalse);
  });

  test('Sala lê o tipo (tabela tb_tipo_sala) e monta o rótulo', () {
    final s = Sala.fromJson({
      'id': 3,
      'numero': 2,
      'id_tipo_sala': 7,
      'tipo': {'id': 7, 'nome': 'Quadra'},
    });
    expect(s.tipo, const TipoSala(id: '7', nome: 'Quadra'));
    expect(s.rotulo, 'Quadra 2');
    expect(s.toInsertJson(), {'numero': 2, 'id_tipo_sala': 7});
  });

  test('Curso noturno é lido e gravado como "noite"', () {
    final c = Curso.fromJson({
      'id': 1,
      'nome': 'Info Noite',
      'periodo_preferencia': 'noite',
    });
    expect(c.preferenciaPeriodo, PreferenciaPeriodo.noite);
    expect(c.toInsertJson()['periodo_preferencia'], 'noite');
  });

  test('HorarioPeriodo converte o período 0-based ↔ 1-based', () {
    final h = HorarioPeriodo.fromJson({'periodo': 13, 'texto': '19:00 – 19:45'});
    expect(h.indicePeriodo, 12);
    expect(h.toJson(), {'periodo': 13, 'texto': '19:00 – 19:45'});
  });
}
