import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/components/coluna_quadro.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_confirmar_exclusao.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_materia.dart';
import 'package:flutter_test_project/components/cartao_item.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/providers/providers.dart';

class ColunaMateria extends ConsumerWidget {
  const ColunaMateria({super.key});

  List<Professor> _professoresOuVazio(WidgetRef ref) {
    return ref.read(provedorProfessores).value ?? const [];
  }

  Future<void> _criar(BuildContext context, WidgetRef ref) async {
    final result = await mostrarDialogoFormularioMateria(
      context,
      titulo: 'Nova matéria',
      professores: _professoresOuVazio(ref),
    );
    if (result == null) return;

    try {
      await ref
          .read(provedorRepositorioMateria)
          .adicionar(result.nome, idsProfessores: result.idsProfessores);
      ref.invalidate(provedorMaterias);
      ref.invalidate(provedorProfessorMaterias);
    } catch (e) {
      if (!context.mounted) return;
      _mostrarErro(context, e);
    }
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Materia subject,
  ) async {
    final repo = ref.read(provedorRepositorioMateria);
    // Usa os vínculos já carregados em tempo real: o formulário abre na hora.
    final ligacoes = ref.read(provedorProfessorMaterias).value;
    final List<String> idsAtuais;
    if (ligacoes != null) {
      idsAtuais = ligacoes
          .where((link) => link.idMateria == subject.id)
          .map((link) => link.idProfessor)
          .toList();
    } else {
      try {
        idsAtuais = await repo.buscarIdsProfessores(subject.id);
      } catch (e) {
        if (!context.mounted) return;
        _mostrarErro(context, e);
        return;
      }
      if (!context.mounted) return;
    }

    final result = await mostrarDialogoFormularioMateria(
      context,
      titulo: 'Editar matéria',
      professores: _professoresOuVazio(ref),
      nomeInicial: subject.nome,
      idsProfessoresIniciais: idsAtuais,
    );
    if (result == null) return;

    try {
      await repo.atualizar(
        Materia(id: subject.id, nome: result.nome),
        idsProfessores: result.idsProfessores,
      );
      ref.invalidate(provedorMaterias);
      ref.invalidate(provedorProfessorMaterias);
    } catch (e) {
      if (!context.mounted) return;
      _mostrarErro(context, e);
    }
  }

  Future<void> _excluir(
    BuildContext context,
    WidgetRef ref,
    Materia subject,
  ) async {
    final confirmed = await mostrarDialogoConfirmarExclusao(
      context,
      titulo: 'Excluir matéria',
      mensagem:
          'Excluir "${subject.nome}"? Também remove das cargas dos cursos, '
          'vínculos com professores e aulas na grade.',
    );
    if (!confirmed) return;

    try {
      await ref.read(provedorRepositorioMateria).excluir(subject.id);
      ref.invalidate(provedorMaterias);
      ref.invalidate(provedorCargasCurso);
      ref.invalidate(provedorProfessorMaterias);
      ref.invalidate(provedorAulas);
    } catch (e) {
      if (!context.mounted) return;
      _mostrarErro(context, e);
    }
  }

  void _mostrarErro(BuildContext context, Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro: $e')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(provedorMaterias);
    final ligacoes = ref.watch(provedorProfessorMaterias).value ?? const [];

    return ColunaQuadro(
      titulo: 'Matérias',
      icone: Icons.menu_book_outlined,
      acoes: [
        IconButton(
          onPressed: () => _criar(context, ref),
          tooltip: 'Adicionar matéria',
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          visualDensity: VisualDensity.compact,
        ),
      ],
      child: subjectsAsync.when(
        data: (materias) {
          if (materias.isEmpty) {
            return const DicaColunaVazia(mensagem: 'Nenhuma matéria cadastrada');
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: materias.map((subject) {
              final count = ligacoes
                  .where((link) => link.idMateria == subject.id)
                  .length;
              return CartaoItem(
                titulo: subject.nome,
                subtitulo: count == 1 ? '1 professor' : '$count professores',
                // Clicar na matéria abre o mesmo formulário de edição.
                aoTocar: () => _editar(context, ref, subject),
                aoEditar: () => _editar(context, ref, subject),
                aoExcluir: () => _excluir(context, ref, subject),
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => DicaColunaVazia(mensagem: 'Erro: $e'),
      ),
    );
  }
}
