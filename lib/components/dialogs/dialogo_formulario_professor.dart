import 'package:flutter/material.dart';
import 'package:flutter_test_project/model/materia/materia.dart';

class ResultadoFormularioProfessor {
  const ResultadoFormularioProfessor({
    required this.nome,
    required this.idsMaterias,
  });

  final String nome;
  final List<String> idsMaterias;
}

Future<ResultadoFormularioProfessor?> mostrarDialogoFormularioProfessor(
  BuildContext context, {
  required String titulo,
  required List<Materia> materias,
  String? nomeInicial,
  List<String> idsMateriasIniciais = const [],
}) {
  return showDialog<ResultadoFormularioProfessor>(
    context: context,
    builder: (context) => _ProfessorFormDialog(
      titulo: titulo,
      materias: materias,
      nomeInicial: nomeInicial,
      idsMateriasIniciais: idsMateriasIniciais,
    ),
  );
}

class _ProfessorFormDialog extends StatefulWidget {
  const _ProfessorFormDialog({
    required this.titulo,
    required this.materias,
    this.nomeInicial,
    required this.idsMateriasIniciais,
  });

  final String titulo;
  final List<Materia> materias;
  final String? nomeInicial;
  final List<String> idsMateriasIniciais;

  @override
  State<_ProfessorFormDialog> createState() => _ProfessorFormDialogState();
}

class _ProfessorFormDialogState extends State<_ProfessorFormDialog> {
  late final TextEditingController _controlador;
  late final Set<String> _idsSelecionados;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: widget.nomeInicial ?? '');
    _idsSelecionados = {...widget.idsMateriasIniciais};
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
      ResultadoFormularioProfessor(
        nome: nome,
        idsMaterias: _idsSelecionados.toList(),
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
              'Componentes que leciona',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (widget.materias.isEmpty)
              const Text('Nenhum componente cadastrado ainda.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.materias.map((subject) {
                      final selecionado = _idsSelecionados.contains(subject.id);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selecionado,
                        title: Text(subject.nome),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _idsSelecionados.add(subject.id);
                            } else {
                              _idsSelecionados.remove(subject.id);
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
        FilledButton(
          onPressed: _enviar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
