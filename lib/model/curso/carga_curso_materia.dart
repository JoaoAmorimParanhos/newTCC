class CargaCursoMateria {
  CargaCursoMateria({
    required this.idCurso,
    required this.idMateria,
    required this.quantidadeAulas,
    this.tamanhoBloco = 1,
  });

  final String idCurso;
  final String idMateria;
  final int quantidadeAulas;

  /// Aulas consecutivas no mesmo turno, até a carga da matéria e no máximo 6.
  final int tamanhoBloco;

  factory CargaCursoMateria.fromJson(Map<String, dynamic> json) =>
      CargaCursoMateria(
        idCurso: json['id_curso'].toString(),
        idMateria: json['id_materia'].toString(),
        quantidadeAulas: (json['quantidade_aulas'] as num).toInt(),
        tamanhoBloco: (json['tamanho_bloco'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toInsertJson() => {
        'id_curso': int.parse(idCurso),
        'id_materia': int.parse(idMateria),
        'quantidade_aulas': quantidadeAulas,
        'tamanho_bloco': tamanhoBloco,
      };
}
