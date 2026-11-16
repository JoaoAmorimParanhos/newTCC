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
    });

    test('sem a coluna de blocos, guarda blocos = aulas', () {
      final par = AulaGeminadaCurso.fromJson({
        'id_curso': 1,
        'id_materia_a': 10,
        'id_materia_b': 11,
        'quantidade_periodos': 3,
      });
      expect(par.quantidadeBlocos, 3);
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
      final formato = par.formato(
        blocoDe: (_) => 4,
        limiteTurno: 6,
      );
      expect(formato.tamanhos, [4]);
      expect(formato.juntas, [2]);
      expect(formato.horariosG1Livre, 2);
    });

    test('formato: os blocos vêm do Bloco da carga de cada componente', () {
      final par = AulaGeminadaCurso(
        idCurso: '1',
        idMateriaA: '10',
        idMateriaB: '11',
        quantidadePeriodos: 1,
        quantidadePeriodosB: 4,
        // Número antigo guardado no par: não muda o formato.
        quantidadeBlocos: 4,
      );
      final formato = par.formato(blocoDe: (_) => 2, limiteTurno: 6);
      expect(formato.tamanhos, [2, 2]);
      expect(formato.juntas, [1, 0]);
    });
  });

  group('formatoAulaDividida', () {
    FormatoAulaDividida formato(
      int g1,
      int g2, {
      required int blocoG1,
      required int blocoG2,
      int turno = 6,
    }) => formatoAulaDividida(
      aulasG1: g1,
      aulasG2: g2,
      blocoG1: blocoG1,
      blocoG2: blocoG2,
      limiteTurno: turno,
    );

    test('mesmas aulas e Bloco 3 = 1 bloco de 3 (caso do banco)', () {
      final f = formato(3, 3, blocoG1: 3, blocoG2: 3);
      expect(f.tamanhos, [3]);
      expect(f.juntas, [3]);
      expect(f.horariosG1Livre, 0);
    });

    test('blocos como nas aulas comuns: cheios e o resto no fim', () {
      final f = formato(6, 6, blocoG1: 4, blocoG2: 4);
      expect(f.tamanhos, [4, 2]);
      expect(f.juntas, [4, 2]);
    });

    test('mesmas aulas com Blocos diferentes: vale o menor', () {
      expect(formato(4, 4, blocoG1: 2, blocoG2: 4).tamanhos, [2, 2]);
      expect(formato(4, 4, blocoG1: 4, blocoG2: 2).tamanhos, [2, 2]);
    });

    test('o G1 não passa do Bloco dele; o G2 segue o dele', () {
      // ADS 2 (Bloco 1) e Programação 4 (Bloco 4).
      final f = formato(2, 4, blocoG1: 1, blocoG2: 4);
      expect(f.tamanhos, [3, 1]);
      expect(f.juntas, [1, 1]);
    });

    test('nenhum bloco passa do turno (noite: 4)', () {
      final f = formato(8, 8, blocoG1: 6, blocoG2: 6, turno: 4);
      expect(f.tamanhos, [4, 4]);
    });

    test('sem aulas, sem blocos', () {
      expect(formato(0, 0, blocoG1: 2, blocoG2: 2).tamanhos, isEmpty);
    });
  });

  group('blocosDeTamanho e espalharJuntas', () {
    test('blocos cheios e o resto no fim', () {
      expect(blocosDeTamanho(8, 4), [4, 4]);
      expect(blocosDeTamanho(6, 4), [4, 2]);
      expect(blocosDeTamanho(5, 2), [2, 2, 1]);
      expect(blocosDeTamanho(2, 5), [2]);
      expect(blocosDeTamanho(0, 2), isEmpty);
    });

    test('juntas repartidas por igual, sem passar do bloco', () {
      expect(espalharJuntas(2, [2, 2]), [1, 1]);
      expect(espalharJuntas(1, [2, 2]), [1, 0]);
      expect(espalharJuntas(4, [4, 2]), [2, 2]);
      expect(espalharJuntas(5, [4, 1]), [4, 1]);
    });
  });

  group('AulaGeminadaCurso (limites)', () {

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
