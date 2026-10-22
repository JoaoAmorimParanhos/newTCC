import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test_project/model/horario/horario_periodo.dart';

class RepositorioHorarioPeriodo {
  RepositorioHorarioPeriodo({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _table = 'tb_horario_periodo';

  Stream<List<HorarioPeriodo>> observarTodos() {
    final controller = StreamController<List<HorarioPeriodo>>();
    var closed = false;

    Future<void> emit() async {
      try {
        final data = await buscarTodos();
        if (!closed && !controller.isClosed) {
          controller.add(data);
        }
      } catch (error, stackTrace) {
        if (!closed && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    final channel = _client
        .channel('watch:$_table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (_) => unawaited(emit()),
        )
        .subscribe();

    unawaited(emit());

    controller.onCancel = () async {
      closed = true;
      await _client.removeChannel(channel);
      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  Future<List<HorarioPeriodo>> buscarTodos() async {
    final data = await _client.from(_table).select();
    return (data as List)
        .map((row) => HorarioPeriodo.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Grava o texto do período (cria a linha se ainda não existir).
  Future<void> salvar(HorarioPeriodo horario) async {
    await _client.from(_table).upsert(horario.toJson(), onConflict: 'periodo');
  }
}
