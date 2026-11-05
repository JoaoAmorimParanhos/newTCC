import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/model/sala/sala.dart';

/// Máximo de grupos (aulas paralelas) por horário na mesma turma
/// quando existe uma regra de aula geminada para a turma.
const int maxGruposPorCelula = 2;

int maxGruposDoCurso(Curso curso, List<AulaGeminadaCurso> aulasGeminadas) {
  final temParGeminado = aulasGeminadas.any((par) => par.idCurso == curso.id);
  return temParGeminado ? maxGruposPorCelula : 1;
}

Map<String, Materia> materiaPorId(List<Materia> materias) => {
  for (final m in materias) m.id: m,
};

Map<String, Professor> professorPorId(List<Professor> professores) => {
  for (final p in professores) p.id: p,
};

Map<String, Sala> salaPorId(List<Sala> salas) => {
  for (final s in salas) s.id: s,
};

Map<CelulaGrade, List<Aula>> aulasPorCelulaDoCurso(
  List<Aula> aulas,
  String idCurso,
) {
  final mapa = <CelulaGrade, List<Aula>>{};
  for (final aula in aulas.where((a) => a.idCurso == idCurso)) {
    mapa.putIfAbsent(aula.celula, () => []).add(aula);
  }
  for (final lista in mapa.values) {
    lista.sort((a, b) => a.grupo.compareTo(b.grupo));
  }
  return mapa;
}

List<Aula> aulasNaCelula(List<Aula> aulas, String idCurso, CelulaGrade celula) {
  return aulas
      .where(
        (a) =>
            a.idCurso == idCurso &&
            a.indiceDia == celula.indiceDia &&
            a.indicePeriodo == celula.indicePeriodo,
      )
      .toList()
    ..sort((a, b) => a.grupo.compareTo(b.grupo));
}

/// Turma dividida em que só o grupo 2 tem aula: o grupo 1 está livre
/// (parte da aula geminada em que só a matéria maior tem aula, ou par em
/// que o grupo 1 foi excluído).
bool turmaDivididaComGrupoLivre(List<Aula> aulasNaCelula) =>
    aulasNaCelula.length == 1 && aulasNaCelula.single.grupo == 2;

/// Próximo número de grupo livre (1 ou 2) na célula, ou null se cheia.
int? proximoGrupoLivre(List<Aula> aulasNaCelula, {String? idAulaExcluida}) {
  final usados = aulasNaCelula
      .where((a) => a.id != idAulaExcluida)
      .map((a) => a.grupo)
      .toSet();
  for (var g = 1; g <= maxGruposPorCelula; g++) {
    if (!usados.contains(g)) return g;
  }
  return null;
}

bool estaIndisponivel(
  List<IndisponibilidadeProfessor> linhas,
  String idProfessor,
  CelulaGrade celula,
) {
  return linhas.any(
    (u) =>
        u.idProfessor == idProfessor &&
        u.indiceDia == celula.indiceDia &&
        u.indicePeriodo == celula.indicePeriodo,
  );
}

List<Professor> professoresDaMateriaNaCelula({
  required String idMateria,
  required CelulaGrade celula,
  required List<Professor> professores,
  required List<ProfessorMateria> ligacoes,
  required List<IndisponibilidadeProfessor> indisponibilidades,
  required List<Aula> todasAulas,
  String? idAulaExcluida,
}) {
  final idsLigados = ligacoes
      .where((l) => l.idMateria == idMateria)
      .map((l) => l.idProfessor)
      .toSet();

  return professores.where((p) {
    if (!idsLigados.contains(p.id)) return false;
    if (estaIndisponivel(indisponibilidades, p.id, celula)) return false;
    final ocupado = todasAulas.any(
      (a) =>
          a.id != idAulaExcluida &&
          a.idProfessor == p.id &&
          a.indiceDia == celula.indiceDia &&
          a.indicePeriodo == celula.indicePeriodo,
    );
    return !ocupado;
  }).toList();
}

String subtituloProgresso(
  Curso curso,
  List<CargaCursoMateria> cargas,
  List<Aula> aulas,
) {
  final cargasDoCurso = cargas.where((l) => l.idCurso == curso.id).toList();
  if (cargasDoCurso.isEmpty) return 'Sem carga definida';

  final necessario = cargasDoCurso.fold<int>(
    0,
    (s, l) => s + l.quantidadeAulas,
  );
  final alocado = aulas.where((a) => a.idCurso == curso.id).length;
  return '$alocado/$necessario aulas alocadas';
}

/// Professores disponíveis + professor atual (mesmo bloqueado) ao editar.
List<Professor> professoresParaDialogoAula({
  required String idMateria,
  required CelulaGrade celula,
  required List<Professor> professores,
  required List<ProfessorMateria> ligacoes,
  required List<IndisponibilidadeProfessor> indisponibilidades,
  required List<Aula> todasAulas,
  Aula? existente,
}) {
  final disponiveis = professoresDaMateriaNaCelula(
    idMateria: idMateria,
    celula: celula,
    professores: professores,
    ligacoes: ligacoes,
    indisponibilidades: indisponibilidades,
    todasAulas: todasAulas,
    idAulaExcluida: existente?.id,
  );

  if (existente != null &&
      existente.idMateria == idMateria &&
      !disponiveis.any((p) => p.id == existente.idProfessor)) {
    final atual = professores.where((p) => p.id == existente.idProfessor);
    if (atual.isNotEmpty) {
      return [...disponiveis, atual.first];
    }
  }
  return disponiveis;
}

