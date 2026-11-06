import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/components/coluna_quadro.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/horario/horario_periodo.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/pages/layout_base.dart';
import 'package:flutter_test_project/pages/page3/helpers/acoes_horario.dart';
import 'package:flutter_test_project/pages/page3/widgets/barra_acoes_horario.dart';
import 'package:flutter_test_project/pages/page3/widgets/lista_cursos_horario.dart';
import 'package:flutter_test_project/pages/page3/widgets/painel_grade_curso.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/exportador_horario_pdf.dart';
import 'package:printing/printing.dart';

class Page3 extends ConsumerStatefulWidget {
  const Page3({super.key});

  @override
  ConsumerState<Page3> createState() => _Page3State();
}

class _Page3State extends ConsumerState<Page3> {
  Curso? _cursoSelecionado;
  bool _ocupado = false;

  // Usa o container do ProviderScope (não o ref da tela): as ações
  // continuam funcionando se a pessoa trocar de página no meio de uma
  // gravação.
  AcoesHorario get _acoes =>
      AcoesHorario(ProviderScope.containerOf(context, listen: false));

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  void _mostrarErro(Object e) => _mostrarMensagem('Erro: $e');

  /// Roda [acao] e mostra a mensagem que ela devolver. A grade só trava
  /// quando a ação chama `iniciarGravacao` (depois das confirmações), não
  /// enquanto a pessoa ainda está decidindo num diálogo.
  Future<void> _executar(
    Future<String?> Function(VoidCallback iniciarGravacao) acao,
  ) async {
    if (_ocupado) return;
    void iniciarGravacao() {
      if (mounted) setState(() => _ocupado = true);
    }

    try {
      final mensagem = await acao(iniciarGravacao);
      if (mensagem != null) _mostrarMensagem(mensagem);
    } catch (e) {
      _mostrarErro(e);
    } finally {
      if (mounted && _ocupado) setState(() => _ocupado = false);
    }
  }

  Future<void> _gerarTodos({
    required List<Curso> cursos,
    required List<CargaCursoMateria> cargas,
    required List<Professor> professores,
    required List<ProfessorMateria> ligacoes,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<Materia> materias,
  }) {
    return _executar(
      (iniciarGravacao) => _acoes.gerarTodos(
        context: context,
        iniciarGravacao: iniciarGravacao,
        cursos: cursos,
        cargas: cargas,
        professores: professores,
        ligacoes: ligacoes,
        indisponibilidades: indisponibilidades,
        aulasGeminadas: aulasGeminadas,
        materias: materias,
      ),
    );
  }

  Future<void> _limparCurso(Curso curso) {
    return _executar(
      (iniciarGravacao) => _acoes.limparCurso(
        context: context,
        iniciarGravacao: iniciarGravacao,
        curso: curso,
      ),
    );
  }

  Future<void> _exportarPdf({
    required List<Curso> cursos,
    required List<Aula> aulas,
    required List<Materia> materias,
    required List<Professor> professores,
    required List<Sala> salas,
    required Map<int, String> horarios,
  }) {
    // Trava enquanto monta o PDF: evita dois diálogos de impressão e
    // exportar no meio de um "Gerar".
    return _executar((iniciarGravacao) async {
      iniciarGravacao();
      final bytes = await const ExportadorHorarioPdf().gerar(
        cursos: cursos,
        aulas: aulas,
        materias: materias,
        professores: professores,
        salas: salas,
        horarios: horarios,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'horarios');
      return null;
    });
  }

  /// Devolve false se não conseguiu gravar (o campo volta ao valor salvo).
  Future<bool> _salvarHorario(int indicePeriodo, String texto) async {
    try {
      await _acoes.salvarHorarioPeriodo(indicePeriodo, texto);
      return true;
    } catch (e) {
      _mostrarErro(e);
      return false;
    }
  }

  Future<void> _aoTocarCelula({
    required Curso curso,
    required CelulaGrade celula,
    required List<Materia> materias,
    required List<Professor> professores,
    required List<ProfessorMateria> ligacoes,
    required List<Aula> aulas,
    required List<CargaCursoMateria> cargas,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Sala> salas,
  }) async {
    return _executar(
      (iniciarGravacao) => _acoes.aoTocarCelula(
        context: context,
        iniciarGravacao: iniciarGravacao,
        celula: celula,
        curso: curso,
        todasMaterias: materias,
        professores: professores,
        ligacoes: ligacoes,
        todasAulas: aulas,
        cargas: cargas,
        aulasGeminadas: aulasGeminadas,
        indisponibilidades: indisponibilidades,
        salas: salas,
      ),
    );
  }

