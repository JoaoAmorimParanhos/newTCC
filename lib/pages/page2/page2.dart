import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/components/coluna_quadro.dart';
import 'package:flutter_test_project/components/cartao_item.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/pages/layout_base.dart';
import 'package:flutter_test_project/providers/providers.dart';

class Page2 extends ConsumerStatefulWidget {
  const Page2({super.key});

  @override
  ConsumerState<Page2> createState() => _Page2State();
}

class _Page2State extends ConsumerState<Page2> {
  Professor? _professorSelecionado;
  bool _salvando = false;

  void _mostrarErro(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro: $e')),
    );
  }

  Set<CelulaGrade> _celulasDoProfessor(
    String idProfessor,
    List<IndisponibilidadeProfessor> linhas,
  ) {
    return linhas
        .where((r) => r.idProfessor == idProfessor)
        .map((r) => r.celula)
        .toSet();
  }

  Future<void> _alternarCelula(
    CelulaGrade celula,
    Set<CelulaGrade> current,
  ) async {
    final professor = _professorSelecionado;
    if (professor == null || _salvando) return;

    setState(() => _salvando = true);
    final repo = ref.read(provedorRepositorioIndisponibilidade);

    try {
      if (current.contains(celula)) {
        await repo.excluirPorProfessorCelula(
          idProfessor: professor.id,
          celula: celula,
        );
      } else {
        await repo.adicionar(idProfessor: professor.id, celula: celula);
      }
      ref.invalidate(provedorIndisponibilidades);
    } catch (e) {
      _mostrarErro(e);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final professorsAsync = ref.watch(provedorProfessores);
    final unavailabilityAsync = ref.watch(provedorIndisponibilidades);
    final professores = professorsAsync.value ?? const <Professor>[];
    final linhas =
        unavailabilityAsync.value ?? const <IndisponibilidadeProfessor>[];

    // Se o professor foi excluído na Página 1, limpa a seleção.
    final selecionado = _professorSelecionado == null
        ? null
        : professores
              .where((p) => p.id == _professorSelecionado!.id)
              .firstOrNull;
    if (_professorSelecionado != null && selecionado == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _professorSelecionado = null);
      });
    }

    return LayoutBase(
      titulo: 'Página 2',
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selecionado != null)
              ColunaQuadro(
                flex: 7,
                titulo: 'Indisponibilidade — ${selecionado.nome}',
                icone: Icons.calendar_month_outlined,
                acoes: [
                  IconButton(
                    onPressed: () => setState(() => _professorSelecionado = null),
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close, color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                child: unavailabilityAsync.when(
                  data: (data) {
                    final marked = _celulasDoProfessor(selecionado.id, data);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Text(
                            'Toque nos horários indisponíveis. '
                            'Salvo no banco automaticamente.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        if (_salvando)
                          const LinearProgressIndicator(minHeight: 2),
                        Expanded(
                          child: GradeHoraria(
                            interativo: true,
                            celulasMarcadas: marked,
                            aoAlternar: _salvando
                                ? null
                                : (celula) => _alternarCelula(celula, marked),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => DicaColunaVazia(
                    mensagem:
                        'Erro ao carregar indisponibilidade '
                        '(crie tb_professor_indisponibilidade no Supabase):\n$e',
                  ),
                ),
              )
            else
              const Expanded(
                flex: 7,
                child: DicaColunaVazia(
                  mensagem:
                      'Selecione um professor para marcar dias e horários indisponíveis',
                ),
              ),
            ColunaQuadro(
              flex: 3,
              titulo: 'Professores',
              icone: Icons.person_outline,
              child: professorsAsync.when(
                data: (professores) {
                  if (professores.isEmpty) {
                    return const DicaColunaVazia(
                      mensagem: 'Nenhum professor cadastrado',
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: professores.map((professor) {
                      final isSelected = selecionado?.id == professor.id;
                      final blocked = linhas
                          .where((r) => r.idProfessor == professor.id)
                          .length;
                      return CartaoItem(
                        titulo: professor.nome,
                        subtitulo: blocked == 0
                            ? null
                            : '$blocked horário(s) bloqueado(s)',
                        selecionado: isSelected,
                        aoTocar: () {
                          setState(() {
                            _professorSelecionado =
                                isSelected ? null : professor;
                          });
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, stack) => DicaColunaVazia(mensagem: 'Erro: $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
