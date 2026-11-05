import 'package:flutter/material.dart';
import 'package:flutter_test_project/theme/app_theme.dart';

/// Botão (?) que explica o campo "Bloco" da carga do curso.
class BotaoAjudaBloco extends StatelessWidget {
  const BotaoAjudaBloco({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('ajuda-bloco'),
      tooltip: 'O que é Bloco?',
      icon: const Icon(Icons.help_outline, color: IfprColors.verde),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const _DialogoAjuda(
          titulo: 'O que é "Bloco"?',
          texto:
              'Bloco é quantas aulas da matéria acontecem uma atrás da '
              'outra, no mesmo dia.\n\n'
              'Exemplo: Matemática com 4 aulas e Bloco 2 vira 2 dias com 2 '
              'aulas seguidas.',
          grade: _MiniGrade(
            linhas: 3,
            celulas: {
              (0, 0): _Celula.inteira('Matemática'),
              (0, 1): _Celula.inteira('Matemática'),
              (2, 0): _Celula.inteira('Matemática'),
              (2, 1): _Celula.inteira('Matemática'),
            },
          ),
          nota: 'Na turma da Noite o Bloco vai até 4 (são 4 horários).',
        ),
      ),
    );
  }
}

/// Botão (?) que explica o campo "Blocos" da aula geminada.
class BotaoAjudaBlocosGeminada extends StatelessWidget {
  const BotaoAjudaBlocosGeminada({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('ajuda-blocos-geminada'),
      tooltip: 'O que é Blocos?',
      icon: const Icon(Icons.help_outline, color: IfprColors.verde),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const _DialogoAjuda(
          titulo: 'O que é "Blocos" na aula geminada?',
          texto:
              'Na aula geminada a turma se divide em 2 grupos ao mesmo tempo '
              '(G1 numa matéria, G2 na outra). "Blocos" é em quantas partes '
              'essas aulas são divididas ao longo da semana.\n\n'
              'Exemplo: ADS com 2 aulas e Programação com 4, em 2 blocos, '
              'vira 2 dias com 2 horários cada. Quando uma matéria tem menos '
              'aulas, o grupo dela fica livre no horário que sobra.',
          grade: _MiniGrade(
            linhas: 3,
            celulas: {
              (0, 0): _Celula.dividida('ADS', 'Programação'),
              (0, 1): _Celula.dividida(null, 'Programação'),
              (2, 0): _Celula.dividida('ADS', 'Programação'),
              (2, 1): _Celula.dividida(null, 'Programação'),
            },
          ),
          nota: '"Livre" = aquele grupo não tem aula nesse horário.',
        ),
      ),
    );
  }
}

class _DialogoAjuda extends StatelessWidget {
  const _DialogoAjuda({
    required this.titulo,
    required this.texto,
    required this.grade,
    required this.nota,
  });

  final String titulo;
  final String texto;
  final Widget grade;
  final String nota;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(texto),
              const SizedBox(height: 16),
              grade,
              const SizedBox(height: 8),
              Text(
                nota,
                style: const TextStyle(
                  fontSize: 12,
                  color: IfprColors.cinzaClaro,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}

/// Conteúdo de uma célula da mini grade.
class _Celula {
  const _Celula.inteira(String materia) : g1 = materia, g2 = null, dividida = false;
  const _Celula.dividida(this.g1, this.g2) : dividida = true;

  final String? g1;
  final String? g2;
  final bool dividida;
}

/// Grade pequena (Seg–Sex × [linhas] horários) só para ilustrar.
class _MiniGrade extends StatelessWidget {
  const _MiniGrade({required this.linhas, required this.celulas});

  final int linhas;

  /// (dia, horário) → conteúdo.
  final Map<(int, int), _Celula> celulas;

  static const _dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex'];

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: const Color(0xFFE2E8E0)),
      columnWidths: const {0: FixedColumnWidth(40)},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: IfprColors.verdeFundo),
          children: [
            const SizedBox(),
            for (final d in _dias) _texto(d, negrito: true),
          ],
        ),
        for (var h = 0; h < linhas; h++)
          TableRow(
            children: [
              _texto('${h + 1}º', negrito: true),
              for (var d = 0; d < _dias.length; d++) _celula(celulas[(d, h)]),
            ],
          ),
      ],
    );
  }

  Widget _texto(String texto, {bool negrito = false, bool livre = false}) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: negrito ? FontWeight.w700 : FontWeight.w500,
          fontStyle: livre ? FontStyle.italic : FontStyle.normal,
          color: livre ? IfprColors.cinzaClaro : IfprColors.verdeEscuro,
        ),
      ),
    );
  }

  Widget _celula(_Celula? c) {
    if (c == null) return const SizedBox(height: 36);
    final fundo = Container(
      height: 36,
      color: IfprColors.verdeFundo,
      alignment: Alignment.center,
      child: c.dividida
          ? Row(
              children: [
                Expanded(
                  child: _texto(
                    c.g1 == null ? 'G1 Livre' : 'G1 ${c.g1}',
                    livre: c.g1 == null,
                  ),
                ),
                Container(width: 1, color: IfprColors.verde),
                Expanded(child: _texto('G2 ${c.g2}')),
              ],
            )
          : _texto(c.g1!),
    );
    return fundo;
  }
}
