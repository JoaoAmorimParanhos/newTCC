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

List<Materia> materiasDoCurso(
  String idCurso,
  List<CargaCursoMateria> cargas,
  List<Materia> materias,
) {
  final ids = cargas
      .where((l) => l.idCurso == idCurso)
      .map((l) => l.idMateria)
      .toSet();
  return materias.where((m) => ids.contains(m.id)).toList();
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

int quantidadeAgendada(
  List<Aula> aulas,
  String idCurso,
  String idMateria, {
  String? idAulaExcluida,
}) {
  return aulas
      .where(
        (a) =>
            a.idCurso == idCurso &&
            a.idMateria == idMateria &&
            a.id != idAulaExcluida,
      )
      .length;
}

int? cargaMaxima(
  List<CargaCursoMateria> cargas,
  String idCurso,
  String idMateria,
) {
  for (final carga in cargas) {
    if (carga.idCurso == idCurso && carga.idMateria == idMateria) {
      return carga.quantidadeAulas;
    }
  }
  return null;
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

List<Materia> materiasParaDialogoAula({
  required List<Materia> materiasCurso,
  required List<Materia> todasMaterias,
  Aula? existente,
}) {
  final lista = List<Materia>.from(materiasCurso);
  if (existente != null && !lista.any((m) => m.id == existente.idMateria)) {
    final orfao = todasMaterias.where((m) => m.id == existente.idMateria);
    if (orfao.isNotEmpty) {
      lista.add(orfao.first);
    }
  }
  return lista;
}

/// Retorna mensagem de erro ou null se a aula pode ser salva.
String? validarSalvarAula({
  required Curso curso,
  required CelulaGrade celula,
  required String idMateria,
  required String idProfessor,
  required String? idSala,
  required Aula? existente,
  required int grupo,
  required List<CargaCursoMateria> cargas,
  required List<AulaGeminadaCurso> aulasGeminadas,
  required List<Aula> todasAulas,
  required List<ProfessorMateria> ligacoes,
  required List<IndisponibilidadeProfessor> indisponibilidades,
}) {
  final maximo = cargaMaxima(cargas, curso.id, idMateria);
  if (maximo == null) {
    return 'Matéria não pertence à carga deste curso.';
  }

  final jaAgendada = quantidadeAgendada(
    todasAulas,
    curso.id,
    idMateria,
    idAulaExcluida: existente?.id,
  );
  if (jaAgendada >= maximo) {
    return 'Carga completa para esta matéria ($maximo aula(s)).';
  }

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

  final limiteGrupos = maxGruposDoCurso(curso, aulasGeminadas);
  final naCelula = aulasNaCelula(
    todasAulas,
    curso.id,
    celula,
  ).where((a) => a.id != existente?.id).toList();
  if (naCelula.length >= limiteGrupos) {
    if (limiteGrupos == 1) {
      return 'Cadastre um par de aula geminada para usar 2 grupos.';
    }
    return 'Este horário já tem $limiteGrupos grupos nesta turma.';
  }
  if (naCelula.any((a) => a.grupo == grupo)) {
    return 'O grupo $grupo já está ocupado neste horário.';
  }
  if (naCelula.any((a) => a.idMateria == idMateria)) {
    return 'Esta matéria já está neste horário (outro grupo).';
  }
  if (naCelula.isNotEmpty &&
      !existeAulaGeminada(
        idCurso: curso.id,
        idMateriaA: naCelula.first.idMateria,
        idMateriaB: idMateria,
        aulasGeminadas: aulasGeminadas,
      )) {
    return 'Estas matérias não formam uma aula geminada nesta turma.';
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
    if (naCelula.length != 2) return null;
    if (!existeAulaGeminada(
      idCurso: aula.idCurso,
      idMateriaA: naCelula.first.idMateria,
      idMateriaB: naCelula.last.idMateria,
      aulasGeminadas: aulasGeminadas,
    )) {
      return null;
    }
    return naCelula;
  }

  final daCelula = parNaCelula(aula.indicePeriodo);
  if (daCelula == null) return [aula];

  bool mesmoPar(List<Aula> outra) {
    final materias = {for (final a in daCelula) a.idMateria};
    return outra.every((a) => materias.contains(a.idMateria));
  }

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

String _rotulo(CelulaGrade c) =>
    '${GradeHoraria.dias[c.indiceDia]} ${GradeHoraria.periodos[c.indicePeriodo]}';

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

    if (outras.any((a) => a.idCurso == nova.idCurso)) {
      return ehConjunto
          ? 'Horário ocupado: a aula geminada precisa de $horarios '
                'horário(s) vazios seguidos (${_rotulo(celula)} já tem aula).'
          : 'Horário ocupado: solte a aula numa célula vazia '
                '(${_rotulo(celula)} já tem aula).';
    }

    final nomeProfessor = nomes[nova.idProfessor] ?? 'Professor';
    if (outras.any((a) => a.idProfessor == nova.idProfessor)) {
      return '$nomeProfessor já está dando aula em ${_rotulo(celula)}.';
    }
    if (estaIndisponivel(indisponibilidades, nova.idProfessor, celula)) {
      return '$nomeProfessor está indisponível em ${_rotulo(celula)} '
          '(Página 2).';
    }
    final idSala = nova.idSala;
    if (idSala != null && outras.any((a) => a.idSala == idSala)) {
      return 'A sala já está ocupada por outra turma em ${_rotulo(celula)}.';
    }
  }
  return null;
}
