import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_confirmar_exclusao.dart';
import 'package:flutter_test_project/components/dialogs/dialogo_formulario_aula.dart';
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
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';
import 'package:flutter_test_project/providers/providers.dart';
import 'package:flutter_test_project/services/gerador_horario.dart';

/// Ações de horário (gerar, limpar, editar aula) — sem widgets de layout.
class AcoesHorario {
  AcoesHorario(this.ref);

  /// Container do ProviderScope: continua válido mesmo se a tela que
  /// iniciou a ação sair da árvore no meio de uma gravação.

  final ProviderContainer ref;

  /// Grava o texto do horário do período. Vale para todas as turmas.
  Future<void> salvarHorarioPeriodo(int indicePeriodo, String texto) async {
    await ref
        .read(provedorRepositorioHorarioPeriodo)
        .salvar(HorarioPeriodo(indicePeriodo: indicePeriodo, texto: texto));
    ref.invalidate(provedorHorariosPeriodo);
  }

  Future<String?> limparCurso({
    required BuildContext context,
    required VoidCallback iniciarGravacao,
    required Curso curso,
  }) async {
    final confirmado = await mostrarDialogoConfirmarExclusao(
      context,
      titulo: 'Limpar grade',
      mensagem:
          'Remover todas as aulas de "${curso.nome}"? '
          'Esta ação não pode ser desfeita.',
    );
    if (!confirmado) return null;

    iniciarGravacao();
    await ref.read(provedorRepositorioAula).excluirPorCurso(curso.id);
    ref.invalidate(provedorAulas);
    return 'Grade de "${curso.nome}" limpa.';
  }

  Future<String?> gerarTodos({
    required BuildContext context,
    required VoidCallback iniciarGravacao,
    required List<Curso> cursos,
    required List<CargaCursoMateria> cargas,
    required List<Professor> professores,
    required List<ProfessorMateria> ligacoes,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<Materia> materias,
  }) async {
    final confirmado = await mostrarDialogoConfirmarExclusao(
      context,
      titulo: 'Gerar horários',
      mensagem:
          'Regenerar os horários de todas as turmas? '
          'Isso apaga os horários atuais e recria com base nas '
          'configurações de Cadastros e na Disponibilidade dos '
          'professores. Esta ação não pode ser desfeita.',
      rotuloConfirmar: 'Gerar',
    );
    if (!confirmado) return null;

    iniciarGravacao();
    // Gera antes de apagar: se nada couber, a grade atual fica intacta.
    final resultado = const GeradorHorario().gerarTodos(
      cursos: cursos,
      cargas: cargas,
      professores: professores,
      ligacoes: ligacoes,
      indisponibilidades: indisponibilidades,
      aulasGeminadas: aulasGeminadas,
      nomesMaterias: {for (final m in materias) m.id: m.nome},
      nomesCursos: {for (final c in cursos) c.id: c.nome},
    );

    if (resultado.novasAulas.isEmpty) {
      final motivo = resultado.falhas.isEmpty
          ? 'nenhuma aula a alocar.'
          : resultado.falhas.first;
      return 'Não foi possível gerar (grade atual mantida): $motivo';
    }

    final repo = ref.read(provedorRepositorioAula);
    try {
      // Troca a grade inteira numa transação só: se falhar, nada muda.
      await repo.substituirTodas(resultado.novasAulas);
    } catch (e) {
      final detalhe = e is PostgrestException ? e.message : '$e';
      return 'Não foi possível salvar o horário gerado '
          '(grade anterior mantida): $detalhe';
    } finally {
      ref.invalidate(provedorAulas);
    }

    if (resultado.completo) {
      return 'Horários gerados: ${resultado.novasAulas.length} aula(s) alocadas.';
    }
    return 'Parcial: ${resultado.novasAulas.length} aula(s). '
        '${resultado.falhas.take(3).join(' ')}';
  }

