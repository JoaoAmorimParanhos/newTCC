import 'package:flutter/material.dart';
import 'package:flutter_test_project/theme/app_theme.dart';

/// Identifies a cell in the shared week × period grid (Page 2 / Page 3).
class CelulaGrade {
  const CelulaGrade({required this.indiceDia, required this.indicePeriodo});

  /// 0 = Seg … 4 = Sex
  final int indiceDia;

  /// 0–5 manhã, 6–11 tarde, 12–15 noite
  final int indicePeriodo;

  @override
  bool operator ==(Object other) =>
      other is CelulaGrade &&
      other.indiceDia == indiceDia &&
      other.indicePeriodo == indicePeriodo;

  @override
  int get hashCode => Object.hash(indiceDia, indicePeriodo);
}

///
/// - Page 2: [interativo] true — tap toggles red (unavailable).
/// - Page 3: pass [construirCelula] to show/edit aulas.
class GradeHoraria extends StatelessWidget {
  const GradeHoraria({
    super.key,
    this.interativo = false,
    this.celulasMarcadas = const {},
    this.aoAlternar,
    this.construirCelula,
    this.construirRotuloPeriodo,
    this.larguraRotulo = 64,
  });

  static const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex'];

  /// 16 períodos: 0–5 manhã, 6–11 tarde, 12–15 noite. DB: periodo 1–16.
  static const periodos = [
    '1º M',
    '2º M',
    '3º M',
    '4º M',
    '5º M',
    '6º M',
    '1º T',
    '2º T',
    '3º T',
    '4º T',
    '5º T',
    '6º T',
    '1º N',
    '2º N',
    '3º N',
    '4º N',
  ];

  static const quantidadePeriodosManha = 6;
  static const quantidadePeriodosTarde = 6;
  static const quantidadePeriodosNoite = 4;

  static int get inicioTarde => quantidadePeriodosManha;
  static int get inicioNoite => inicioTarde + quantidadePeriodosTarde;

  /// Índices dos períodos de cada turno.
  static List<int> get periodosManha => [
    for (var p = 0; p < inicioTarde; p++) p,
  ];
  static List<int> get periodosTarde => [
    for (var p = inicioTarde; p < inicioNoite; p++) p,
  ];
  static List<int> get periodosNoite => [
    for (var p = inicioNoite; p < periodos.length; p++) p,
  ];

  /// 0 = manhã, 1 = tarde, 2 = noite
  static int faixaDoPeriodo(int indicePeriodo) {
    if (indicePeriodo < inicioTarde) return 0;
    if (indicePeriodo < inicioNoite) return 1;
    return 2;
  }

  static bool periodosNaMesmaFaixa(int a, int b) =>
      faixaDoPeriodo(a) == faixaDoPeriodo(b);

  final bool interativo;
  final Set<CelulaGrade> celulasMarcadas;
  final void Function(CelulaGrade celula)? aoAlternar;

  /// When set, overrides the default empty / unavailability cell.
  final Widget Function(CelulaGrade celula)? construirCelula;

  /// When set, overrides the period label in the first column
  /// (Page 3: editable class times).
  final Widget Function(int indicePeriodo)? construirRotuloPeriodo;

  final double larguraRotulo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 24),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(
                  color: const Color(0xFFE2E8E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                columnWidths: {
                  0: FixedColumnWidth(larguraRotulo),
                  for (var i = 1; i <= dias.length; i++)
                    i: const FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    decoration:
                        const BoxDecoration(color: IfprColors.verdeFundo),
                    children: [
                      _celulaCabecalho(''),
                      ...dias.map(_celulaCabecalho),
                    ],
                  ),
                  for (final p in periodosManha) _linhaPeriodo(p),
                  _linhaSeparador('Almoço'),
                  for (final p in periodosTarde) _linhaPeriodo(p),
                  _linhaSeparador('Jantar'),
                  for (final p in periodosNoite) _linhaPeriodo(p),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TableRow _linhaPeriodo(int indicePeriodo) {
    return TableRow(
      children: [
        construirRotuloPeriodo?.call(indicePeriodo) ??
            _celulaCabecalho(periodos[indicePeriodo]),
        for (var d = 0; d < dias.length; d++)
          _celulaSlot(
            CelulaGrade(indiceDia: d, indicePeriodo: indicePeriodo),
          ),
      ],
    );
  }

  TableRow _linhaSeparador(String rotulo) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        for (var i = 0; i <= dias.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Text(
              i == 0 ? rotulo : '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _celulaCabecalho(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: IfprColors.verdeEscuro,
        ),
      ),
    );
  }

  Widget _celulaSlot(CelulaGrade celula) {
    if (construirCelula != null) {
      return construirCelula!(celula);
    }

    if (!interativo) {
      return const SizedBox(height: 48);
    }

    final marked = celulasMarcadas.contains(celula);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: marked ? Colors.red.shade600 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: aoAlternar == null ? null : () => aoAlternar!(celula),
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Icon(
                marked ? Icons.block : Icons.add,
                size: 16,
                color: marked ? Colors.white : IfprColors.cinzaClaro,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
