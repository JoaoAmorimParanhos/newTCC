import 'dart:math' as math;

/// Par de matérias que acontecem ao mesmo tempo na turma dividida em 2 grupos.
///
/// Cada matéria tem a sua quantidade de aulas. Ex.: A = 2 e B = 4 ocupam
/// 4 horários: nos 2 primeiros G1 tem A e G2 tem B; nos 2 últimos só G2 tem
/// aula (B) e o G1 fica livre.
class AulaGeminadaCurso {
  factory AulaGeminadaCurso({
    required String idCurso,
    required String idMateriaA,
    required String idMateriaB,
    int quantidadePeriodos = 1,
    int? quantidadePeriodosB,
    int? quantidadeBlocos,
  }) {
    final qa = quantidadePeriodos < 1 ? 1 : quantidadePeriodos;
    final qbBruto = quantidadePeriodosB ?? qa;
    final qb = qbBruto < 1 ? 1 : qbBruto;
    // O banco guarda o par com id_materia_a < id_materia_b: ao trocar as
    // matérias de lado, as quantidades trocam junto.
    final trocar = _primeiroId(idMateriaA, idMateriaB) != idMateriaA;
    final quantidadeA = trocar ? qb : qa;
    final quantidadeB = trocar ? qa : qb;
    return AulaGeminadaCurso._(
      idCurso: idCurso,
      idMateriaA: trocar ? idMateriaB : idMateriaA,
      idMateriaB: trocar ? idMateriaA : idMateriaB,
      quantidadeA: quantidadeA,
      quantidadeB: quantidadeB,
      quantidadeBlocos: _limitarBlocos(
        quantidadeBlocos,
        math.max(quantidadeA, quantidadeB),
      ),
    );
  }

  const AulaGeminadaCurso._({
    required this.idCurso,
    required this.idMateriaA,
    required this.idMateriaB,
    required this.quantidadeA,
    required this.quantidadeB,
    required this.quantidadeBlocos,
  });


  final String idCurso;
  final String idMateriaA;
  final String idMateriaB;

  /// Aulas de cada matéria dentro da geminada.
  final int quantidadeA;
  final int quantidadeB;

  /// Em quantos blocos de aulas seguidas o par fica na grade. Não é escolhido
  /// à parte: sai do Bloco da carga dos dois componentes (ver [formato]) e é
  /// guardado só como registro; o gerador sempre recalcula.
  final int quantidadeBlocos;

  /// Compatível com o par de cargas iguais: aulas da matéria A.
  int get quantidadePeriodos => quantidadeA;

  /// Horários com os dois grupos tendo aula.
  int get juntas => math.min(quantidadeA, quantidadeB);

  /// Horários ocupados pelo par (a matéria maior define o tamanho).
  int get periodosOcupados => math.max(quantidadeA, quantidadeB);

  /// Horários em que só a matéria maior tem aula (G1 livre).
  int get periodosSoMaior => periodosOcupados - juntas;

  /// Matéria que fica no grupo 2: a de mais aulas (B se forem iguais).
  String get idMateriaMaior =>
      quantidadeA > quantidadeB ? idMateriaA : idMateriaB;

  /// Matéria do grupo 1: a de menos aulas (A se forem iguais).
  String get idMateriaMenor => idMateriaMaior == idMateriaA ? idMateriaB : idMateriaA;

  int quantidadeDe(String idMateria) {
    assert(contemMateria(idMateria), 'matéria fora do par');
    return idMateria == idMateriaA ? quantidadeA : quantidadeB;
  }

  /// Como o par fica na grade, usando o Bloco da carga de cada componente
  /// ([blocoDe]) e o tamanho do turno da turma ([limiteTurno]).
  FormatoAulaDividida formato({
    required int Function(String idMateria) blocoDe,
    required int limiteTurno,
  }) => formatoAulaDividida(
    aulasG1: quantidadeDe(idMateriaMenor),
    aulasG2: quantidadeDe(idMateriaMaior),
    blocoG1: blocoDe(idMateriaMenor),
    blocoG2: blocoDe(idMateriaMaior),
    limiteTurno: limiteTurno,
  );

  factory AulaGeminadaCurso.fromJson(Map<String, dynamic> json) {
    final periodosA = (json['quantidade_periodos'] as num?)?.toInt() ?? 1;
    final periodosB =
        (json['quantidade_periodos_b'] as num?)?.toInt() ?? periodosA;
    return AulaGeminadaCurso(
      idCurso: json['id_curso'].toString(),
      idMateriaA: json['id_materia_a'].toString(),
      idMateriaB: json['id_materia_b'].toString(),
      quantidadePeriodos: periodosA,
      quantidadePeriodosB: periodosB,
      // Sem a coluna, mantém o comportamento antigo: aulas soltas.
      quantidadeBlocos:
          (json['quantidade_blocos'] as num?)?.toInt() ??
          math.max(periodosA, periodosB),
    );
  }

  Map<String, dynamic> toInsertJson({String? idCursoOverride}) => {
    'id_curso': int.parse(idCursoOverride ?? idCurso),
    'id_materia_a': int.parse(idMateriaA),
    'id_materia_b': int.parse(idMateriaB),
    'quantidade_periodos': quantidadeA,
    'quantidade_periodos_b': quantidadeB,
    'quantidade_blocos': quantidadeBlocos,
  };

  static int _limitarBlocos(int? blocos, int periodos) {
    final valor = blocos ?? 1;
    if (valor < 1) return 1;
    if (valor > periodos) return periodos;
    return valor;
  }

