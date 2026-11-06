import 'package:flutter/material.dart';
import 'package:flutter_test_project/components/manual/conteudo_manual.dart';
import 'package:flutter_test_project/theme/app_theme.dart';

/// Abre o manual "Como usar", já no assunto da tela em que a pessoa está.
Future<void> mostrarManual(BuildContext context, {String? rotaAtual}) {
  return showDialog<void>(
    context: context,
    builder: (_) => DialogoManual(secaoInicial: secaoInicialDaRota(rotaAtual)),
  );
}

/// Janela do manual: índice de assuntos à esquerda e o passo a passo do
/// assunto escolhido à direita, com letra grande e botões Anterior/Próximo.
class DialogoManual extends StatefulWidget {
  const DialogoManual({super.key, this.secaoInicial = 0});

  final int secaoInicial;

  @override
  State<DialogoManual> createState() => _DialogoManualState();
}

class _DialogoManualState extends State<DialogoManual> {
  late int _atual = widget.secaoInicial.clamp(0, secoesManual.length - 1);
  final _rolagem = ScrollController();

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  void _ir(int indice) {
    setState(() => _atual = indice);
    if (_rolagem.hasClients) _rolagem.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    final largura = (tela.width * 0.92).clamp(320.0, 1040.0);
    final altura = (tela.height * 0.86).clamp(360.0, 760.0);
    final estreita = largura < 720;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: largura,
        height: altura,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cabecalho(context),
            const Divider(height: 1),
            Expanded(
              child: estreita
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _escolhaEstreita(),
                        const Divider(height: 1),
                        Expanded(child: _conteudo()),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 280, child: _indice()),
                        const VerticalDivider(width: 1),
                        Expanded(child: _conteudo()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
      child: Row(
        children: [
          const Icon(Icons.help_outline, color: IfprColors.verde, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Como usar o Projeto Timetable',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('manual-fechar'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 24),
            label: const Text('Fechar', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }

  Widget _indice() {
    // Coluna (não lista preguiçosa): todos os assuntos ficam montados e o
    // índice só rola se a tela for muito baixa.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < secoesManual.length; i++) _itemIndice(i),
        ],
      ),
    );
  }

  Widget _itemIndice(int i) {
    final secao = secoesManual[i];
    final selecionada = i == _atual;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selecionada ? IfprColors.verdeFundo : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('manual-indice-${secao.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => _ir(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  secao.icone,
                  size: 22,
                  color: selecionada
                      ? IfprColors.verdeEscuro
                      : IfprColors.cinzaClaro,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${i + 1}. ${secao.titulo}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: selecionada
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selecionada
                          ? IfprColors.verdeEscuro
                          : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Em telas estreitas o índice vira uma lista de escolha no alto.
  Widget _escolhaEstreita() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: DropdownButtonFormField<int>(
        key: ValueKey('manual-escolha-$_atual'),
        initialValue: _atual,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Assunto'),
        items: [
          for (var i = 0; i < secoesManual.length; i++)
            DropdownMenuItem(
              value: i,
              child: Text(
                '${i + 1}. ${secoesManual[i].titulo}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (i) {
          if (i != null) _ir(i);
        },
      ),
    );
  }

  Widget _conteudo() {
    final secao = secoesManual[_atual];
    final ultimo = _atual == secoesManual.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scrollbar(
            controller: _rolagem,
            thumbVisibility: true,
            child: ListView(
              controller: _rolagem,
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              children: [
                Text(
                  secao.onde,
                  style: const TextStyle(
                    fontSize: 16,
                    color: IfprColors.cinzaClaro,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  secao.titulo,
                  key: const ValueKey('manual-titulo'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: IfprColors.verdeEscuro,
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < secao.passos.length; i++)
                  _Passo(numero: i + 1, texto: secao.passos[i]),
                if (secao.dica != null) _Dica(texto: secao.dica!),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                key: const ValueKey('manual-anterior'),
                onPressed: _atual == 0 ? null : () => _ir(_atual - 1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Anterior', style: TextStyle(fontSize: 17)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${_atual + 1} de ${secoesManual.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: IfprColors.cinzaClaro,
                  ),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('manual-proximo'),
                onPressed: ultimo
                    ? () => Navigator.of(context).pop()
                    : () => _ir(_atual + 1),
                icon: Icon(ultimo ? Icons.check : Icons.arrow_forward),
                label: Text(
                  ultimo ? 'Concluir' : 'Próximo',
                  style: const TextStyle(fontSize: 17),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Um passo numerado. O que está entre **asteriscos** sai em negrito.
class _Passo extends StatelessWidget {
  const _Passo({required this.numero, required this.texto});

  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: IfprColors.verdeFundo,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: IfprColors.verdeEscuro,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                textoComNegrito(texto),
                style: const TextStyle(fontSize: 18, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dica extends StatelessWidget {
  const _Dica({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF2C46B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xFF8A5A00)),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              textoComNegrito(texto),
              style: const TextStyle(
                fontSize: 17,
                height: 1.5,
                color: Color(0xFF5C3D00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Transforma "Clique em **Salvar**" em texto com "Salvar" em negrito.
TextSpan textoComNegrito(String texto) {
  final partes = texto.split('**');
  return TextSpan(
    children: [
      for (var i = 0; i < partes.length; i++)
        if (partes[i].isNotEmpty)
          TextSpan(
            text: partes[i],
            style: i.isOdd
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
    ],
  );
}