/// Retorna mensagem de erro ou null se a aula pode ser salva.
///
/// A carga e os pares de aula geminada não bloqueiam: criar ou excluir na
/// grade atualiza o cadastro do curso (ver `cadastro_da_grade.dart`).
String? validarSalvarAula({
  required Curso curso,
  required CelulaGrade celula,
  required String idMateria,
  required String idProfessor,
  required String? idSala,
  required Aula? existente,
  required int grupo,
  required List<Aula> todasAulas,
  required List<ProfessorMateria> ligacoes,
  required List<IndisponibilidadeProfessor> indisponibilidades,
}) {
  final vinculado = ligacoes.any(
    (l) => l.idProfessor == idProfessor && l.idMateria == idMateria,
  );
  if (!vinculado) {
    return 'Este professor não está vinculado a esta matéria.';
  }

  if (estaIndisponivel(indisponibilidades, idProfessor, celula)) {
    return 'Professor indisponível neste horário (Página 2).';
  }

  final professorOcupado = todasAulas.any(
    (a) =>
        a.id != existente?.id &&
        a.idProfessor == idProfessor &&
        a.indiceDia == celula.indiceDia &&
        a.indicePeriodo == celula.indicePeriodo,
  );
  if (professorOcupado) {
    return 'Este professor já está alocado neste horário.';
  }

  final naCelula = aulasNaCelula(
    todasAulas,
    curso.id,
    celula,
  ).where((a) => a.id != existente?.id).toList();
  if (naCelula.length >= maxGruposPorCelula) {
    return 'Este horário já tem $maxGruposPorCelula grupos nesta turma.';
  }
  if (naCelula.any((a) => a.grupo == grupo)) {
    return 'O grupo $grupo já está ocupado neste horário.';
  }
  if (naCelula.any((a) => a.idMateria == idMateria)) {
    return 'Esta matéria já está neste horário (outro grupo).';
  }

  // Sala: grupos da mesma turma podem dividir; outra turma conflita.
  if (idSala != null) {
    final salaOcupada = todasAulas.any(
      (a) =>
          a.id != existente?.id &&
          a.idSala == idSala &&
          a.indiceDia == celula.indiceDia &&
          a.indicePeriodo == celula.indicePeriodo &&
          a.idCurso != curso.id,
    );
    if (salaOcupada) {
      return 'Esta sala já está ocupada por outra turma neste horário.';
    }
  }

  return null;
}

/// Aulas que se movem juntas ao arrastar [aula].
///
/// Aula comum: só ela. Aula geminada: o conjunto inteiro, ou seja, os dois
/// grupos de todos os horários seguidos (no mesmo dia e turno) em que o
/// mesmo par está junto.
List<Aula> aulasQueMovemJunto({
  required Aula aula,
  required List<Aula> todasAulas,
  required List<AulaGeminadaCurso> aulasGeminadas,
}) {
  final paresDoCurso = aulasGeminadas
      .where((p) => p.idCurso == aula.idCurso)
      .toList();

  /// Aulas da célula se ela faz parte de um conjunto geminado: os dois
  /// grupos do par, ou só o grupo 2 (grupo 1 livre) de uma matéria de par.
  List<Aula>? parNaCelula(int periodo) {
    if (periodo < 0 || periodo >= GradeHoraria.periodos.length) return null;
    if (!GradeHoraria.periodosNaMesmaFaixa(periodo, aula.indicePeriodo)) {
      return null;
    }
    final naCelula = aulasNaCelula(
      todasAulas,
      aula.idCurso,
      CelulaGrade(indiceDia: aula.indiceDia, indicePeriodo: periodo),
    );
    if (naCelula.length == 2 &&
        existeAulaGeminada(
          idCurso: aula.idCurso,
          idMateriaA: naCelula.first.idMateria,
          idMateriaB: naCelula.last.idMateria,
          aulasGeminadas: aulasGeminadas,
        )) {
      return naCelula;
    }
    if (turmaDivididaComGrupoLivre(naCelula) &&
        paresDoCurso.any((p) => p.contemMateria(naCelula.single.idMateria))) {
      return naCelula;
    }
    return null;
  }

  final daCelula = parNaCelula(aula.indicePeriodo);
  if (daCelula == null) return [aula];

  // Matérias que podem fazer parte do mesmo conjunto: as dos pares que
  // contêm as matérias da célula arrastada.
  final materiasDoConjunto = <String>{
    for (final par in paresDoCurso)
      if (daCelula.every((a) => par.contemMateria(a.idMateria))) ...[
        par.idMateriaA,
        par.idMateriaB,
      ],
  };

  bool mesmoPar(List<Aula> outra) =>
      outra.every((a) => materiasDoConjunto.contains(a.idMateria));

  final conjunto = <Aula>[...daCelula];
  for (var p = aula.indicePeriodo - 1; ; p--) {
    final vizinha = parNaCelula(p);
    if (vizinha == null || !mesmoPar(vizinha)) break;
    conjunto.addAll(vizinha);
  }
  for (var p = aula.indicePeriodo + 1; ; p++) {
    final vizinha = parNaCelula(p);
    if (vizinha == null || !mesmoPar(vizinha)) break;
    conjunto.addAll(vizinha);
  }
  return conjunto;
}

