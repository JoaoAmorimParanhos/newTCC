import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';
import 'package:flutter_test_project/services/repositories/repositorio_aula.dart';

import 'apoio/dados.dart';

final _parInfIng = par(informatica.id, ingles.id, aulas: 4, blocos: 1);

/// Conjunto geminado Informática (G1, Ana) + Inglês (G2, Bruno) nos
/// [periodos] do [dia].
List<Aula> _geminada({int dia = 0, required List<int> periodos}) => [
  for (final p in periodos) ...[
    aula(
      id: 'inf-$dia-$p',
      dia: dia,
      periodo: p,
      idMateria: informatica.id,
      idProfessor: ana.id,
    ),
    aula(
      id: 'ing-$dia-$p',
      dia: dia,
      periodo: p,
      idMateria: ingles.id,
      idProfessor: bruno.id,
      grupo: 2,
    ),
  ],
];

/// Simula soltar [pega] em [destino] e devolve o motivo da recusa (ou null).
String? _soltar(
  Aula pega,
  int dia,
  int periodo,
  List<Aula> todas, {
  List<IndisponibilidadeProfessor> indisponibilidades = const [],
}) {
  final originais = aulasQueMovemJunto(
    aula: pega,
    todasAulas: todas,
    aulasGeminadas: [_parInfIng],
  );
  return validarMoverAulas(
    originais: originais,
    movidas: deslocarAulas(
      originais,
      origem: pega.celula,
      destino: celula(dia, periodo),
    ),
    todasAulas: todas,
    professores: professoresPadrao,
    indisponibilidades: indisponibilidades,
  );
}

