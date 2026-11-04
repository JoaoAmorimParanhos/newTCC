import 'package:flutter_test_project/components/grade_horaria.dart';

class IndisponibilidadeProfessor {
  IndisponibilidadeProfessor({
    required this.id,
    required this.idProfessor,
    required this.indiceDia,
    required this.indicePeriodo,
  });

  final String id;
  final String idProfessor;

  /// 0 = Seg … 4 = Sex
  final int indiceDia;

  /// 0–5 manhã, 6–11 tarde, 12–15 noite (DB: periodo 1–16)
  final int indicePeriodo;

  CelulaGrade get celula => CelulaGrade(
        indiceDia: indiceDia,
        indicePeriodo: indicePeriodo,
      );

  factory IndisponibilidadeProfessor.fromJson(Map<String, dynamic> json) =>
      IndisponibilidadeProfessor(
        id: json['id'].toString(),
        idProfessor: json['id_professor'].toString(),
        indiceDia: (json['dia_semana'] as num).toInt() - 1,
        indicePeriodo: (json['periodo'] as num).toInt() - 1,
      );

  Map<String, dynamic> toInsertJson() => {
        'id_professor': int.parse(idProfessor),
        'dia_semana': indiceDia + 1,
        'periodo': indicePeriodo + 1,
      };
}
