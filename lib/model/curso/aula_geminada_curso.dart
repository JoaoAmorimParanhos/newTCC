class AulaGeminadaCurso {
  AulaGeminadaCurso({
    required this.idCurso,
    required String idMateriaA,
    required String idMateriaB,
    int quantidadePeriodos = 1,
    int? quantidadeBlocos,
  }) : idMateriaA = _primeiroId(idMateriaA, idMateriaB),
       idMateriaB = _segundoId(idMateriaA, idMateriaB),
       quantidadePeriodos = quantidadePeriodos < 1 ? 1 : quantidadePeriodos,
       quantidadeBlocos = _limitarBlocos(
         quantidadeBlocos,
         quantidadePeriodos < 1 ? 1 : quantidadePeriodos,
       );

  /// Maior bloco possível: um turno inteiro.
  static const int maxAulasPorBloco = 6;

  final String idCurso;
  final String idMateriaA;
  final String idMateriaB;

  /// Quantas aulas o par tem juntas na semana (G1 numa matéria, G2 na outra).
  final int quantidadePeriodos;

  /// Em quantos blocos de aulas seguidas essas aulas são divididas ao longo
  /// dos dias. Ex.: 8 aulas em 2 blocos = 2 conjuntos de 4 aulas geminadas.
  final int quantidadeBlocos;

  /// Tamanho de cada bloco, o mais igual possível (5 em 2 blocos = [3, 2]).
  List<int> get tamanhosBlocos => dividirEmBlocos(
    quantidadePeriodos,
    quantidadeBlocos,
  );

  factory AulaGeminadaCurso.fromJson(Map<String, dynamic> json) {
    final periodos = (json['quantidade_periodos'] as num?)?.toInt() ?? 1;
    return AulaGeminadaCurso(
      idCurso: json['id_curso'].toString(),
      idMateriaA: json['id_materia_a'].toString(),
      idMateriaB: json['id_materia_b'].toString(),
      quantidadePeriodos: periodos,
      // Sem a coluna, mantém o comportamento antigo: aulas soltas.
      quantidadeBlocos:
          (json['quantidade_blocos'] as num?)?.toInt() ?? periodos,
    );
  }

  Map<String, dynamic> toInsertJson({String? idCursoOverride}) => {
    'id_curso': int.parse(idCursoOverride ?? idCurso),
    'id_materia_a': int.parse(idMateriaA),
    'id_materia_b': int.parse(idMateriaB),
    'quantidade_periodos': quantidadePeriodos,
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
    final normalizado = AulaGeminadaCurso(
      idCurso: idCurso,
      idMateriaA: primeira,
      idMateriaB: segunda,
    );
    return idMateriaA == normalizado.idMateriaA &&
        idMateriaB == normalizado.idMateriaB;
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
  final base = total ~/ partes;
  final sobra = total % partes;
  return [for (var i = 0; i < partes; i++) base + (i < sobra ? 1 : 0)];
}
