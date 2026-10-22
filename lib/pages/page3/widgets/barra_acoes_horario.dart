import 'package:flutter/material.dart';
import 'package:flutter_test_project/theme/app_theme.dart';

/// Ações que valem para todas as turmas, sempre visíveis no topo da Página 3.
class BarraAcoesHorario extends StatelessWidget {
  const BarraAcoesHorario({
    super.key,
    required this.aoGerar,
    required this.aoPdf,
  });

  final VoidCallback? aoGerar;
  final VoidCallback? aoPdf;

  static const _padding = EdgeInsets.symmetric(horizontal: 24, vertical: 18);
  static const _texto = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            key: const ValueKey('botao-gerar'),
            onPressed: aoGerar,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Gerar'),
            style: FilledButton.styleFrom(
              backgroundColor: IfprColors.verde,
              padding: _padding,
              textStyle: _texto,
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('botao-pdf'),
            onPressed: aoPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: IfprColors.verdeEscuro,
              padding: _padding,
              textStyle: _texto,
              side: const BorderSide(color: IfprColors.verde, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}
