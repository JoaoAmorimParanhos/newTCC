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

  /// Maior bloco possível: um turno inteiro.
  static const int maxAulasPorBloco = 6;

  final String idCurso;
  final String idMateriaA;
  final String idMateriaB;

  /// Aulas de cada matéria dentro da geminada.
  final int quantidadeA;
  final int quantidadeB;

  /// Em quantos blocos de aulas seguidas o par é dividido ao longo dos dias.
  /// Ex.: 8 aulas em 2 blocos = 2 conjuntos de 4 aulas geminadas.
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

  int quantidadeDe(String idMateria) =>
      idMateria == idMateriaA ? quantidadeA : quantidadeB;

  /// Tamanho de cada bloco, o mais igual possível (5 em 2 blocos = [3, 2]).
  List<int> get tamanhosBlocos =>
      dividirEmBlocos(periodosOcupados, quantidadeBlocos);

  /// Quantos horários com os 2 grupos cada bloco tem, na mesma ordem de
  /// [tamanhosBlocos]. Ex.: A = 2, B = 4 em 2 blocos → blocos [2, 2] e
  /// juntas [1, 1].
  List<int> get juntasPorBloco {
    final tamanhos = tamanhosBlocos;
    final partes = dividirEmPartes(juntas, tamanhos.length);
    return [
      for (var i = 0; i < tamanhos.length; i++) math.min(partes[i], tamanhos[i]),
    ];
  }

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

/// Divide [total] aulas em [blocos] partes o mais iguais possível,
/// maiores primeiro. Ex.: (8, 2) = [4, 4]; (5, 2) = [3, 2].
List<int> dividirEmBlocos(int total, int blocos) {
  if (total < 1) return const [];
  final partes = blocos.clamp(1, total);
  return dividirEmPartes(total, partes);
}

/// Como [dividirEmBlocos], mas sempre com [partes] itens (pode ter zeros).
/// Ex.: (1, 2) = [1, 0].
List<int> dividirEmPartes(int total, int partes) {
  if (partes < 1) return const [];
  final base = total ~/ partes;
  final sobra = total % partes;
  return [for (var i = 0; i < partes; i++) base + (i < sobra ? 1 : 0)];
}
