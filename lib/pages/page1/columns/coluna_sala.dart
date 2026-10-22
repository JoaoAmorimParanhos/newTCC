import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/components/coluna_quadro.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_confirmar_exclusao.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_numero.dart';
import 'package:flutter_test_project/components/cartao_item.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/providers/providers.dart';

class ColunaSala extends ConsumerWidget {
  const ColunaSala({super.key});

  Future<TipoSala> _criarTipo(WidgetRef ref, String nome) async {
    final novo = await ref.read(provedorRepositorioTipoSala).adicionar(nome);
    ref.invalidate(provedorTiposSala);
    return novo;
  }

  Future<void> _criar(BuildContext context, WidgetRef ref) async {
    final dados = await mostrarDialogoNumero(
      context,
      titulo: 'Nova sala',
      rotulo: 'Número da sala',
      tipos: ref.read(provedorTiposSala).value ?? const [],
      aoCriarTipo: (nome) => _criarTipo(ref, nome),
    );
    if (dados == null) return;

    try {
      await ref.read(provedorRepositorioSala).adicionar(dados.numero, dados.tipo);
      ref.invalidate(provedorSalas);
    } on SalaDuplicada {
      if (!context.mounted) return;
      _mostrarErro(
        context,
        'Esse número já está em uso para ${dados.tipo.nome}.',
      );
    } catch (e) {
      if (!context.mounted) return;
      _mostrarErro(context, e);
    }
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Sala room,
  ) async {
    final dados = await mostrarDialogoNumero(
      context,
      titulo: 'Editar sala',
      rotulo: 'Número da sala',
      tipos: ref.read(provedorTiposSala).value ?? const [],
      aoCriarTipo: (nome) => _criarTipo(ref, nome),
      numeroInicial: room.numero,
      tipoInicial: room.tipo,
    );
    if (dados == null) return;

    try {
      await ref.read(provedorRepositorioSala).atualizar(
            Sala(id: room.id, numero: dados.numero, tipo: dados.tipo),
          );
      ref.invalidate(provedorSalas);
    } on SalaDuplicada {
      if (!context.mounted) return;
      _mostrarErro(
        context,
        'Esse número já está em uso para ${dados.tipo.nome}.',
      );
    } catch (e) {
      if (!context.mounted) return;
      _mostrarErro(context, e);
    }
  }

  Future<void> _excluir(
    BuildContext context,
    WidgetRef ref,
    Sala room,
  ) async {
    final confirmed = await mostrarDialogoConfirmarExclusao(
      context,
      titulo: 'Excluir sala',
      mensagem:
          'Excluir ${room.rotulo}? Cursos e aulas que usavam esta '
          'sala ficam sem sala.',
    );
    if (!confirmed) return;

    try {
      await ref.read(provedorRepositorioSala).excluir(room.id);
      ref.invalidate(provedorSalas);
      ref.invalidate(provedorCursos);
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
    final roomsAsync = ref.watch(provedorSalas);
    // Mantém a lista de tipos carregada para o diálogo de sala.
    ref.watch(provedorTiposSala);

    return ColunaQuadro(
      titulo: 'Salas',
      icone: Icons.meeting_room_outlined,
      acoes: [
        IconButton(
          onPressed: () => _criar(context, ref),
          tooltip: 'Adicionar sala',
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          visualDensity: VisualDensity.compact,
        ),
      ],
      child: roomsAsync.when(
        data: (salas) {
          if (salas.isEmpty) {
            return const DicaColunaVazia(mensagem: 'Nenhuma sala cadastrada');
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: salas
                .map(
                  (room) => CartaoItem(
                    titulo: room.rotulo,
                    aoEditar: () => _editar(context, ref, room),
                    aoExcluir: () => _excluir(context, ref, room),
                  ),
                )
                .toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => DicaColunaVazia(mensagem: 'Erro: $e'),
      ),
    );
  }
}
