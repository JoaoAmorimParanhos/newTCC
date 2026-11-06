import 'package:flutter/material.dart';
import 'package:flutter_test_project/theme/app_theme.dart';

class ColunaQuadro extends StatefulWidget {
  final String titulo;
  final IconData icone;
  final int flex;

  final List<Widget> acoes;

  /// Conteúdo fixo da coluna (sem busca).
  final Widget? child;

  /// Com isto, a coluna mostra um campo "Buscar" abaixo do título e monta
  /// o conteúdo com o texto digitado (para filtrar a lista).
  final Widget Function(String busca)? construirComBusca;

  const ColunaQuadro({
    super.key,
    required this.titulo,
    required this.icone,
    this.child,
    this.construirComBusca,
    this.acoes = const [],
    this.flex = 1,
  }) : assert(child != null || construirComBusca != null);

  @override
  State<ColunaQuadro> createState() => _ColunaQuadroState();
}

class _ColunaQuadroState extends State<ColunaQuadro> {
  final _controladorBusca = TextEditingController();

  @override
  void dispose() {
    _controladorBusca.dispose();
    super.dispose();
  }

  Widget _campoBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: TextField(
        key: ValueKey('busca-${widget.titulo}'),
        controller: _controladorBusca,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Buscar',
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          border: const OutlineInputBorder(),
          suffixIcon: _controladorBusca.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(_controladorBusca.clear),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.titulo;
    final icone = widget.icone;
    final acoes = widget.acoes;
    final flex = widget.flex;
    final construir = widget.construirComBusca;
    final conteudo = construir == null
        ? widget.child!
        : construir(_controladorBusca.text);
    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8E0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: IfprColors.verde,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(icone, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...acoes,
                ],
              ),
            ),
            if (construir != null) _campoBusca(),
            Expanded(child: conteudo),
          ],
        ),
      ),
    );
  }
}

class DicaColunaVazia extends StatelessWidget {
  final String mensagem;
  const DicaColunaVazia({super.key, required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(color: IfprColors.cinzaClaro),
        ),
      ),
    );
  }
}

/// Mensagem da coluna quando a busca não encontra nada.
class DicaBuscaVazia extends StatelessWidget {
  final String busca;
  const DicaBuscaVazia({super.key, required this.busca});

  @override
  Widget build(BuildContext context) =>
      DicaColunaVazia(mensagem: 'Nada encontrado para "${busca.trim()}"');
}