/// As [aulas] deslocadas como um conjunto: a aula pega em [origem] vai para
/// [destino] e as outras mantêm a mesma distância dela.
List<Aula> deslocarAulas(
  List<Aula> aulas, {
  required CelulaGrade origem,
  required CelulaGrade destino,
}) {
  final dDia = destino.indiceDia - origem.indiceDia;
  final dPeriodo = destino.indicePeriodo - origem.indicePeriodo;
  return [
    for (final a in aulas)
      Aula(
        id: a.id,
        idCurso: a.idCurso,
        indiceDia: a.indiceDia + dDia,
        indicePeriodo: a.indicePeriodo + dPeriodo,
        idMateria: a.idMateria,
        idProfessor: a.idProfessor,
        idSala: a.idSala,
        grupo: a.grupo,
      ),
  ];
}

/// "Seg 1º M". Índice fora da grade (dado antigo) não quebra a mensagem.
String rotuloCelula(CelulaGrade c) {
  final dentro =
      c.indiceDia >= 0 &&
      c.indiceDia < GradeHoraria.dias.length &&
      c.indicePeriodo >= 0 &&
      c.indicePeriodo < GradeHoraria.periodos.length;
  if (!dentro) return 'dia ${c.indiceDia + 1}, período ${c.indicePeriodo + 1}';
  return '${GradeHoraria.dias[c.indiceDia]} '
      '${GradeHoraria.periodos[c.indicePeriodo]}';
}

/// Retorna o motivo para recusar soltar as [movidas] (já na posição nova),
/// ou null se pode mover.
String? validarMoverAulas({
  required List<Aula> originais,
  required List<Aula> movidas,
  required List<Aula> todasAulas,
  required List<Professor> professores,
  required List<IndisponibilidadeProfessor> indisponibilidades,
}) {
  final idsMovidas = {for (final a in originais) a.id};
  final horarios = <int>{for (final a in originais) a.indicePeriodo}.length;
  final ehConjunto = horarios > 1 || originais.length > 1;
  final nomes = {for (final p in professores) p.id: p.nome};

  final dentro = movidas.every(
    (a) =>
        a.indiceDia >= 0 &&
        a.indiceDia < GradeHoraria.dias.length &&
        a.indicePeriodo >= 0 &&
        a.indicePeriodo < GradeHoraria.periodos.length,
  );
  final mesmoTurno =
      dentro &&
      movidas.every(
        (a) => GradeHoraria.periodosNaMesmaFaixa(
          a.indicePeriodo,
          movidas.first.indicePeriodo,
        ),
      );
  if (!mesmoTurno) {
    return 'Não cabe aqui: a aula geminada precisa de $horarios horário(s) '
        'seguidos no mesmo turno.';
  }

  for (final nova in movidas) {
    final celula = nova.celula;
    final outras = todasAulas.where(
      (a) =>
          !idsMovidas.contains(a.id) &&
          a.indiceDia == nova.indiceDia &&
          a.indicePeriodo == nova.indicePeriodo,
    );

    final daTurma = outras.where((a) => a.idCurso == nova.idCurso).toList();
    if (turmaDivididaComGrupoLivre(daTurma)) {
      return 'Horário dividido: em ${rotuloCelula(celula)} a turma está em 2 '
          'grupos e o grupo 1 fica livre (aula geminada). Não dá para '
          'soltar aula aqui.';
    }
    if (daTurma.isNotEmpty) {
      return ehConjunto
          ? 'Horário ocupado: a aula geminada precisa de $horarios '
                'horário(s) vazios seguidos (${rotuloCelula(celula)} já tem aula).'
          : 'Horário ocupado: solte a aula numa célula vazia '
                '(${rotuloCelula(celula)} já tem aula).';
    }

    final nomeProfessor = nomes[nova.idProfessor] ?? 'Professor';
    if (outras.any((a) => a.idProfessor == nova.idProfessor)) {
      return '$nomeProfessor já está dando aula em ${rotuloCelula(celula)}.';
    }
    if (estaIndisponivel(indisponibilidades, nova.idProfessor, celula)) {
      return '$nomeProfessor está indisponível em ${rotuloCelula(celula)} '
          '(Página 2).';
    }
    final idSala = nova.idSala;
    if (idSala != null && outras.any((a) => a.idSala == idSala)) {
      return 'A sala já está ocupada por outra turma em ${rotuloCelula(celula)}.';
    }
  }
  return null;
}
