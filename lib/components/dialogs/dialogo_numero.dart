import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test_project/model/sala/sala.dart';

class DadosSala {
  const DadosSala({required this.numero, required this.tipo});

  final int numero;
  final TipoSala tipo;
}

/// Formulário de sala: tipo (cadastrável pelo usuário) e número.
///
/// [aoCriarTipo] grava um tipo novo e devolve o tipo criado, ou lança
/// [TipoSalaDuplicado] se o nome já existe.
Future<DadosSala?> mostrarDialogoNumero(
  BuildContext context, {
  required String titulo,
  required List<TipoSala> tipos,
  required Future<TipoSala> Function(String nome) aoCriarTipo,
  int? numeroInicial,
  TipoSala? tipoInicial,
  String rotulo = 'Número',
}) {
  return showDialog<DadosSala>(
    context: context,
    builder: (context) => _NumberFormDialog(
      titulo: titulo,
      tipos: tipos,
      aoCriarTipo: aoCriarTipo,
      numeroInicial: numeroInicial,
      tipoInicial: tipoInicial,
      rotulo: rotulo,
    ),
  );
}

class _NumberFormDialog extends StatefulWidget {
  const _NumberFormDialog({
    required this.titulo,
    required this.tipos,
    required this.aoCriarTipo,
    this.numeroInicial,
    this.tipoInicial,
    required this.rotulo,
  });

  final String titulo;
  final List<TipoSala> tipos;
  final Future<TipoSala> Function(String nome) aoCriarTipo;
  final int? numeroInicial;
  final TipoSala? tipoInicial;
  final String rotulo;

  @override
  State<_NumberFormDialog> createState() => _NumberFormDialogState();
}

class _NumberFormDialogState extends State<_NumberFormDialog> {
  late final TextEditingController _controlador;
  final _controladorNovoTipo = TextEditingController();
  late final List<TipoSala> _tipos;
  TipoSala? _tipo;
  bool _criandoTipo = false;
  bool _salvandoTipo = false;
  String? _erro;
  String? _erroTipo;

  @override
  void initState() {
    super.initState();
    _tipos = List.of(widget.tipos);
    final inicial = widget.tipoInicial;
    if (inicial != null && !_tipos.contains(inicial)) _tipos.add(inicial);
    _tipo = inicial ?? (_tipos.isEmpty ? null : _tipos.first);
    _controlador = TextEditingController(
      text: widget.numeroInicial?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controlador.dispose();
    _controladorNovoTipo.dispose();
    super.dispose();
  }

  Future<void> _salvarNovoTipo() async {
    final nome = _controladorNovoTipo.text.trim();
    if (nome.isEmpty) {
      setState(() => _erroTipo = 'Informe o nome do tipo');
      return;
    }
    final existente = _tipos.where(
      (t) => t.nome.toLowerCase() == nome.toLowerCase(),
    );
    if (existente.isNotEmpty) {
      setState(() {
        _tipo = existente.first;
        _criandoTipo = false;
        _erroTipo = null;
      });
      return;
    }

    setState(() => _salvandoTipo = true);
    try {
      final novo = await widget.aoCriarTipo(nome);
      if (!mounted) return;
      setState(() {
        _tipos.add(novo);
        _tipo = novo;
        _criandoTipo = false;
        _erroTipo = null;
        _controladorNovoTipo.clear();
      });
    } on TipoSalaDuplicado {
      if (mounted) setState(() => _erroTipo = 'Esse tipo já existe');
    } catch (e) {
      if (mounted) setState(() => _erroTipo = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _salvandoTipo = false);
    }
  }

  void _enviar() {
    final tipo = _tipo;
    if (tipo == null) {
      setState(() => _erro = 'Escolha ou crie um tipo de sala');
      return;
    }
    final raw = _controlador.text.trim();
    final numero = int.tryParse(raw);
    if (numero == null || numero < 1) {
      setState(() => _erro = 'Informe um número válido (≥ 1)');
      return;
    }
    Navigator.of(context).pop(DadosSala(numero: numero, tipo: tipo));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_criandoTipo)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controladorNovoTipo,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Novo tipo (ex.: Quadra)',
                        errorText: _erroTipo,
                      ),
                      onSubmitted: (_) => _salvarNovoTipo(),
                    ),
                  ),
                  IconButton(
                    onPressed: _salvandoTipo ? null : _salvarNovoTipo,
                    tooltip: 'Criar tipo',
                    icon: const Icon(Icons.check),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _criandoTipo = false;
                      _erroTipo = null;
                    }),
                    tooltip: 'Cancelar',
                    icon: const Icon(Icons.close),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TipoSala>(
                      key: ValueKey('tipo-${_tipo?.id}-${_tipos.length}'),
                      initialValue: _tipo,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: _tipos
                          .map(
                            (tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(
                                tipo.nome,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _tipo = value);
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _criandoTipo = true),
                    tooltip: 'Novo tipo de sala',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _controlador,
              autofocus: !_criandoTipo,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: widget.rotulo,
                errorText: _erro,
              ),
              onSubmitted: (_) => _enviar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _enviar, child: const Text('Salvar')),
      ],
    );
  }
}