  bool contemMateria(String idMateria) =>
      idMateriaA == idMateria || idMateriaB == idMateria;

  bool formaPar(String primeira, String segunda) {
    return idMateriaA == _primeiroId(primeira, segunda) &&
        idMateriaB == _segundoId(primeira, segunda);
  }

  String get chave => '$idCurso:$idMateriaA:$idMateriaB';

  static String _primeiroId(String a, String b) {
    final numeroA = int.tryParse(a);
    final numeroB = int.tryParse(b);
    if (numeroA != null && numeroB != null) {
      return numeroA <= numeroB ? a : b;
    }
    return a.compareTo(b) <= 0 ? a : b;
  }

  static String _segundoId(String a, String b) {
    final primeiro = _primeiroId(a, b);
    return primeiro == a ? b : a;
  }
}

bool existeAulaGeminada({
  required String idCurso,
  required String idMateriaA,
  required String idMateriaB,
  required List<AulaGeminadaCurso> aulasGeminadas,
}) {
  return aulasGeminadas.any(
    (par) => par.idCurso == idCurso && par.formaPar(idMateriaA, idMateriaB),
  );
}

List<String> materiasGeminadasCom({
  required String idCurso,
  required String idMateria,
  required List<AulaGeminadaCurso> aulasGeminadas,
}) {
  final ids = <String>{};
  for (final par in aulasGeminadas) {
    if (par.idCurso != idCurso || !par.contemMateria(idMateria)) continue;
    ids.add(par.idMateriaA == idMateria ? par.idMateriaB : par.idMateriaA);
  }
  return ids.toList();
}

/// Como a aula dividida fica na grade: blocos de horários seguidos e, em
/// cada bloco, quantos horários têm os 2 grupos juntos (os primeiros); no
/// resto do bloco só o G2 tem aula e o G1 fica livre.
class FormatoAulaDividida {
  const FormatoAulaDividida({required this.tamanhos, required this.juntas});

  /// Horários seguidos de cada bloco. Ex.: [2, 2].
  final List<int> tamanhos;

  /// Horários com os 2 grupos em cada bloco, na ordem de [tamanhos].
  final List<int> juntas;

  int get quantidadeBlocos => tamanhos.length;

  /// Horários em que o G1 fica livre (só o G2 tem aula).
  int get horariosG1Livre {
    var soma = 0;
    for (var i = 0; i < tamanhos.length; i++) {
      soma += tamanhos[i] - juntas[i];
    }
    return soma;
  }
}

/// Monta a aula dividida com o mesmo "Bloco" das aulas comuns (aulas
/// seguidas no mesmo dia, definido na carga de cada componente):
/// - o componente do G2 (o de mais aulas) fica em blocos de [blocoG2]
///   aulas seguidas, como numa aula comum;
/// - nenhum bloco tem mais aulas do G1 do que o [blocoG1];
/// - nenhum bloco passa do turno ([limiteTurno]; noite: 4).
///
/// Ex.: 3 + 3 com Bloco 3 = 1 bloco de 3; 2 + 4 com Bloco 2 = blocos [2, 2]
/// com 1 horário junto em cada.
FormatoAulaDividida formatoAulaDividida({
  required int aulasG1,
  required int aulasG2,
  required int blocoG1,
  required int blocoG2,
  required int limiteTurno,
}) {
  final ocupados = math.max(aulasG1, aulasG2);
  final juntas = math.min(aulasG1, aulasG2);
  if (ocupados < 1) {
    return const FormatoAulaDividida(tamanhos: [], juntas: []);
  }
  final maxJuntas = math.max(1, blocoG1);
  // Começa no Bloco do G2 e diminui só se o G1 passaria do Bloco dele.
  for (var tamanho = math.min(blocoG2, limiteTurno); ; tamanho--) {
    final tamanhos = blocosDeTamanho(ocupados, tamanho);
    final juntasPorBloco = espalharJuntas(juntas, tamanhos);
    if (tamanho <= 1 || juntasPorBloco.every((j) => j <= maxJuntas)) {
      return FormatoAulaDividida(tamanhos: tamanhos, juntas: juntasPorBloco);
    }
  }
}

/// Divide [total] aulas em blocos de [tamanho] e um bloco menor com o que
/// sobrar — a mesma regra das aulas comuns. Ex.: (6, 4) = [4, 2];
/// (6, 2) = [2, 2, 2].
List<int> blocosDeTamanho(int total, int tamanho) {
  if (total < 1) return const [];
  final t = tamanho.clamp(1, total);
  return [
    for (var restante = total; restante > 0; restante -= t)
      restante >= t ? t : restante,
  ];
}

/// Reparte [juntas] horários entre os blocos de [tamanhos] o mais igual
/// possível, sem passar do tamanho de cada bloco. Ex.: (2, [2, 2]) = [1, 1];
/// (4, [4, 2]) = [2, 2].
List<int> espalharJuntas(int juntas, List<int> tamanhos) {
  final saida = List<int>.filled(tamanhos.length, 0);
  for (var r = 0; r < juntas; r++) {
    var escolhido = -1;
    for (var i = 0; i < tamanhos.length; i++) {
      if (saida[i] >= tamanhos[i]) continue;
      if (escolhido < 0 || saida[i] < saida[escolhido]) escolhido = i;
    }
    if (escolhido < 0) break;
    saida[escolhido]++;
  }
  return saida;
}