  /// Toque numa célula da grade: célula vazia cria uma aula; com uma aula,
  /// edita essa aula; com dois grupos, pergunta qual editar.
  ///
  /// A Página 3 não muda a carga nem os pares de aula dividida: só usa o
  /// que está cadastrado na Página 1. Excluir uma aula deixa a falta
  /// aparecer no painel ("Faltam X aula(s)").
  Future<String?> aoTocarCelula({
    required BuildContext context,
    required VoidCallback iniciarGravacao,
    required CelulaGrade celula,
    required Curso curso,
    required List<Materia> todasMaterias,
    required List<Professor> professores,
    required List<ProfessorMateria> ligacoes,
    required List<Aula> todasAulas,
    required List<CargaCursoMateria> cargas,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Sala> salas,
  }) async {
    final naCelula = aulasNaCelula(todasAulas, curso.id, celula);
    final mapaMaterias = materiaPorId(todasMaterias);

    Aula? existente;
    if (naCelula.length == 1) {
      existente = naCelula.single;
    } else if (naCelula.length > 1) {
      existente = await _escolherGrupoParaEditar(
        context,
        naCelula,
        mapaMaterias,
      );
      if (existente == null) return null;
    }
    final grupo = existente?.grupo ?? 1;

    if (!context.mounted) return null;

    final rotuloDia = GradeHoraria.dias[celula.indiceDia];
    final rotuloPeriodo = GradeHoraria.periodos[celula.indicePeriodo];
    // "Grupo N" só quando a turma está dividida nesse horário (dois grupos
    // ou G1 livre); aula da turma inteira não fala em grupo.
    final turmaDividida = naCelula.length > 1 || grupo == 2;
    final sufixoGrupo = turmaDividida ? ' · Grupo $grupo' : '';
    final titulo = existente == null
        ? 'Nova aula — $rotuloDia $rotuloPeriodo'
        : 'Editar — $rotuloDia $rotuloPeriodo$sufixoGrupo';

    String? motivoRecusa(
      ResultadoFormularioAula r, {
      required List<Aula> aulas,
      required List<CargaCursoMateria> cargas,
      required List<AulaGeminadaCurso> pares,
      required List<ProfessorMateria> ligacoes,
      required List<IndisponibilidadeProfessor> indisponibilidades,
    }) => validarSalvarAula(
      curso: curso,
      celula: celula,
      idMateria: r.idMateria,
      idProfessor: r.idProfessor,
      idSala: r.idSala,
      existente: existente,
      grupo: grupo,
      cargas: cargas,
      aulasGeminadas: pares,
      todasAulas: aulas,
      ligacoes: ligacoes,
      indisponibilidades: indisponibilidades,
    );

    final resultado = await mostrarDialogoFormularioAula(
      context,
      validar: (r) => motivoRecusa(
        r,
        aulas: todasAulas,
        cargas: cargas,
        pares: aulasGeminadas,
        ligacoes: ligacoes,
        indisponibilidades: indisponibilidades,
      ),
      avisoProfessor: (idMateria, idProfessor) => avisoProfessorNaCelula(
        idProfessor: idProfessor,
        celula: celula,
        indisponibilidades: indisponibilidades,
        todasAulas: todasAulas,
        idAulaExcluida: existente?.id,
      ),
      titulo: titulo,
      // Só os componentes da carga do curso (Cadastros). Ao editar, o atual
      // continua na lista mesmo se saiu da carga.
      materias: materiasParaDialogoAula(
        materiasCurso: materiasDoCurso(curso.id, cargas, todasMaterias),
        todasMaterias: todasMaterias,
        existente: existente,
      ),
      salas: salas,
      professoresDaMateria: (idMateria) => professoresParaDialogoAula(
        idMateria: idMateria,
        celula: celula,
        professores: professores,
        ligacoes: ligacoes,
        indisponibilidades: indisponibilidades,
        todasAulas: todasAulas,
        existente: existente,
      ),
      idMateriaInicial: existente?.idMateria,
      idProfessorInicial: existente?.idProfessor,
      idSalaInicial: existente?.idSala ?? curso.idSala,
      permitirExcluir: existente != null,
      mensagemExclusao: existente == null
          ? null
          : turmaDividida
          ? 'Excluir a aula do grupo $grupo em $rotuloDia $rotuloPeriodo?'
          : 'Excluir a aula de $rotuloDia $rotuloPeriodo?',
    );

    if (resultado == null) return null;
    final repo = ref.read(provedorRepositorioAula);

    // Dados mais recentes: a grade ou a Página 1/2 podem ter mudado
    // enquanto o diálogo estava aberto (outra aba ou outra pessoa).
    final aulasAgora = ref.read(provedorAulas).valueOrNull ?? todasAulas;
    final paresAgora =
        ref.read(provedorAulasGeminadasCurso).valueOrNull ?? aulasGeminadas;

    if (resultado is ExclusaoFormularioAula) {
      final excluida = existente;
      if (excluida == null) return null;
      iniciarGravacao();
      try {
        await repo.excluir(excluida.id);
        // Aula dividida continua dividida: a que sobra vai para o grupo 2
        // e o grupo 1 fica livre. Se as duas não formam mais par na
        // Página 1, a que sobra vira aula comum (grupo 1).
        final restante = aulasNaCelula(
          aulasAgora,
          curso.id,
          celula,
        ).where((a) => a.id != excluida.id).toList();
        if (restante.length == 1) {
          final novoGrupo = grupoDaQueSobra(
            idCurso: curso.id,
            excluida: excluida,
            restante: restante.single,
            aulasGeminadas: paresAgora,
          );
          if (novoGrupo != restante.single.grupo) {
            await repo.atualizar(_comGrupo(restante.single, novoGrupo));
          }
        }
      } finally {
        ref.invalidate(provedorAulas);
      }
      return null;
    }

    if (resultado is! ResultadoFormularioAula) return null;

    final erro = motivoRecusa(
      resultado,
      aulas: aulasAgora,
      cargas: ref.read(provedorCargasCurso).valueOrNull ?? cargas,
      pares: paresAgora,
      ligacoes: ref.read(provedorProfessorMaterias).valueOrNull ?? ligacoes,
      indisponibilidades:
          ref.read(provedorIndisponibilidades).valueOrNull ??
          indisponibilidades,
    );
    if (erro != null) return erro;
    iniciarGravacao();

    final aula = Aula(
      id: existente?.id ?? '0',
      idCurso: curso.id,
      indiceDia: celula.indiceDia,
      indicePeriodo: celula.indicePeriodo,
      idMateria: resultado.idMateria,
      idProfessor: resultado.idProfessor,
      idSala: resultado.idSala,
      grupo: grupoAoSalvar(
        idCurso: curso.id,
        idMateria: resultado.idMateria,
        grupoAtual: grupo,
        outrasNaCelula: aulasNaCelula(
          aulasAgora,
          curso.id,
          celula,
        ).where((a) => a.id != existente?.id).toList(),
        aulasGeminadas: paresAgora,
      ),
    );
    try {
      if (existente == null) {
        await repo.adicionar(aula);
      } else {
        await repo.atualizar(aula);
      }
    } finally {
      ref.invalidate(provedorAulas);
    }
    return null;
  }

