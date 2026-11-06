import 'package:flutter/services.dart';

/// Molde do horário de um período: "07:30 - 08:20".
const String moldeHorario = '00:00 - 00:00';

/// Monta o horário no molde a partir dos números digitados, colocando
/// ":" e " - " sozinho. Aceita no máximo 8 números (HHMMHHMM).
/// Ex.: "0730" → "07:30"; "07300820" → "07:30 - 08:20".
String formatarDigitosHorario(String digitos) {
  final d = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
  final texto = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 2 || i == 6) texto.write(':');
    if (i == 4) texto.write(' - ');
    texto.write(d[i]);
  }
  return texto.toString();
}

/// Só deixa digitar números e encaixa no molde [moldeHorario].
class MascaraHorarioFormatter extends TextInputFormatter {
  const MascaraHorarioFormatter();

  static final _naoDigito = RegExp(r'\D');

  /// Horários colados com hora de 1 dígito ("7:30 - 8:20", "07h30 às 8h20")
  /// viram "07300820". Null se não houver nenhum "H:MM" no texto.
  static String? _lerColado(String texto) {
    final achados = RegExp(r'(\d{1,2})\s*[:hH]\s*(\d{2})').allMatches(texto);
    if (achados.isEmpty) return null;
    return achados
        .take(2)
        .map((m) => m.group(1)!.padLeft(2, '0') + m.group(2)!)
        .join();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    final cursor = novo.selection.isValid
        ? novo.selection.end.clamp(0, novo.text.length)
        : novo.text.length;
    var digitos = novo.text.replaceAll(_naoDigito, '');
    // Quantos números ficam antes do cursor: é onde ele volta a ficar.
    var antes = novo.text.substring(0, cursor).replaceAll(_naoDigito, '').length;
    final digitosAntigos = antigo.text.replaceAll(_naoDigito, '');

    // Trecho que entrou no lugar do antigo (o que mudou entre os dois).
    var prefixo = 0;
    final menor = antigo.text.length < novo.text.length
        ? antigo.text.length
        : novo.text.length;
    while (prefixo < menor && antigo.text[prefixo] == novo.text[prefixo]) {
      prefixo++;
    }
    var sufixo = 0;
    while (sufixo < menor - prefixo &&
        antigo.text[antigo.text.length - 1 - sufixo] ==
            novo.text[novo.text.length - 1 - sufixo]) {
      sufixo++;
    }
    final inserido = novo.text.substring(prefixo, novo.text.length - sufixo);
    // Digitar insere 1 caractere; mais que isso é colar. Se o colado tem
    // um "H:MM", lê o campo inteiro como horário (funciona também colando
    // por cima de um horário já preenchido, com texto mais curto).
    final colado = inserido.length > 1 && _lerColado(inserido) != null
        ? _lerColado(novo.text)
        : null;

    if (colado != null) {
      digitos = colado;
      antes = colado.length;
    } else if (novo.text.length < antigo.text.length &&
        digitos == digitosAntigos &&
        antes > 0) {
      // Apagou só um separador (":" ou " - "): apaga o número à esquerda
      // dele, senão o separador voltaria na hora e o backspace "travaria".
      digitos = digitos.substring(0, antes - 1) + digitos.substring(antes);
      antes--;
    }

    if (digitos.length > 8) {
      // Digitou no meio de um horário completo: o número novo substitui o
      // que estava logo depois do cursor.
      if (antes < digitos.length) {
        digitos = digitos.substring(0, antes) + digitos.substring(antes + 1);
      }
      digitos = digitos.substring(0, 8);
      if (antes > 8) antes = 8;
    }

    final texto = formatarDigitosHorario(digitos);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: _posicaoDepoisDe(texto, antes)),
    );
  }

  /// Posição no [texto] logo depois do número de ordem [quantidade].
  static int _posicaoDepoisDe(String texto, int quantidade) {
    if (quantidade <= 0) return 0;
    var vistos = 0;
    for (var i = 0; i < texto.length; i++) {
      if (_naoDigito.hasMatch(texto[i])) continue;
      vistos++;
      if (vistos == quantidade) return i + 1;
    }
    return texto.length;
  }
}

/// Erro do horário digitado, ou null se pode salvar.
/// Vazio é aceito (apaga o horário do período).
String? validarHorario(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'^(\d{2}):(\d{2}) - (\d{2}):(\d{2})$').firstMatch(t);
  if (m == null) return 'Use $moldeHorario';
  final numeros = [for (var i = 1; i <= 4; i++) int.parse(m.group(i)!)];
  if (numeros[0] > 23 || numeros[2] > 23) return 'Hora vai até 23';
  if (numeros[1] > 59 || numeros[3] > 59) return 'Minuto vai até 59';
  final inicio = numeros[0] * 60 + numeros[1];
  final fim = numeros[2] * 60 + numeros[3];
  if (fim <= inicio) return 'O fim deve ser depois do início';
  return null;
}
