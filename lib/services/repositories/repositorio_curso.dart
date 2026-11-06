import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/services/repositories/buscar_todas_linhas.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/services/repositories/observar_tabela.dart';

class RepositorioCurso {
  RepositorioCurso({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_curso';
  static const String _loadTable = 'tb_curso_materia';
  static const String _geminatedTable = 'tb_curso_aula_geminada';

  Stream<List<Curso>> observarTodos() =>
      observarTabela(client: _client, tabela: _table, buscar: buscarTodos);

  Stream<List<CargaCursoMateria>> observarCargas() => observarTabela(
    client: _client,
    tabela: _loadTable,
    buscar: buscarTodasCargas,
  );

  Stream<List<AulaGeminadaCurso>> observarAulasGeminadas() => observarTabela(
    client: _client,
    tabela: _geminatedTable,
    buscar: buscarTodasAulasGeminadas,
  );

  Future<List<Curso>> buscarTodos() async {
    // Ordem em que foram criados.
    final data = await _client
        .from(_table)
        .select()
        .order('id', ascending: true);
    return (data as List)
        .map((row) => Curso.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<CargaCursoMateria>> buscarTodasCargas() async {
    final data = await buscarTodasLinhas(
      _client,
      _loadTable,
      ordem: const ['id_curso', 'id_materia'],
    );
    return (data as List)
        .map((row) => CargaCursoMateria.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<CargaCursoMateria>> buscarCargas(String idCurso) async {
    final data = await _client
        .from(_loadTable)
        .select()
        .eq('id_curso', int.parse(idCurso));
    return (data as List)
        .map((row) => CargaCursoMateria.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AulaGeminadaCurso>> buscarTodasAulasGeminadas() async {
    final data = await _client.from(_geminatedTable).select();
    return (data as List)
        .map((row) => AulaGeminadaCurso.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AulaGeminadaCurso>> buscarAulasGeminadas(String idCurso) async {
    final data = await _client
        .from(_geminatedTable)
        .select()
        .eq('id_curso', int.parse(idCurso));
    return (data as List)
        .map((row) => AulaGeminadaCurso.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<String> adicionar(
    String nome, {
    String? idSala,
    PreferenciaPeriodo preferenciaPeriodo = PreferenciaPeriodo.manhaTarde,
    List<CargaCursoMateria> cargas = const [],
    List<AulaGeminadaCurso> aulasGeminadas = const [],
  }) async {
    final curso = Curso(
      id: '0',
      nome: nome,
      idSala: idSala,
      preferenciaPeriodo: preferenciaPeriodo,
    );
    final row = await _client
        .from(_table)
        .insert(curso.toInsertJson())
        .select('id')
        .single();
    final id = row['id'].toString();
    try {
      await salvarCargaEPares(id, cargas: cargas, aulasGeminadas: aulasGeminadas);
    } catch (_) {
      // Sem a carga o curso ficaria pela metade: desfaz a criação.
      try {
        await excluir(id);
      } catch (_) {}
      rethrow;
    }
    return id;
  }

  /// Grava nome, sala e turno e depois a carga e os pares. Se a segunda
  /// parte falhar, volta o curso para [anterior] (quando informado), para
  /// não ficar turno novo com carga antiga.
  Future<void> atualizar(
    Curso course, {
    Curso? anterior,
    required List<CargaCursoMateria> cargas,
    required List<AulaGeminadaCurso> aulasGeminadas,
  }) async {
    await _gravarCurso(course);
    try {
      await salvarCargaEPares(
        course.id,
        cargas: cargas,
        aulasGeminadas: aulasGeminadas,
      );
    } catch (_) {
      if (anterior != null) {
        try {
          await _gravarCurso(anterior);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> _gravarCurso(Curso course) => _client
      .from(_table)
      .update({
        'nome': course.nome,
        'id_sala': course.idSala == null ? null : int.parse(course.idSala!),
        'periodo_preferencia': course.preferenciaPeriodo.toDb(),
      })
      .eq('id', int.parse(course.id));

  /// Troca a carga e os pares de aula geminada do curso e apaga as aulas
  /// de matérias que saíram da carga, numa transação só (função
  /// `salvar_carga_e_pares` no banco): se falhar, nada muda.
  Future<void> salvarCargaEPares(
    String idCurso, {
    required List<CargaCursoMateria> cargas,
    required List<AulaGeminadaCurso> aulasGeminadas,
  }) async {
    final pares = <String, AulaGeminadaCurso>{
      for (final par in aulasGeminadas) par.chave: par,
    };
    await _client.rpc(
      'salvar_carga_e_pares',
      params: {
        'p_id_curso': int.parse(idCurso),
        'p_cargas': [for (final c in cargas) c.toInsertJson()],
        'p_pares': [
          for (final par in pares.values)
            par.toInsertJson(idCursoOverride: idCurso),
        ],
      },
    );
  }

  /// Carga, pares e aulas do curso saem junto (cascata no banco).
  Future<void> excluir(String id) async {
    await _client.from(_table).delete().eq('id', int.parse(id));
  }
}