  static Aula _comGrupo(Aula a, int grupo) => Aula(
    id: a.id,
    idCurso: a.idCurso,
    indiceDia: a.indiceDia,
    indicePeriodo: a.indicePeriodo,
    idMateria: a.idMateria,
    idProfessor: a.idProfessor,
    idSala: a.idSala,
    grupo: grupo,
  );

  /// Motivo para não soltar [aula] em [destino], ou null se pode.
  /// Também usado para pintar a célula enquanto a aula passa por cima.
  static String? motivoParaNaoSoltar({
    required Aula aula,
    required CelulaGrade destino,
    required List<Aula> todasAulas,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<Professor> professores,
    required List<IndisponibilidadeProfessor> indisponibilidades,
  }) {
    // Aula comum solta em cima de outra aula comum: as duas trocam de lugar.
    final outra = aulaParaTrocar(
      aula: aula,
      destino: destino,
      todasAulas: todasAulas,
      aulasGeminadas: aulasGeminadas,
    );
    if (outra != null) {
      return validarTrocaAulas(
        a: aula,
        b: outra,
        todasAulas: todasAulas,
        professores: professores,
        indisponibilidades: indisponibilidades,
      );
    }
    final originais = aulasQueMovemJunto(
      aula: aula,
      todasAulas: todasAulas,
      aulasGeminadas: aulasGeminadas,
    );
    return validarMoverAulas(
      originais: originais,
      movidas: deslocarAulas(originais, origem: aula.celula, destino: destino),
      todasAulas: todasAulas,
      professores: professores,
      indisponibilidades: indisponibilidades,
    );
  }

