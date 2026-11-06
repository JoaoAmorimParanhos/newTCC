import 'package:flutter/material.dart';
import 'package:flutter_test_project/components/manual/dialogo_manual.dart';
import 'package:flutter_test_project/theme/app_theme.dart';

class LayoutBase extends StatelessWidget {
  final String titulo;
  final Widget body;

  const LayoutBase({super.key, required this.titulo, required this.body});

  @override
  Widget build(BuildContext context) {
    // Janelas estreitas: primeiro some o título; se ainda faltar espaço,
    // os botões das páginas mostram só o número (o nome fica na dica).
    final largura = MediaQuery.sizeOf(context).width;
    final mostrarTitulo = largura >= 1000;
    final compacto = largura < 760;
    return Scaffold(
      appBar: AppBar(
        // Símbolo do Instituto Federal, num quadrado branco para não sumir
        // no fundo verde do cabeçalho.
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              key: const ValueKey('simbolo-if'),
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/simbolo_if.png',
                semanticLabel: 'Instituto Federal',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        leadingWidth: 64,
        title: mostrarTitulo ? const Text("PROJETO TIMETABLE") : null,
        toolbarHeight: 72,
        actions: [
          // Nunca passa da largura que sobra: se faltar espaço, a fileira de
          // botões encolhe um pouco em vez de sair da tela.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (largura - 64 - (mostrarTitulo ? 280 : 8)).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavButton(
                    rotulo: "1. Cadastros",
                    route: "/",
                    compacto: compacto,
                  ),
                  _NavButton(
                    rotulo: "2. Disponibilidade",
                    route: "/page2",
                    compacto: compacto,
                  ),
                  _NavButton(
                    rotulo: "3. Horário",
                    route: "/page3",
                    compacto: compacto,
                  ),
                  const SizedBox(width: 12),
                  const _BotaoManual(),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _NavButton extends StatelessWidget {
  final String rotulo;
  final String route;

  /// Só o número da página ("1"), com o nome completo na dica.
  final bool compacto;

  const _NavButton({
    required this.rotulo,
    required this.route,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final selecionado = currentRoute == route;

    final botao = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: selecionado
            ? null
            : () => Navigator.pushReplacementNamed(context, route),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(
            alpha: selecionado ? 0.28 : 0.12,
          ),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(compacto ? rotulo.split('.').first : rotulo),
      ),
    );
    return compacto ? Tooltip(message: rotulo, child: botao) : botao;
  }
}

/// Botão "Como usar": abre o manual no assunto da tela atual. Fica em
/// destaque (fundo branco) e com texto, não só ícone, para ser fácil achar.
class _BotaoManual extends StatelessWidget {
  const _BotaoManual();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('botao-manual'),
      onPressed: () => mostrarManual(
        context,
        rotaAtual: ModalRoute.of(context)?.settings.name,
      ),
      icon: const Icon(Icons.help_outline, size: 22),
      label: const Text(
        'Como usar',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: IfprColors.verdeEscuro,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
