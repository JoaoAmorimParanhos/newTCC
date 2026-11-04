import 'package:flutter_test_project/components/grade_horaria.dart';

/// Turno(s) em que o gerador coloca as aulas da turma.
///
/// Os "CT" (contraturno) começam por um turno e o que sobrar vai para o
/// outro. A noite só usa a noite. Na edição manual (tocar/arrastar) não há
/// bloqueio: qualquer turno é aceito.
enum PreferenciaPeriodo {
  manha,
  tarde,
  noite,
  manhaTarde,
  tardeManha;

  static PreferenciaPeriodo fromDb(String? value) => switch (value) {
    'apenas_manha' => PreferenciaPeriodo.manha,
    'apenas_tarde' => PreferenciaPeriodo.tarde,
    'noite' => PreferenciaPeriodo.noite,
    'tarde_manha' || 'tarde' => PreferenciaPeriodo.tardeManha,
    _ => PreferenciaPeriodo.manhaTarde,
  };

  String toDb() => switch (this) {
    PreferenciaPeriodo.manha => 'apenas_manha',
    PreferenciaPeriodo.tarde => 'apenas_tarde',
    PreferenciaPeriodo.noite => 'noite',
    PreferenciaPeriodo.manhaTarde => 'manha_tarde',
    PreferenciaPeriodo.tardeManha => 'tarde_manha',
  };

  String get rotulo => switch (this) {
    PreferenciaPeriodo.manha => 'Manhã',
    PreferenciaPeriodo.tarde => 'Tarde',
    PreferenciaPeriodo.noite => 'Noite',
    PreferenciaPeriodo.manhaTarde => 'Manhã CT: Tarde',
    PreferenciaPeriodo.tardeManha => 'Tarde CT: Manhã',
  };

  /// Turnos que o gerador usa, na ordem em que preenche.
  List<List<int>> get turnos {
    final manha = GradeHoraria.periodosManha;
    final tarde = GradeHoraria.periodosTarde;
    return switch (this) {
      PreferenciaPeriodo.manha => [manha],
      PreferenciaPeriodo.tarde => [tarde],
      PreferenciaPeriodo.noite => [GradeHoraria.periodosNoite],
      PreferenciaPeriodo.manhaTarde => [manha, tarde],
      PreferenciaPeriodo.tardeManha => [tarde, manha],
    };
  }

  /// Maior bloco de aulas seguidas que cabe nos turnos da turma
  /// (6 de manhã/tarde, 4 à noite).
  int get maxAulasPorBloco =>
      turnos.map((t) => t.length).reduce((a, b) => a > b ? a : b);
}
