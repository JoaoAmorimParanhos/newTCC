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

/// Aviso para o professor escolhido no diálogo de aula, ou null se ele
/// pode dar a aula neste horário. Serve para o professor atual de uma aula
/// que ficou bloqueado depois (Página 2 ou outra turma).
String? avisoProfessorNaCelula({
  required String idProfessor,
  required CelulaGrade celula,
  required List<IndisponibilidadeProfessor> indisponibilidades,
  required List<Aula> todasAulas,
  String? idAulaExcluida,
}) {
  if (estaIndisponivel(indisponibilidades, idProfessor, celula)) {
    return 'O professor atual está indisponível neste horário (Disponibilidade). '
        'Selecione outro para salvar.';
  }
  final ocupado = todasAulas.any(
    (a) =>
        a.id != idAulaExcluida &&
        a.idProfessor == idProfessor &&
        a.indiceDia == celula.indiceDia &&
        a.indicePeriodo == celula.indicePeriodo,
  );
  if (ocupado) {
    return 'O professor atual já está em outra aula neste horário. '
        'Selecione outro para salvar.';
  }
  return null;
}

/// Grupo com que a aula é gravada ao salvar o diálogo.
///
/// Uma aula sozinha no grupo 2 ("G1 livre") só continua no grupo 2 se o
/// componente ainda faz parte de uma aula dividida do curso; senão vira
/// aula comum (grupo 1).
int grupoAoSalvar({
  required String idCurso,
  required String idMateria,
  required int grupoAtual,
  required List<Aula> outrasNaCelula,
  required List<AulaGeminadaCurso> aulasGeminadas,
}) {
  if (grupoAtual != 2 || outrasNaCelula.isNotEmpty) return grupoAtual;
  final temPar = materiasGeminadasCom(
    idCurso: idCurso,
    idMateria: idMateria,
    aulasGeminadas: aulasGeminadas,
  ).isNotEmpty;
  return temPar ? 2 : 1;
}

