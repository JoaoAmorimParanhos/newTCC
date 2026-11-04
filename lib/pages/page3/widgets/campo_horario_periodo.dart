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

  /// Grava o texto; devolve false se não conseguiu (ex.: sem conexão).
  final Future<bool> Function(String texto)? aoSalvar;

  @override
  State<CampoHorarioPeriodo> createState() => _CampoHorarioPeriodoState();
}

class _CampoHorarioPeriodoState extends State<CampoHorarioPeriodo> {
  late final _controlador = TextEditingController(text: widget.texto);
  final _foco = FocusNode();
  String? _erro;

  /// Texto já enviado para salvar, enquanto o valor gravado
  /// ([CampoHorarioPeriodo.texto]) ainda não chegou atualizado.
  String? _enviado;

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
    if (antigo.texto != widget.texto) {
      _enviado = null;
      // Dados novos atualizam o texto, mas nunca enquanto o usuário está
      // digitando nele.
      if (!_foco.hasFocus) _controlador.text = widget.texto;
    }
  }

  @override
  void dispose() {
    _foco.dispose();
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!mounted) return;
    final texto = _controlador.text.trim();
    // Sem mudança, ou já enviado: depois do Enter o campo perde o foco e
    // passa por aqui de novo, e não pode salvar duas vezes. Também não limpa
    // o erro; ele some quando a pessoa volta a digitar.
    if (texto == widget.texto || texto == _enviado) return;
    final erro = validarHorario(texto);
    if (erro != null) {
      // Não salva: volta ao horário que já estava gravado.
      setState(() {
        _erro = erro;
        _controlador.text = widget.texto;
      });
      return;
    }
    final aoSalvar = widget.aoSalvar;
    if (aoSalvar == null) return;
    setState(() => _erro = null);
    _enviado = texto;
    final salvou = await aoSalvar(texto);
    if (!mounted || salvou) return;
    // Não gravou (ex.: sem conexão): mostra de novo o que está gravado.
    setState(() {
      _enviado = null;
      _controlador.text = widget.texto;
    });
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
