import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/components/coluna_quadro.dart';
import 'package:flutter_test_project/services/texto.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_confirmar_exclusao.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_professor.dart';
import 'package:flutter_test_project/components/cartao_item.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/arrumacao_grupos.dart';

class ColunaProfessor extends ConsumerWidget {
  const ColunaProfessor({super.key});

  List<Materia> _materiasOuVazio(AsyncValue<List<Materia>> subjectsAsync) {
    return subjectsAsync.valueOrNull ?? const [];
  }

  Future<void> _criar(BuildContext context, WidgetRef ref) async {
    final materias = _materiasOuVazio(ref.read(provedorMaterias));
    final result = await mostrarDialogoFormularioProfessor(
      context,
      titulo: 'Novo professor',
      materias: materias,
    );
    if (result == null) return;

    try {
      await ref.read(provedorRepositorioProfessor).adicionar(
            result.nome,
            idsMaterias: result.idsMaterias,
          );
      ref.invalidate(provedorProfessores);
      ref.invalidate(provedorProfessorMaterias);
    } catch (e) {
      if (!context.mounted) return;
      _mostrarErro(context, e);
    }
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Professor professor,
  ) async {
    final materias = _materiasOuVazio(ref.read(provedorMaterias));
    final List<String> currentIds;
    try {
      currentIds = await ref
          .read(provedorRepositorioProfessor)
          .buscarIdsMaterias(professor.id);
    } catch (e) {
      if (context.mounted) _mostrarErro(context, e);
      return;
    }
    if (!context.mounted) return;

    final result = await mostrarDialogoFormularioProfessor(
      context,
      titulo: 'Editar professor',
      materias: materias,
      nomeInicial: professor.nome,
      idsMateriasIniciais: currentIds,
    );
    if (result == null) return;

    try {
      await ref.read(provedorRepositorioProfessor).atualizar(
            Professor(id: professor.id, nome: result.nome),
            idsMaterias: result.idsMaterias,
          );
      ref.invalidate(provedorProfessores);
      ref.invalidate(provedorProfessorMaterias);
    } catch (e) {
      if (!context.mounted) return;
      _mostrarErro(context, e);
    }
  }

  Future<void> _excluir(
    BuildContext context,
    WidgetRef ref,
    Professor professor,
  ) async {
    final confirmed = await mostrarDialogoConfirmarExclusao(
      context,
      titulo: 'Excluir professor',
      mensagem:
          'Excluir "${professor.nome}"? Também remove suas aulas na grade '
          'e indisponibilidades.',
    );
    if (!confirmed) return;

    try {
      final repoAula = ref.read(provedorRepositorioAula);
      final todasAulas = await repoAula.buscarTodos();
      final pares = await ref
          .read(provedorRepositorioCurso)
          .buscarTodasAulasGeminadas();
      // Se ele dava o grupo 2 de um par, o grupo 1 que sobra passa para o
      // grupo 2 (G1 livre), como ao excluir o grupo 2 na grade.
      final paraGrupo2 = aulasQueVaoParaGrupo2(
        excluidas: todasAulas
            .where((a) => a.idProfessor == professor.id)
            .toList(),
        todasAulas: todasAulas,
        pares: pares,
      );
      await ref.read(provedorRepositorioProfessor).excluir(professor.id);
      for (final aula in paraGrupo2) {
        await repoAula.atualizar(aula);
      }
      ref.invalidate(provedorProfessores);
      ref.invalidate(provedorProfessorMaterias);
      ref.invalidate(provedorAulas);
      ref.invalidate(provedorIndisponibilidades);
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
    final professorsAsync = ref.watch(provedorProfessores);
    final linksAsync = ref.watch(provedorProfessorMaterias);

    return ColunaQuadro(
      titulo: 'Professores',
      icone: Icons.person_outline,
      acoes: [
        IconButton(
          onPressed: () => _criar(context, ref),
          tooltip: 'Adicionar professor',
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          visualDensity: VisualDensity.compact,
        ),
      ],
      construirComBusca: (busca) => professorsAsync.when(
        data: (todos) {
          if (todos.isEmpty) {
            return const DicaColunaVazia(
              mensagem: 'Nenhum professor cadastrado',
            );
          }
          final professores = todos
              .where((p) => correspondeBusca(p.nome, busca))
              .toList();
          if (professores.isEmpty) return DicaBuscaVazia(busca: busca);

          final ligacoes = linksAsync.valueOrNull ?? const [];
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: professores.map((professor) {
              final count = ligacoes
                  .where((link) => link.idProfessor == professor.id)
                  .length;
              return CartaoItem(
                titulo: professor.nome,
                subtitulo: count == 1
                    ? '1 componente'
                    : '$count componentes',
                aoEditar: () => _editar(context, ref, professor),
                aoExcluir: () => _excluir(context, ref, professor),
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
