import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/pages/page3/helpers/formato_horario.dart';

/// Simula o usuário mudando o texto de [antigo] para [novo].
String _aplicar(String antigo, String novo) => const MascaraHorarioFormatter()
    .formatEditUpdate(
      TextEditingValue(text: antigo),
      TextEditingValue(text: novo),
    )
    .text;

void main() {
  group('Molde 00:00 - 00:00', () {
    test('coloca ":" e " - " conforme os números são digitados', () {
      expect(formatarDigitosHorario(''), '');
      expect(formatarDigitosHorario('0'), '0');
      expect(formatarDigitosHorario('07'), '07');
      expect(formatarDigitosHorario('073'), '07:3');
      expect(formatarDigitosHorario('0730'), '07:30');
      expect(formatarDigitosHorario('07300'), '07:30 - 0');
      expect(formatarDigitosHorario('0730082'), '07:30 - 08:2');
      expect(formatarDigitosHorario('07300820'), '07:30 - 08:20');
    });

    test('para no 8º número', () {
      expect(formatarDigitosHorario('073008209999'), '07:30 - 08:20');
      expect(_aplicar('07:30 - 08:20', '07:30 - 08:205'), '07:30 - 08:20');
    });

    test('ignora tudo que não é número', () {
      expect(_aplicar('', 'a'), '');
      expect(_aplicar('', '07h30 às 08h20'), '07:30 - 08:20');
      expect(_aplicar('07:3', '07:3x'), '07:3');
    });

    test('digitando um número por vez', () {
      var texto = '';
      for (final d in '07300820'.split('')) {
        texto = _aplicar(texto, texto + d);
      }
      expect(texto, '07:30 - 08:20');
    });

    test('apagar o separador apaga o número antes dele', () {
      expect(_aplicar('07:30 - 0', '07:30 -'), '07:30');
      expect(_aplicar('07:30', '07:3'), '07:3');
      expect(_aplicar('07:3', '07:'), '07');
      expect(_aplicar('07', '0'), '0');
    });
  });

  group('Validação do horário', () {
    test('horário completo e válido', () {
      expect(validarHorario('07:30 - 08:20'), isNull);
      expect(validarHorario('00:00 - 23:59'), isNull);
    });

    test('vazio é aceito (apaga o horário)', () {
      expect(validarHorario(''), isNull);
    });

    test('incompleto ou fora do molde', () {
      expect(validarHorario('07:30'), 'Use 00:00 - 00:00');
      expect(validarHorario('07:30 - 08:2'), 'Use 00:00 - 00:00');
      expect(validarHorario('07:30 – 08:20'), 'Use 00:00 - 00:00');
    });

    test('hora ou minuto impossível', () {
      expect(validarHorario('24:00 - 08:00'), 'Hora vai até 23');
      expect(validarHorario('07:00 - 25:00'), 'Hora vai até 23');
      expect(validarHorario('07:60 - 08:00'), 'Minuto vai até 59');
      expect(validarHorario('07:00 - 08:99'), 'Minuto vai até 59');
    });

    test('não confere se faz sentido (fim antes do início é aceito)', () {
      expect(validarHorario('08:00 - 07:50'), isNull);
    });
  });
}
