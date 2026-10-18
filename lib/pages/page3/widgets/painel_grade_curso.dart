import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/components/coluna_quadro.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/pages/page3/helpers/acoes_horario.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';
import 'package:flutter_test_project/pages/page3/widgets/celula_horario.dart';
import 'package:flutter_test_project/pages/page3/widgets/painel_validacao_horario.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/validador_horario.dart';

class PainelGradeCurso extends ConsumerWidget {
  const PainelGradeCurso({
    super.key,
    required this.curso,
    required this.cursos,
    required this.aulas,
    required this.cargas,
    required this.aulasGeminadas,
    required this.materias,
    required this.professores,
    required this.ligacoes,
    required this.indisponibilidades,
    required this.salas,
    required this.ocupado,
    required this.aoGerar,
    required this.aoPdf,
    required this.aoLimpar,
    required this.aoFechar,
    required this.aoTocarCelula,
    this.aoSoltarAula,
  });

  final Curso curso;
  final List<Curso> cursos;
  final List<Aula> aulas;
  final List<CargaCursoMateria> cargas;
  final List<AulaGeminadaCurso> aulasGeminadas;
  final List<Materia> materias;
  final List<Professor> professores;
  final List<ProfessorMateria> ligacoes;
  final List<IndisponibilidadeProfessor> indisponibilidades;
  final List<Sala> salas;
  final bool ocupado;
  final VoidCallback? aoGerar;
  final VoidCallback? aoPdf;
  final VoidCallback? aoLimpar;
  final VoidCallback aoFechar;
  final Future<void> Function({required CelulaGrade celula}) aoTocarCelula;

  /// Aula arrastada solta em [destino] (aula comum ou conjunto geminado).
  final Future<void> Function({required Aula aula, required CelulaGrade destino})?
  aoSoltarAula;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aulasAsync = ref.watch(provedorAulas);

    return ColunaQuadro(
      flex: 7,
      titulo: 'Horário — ${curso.nome}',
      icone: Icons.table_chart_outlined,
      acoes: [
        TextButton(
          onPressed: aoGerar,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Gerar'),
        ),
        TextButton(
          onPressed: aoPdf,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('PDF'),
        ),
        IconButton(
          onPressed: aoLimpar,
          tooltip: 'Limpar grade',
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: aoFechar,
          tooltip: 'Fechar',
          icon: const Icon(Icons.close, color: Colors.white),
          visualDensity: VisualDensity.compact,
        ),
      ],
      child: aulasAsync.when(
        data: (_) {
          final porCelula = aulasPorCelulaDoCurso(aulas, curso.id);
          final mapaMaterias = materiaPorId(materias);
          final mapaProfessores = professorPorId(professores);
          final mapaSalas = salaPorId(salas);

          final validacao = const ValidadorHorario().validarCurso(
            idCurso: curso.id,
            todasAulas: aulas,
            cursos: cursos,
            cargas: cargas,
            aulasGeminadas: aulasGeminadas,
            professores: professores,
            materias: materias,
            salas: salas,
            indisponibilidades: indisponibilidades,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  subtituloProgresso(curso, cargas, aulas),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (ocupado) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: GradeHoraria(
                  construirCelula: (celula) {
                    return CelulaHorario(
                      celula: celula,
                      aulas: porCelula[celula] ?? const [],
                      materias: mapaMaterias,
                      professores: mapaProfessores,
                      salasPorId: mapaSalas,
                      ocupado: ocupado,
                      aoTocar: () => aoTocarCelula(celula: celula),
                      aoSoltar: aoSoltarAula == null
                          ? null
                          : (aula) => aoSoltarAula!(aula: aula, destino: celula),
                      motivoParaNaoSoltar: (aula) =>
                          AcoesHorario.motivoParaNaoSoltar(
                            aula: aula,
                            destino: celula,
                            todasAulas: aulas,
                            aulasGeminadas: aulasGeminadas,
                            professores: professores,
                            indisponibilidades: indisponibilidades,
                          ),
                    );
                  },
                ),
              ),
              PainelValidacaoHorario(validacao: validacao),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => DicaColunaVazia(
          mensagem:
              'Erro ao carregar aulas (crie a tabela tb_aula no Supabase se ainda não existir):\n$e',
        ),
      ),
    );
  }
}
