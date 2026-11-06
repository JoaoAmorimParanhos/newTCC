/// Texto em minúsculas e sem acentos, para comparar e ordenar nomes em
/// português ("Álgebra" e "algebra" ficam iguais).
String normalizarTexto(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final saida = StringBuffer();
  for (final ch in texto.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    saida.write(i < 0 ? ch : para[i]);
  }
  return saida.toString();
}

/// Se [texto] combina com o que foi digitado na busca: ignora maiúsculas,
/// acentos e espaços nas pontas. Busca vazia combina com tudo.
bool correspondeBusca(String texto, String busca) {
  final termo = normalizarTexto(busca.trim());
  if (termo.isEmpty) return true;
  return normalizarTexto(texto).contains(termo);
}
