import 'package:flutter/material.dart';
import 'package:flutter_test_project/pages/page3/helpers/formato_horario.dart';
import 'package:flutter_test_project/theme/app_theme.dart';

/// Rótulo do período ("1º M") com o horário editável embaixo, só com
/// números no molde "00:00 - 00:00". Salva ao apertar Enter ou ao sair do
/// campo; horário inválido não é salvo e o campo volta ao valor anterior.
class CampoHorarioPeriodo extends StatefulWidget {
  const CampoHorarioPeriodo({
    super.key,
    required this.rotulo,
    required this.texto,
    required this.aoSalvar,
  });

  final String rotulo;
  final String texto;
  final void Function(String texto)? aoSalvar;

  @override
  State<CampoHorarioPeriodo> createState() => _CampoHorarioPeriodoState();
}

class _CampoHorarioPeriodoState extends State<CampoHorarioPeriodo> {
  late final _controlador = TextEditingController(text: widget.texto);
  final _foco = FocusNode();
  String? _erro;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _confirmar();
    });
  }

  @override
  void didUpdateWidget(covariant CampoHorarioPeriodo antigo) {
    super.didUpdateWidget(antigo);
    // Dados em tempo real atualizam o texto, mas nunca enquanto o
    // usuário está digitando nele.
    if (!_foco.hasFocus && antigo.texto != widget.texto) {
      _controlador.text = widget.texto;
    }
  }

  @override
  void dispose() {
    _foco.dispose();
    _controlador.dispose();
    super.dispose();
  }

  void _confirmar() {
    final texto = _controlador.text.trim();
    // Sem mudança. Não limpa o erro: depois do Enter o campo perde o foco e
    // passa por aqui de novo; o erro some quando a pessoa volta a digitar.
    if (texto == widget.texto) return;
    final erro = validarHorario(texto);
    if (erro != null) {
      // Não salva: volta ao horário que já estava gravado.
      setState(() {
        _erro = erro;
        _controlador.text = widget.texto;
      });
      return;
    }
    setState(() => _erro = null);
    widget.aoSalvar?.call(texto);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.rotulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: IfprColors.verdeEscuro,
            ),
          ),
          TextField(
            controller: _controlador,
            focusNode: _foco,
            enabled: widget.aoSalvar != null,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            keyboardType: TextInputType.number,
            inputFormatters: const [MascaraHorarioFormatter()],
            onChanged: (_) {
              if (_erro != null) setState(() => _erro = null);
            },
            onSubmitted: (_) => _confirmar(),
            decoration: InputDecoration(
              isDense: true,
              hintText: moldeHorario,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
              errorText: _erro,
              errorMaxLines: 2,
              errorStyle: const TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }
}
