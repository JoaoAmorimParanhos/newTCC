import 'package:flutter/material.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_confirmar_exclusao.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/model/materia/materia.dart';

class ResultadoFormularioAula {
  const ResultadoFormularioAula({
    required this.idMateria,
    required this.idProfessor,
    this.idSala,
  });

  final String idMateria;
  final String idProfessor;
  final String? idSala;
}

/// Devolvido quando a pessoa confirma a exclusão (só com [permitirExcluir]).
class ExclusaoFormularioAula {
  const ExclusaoFormularioAula();
}

Future<Object?> mostrarDialogoFormularioAula(
  BuildContext context, {
  required String titulo,
  required List<Materia> materias,
  required List<Professor> Function(String idMateria) professoresDaMateria,
  required List<Sala> salas,
  String? idMateriaInicial,
  String? idProfessorInicial,
  String? idSalaInicial,
  bool permitirExcluir = false,
  String? mensagemExclusao,

  /// Confere a aula antes de fechar; devolve o motivo da recusa ou null.
  /// Com recusa o diálogo fica aberto e mostra o motivo (nada se perde).
  String? Function(ResultadoFormularioAula resultado)? validar,
}) {
  return showDialog<Object>(
    context: context,
    builder: (context) => _AulaFormDialog(
      titulo: titulo,
      materias: materias,
      salas: salas,
      professoresDaMateria: professoresDaMateria,
      idMateriaInicial: idMateriaInicial,
      idProfessorInicial: idProfessorInicial,
      idSalaInicial: idSalaInicial,
      permitirExcluir: permitirExcluir,
      mensagemExclusao: mensagemExclusao,
      validar: validar,
    ),
  );
}

class _AulaFormDialog extends StatefulWidget {
  const _AulaFormDialog({
    required this.titulo,
    required this.materias,
    required this.salas,
    required this.professoresDaMateria,
    this.idMateriaInicial,
    this.idProfessorInicial,
    this.idSalaInicial,
    this.permitirExcluir = false,
    this.mensagemExclusao,
    this.validar,
  });

  final String titulo;
  final List<Materia> materias;
  final List<Sala> salas;
  final List<Professor> Function(String idMateria) professoresDaMateria;
  final String? idMateriaInicial;
  final String? idProfessorInicial;
  final String? idSalaInicial;
  final bool permitirExcluir;
  final String? mensagemExclusao;
  final String? Function(ResultadoFormularioAula resultado)? validar;

  @override
  State<_AulaFormDialog> createState() => _AulaFormDialogState();
}

class _AulaFormDialogState extends State<_AulaFormDialog> {
  String? _idMateria;
  String? _idProfessor;
  String? _idSala;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final idsMaterias = widget.materias.map((s) => s.id).toSet();
    _idMateria = _seEm(widget.idMateriaInicial, idsMaterias);

    final roomIds = widget.salas.map((r) => r.id).toSet();
    final initialRoom = widget.idSalaInicial;
    _idSala = initialRoom == null ? null : _seEm(initialRoom, roomIds);

    final idMateria = _idMateria;
    if (idMateria != null) {
      final professorIds =
          widget.professoresDaMateria(idMateria).map((p) => p.id).toSet();
      _idProfessor = _seEm(widget.idProfessorInicial, professorIds);
    }
  }

  String? _seEm(String? id, Set<String> valid) {
    if (id == null) return null;
    return valid.contains(id) ? id : null;
  }

  List<Professor> get _professores {
    final idMateria = _idMateria;
    if (idMateria == null) return const [];
    return widget.professoresDaMateria(idMateria);
  }

  void _enviar() {
    final idMateria = _idMateria;
    final idProfessor = _idProfessor;
    if (idMateria == null) {
      setState(() => _erro = 'Selecione uma matéria');
      return;
    }
    if (idProfessor == null) {
      setState(() => _erro = 'Selecione um professor');
      return;
    }
    if (!_professores.any((p) => p.id == idProfessor)) {
      setState(() => _erro = 'Selecione um professor disponível');
      return;
    }
    final resultado = ResultadoFormularioAula(
      idMateria: idMateria,
      idProfessor: idProfessor,
      idSala: _idSala,
    );
    // Ex.: professor atual ficou indisponível ou matéria saiu da carga:
    // avisa aqui, sem fechar, para a pessoa corrigir sem perder a edição.
    final recusa = widget.validar?.call(resultado);
    if (recusa != null) {
      setState(() => _erro = recusa);
      return;
    }
    Navigator.of(context).pop(resultado);
  }

  Future<void> _confirmarExclusao() async {
    final confirmed = await mostrarDialogoConfirmarExclusao(
      context,
      titulo: 'Excluir aula',
      mensagem: widget.mensagemExclusao ?? 'Excluir esta aula?',
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop(const ExclusaoFormularioAula());
  }

  @override
  Widget build(BuildContext context) {
    final professores = _professores;
    final subjectValue = _seEm(_idMateria, widget.materias.map((s) => s.id).toSet());
    final professorValue =
        _seEm(_idProfessor, professores.map((p) => p.id).toSet());
    final roomValue = _idSala == null
        ? null
        : _seEm(_idSala, widget.salas.map((r) => r.id).toSet());

    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.materias.isEmpty)
              const Text('Este curso não tem matérias na carga horária.')
            else ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('subject-$subjectValue'),
                initialValue: subjectValue,
                decoration: const InputDecoration(labelText: 'Matéria'),
                items: widget.materias
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.nome, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _idMateria = value;
                    _idProfessor = null;
                    _erro = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('prof-$_idMateria-$professorValue'),
                initialValue: professorValue,
                decoration: const InputDecoration(labelText: 'Professor'),
                items: professores
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.nome, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: professores.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _idProfessor = value;
                          _erro = null;
                        });
                      },
              ),
              if (_idMateria != null && professores.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Nenhum professor disponível neste horário. '
                    'Escolha outra matéria ou ajuste a Página 2.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              // Só quando a matéria continua a mesma: trocar de matéria
              // limpa o professor de propósito, não é indisponibilidade.
              if (widget.idProfessorInicial != null &&
                  _idMateria == widget.idMateriaInicial &&
                  professorValue == null &&
                  professores.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'O professor atual não está disponível neste horário. '
                    'Selecione outro para salvar.',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                key: ValueKey('room-$roomValue'),
                initialValue: roomValue,
                decoration: const InputDecoration(
                  labelText: 'Sala (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nenhuma'),
                  ),
                  ...widget.salas.map(
                    (room) => DropdownMenuItem<String?>(
                      value: room.id,
                      child: Text(
                        room.rotulo,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _idSala = value),
              ),
            ],
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.permitirExcluir)
          TextButton(
            onPressed: _confirmarExclusao,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: widget.materias.isEmpty ? null : _enviar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
