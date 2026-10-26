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

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    var digitos = novo.text.replaceAll(RegExp(r'\D'), '');
    final digitosAntigos = antigo.text.replaceAll(RegExp(r'\D'), '');
    // Apagar só um separador (":" ou " - ") apaga o número antes dele,
    // senão o separador voltaria na hora e o backspace "travaria".
    if (novo.text.length < antigo.text.length &&
        digitos == digitosAntigos &&
        digitos.isNotEmpty) {
      digitos = digitos.substring(0, digitos.length - 1);
    }
    final texto = formatarDigitosHorario(digitos);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
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
  return null;
}
