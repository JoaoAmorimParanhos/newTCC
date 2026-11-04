import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

var _proximoCanal = 0;

/// Stream com o conteúdo de [tabela]: busca uma vez ao começar e de novo
/// quando o banco avisa que a tabela mudou (tempo real do Supabase).
///
/// Várias mudanças seguidas (ex.: "Gerar" grava centenas de aulas) viram
/// uma busca só, depois de [espera] sem novos avisos. Se uma resposta mais
/// antiga chegar depois de uma mais nova, ela é descartada.
Stream<List<T>> observarTabela<T>({
  required SupabaseClient client,
  required String tabela,
  required Future<List<T>> Function() buscar,
  Duration espera = const Duration(milliseconds: 300),
}) {
  final controller = StreamController<List<T>>();
  var fechado = false;
  var geracao = 0;
  Timer? agendada;

  Future<void> emitir() async {
    final minha = ++geracao;
    try {
      final dados = await buscar();
      if (!fechado && minha == geracao) controller.add(dados);
    } catch (error, stackTrace) {
      if (!fechado && minha == geracao) {
        controller.addError(error, stackTrace);
      }
    }
  }

  // Nome único: recriar o stream (ref.invalidate) não reaproveita um canal
  // que ainda está sendo fechado.
  final canal = client
      .channel('watch:$tabela:${_proximoCanal++}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tabela,
        callback: (_) {
          agendada?.cancel();
          agendada = Timer(espera, () => unawaited(emitir()));
        },
      )
      .subscribe();

  unawaited(emitir());

  controller.onCancel = () async {
    fechado = true;
    agendada?.cancel();
    await client.removeChannel(canal);
    if (!controller.isClosed) await controller.close();
  };

  return controller.stream;
}
