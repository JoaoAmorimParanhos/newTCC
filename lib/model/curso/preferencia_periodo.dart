enum PreferenciaPeriodo {
  manhaTarde,
  tardeManha,
  noite;

  static PreferenciaPeriodo fromDb(String? value) => switch (value) {
    'tarde' || 'tarde_manha' => PreferenciaPeriodo.tardeManha,
    'noite' => PreferenciaPeriodo.noite,
    _ => PreferenciaPeriodo.manhaTarde,
  };

  String toDb() => switch (this) {
    PreferenciaPeriodo.manhaTarde => 'manha_tarde',
    PreferenciaPeriodo.tardeManha => 'tarde_manha',
    PreferenciaPeriodo.noite => 'noite',
  };

  String get rotulo => switch (this) {
    PreferenciaPeriodo.manhaTarde => 'Manhã, depois tarde',
    PreferenciaPeriodo.tardeManha => 'Tarde, depois manhã',
    PreferenciaPeriodo.noite => 'Noite',
  };
}