void main() {
  group('Quais aulas se movem juntas', () {
    test('aula comum move só ela', () {
      final mat = aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id);
      final vizinha = aula(dia: 0, periodo: 1, idMateria: matematica.id, idProfessor: carla.id);
      expect(
        aulasQueMovemJunto(
          aula: mat,
          todasAulas: [mat, vizinha],
          aulasGeminadas: [_parInfIng],
        ),
        [mat],
      );
    });

    test('aula geminada leva os dois grupos de todos os horários seguidos', () {
      final conjunto = _geminada(periodos: [0, 1, 2, 3]);
      final pega = conjunto[3]; // Inglês do 2º M
      final movem = aulasQueMovemJunto(
        aula: pega,
        todasAulas: conjunto,
        aulasGeminadas: [_parInfIng],
      );
      expect(movem.map((a) => a.id).toSet(), conjunto.map((a) => a.id).toSet());
    });

    test('o conjunto para no almoço, num horário vazio ou em outro dia', () {
      final manha = _geminada(periodos: [4, 5]);
      final tarde = _geminada(periodos: [6]); // depois do almoço
      final depoisDeVazio = _geminada(periodos: [8]); // 7 vazio
      final outroDia = _geminada(dia: 1, periodos: [5]);
      final todas = [...manha, ...tarde, ...depoisDeVazio, ...outroDia];

      final movem = aulasQueMovemJunto(
        aula: manha.first,
        todasAulas: todas,
        aulasGeminadas: [_parInfIng],
      );
      expect(movem.map((a) => a.id).toSet(), manha.map((a) => a.id).toSet());
    });

    test('2 grupos que não formam o par cadastrado não viram conjunto', () {
      final inf = aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final mat = aula(
        dia: 0,
        periodo: 0,
        idMateria: matematica.id,
        idProfessor: carla.id,
        grupo: 2,
      );
      expect(
        aulasQueMovemJunto(
          aula: inf,
          todasAulas: [inf, mat],
          aulasGeminadas: [_parInfIng],
        ),
        [inf],
      );
    });
  });

  group('Posição nova', () {
    test('mantém a distância da aula pega: pegar o 2º M e soltar no 3º M '
        'leva o conjunto do 1º–4º para o 2º–5º e o 1º fica vazio', () {
      final conjunto = _geminada(periodos: [0, 1, 2, 3]);
      final pega = conjunto[2]; // Informática do 2º M
      final movidas = deslocarAulas(
        conjunto,
        origem: pega.celula,
        destino: celula(0, 2),
      );
      expect(movidas.map((a) => a.indicePeriodo).toSet(), {1, 2, 3, 4});
      expect(movidas.every((a) => a.indiceDia == 0), isTrue);
      expect(movidas.map((a) => a.id).toSet(), conjunto.map((a) => a.id).toSet());
    });

    test('muda de dia mantendo os períodos', () {
      final mat = aula(dia: 0, periodo: 3, idMateria: matematica.id, idProfessor: carla.id);
      final movida = deslocarAulas(
        [mat],
        origem: mat.celula,
        destino: celula(4, 3),
      ).single;
      expect(movida.indiceDia, 4);
      expect(movida.indicePeriodo, 3);
      expect(movida.grupo, mat.grupo);
    });
  });

  group('Soltar: quando é recusado', () {
    test('aula comum numa célula vazia pode', () {
      final mat = aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id);
      expect(_soltar(mat, 2, 3, [mat]), isNull);
    });

    test('célula ocupada é recusada com mensagem', () {
      final mat = aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id);
      final inf = aula(dia: 2, periodo: 3, idMateria: informatica.id, idProfessor: ana.id);
      expect(_soltar(mat, 2, 3, [mat, inf]), startsWith('Horário ocupado'));
    });

    test('conjunto de 4 precisa de 4 horários vazios seguidos', () {
      final conjunto = _geminada(periodos: [0, 1, 2, 3]);
      final atrapalha = aula(
        dia: 1,
        periodo: 2,
        idMateria: matematica.id,
        idProfessor: carla.id,
      );
      final todas = [...conjunto, atrapalha];

      // Seg 1º–4º para Ter 1º–4º: o 3º M de terça está ocupado.
      expect(
        _soltar(conjunto.first, 1, 0, todas),
        contains('precisa de 4 horário(s) vazios seguidos'),
      );
      // A partir do Ter 4º M o conjunto passaria pelo almoço.
      expect(
        _soltar(conjunto.first, 1, 3, todas),
        contains('seguidos no mesmo turno'),
      );
      // Qua 1º–4º está livre.
      expect(_soltar(conjunto.first, 2, 0, todas), isNull);
    });

    test('não atravessa o almoço', () {
      final conjunto = _geminada(periodos: [0, 1]);
      expect(
        _soltar(conjunto.first, 0, 5, conjunto),
        contains('mesmo turno'),
      );
    });

    test('as células do próprio conjunto contam como livres', () {
      final conjunto = _geminada(periodos: [0, 1, 2, 3]);
      // Descer um período: 1º–4º para 2º–5º.
      expect(_soltar(conjunto.first, 0, 1, conjunto), isNull);
    });

    test('professor dando aula em outra turma no destino', () {
      final mat = aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id);
      final outraTurma = aula(
        idCurso: '2',
        dia: 2,
        periodo: 3,
        idMateria: matematica.id,
        idProfessor: carla.id,
      );
      expect(
        _soltar(mat, 2, 3, [mat, outraTurma]),
        'Carla já está dando aula em Qua 4º M.',
      );
    });

    test('professor indisponível no destino (página 2)', () {
      final mat = aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id);
      expect(
        _soltar(
          mat,
          2,
          3,
          [mat],
          indisponibilidades: [indisponivel(carla.id, dia: 2, periodo: 3)],
        ),
        'Carla está indisponível em Qua 4º M (Página 2).',
      );
    });

    test('sala ocupada por outra turma no destino', () {
      final mat = aula(
        dia: 0,
        periodo: 0,
        idMateria: matematica.id,
        idProfessor: carla.id,
        idSala: sala1.id,
      );
      final outraTurma = aula(
        idCurso: '2',
        dia: 2,
        periodo: 3,
        idMateria: informatica.id,
        idProfessor: ana.id,
        idSala: sala1.id,
      );
      expect(
        _soltar(mat, 2, 3, [mat, outraTurma]),
        'A sala já está ocupada por outra turma em Qua 4º M.',
      );
    });
  });

  test('ordem segura para gravar: descendo, de baixo para cima', () {
    final movidas = [
      aula(id: 'p1', dia: 0, periodo: 1, idMateria: matematica.id, idProfessor: carla.id),
      aula(id: 'p3', dia: 0, periodo: 3, idMateria: matematica.id, idProfessor: carla.id),
      aula(id: 'p2', dia: 0, periodo: 2, idMateria: matematica.id, idProfessor: carla.id),
    ];
    expect(
      RepositorioAula.ordemParaMover(movidas, 1).map((a) => a.id),
      ['p3', 'p2', 'p1'],
    );
    expect(
      RepositorioAula.ordemParaMover(movidas, -1).map((a) => a.id),
      ['p1', 'p2', 'p3'],
    );
  });
}
