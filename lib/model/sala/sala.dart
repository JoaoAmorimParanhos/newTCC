/// Tipo de sala cadastrado pelo usuário (ex.: Sala de aula, Quadra).
class TipoSala {
  const TipoSala({required this.id, required this.nome});

  final String id;
  final String nome;

  factory TipoSala.fromJson(Map<String, dynamic> json) => TipoSala(
    id: json['id'].toString(),
    nome: json['nome'] as String,
  );

  @override
  bool operator ==(Object other) => other is TipoSala && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class SalaDuplicada implements Exception {
  const SalaDuplicada();
}

class TipoSalaDuplicado implements Exception {
  const TipoSalaDuplicado();
}

class Sala {
  Sala({
    required this.id,
    required this.numero,
    required this.tipo,
  });

  final String id;
  final int numero;
  final TipoSala tipo;

  String get rotulo => '${tipo.nome} $numero';

  /// [json] vem de `select('*, tipo:tb_tipo_sala(id, nome)')`.
  factory Sala.fromJson(Map<String, dynamic> json) {
    final tipo = json['tipo'];
    return Sala(
      id: json['id'].toString(),
      numero: (json['numero'] as num).toInt(),
      tipo: tipo is Map<String, dynamic>
          ? TipoSala.fromJson(tipo)
          : TipoSala(id: json['id_tipo_sala'].toString(), nome: 'Sala'),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'numero': numero,
    'id_tipo_sala': int.parse(tipo.id),
  };
}
