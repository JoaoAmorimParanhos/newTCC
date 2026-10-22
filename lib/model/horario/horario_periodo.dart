/// Texto livre com o horário de um período (ex.: "07:30 – 08:20").
///
/// É global: o mesmo período mostra o mesmo horário em todas as turmas.
class HorarioPeriodo {
  HorarioPeriodo({required this.indicePeriodo, required this.texto});

  /// 0–15 (DB: periodo 1–16)
  final int indicePeriodo;
  final String texto;

  factory HorarioPeriodo.fromJson(Map<String, dynamic> json) => HorarioPeriodo(
    indicePeriodo: (json['periodo'] as num).toInt() - 1,
    texto: json['texto'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'periodo': indicePeriodo + 1,
    'texto': texto,
  };
}