/// Grupo da aula que sobra na célula depois de excluir [excluida].
///
/// Se as duas formavam uma aula dividida cadastrada, a que sobra fica no
/// grupo 2 (G1 livre). Se não formam mais par (o par saiu da Página 1),
/// a que sobra vira aula comum (grupo 1).
int grupoDaQueSobra({
  required String idCurso,
  required Aula excluida,
  required Aula restante,
  required List<AulaGeminadaCurso> aulasGeminadas,
}) {
  final formamPar = existeAulaGeminada(
    idCurso: idCurso,
    idMateriaA: excluida.idMateria,
    idMateriaB: restante.idMateria,
    aulasGeminadas: aulasGeminadas,
  );
  return formamPar ? 2 : 1;
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

/// Componentes da carga do curso (os que a Página 3 oferece numa aula nova).
List<Materia> materiasDoCurso(
  String idCurso,
  List<CargaCursoMateria> cargas,
  List<Materia> materias,
) {
  final ids = {
    for (final c in cargas.where((c) => c.idCurso == idCurso)) c.idMateria,
  };
  return materias.where((m) => ids.contains(m.id)).toList();
}

/// Lista do diálogo de aula: os componentes da carga e, ao editar, o
/// componente atual mesmo que tenha saído da carga.
List<Materia> materiasParaDialogoAula({
  required List<Materia> materiasCurso,
  required List<Materia> todasMaterias,
  Aula? existente,
}) {
  final lista = List<Materia>.from(materiasCurso);
  if (existente != null && !lista.any((m) => m.id == existente.idMateria)) {
    final atual = todasMaterias.where((m) => m.id == existente.idMateria);
    if (atual.isNotEmpty) lista.add(atual.first);
  }
  return lista;
}

/// Aulas do componente já marcadas na grade da turma.
int quantidadeAgendada(
  List<Aula> aulas,
  String idCurso,
  String idMateria, {
  String? idAulaExcluida,
}) => aulas
    .where(
      (a) =>
          a.idCurso == idCurso &&
          a.idMateria == idMateria &&
          a.id != idAulaExcluida,
    )
    .length;

/// Carga do componente no curso, ou null se não está na carga.
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

/// Retorna mensagem de erro ou null se a aula pode ser salva.
///
/// A Página 3 só usa o que está cadastrado na Página 1: o componente
/// precisa estar na carga (e ainda faltar aula dele), e dois grupos no
/// mesmo horário precisam formar um par de aula dividida.
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
  // A carga só conta quando entra uma aula nova do componente (aula nova
  // ou troca de componente). Editar professor/sala de uma aula que já
  // existe não aumenta nada, mesmo que a carga tenha diminuído depois.
  final mudaComponente = existente == null || existente.idMateria != idMateria;
  if (mudaComponente) {
    final maximo = cargaMaxima(cargas, curso.id, idMateria);
    if (maximo == null) {
      return 'Este componente não está na carga do curso (Cadastros).';
    }
    final jaAgendada = quantidadeAgendada(
      todasAulas,
      curso.id,
      idMateria,
      idAulaExcluida: existente?.id,
    );
    if (jaAgendada >= maximo) {
      return 'Carga completa para este componente ($maximo aula(s)).';
    }
  }

  final vinculado = ligacoes.any(
    (l) => l.idProfessor == idProfessor && l.idMateria == idMateria,
  );
  if (!vinculado) {
    return 'Este professor não está vinculado a este componente.';
  }

  if (estaIndisponivel(indisponibilidades, idProfessor, celula)) {
    return 'Professor indisponível neste horário (Disponibilidade).';
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
    return 'Este componente já está neste horário (outro grupo).';
  }
  if (naCelula.isNotEmpty &&
      !existeAulaGeminada(
        idCurso: curso.id,
        idMateriaA: naCelula.first.idMateria,
        idMateriaB: idMateria,
        aulasGeminadas: aulasGeminadas,
      )) {
    return 'Estes componentes não formam uma aula dividida nesta turma '
        '(Cadastros).';
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
/// Aula com que [aula] troca de lugar ao ser solta em [destino], ou null
/// se não é caso de troca.
///
/// Só troca duas aulas comuns: cada uma sozinha na sua célula (turma
/// inteira, grupo 1) e fora de qualquer conjunto de aula dividida.
/// Aula dividida continua precisando de horários vazios.
Aula? aulaParaTrocar({
  required Aula aula,
  required CelulaGrade destino,
  required List<Aula> todasAulas,
  required List<AulaGeminadaCurso> aulasGeminadas,
}) {
  if (aula.celula == destino) return null;
  final naOrigem = aulasNaCelula(todasAulas, aula.idCurso, aula.celula);
  final noDestino = aulasNaCelula(todasAulas, aula.idCurso, destino);
  if (naOrigem.length != 1 || noDestino.length != 1) return null;
  final outra = noDestino.single;
  if (naOrigem.single.id != aula.id) return null;
  if (aula.grupo != 1 || outra.grupo != 1) return null;
  bool sozinha(Aula a) =>
      aulasQueMovemJunto(
        aula: a,
        todasAulas: todasAulas,
        aulasGeminadas: aulasGeminadas,
      ).length ==
      1;
  if (!sozinha(aula) || !sozinha(outra)) return null;
  return outra;
}

/// As duas aulas na posição uma da outra (para gravar a troca).
(Aula, Aula) aulasTrocadas(Aula a, Aula b) => (
  deslocarAulas([a], origem: a.celula, destino: b.celula).single,
  deslocarAulas([b], origem: b.celula, destino: a.celula).single,
);

/// Motivo para não trocar [a] e [b] de lugar, ou null se pode: cada uma
/// precisa caber no lugar da outra (professor livre e disponível, sala
/// livre). Pode trocar entre turnos diferentes.
String? validarTrocaAulas({
  required Aula a,
  required Aula b,
  required List<Aula> todasAulas,
  required List<Professor> professores,
  required List<IndisponibilidadeProfessor> indisponibilidades,
}) {
  final (aNoLugarDeB, bNoLugarDeA) = aulasTrocadas(a, b);
  for (final movida in [aNoLugarDeB, bNoLugarDeA]) {
    final motivo = validarMoverAulas(
      originais: [a, b],
      movidas: [movida],
      todasAulas: todasAulas,
      professores: professores,
      indisponibilidades: indisponibilidades,
    );
    if (motivo != null) return 'Não dá para trocar: $motivo';
  }
  return null;
}

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
    return 'Não cabe aqui: a aula dividida precisa de $horarios horário(s) '
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
          'grupos e o grupo 1 fica livre (aula dividida). Não dá para '
          'soltar aula aqui.';
    }
    if (daTurma.isNotEmpty) {
      return ehConjunto
          ? 'Horário ocupado: a aula dividida precisa de $horarios '
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
          '(Disponibilidade).';
    }
    final idSala = nova.idSala;
    if (idSala != null && outras.any((a) => a.idSala == idSala)) {
      return 'A sala já está ocupada por outra turma em ${rotuloCelula(celula)}.';
    }
  }
  return null;
}
