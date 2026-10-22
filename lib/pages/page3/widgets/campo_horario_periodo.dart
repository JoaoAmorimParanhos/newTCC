import 'package:flutter/material.dart';
import 'package:flutter_test_project/theme/app_theme.dart';

/// Rótulo do período ("1º M") com o horário editável embaixo, como texto
/// livre. Salva ao apertar Enter ou ao sair do campo.
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
    if (texto == widget.texto) return;
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
            onSubmitted: (_) => _confirmar(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: '00:00 - 00:00',
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}
