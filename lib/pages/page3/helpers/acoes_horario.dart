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

  final WidgetRef ref;

  Future<String?> limparCurso({
    required BuildContext context,
    required Curso curso,
  }) async {
    final confirmado = await mostrarDialogoConfirmarExclusao(
      context,
      titulo: 'Limpar grade',
      mensagem:
          'Remover todas as aulas de "${curso.nome}"? Esta ação não desfaz.',
    );
    if (!confirmado) return null;

    await ref.read(provedorRepositorioAula).excluirPorCurso(curso.id);
    ref.invalidate(provedorAulas);
    return 'Grade de "${curso.nome}" limpa.';
  }

  Future<String?> gerarTodos({
    required BuildContext context,
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
          'configurações da Página 1.',
      rotuloConfirmar: 'Gerar',
    );
    if (!confirmado) return null;

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
    final anteriores = await repo.buscarTodos();
    await repo.excluirTodas();

    try {
      await repo.adicionarVarias(resultado.novasAulas);
    } catch (e) {
      // Restaura a grade anterior para não deixar o banco vazio.
      try {
        await repo.excluirTodas();
        await repo.adicionarVarias(anteriores);
      } finally {
        ref.invalidate(provedorAulas);
      }
      final detalhe = e is PostgrestException ? e.message : '$e';
      return 'Não foi possível salvar o horário gerado '
          '(grade anterior restaurada): $detalhe';
    }
    ref.invalidate(provedorAulas);

    if (resultado.completo) {
      return 'Horários gerados: ${resultado.novasAulas.length} aula(s) alocadas.';
    }
    return 'Parcial: ${resultado.novasAulas.length} aula(s). '
        '${resultado.falhas.take(3).join(' ')}';
  }

  Future<String?> aoTocarCelula({
    required BuildContext context,
    required CelulaGrade celula,
    required Curso curso,
    required List<Materia> materiasCurso,
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
    var grupo = 1;
    String? materiaBaseGeminada;

    if (naCelula.isEmpty) {
      grupo = 1;
    } else if (naCelula.length == 1) {
      final materiasPermitidas = materiasGeminadasCom(
        idCurso: curso.id,
        idMateria: naCelula.first.idMateria,
        aulasGeminadas: aulasGeminadas,
      );
      if (materiasPermitidas.isEmpty) {
        existente = naCelula.first;
        grupo = existente.grupo;
      } else {
        final escolha = await _escolherAcaoCelulaComUmaAula(
          context,
          naCelula.first,
          mapaMaterias,
        );
        if (escolha == null) return null;
        if (escolha == _AcaoCelula.editar) {
          existente = naCelula.first;
          grupo = existente.grupo;
        } else {
          final livre = proximoGrupoLivre(naCelula);
          if (livre == null) {
            return 'Este horário já tem $maxGruposPorCelula grupos.';
          }
          grupo = livre;
          materiaBaseGeminada = naCelula.first.idMateria;
        }
      }
    } else {
      final escolhida = await _escolherGrupoParaEditar(
        context,
        naCelula,
        mapaMaterias,
      );
      if (escolhida == null) return null;
      existente = escolhida;
      grupo = escolhida.grupo;
    }

    if (!context.mounted) return null;

    final rotuloDia = GradeHoraria.dias[celula.indiceDia];
    final rotuloPeriodo = GradeHoraria.periodos[celula.indicePeriodo];
    final titulo = existente == null
        ? 'Nova aula — $rotuloDia $rotuloPeriodo · Grupo $grupo'
        : 'Editar — $rotuloDia $rotuloPeriodo · Grupo $grupo';
    final materiasPermitidas = materiaBaseGeminada == null
        ? materiasCurso
        : materiasCurso
              .where(
                (materia) => materiasGeminadasCom(
                  idCurso: curso.id,
                  idMateria: materiaBaseGeminada!,
                  aulasGeminadas: aulasGeminadas,
                ).contains(materia.id),
              )
              .toList();

    final resultado = await mostrarDialogoFormularioAula(
      context,
      titulo: titulo,
      materias: materiasParaDialogoAula(
        materiasCurso: materiasPermitidas,
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
          : 'Excluir a aula do grupo $grupo em $rotuloDia $rotuloPeriodo?',
    );

    if (resultado == null) return null;

    if (resultado is ExclusaoFormularioAula) {
      if (existente == null) return null;
      await ref.read(provedorRepositorioAula).excluir(existente.id);
      ref.invalidate(provedorAulas);
      return null;
    }

    if (resultado is! ResultadoFormularioAula) return null;

    final erro = validarSalvarAula(
      curso: curso,
      celula: celula,
      idMateria: resultado.idMateria,
      idProfessor: resultado.idProfessor,
      idSala: resultado.idSala,
      existente: existente,
      grupo: grupo,
      cargas: cargas,
      aulasGeminadas: aulasGeminadas,
      todasAulas: todasAulas,
      ligacoes: ligacoes,
      indisponibilidades: indisponibilidades,
    );
    if (erro != null) return erro;

    final aula = Aula(
      id: existente?.id ?? '0',
      idCurso: curso.id,
      indiceDia: celula.indiceDia,
      indicePeriodo: celula.indicePeriodo,
      idMateria: resultado.idMateria,
      idProfessor: resultado.idProfessor,
      idSala: resultado.idSala,
      grupo: grupo,
    );

    if (existente == null) {
      await ref.read(provedorRepositorioAula).adicionar(aula);
    } else {
      await ref.read(provedorRepositorioAula).atualizar(aula);
    }
    ref.invalidate(provedorAulas);
    return null;
  }

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
    required Aula aula,
    required CelulaGrade destino,
    required List<Aula> todasAulas,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<Professor> professores,
    required List<IndisponibilidadeProfessor> indisponibilidades,
  }) async {
    if (aula.celula == destino) return null;

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

  Future<_AcaoCelula?> _escolherAcaoCelulaComUmaAula(
    BuildContext context,
    Aula aula,
    Map<String, Materia> materias,
  ) {
    final nome = materias[aula.idMateria]?.nome ?? 'aula';
    return showDialog<_AcaoCelula>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Horário — Grupo ${aula.grupo} ($nome)'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _AcaoCelula.editar),
            child: const Text('Editar este grupo'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _AcaoCelula.adicionarGrupo),
            child: const Text('Adicionar 2º grupo'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
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
                '${materias[aula.idMateria]?.nome ?? 'Matéria'}',
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

enum _AcaoCelula { editar, adicionarGrupo }
