import 'package:flutter/material.dart';
import 'package:flutter_test_project/model/professor/professor.dart';

class ResultadoFormularioMateria {
  const ResultadoFormularioMateria({
    required this.nome,
    required this.idsProfessores,
  });

  final String nome;
  final List<String> idsProfessores;
}

Future<ResultadoFormularioMateria?> mostrarDialogoFormularioMateria(
  BuildContext context, {
  required String titulo,
  required List<Professor> professores,
  String? nomeInicial,
  List<String> idsProfessoresIniciais = const [],
}) {
  return showDialog<ResultadoFormularioMateria>(
    context: context,
    builder: (context) => _MateriaFormDialog(
      titulo: titulo,
      professores: professores,
      nomeInicial: nomeInicial,
      idsProfessoresIniciais: idsProfessoresIniciais,
    ),
  );
}

class _MateriaFormDialog extends StatefulWidget {
  const _MateriaFormDialog({
    required this.titulo,
    required this.professores,
    this.nomeInicial,
    required this.idsProfessoresIniciais,
  });

  final String titulo;
  final List<Professor> professores;
  final String? nomeInicial;
  final List<String> idsProfessoresIniciais;

  @override
  State<_MateriaFormDialog> createState() => _MateriaFormDialogState();
}

class _MateriaFormDialogState extends State<_MateriaFormDialog> {
  late final TextEditingController _controlador;
  late final Set<String> _idsSelecionados;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: widget.nomeInicial ?? '');
    _idsSelecionados = {...widget.idsProfessoresIniciais};
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _enviar() {
    final nome = _controlador.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe um nome');
      return;
    }
    Navigator.of(context).pop(
      ResultadoFormularioMateria(
        nome: nome,
        idsProfessores: _idsSelecionados.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controlador,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Nome',
                errorText: _erro,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Professores que dão esta matéria',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (widget.professores.isEmpty)
              const Text('Nenhum professor cadastrado ainda.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.professores.map((professor) {
                      final selecionado = _idsSelecionados.contains(
                        professor.id,
                      );
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selecionado,
                        title: Text(professor.nome),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _idsSelecionados.add(professor.id);
                            } else {
                              _idsSelecionados.remove(professor.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
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
