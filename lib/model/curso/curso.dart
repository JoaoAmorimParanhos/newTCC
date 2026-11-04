import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';

class Curso {
  Curso({
    required this.id,
    required this.nome,
    this.idSala,
    this.preferenciaPeriodo = PreferenciaPeriodo.manhaTarde,
  });

  final String id;
  final String nome;

  /// Sala padrão do curso (opcional).
  final String? idSala;

  /// Turno(s) que o gerador usa: só manhã, só tarde, só noite, ou um turno
  /// com contraturno (CT) no outro.
  final PreferenciaPeriodo preferenciaPeriodo;

  factory Curso.fromJson(Map<String, dynamic> json) => Curso(
        id: json['id'].toString(),
        nome: json['nome'] as String,
        idSala: json['id_sala']?.toString(),
        preferenciaPeriodo: PreferenciaPeriodo.fromDb(
          json['periodo_preferencia'] as String?,
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        if (idSala != null) 'id_sala': int.parse(idSala!),
        'periodo_preferencia': preferenciaPeriodo.toDb(),
      };

  Map<String, dynamic> toInsertJson() => {
        'nome': nome,
        if (idSala != null) 'id_sala': int.parse(idSala!),
        'periodo_preferencia': preferenciaPeriodo.toDb(),
      };
}
