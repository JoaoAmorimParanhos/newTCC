import 'package:supabase_flutter/supabase_flutter.dart';

/// Linhas por página. O Supabase devolve no máximo 1000 linhas por busca
/// (limite do PostgREST); sem paginar, o que passasse disso sumiria.
const int linhasPorPagina = 1000;

/// Busca todas as linhas de [tabela], de [linhasPorPagina] em
/// [linhasPorPagina], ordenando por [ordem] (colunas que identificam a
/// linha, para as páginas não repetirem nem pularem linhas).
Future<List<Map<String, dynamic>>> buscarTodasLinhas(
  SupabaseClient client,
  String tabela, {
  required List<String> ordem,
}) async {
  final linhas = <Map<String, dynamic>>[];
  for (var inicio = 0; ; inicio += linhasPorPagina) {
    PostgrestTransformBuilder<PostgrestList> consulta = client
        .from(tabela)
        .select();
    for (final coluna in ordem) {
      consulta = consulta.order(coluna, ascending: true);
    }
    final pagina = await consulta.range(
      inicio,
      inicio + linhasPorPagina - 1,
    );
    linhas.addAll(pagina);
    if (pagina.length < linhasPorPagina) break;
  }
  return linhas;
}