  Future<void> _aoSoltarAula({
    required Aula aula,
    required CelulaGrade destino,
    required List<Aula> aulas,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<Professor> professores,
    required List<IndisponibilidadeProfessor> indisponibilidades,
  }) async {
    // Bloqueia a grade enquanto grava, para não começar outro arraste
    // com dados antigos; a recusa (se houver) aparece embaixo.
    return _executar(
      (iniciarGravacao) => _acoes.moverAula(
        iniciarGravacao: iniciarGravacao,
        aula: aula,
        destino: destino,
        todasAulas: aulas,
        aulasGeminadas: aulasGeminadas,
        professores: professores,
        indisponibilidades: indisponibilidades,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cursosAsync = ref.watch(provedorCursos);
    final aulasAsync = ref.watch(provedorAulas);
    final cargasAsync = ref.watch(provedorCargasCurso);
    final aulasGeminadasAsync = ref.watch(provedorAulasGeminadasCurso);
    final materiasAsync = ref.watch(provedorMaterias);
    final professoresAsync = ref.watch(provedorProfessores);
    final ligacoesAsync = ref.watch(provedorProfessorMaterias);
    final indisponibilidadesAsync = ref.watch(provedorIndisponibilidades);
    final salasAsync = ref.watch(provedorSalas);
    // Os horários são só rótulos: se a tabela falhar, a grade segue sem eles.
    final horarios = {
      for (final h in ref.watch(provedorHorariosPeriodo).valueOrNull ??
          const <HorarioPeriodo>[])
        h.indicePeriodo: h.texto,
    };

    final aulas = aulasAsync.valueOrNull ?? const <Aula>[];
    final cargas = cargasAsync.valueOrNull ?? const <CargaCursoMateria>[];
    final aulasGeminadas =
        aulasGeminadasAsync.valueOrNull ?? const <AulaGeminadaCurso>[];
    final materias = materiasAsync.valueOrNull ?? const <Materia>[];
    final professores = professoresAsync.valueOrNull ?? const <Professor>[];
    final ligacoes = ligacoesAsync.valueOrNull ?? const <ProfessorMateria>[];
    final indisponibilidades =
        indisponibilidadesAsync.valueOrNull ?? const <IndisponibilidadeProfessor>[];
    final salas = salasAsync.valueOrNull ?? const <Sala>[];
    final cursos = cursosAsync.valueOrNull ?? const <Curso>[];

    // Só permite gerar com todos os dados carregados (lista vazia por
    // carregamento faria o gerador apagar a grade sem recriá-la).
    final dadosProntos = [
      cursosAsync,
      aulasAsync,
      cargasAsync,
      aulasGeminadasAsync,
      materiasAsync,
      professoresAsync,
      ligacoesAsync,
      indisponibilidadesAsync,
      salasAsync,
    ].every((async) => async.hasValue && !async.hasError);

    // Usa a versão atual do curso (dados em tempo real), não a da seleção.
    final selecionado = _cursoSelecionado == null
        ? null
        : cursos.where((c) => c.id == _cursoSelecionado!.id).firstOrNull;
    if (_cursoSelecionado != null && selecionado == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _cursoSelecionado = null);
      });
    }

    return LayoutBase(
      titulo: 'Horário',
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarraAcoesHorario(
              aoGerar: _ocupado || !dadosProntos || cursos.isEmpty
                  ? null
                  : () => _gerarTodos(
                      cursos: cursos,
                      cargas: cargas,
                      professores: professores,
                      ligacoes: ligacoes,
                      indisponibilidades: indisponibilidades,
                      aulasGeminadas: aulasGeminadas,
                      materias: materias,
                    ),
              aoPdf: _ocupado || !dadosProntos || cursos.isEmpty
                  ? null
                  : () => _exportarPdf(
                      cursos: cursos,
                      aulas: aulas,
                      materias: materias,
                      professores: professores,
                      salas: salas,
                      horarios: horarios,
                    ),
            ),
            Expanded(
              child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selecionado != null)
              PainelGradeCurso(
                curso: selecionado,
                cursos: cursos,
                aulas: aulas,
                cargas: cargas,
                aulasGeminadas: aulasGeminadas,
                materias: materias,
                professores: professores,
                ligacoes: ligacoes,
                indisponibilidades: indisponibilidades,
                salas: salas,
                horarios: horarios,
                // Tocar e arrastar só com todos os dados carregados (sem as
                // indisponibilidades, o arraste aceitaria horário bloqueado).
                ocupado: _ocupado || !dadosProntos,
                aoSalvarHorario: (indicePeriodo, texto) =>
                    _salvarHorario(indicePeriodo, texto),
                aoLimpar: _ocupado ? null : () => _limparCurso(selecionado),
                aoFechar: () => setState(() => _cursoSelecionado = null),
                aoSoltarAula:
                    ({required Aula aula, required CelulaGrade destino}) =>
                        _aoSoltarAula(
                          aula: aula,
                          destino: destino,
                          aulas: aulas,
                          aulasGeminadas: aulasGeminadas,
                          professores: professores,
                          indisponibilidades: indisponibilidades,
                        ),
                aoTocarCelula: ({required CelulaGrade celula}) =>
                    _aoTocarCelula(
                      curso: selecionado,
                      celula: celula,
                      materias: materias,
                      professores: professores,
                      ligacoes: ligacoes,
                      aulas: aulas,
                      cargas: cargas,
                      aulasGeminadas: aulasGeminadas,
                      indisponibilidades: indisponibilidades,
                      salas: salas,
                    ),
              )
            else
              const Expanded(
                flex: 7,
                child: DicaColunaVazia(
                  mensagem: 'Selecione um curso para abrir a grade horária',
                ),
              ),
            ListaCursosHorario(
              cursoSelecionado: selecionado,
              cargas: cargas,
              aulas: aulas,
              aoSelecionar: (curso) {
                setState(() => _cursoSelecionado = curso);
              },
            ),
          ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