  /// Move a aula arrastada (ou o conjunto geminado dela) para [destino].
  /// Retorna a mensagem de recusa, ou null se moveu.
  Future<String?> moverAula({
    required VoidCallback iniciarGravacao,
    required Aula aula,
    required CelulaGrade destino,
    required List<Aula> todasAulas,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<Professor> professores,
    required List<IndisponibilidadeProfessor> indisponibilidades,
  }) async {
    if (aula.celula == destino) return null;

    final outra = aulaParaTrocar(
      aula: aula,
      destino: destino,
      todasAulas: todasAulas,
      aulasGeminadas: aulasGeminadas,
    );
    if (outra != null) {
      return _trocar(
        iniciarGravacao: iniciarGravacao,
        a: aula,
        b: outra,
        todasAulas: todasAulas,
        professores: professores,
        indisponibilidades: indisponibilidades,
      );
    }

    final originais = aulasQueMovemJunto(
      aula: aula,
      todasAulas: todasAulas,
      aulasGeminadas: aulasGeminadas,
    );
    final movidas = deslocarAulas(
      originais,
      origem: aula.celula,
      destino: destino,
    );
    final motivo = validarMoverAulas(
      originais: originais,
      movidas: movidas,
      todasAulas: todasAulas,
      professores: professores,
      indisponibilidades: indisponibilidades,
    );
    if (motivo != null) return 'Não foi possível mover. $motivo';
    iniciarGravacao();

    final repo = ref.read(provedorRepositorioAula);
    final deslocamento = destino.indicePeriodo - aula.indicePeriodo;
    try {
      await repo.moverAulas(movidas, deslocamentoPeriodos: deslocamento);
    } catch (e) {
      // Falhou no meio de um conjunto: devolve todas à posição original
      // para não deixar o conjunto dividido entre dois lugares.
      try {
        await repo.moverAulas(originais, deslocamentoPeriodos: -deslocamento);
      } catch (_) {
        // Sem conexão nem para desfazer; o validador da página mostra o
        // estado real quando os dados recarregarem.
      }
      rethrow;
    } finally {
      ref.invalidate(provedorAulas);
    }
    return null;
  }

  /// Troca [a] e [b] de lugar. Se a gravação cair no meio, devolve as duas
  /// para onde estavam.
  Future<String?> _trocar({
    required VoidCallback iniciarGravacao,
    required Aula a,
    required Aula b,
    required List<Aula> todasAulas,
    required List<Professor> professores,
    required List<IndisponibilidadeProfessor> indisponibilidades,
  }) async {
    final motivo = validarTrocaAulas(
      a: a,
      b: b,
      todasAulas: todasAulas,
      professores: professores,
      indisponibilidades: indisponibilidades,
    );
    if (motivo != null) return motivo;
    iniciarGravacao();

    final repo = ref.read(provedorRepositorioAula);
    try {
      await repo.trocarAulas(a, b);
    } catch (e) {
      // Se falhou no meio, [a] ainda está na própria célula (talvez no
      // grupo 2) e [b] pode estar no lugar de [a]. Volta [b] para a célula
      // dela e depois [a] para o grupo 1.
      try {
        await repo.moverAulas([b], deslocamentoPeriodos: 0);
        await repo.atualizar(a);
      } catch (_) {
        // Sem conexão nem para desfazer; o painel mostra o estado real
        // quando os dados recarregarem.
      }
      rethrow;
    } finally {
      ref.invalidate(provedorAulas);
    }
    return null;
  }

  Future<Aula?> _escolherGrupoParaEditar(
    BuildContext context,
    List<Aula> aulas,
    Map<String, Materia> materias,
  ) {
    return showDialog<Aula>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Qual grupo editar?'),
        children: [
          for (final aula in aulas)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, aula),
              child: Text(
                'Grupo ${aula.grupo} — '
                '${materias[aula.idMateria]?.nome ?? 'Componente'}',
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
