import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';

class ResultadoGeracao {
  const ResultadoGeracao({
    required this.novasAulas,
    required this.totalAlocado,
    required this.totalNecessario,
    required this.falhas,
  });

  final List<Aula> novasAulas;
  final int totalAlocado;
  final int totalNecessario;
  final List<String> falhas;

  bool get completo => falhas.isEmpty && totalAlocado >= totalNecessario;
}

class ResultadoGeracaoCompleta {
  const ResultadoGeracaoCompleta({
    required this.novasAulas,
    required this.falhas,
  });

  final List<Aula> novasAulas;
  final List<String> falhas;

  bool get completo => falhas.isEmpty;
}

/// Coloca aulas em blocos configuráveis, respeitando turno, sala e indisponibilidade.
class GeradorHorario {
  const GeradorHorario();

  ResultadoGeracaoCompleta gerarTodos({
    required List<Curso> cursos,
    required List<CargaCursoMateria> cargas,
    required List<Professor> professores,
    required List<ProfessorMateria> ligacoes,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    List<AulaGeminadaCurso> aulasGeminadas = const [],
    Map<String, String> nomesMaterias = const {},
    Map<String, String> nomesCursos = const {},
  }) {
    final trabalhando = <Aula>[];
    final novasAulas = <Aula>[];
    final falhas = <String>[];

    final ordenados = List<Curso>.from(cursos)
      ..sort((a, b) {
        final cargaA = _totalNecessario(cargas, a.id);
        final cargaB = _totalNecessario(cargas, b.id);
        return cargaB.compareTo(cargaA);
      });

    for (final curso in ordenados) {
      final resultado = gerar(
        curso: curso,
        cargas: cargas,
        professores: professores,
        ligacoes: ligacoes,
        indisponibilidades: indisponibilidades,
        aulasGeminadas: aulasGeminadas,
        aulasExistentes: trabalhando,
        nomesMaterias: nomesMaterias,
      );
      trabalhando.addAll(resultado.novasAulas);
      novasAulas.addAll(resultado.novasAulas);
      final rotuloCurso = nomesCursos[curso.id] ?? curso.nome;
      falhas.addAll(resultado.falhas.map((f) => '$rotuloCurso: $f'));
    }

    return ResultadoGeracaoCompleta(novasAulas: novasAulas, falhas: falhas);
  }

  ResultadoGeracao gerar({
    required Curso curso,
    required List<CargaCursoMateria> cargas,
    required List<Professor> professores,
    required List<ProfessorMateria> ligacoes,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Aula> aulasExistentes,
    List<AulaGeminadaCurso> aulasGeminadas = const [],
    Map<String, String> nomesMaterias = const {},
  }) {
    final idCurso = curso.id;
    final cargasCurso = cargas.where((l) => l.idCurso == idCurso).toList();
    final totalNecessario = cargasCurso.fold<int>(
      0,
      (soma, l) => soma + l.quantidadeAulas,
    );

    if (cargasCurso.isEmpty) {
      return const ResultadoGeracao(
        novasAulas: [],
        totalAlocado: 0,
        totalNecessario: 0,
        falhas: ['Curso sem carga de matérias definida.'],
      );
    }

    final trabalhando = List<Aula>.from(aulasExistentes);
    final novasAulas = <Aula>[];
    final falhas = <String>[];

    cargasCurso.sort((a, b) {
      final contagemA = ligacoes
          .where((l) => l.idMateria == a.idMateria)
          .length;
      final contagemB = ligacoes
          .where((l) => l.idMateria == b.idMateria)
          .length;
      return contagemA.compareTo(contagemB);
    });

    String rotulo(String idMateria) =>
        nomesMaterias[idMateria] ?? 'matéria $idMateria';

    _alocarGeminadas(
      curso: curso,
      cargasCurso: cargasCurso,
      aulasGeminadas: aulasGeminadas,
      professores: professores,
      ligacoes: ligacoes,
      indisponibilidades: indisponibilidades,
      trabalhando: trabalhando,
      novasAulas: novasAulas,
      falhas: falhas,
      rotulo: rotulo,
    );

    for (final carga in cargasCurso) {
      final jaAlocado = trabalhando
          .where((a) => a.idCurso == idCurso && a.idMateria == carga.idMateria)
          .length;
      var restante = carga.quantidadeAulas - jaAlocado;
      if (restante <= 0) continue;

      final professoresMateria = professores
          .where(
            (p) => ligacoes.any(
              (l) => l.idProfessor == p.id && l.idMateria == carga.idMateria,
            ),
          )
          .toList();

      if (professoresMateria.isEmpty) {
        falhas.add(
          '${rotulo(carga.idMateria)}: nenhum professor vinculado '
          '($restante aula(s) faltando).',
        );
        continue;
      }

      final blocos = _blocosPara(restante, carga.tamanhoBloco);
      final fasesPeriodo = _fasesPeriodo(curso.preferenciaPeriodo);

      for (final tamanhoBloco in blocos) {
        // 1ª tentativa: um bloco da matéria por dia (espalha na semana).
        // 2ª tentativa: aceita repetir o dia quando a carga não cabe em 5 dias.
        var alocado = false;
        for (final permitirMesmoDia in const [false, true]) {
          if (alocado) break;

          for (final faixaPeriodos in fasesPeriodo) {
            if (alocado) break;

            for (
              var dia = 0;
              dia < GradeHoraria.dias.length && !alocado;
              dia++
            ) {
              for (final periodoInicio in _periodosInicio(
                faixaPeriodos,
                tamanhoBloco,
              )) {
                if (_tentarColocarBloco(
                  idCurso: idCurso,
                  idMateria: carga.idMateria,
                  dia: dia,
                  periodoInicio: periodoInicio,
                  tamanhoBloco: tamanhoBloco,
                  idSala: curso.idSala,
                  professoresMateria: professoresMateria,
                  indisponibilidades: indisponibilidades,
                  trabalhando: trabalhando,
                  novasAulas: novasAulas,
                  permitirMesmoDia: permitirMesmoDia,
                )) {
                  alocado = true;
                  restante -= tamanhoBloco;
                  break;
                }
              }
            }
          }
        }
      }

      if (restante > 0) {
        falhas.add(
          'Faltam $restante aula(s) de ${rotulo(carga.idMateria)} '
          '(blocos de ${carga.tamanhoBloco}).',
        );
      }
    }

    final totalAlocado =
        aulasExistentes.where((a) => a.idCurso == idCurso).length +
        novasAulas.length;

    return ResultadoGeracao(
      novasAulas: novasAulas,
      totalAlocado: totalAlocado,
      totalNecessario: totalNecessario,
      falhas: falhas,
    );
  }

  int _totalNecessario(List<CargaCursoMateria> cargas, String idCurso) {
    return cargas
        .where((l) => l.idCurso == idCurso)
        .fold<int>(0, (soma, l) => soma + l.quantidadeAulas);
  }

  List<int> _blocosPara(int total, int blocoPreferido) {
    final tamanho = blocoPreferido.clamp(1, total).toInt();
    final blocos = <int>[];
    var restante = total;
    while (restante > 0) {
      final tamanhoAtual = restante >= tamanho ? tamanho : restante;
      blocos.add(tamanhoAtual);
      restante -= tamanhoAtual;
    }
    return blocos;
  }

  List<List<int>> _fasesPeriodo(PreferenciaPeriodo preferencia) {
    const manha = [0, 1, 2, 3, 4, 5];
    const tarde = [6, 7, 8, 9, 10, 11];
    return switch (preferencia) {
      PreferenciaPeriodo.manhaTarde => [manha, tarde],
      PreferenciaPeriodo.tardeManha => [tarde, manha],
    };
  }

  Iterable<int> _periodosInicio(
    List<int> faixaPeriodos,
    int tamanhoBloco,
  ) sync* {
    for (var i = 0; i <= faixaPeriodos.length - tamanhoBloco; i++) {
      yield faixaPeriodos[i];
    }
  }

  void _alocarGeminadas({
    required Curso curso,
    required List<CargaCursoMateria> cargasCurso,
    required List<AulaGeminadaCurso> aulasGeminadas,
    required List<Professor> professores,
    required List<ProfessorMateria> ligacoes,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Aula> trabalhando,
    required List<Aula> novasAulas,
    required List<String> falhas,
    required String Function(String idMateria) rotulo,
  }) {
    final cargaPorMateria = {
      for (final carga in cargasCurso) carga.idMateria: carga.quantidadeAulas,
    };

    List<Professor> professoresDa(String idMateria) {
      return professores
          .where(
            (p) => ligacoes.any(
              (l) => l.idProfessor == p.id && l.idMateria == idMateria,
            ),
          )
          .toList();
    }

    int jaAlocado(String idMateria) {
      return trabalhando
          .where(
            (a) => a.idCurso == curso.id && a.idMateria == idMateria,
          )
          .length;
    }

    for (final par in aulasGeminadas.where((p) => p.idCurso == curso.id)) {
      final nomeA = rotulo(par.idMateriaA);
      final nomeB = rotulo(par.idMateriaB);
      final professoresA = professoresDa(par.idMateriaA);
      final professoresB = professoresDa(par.idMateriaB);
      if (professoresA.isEmpty || professoresB.isEmpty) {
        falhas.add(
          'Aula geminada de $nomeA e $nomeB: falta professor em uma das matérias.',
        );
        continue;
      }
      final temProfessoresDiferentes = professoresA.any(
        (a) => professoresB.any((b) => b.id != a.id),
      );
      if (!temProfessoresDiferentes) {
        falhas.add(
          'Aula geminada de $nomeA e $nomeB precisa de dois professores diferentes.',
        );
        continue;
      }

      final restanteA =
          (cargaPorMateria[par.idMateriaA] ?? 0) - jaAlocado(par.idMateriaA);
      final restanteB =
          (cargaPorMateria[par.idMateriaB] ?? 0) - jaAlocado(par.idMateriaB);
      final limiteCarga = restanteA < restanteB ? restanteA : restanteB;
      var restante = par.quantidadePeriodos < limiteCarga
          ? par.quantidadePeriodos
          : limiteCarga;
      if (restante < 0) restante = 0;
      final excedente = par.quantidadePeriodos - restante;
      if (excedente > 0) {
        falhas.add(
          'Aula geminada de $nomeA e $nomeB pede ${par.quantidadePeriodos} '
          'aula(s), mas a carga só comporta $restante.',
        );
      }

      // Divide as aulas do par em blocos de aulas seguidas
      // (ex.: 8 aulas em 2 blocos = 2 conjuntos de 4).
      var faltando = 0;
      for (final tamanho in dividirEmBlocos(restante, par.quantidadeBlocos)) {
        if (!_tentarColocarBlocoPar(
          curso: curso,
          idMateriaA: par.idMateriaA,
          idMateriaB: par.idMateriaB,
          tamanhoBloco: tamanho,
          professoresA: professoresA,
          professoresB: professoresB,
          indisponibilidades: indisponibilidades,
          trabalhando: trabalhando,
          novasAulas: novasAulas,
        )) {
          faltando += tamanho;
        }
      }
      if (faltando > 0) {
        falhas.add(
          'Não coube aula geminada de $nomeA e $nomeB '
          '($faltando aula(s) faltando).',
        );
      }
    }
  }

  /// Coloca um bloco de aulas seguidas do par: G1 numa matéria e G2 na outra,
  /// com os mesmos dois professores durante todo o bloco.
  bool _tentarColocarBlocoPar({
    required Curso curso,
    required String idMateriaA,
    required String idMateriaB,
    required int tamanhoBloco,
    required List<Professor> professoresA,
    required List<Professor> professoresB,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Aula> trabalhando,
    required List<Aula> novasAulas,
  }) {
    // 1ª tentativa: blocos do par em dias diferentes; 2ª: aceita repetir o dia.
    for (final permitirMesmoDia in const [false, true]) {
      for (final faixaPeriodos in _fasesPeriodo(curso.preferenciaPeriodo)) {
        for (var dia = 0; dia < GradeHoraria.dias.length; dia++) {
          for (final periodoInicio in _periodosInicio(
            faixaPeriodos,
            tamanhoBloco,
          )) {
            for (final professorA in professoresA) {
              for (final professorB in professoresB) {
                if (professorA.id == professorB.id) continue;
                if (!_blocoParCabe(
                  idCurso: curso.id,
                  idMateriaA: idMateriaA,
                  idMateriaB: idMateriaB,
                  idProfessorA: professorA.id,
                  idProfessorB: professorB.id,
                  dia: dia,
                  periodoInicio: periodoInicio,
                  tamanhoBloco: tamanhoBloco,
                  idSala: curso.idSala,
                  indisponibilidades: indisponibilidades,
                  trabalhando: trabalhando,
                  permitirMesmoDia: permitirMesmoDia,
                )) {
                  continue;
                }
                for (var d = 0; d < tamanhoBloco; d++) {
                  _registrarAula(
                    idCurso: curso.id,
                    idMateria: idMateriaA,
                    idProfessor: professorA.id,
                    dia: dia,
                    periodo: periodoInicio + d,
                    idSala: curso.idSala,
                    grupo: 1,
                    trabalhando: trabalhando,
                    novasAulas: novasAulas,
                  );
                  _registrarAula(
                    idCurso: curso.id,
                    idMateria: idMateriaB,
                    idProfessor: professorB.id,
                    dia: dia,
                    periodo: periodoInicio + d,
                    idSala: curso.idSala,
                    grupo: 2,
                    trabalhando: trabalhando,
                    novasAulas: novasAulas,
                  );
                }
                return true;
              }
            }
          }
        }
      }
    }
    return false;
  }

  bool _blocoParCabe({
    required String idCurso,
    required String idMateriaA,
    required String idMateriaB,
    required String idProfessorA,
    required String idProfessorB,
    required int dia,
    required int periodoInicio,
    required int tamanhoBloco,
    required String? idSala,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Aula> trabalhando,
    bool permitirMesmoDia = false,
  }) {
    if (!permitirMesmoDia &&
        trabalhando.any(
          (a) =>
              a.idCurso == idCurso &&
              (a.idMateria == idMateriaA || a.idMateria == idMateriaB) &&
              a.indiceDia == dia,
        )) {
      return false;
    }

    for (var d = 0; d < tamanhoBloco; d++) {
      final periodo = periodoInicio + d;
      if (!GradeHoraria.periodosNaMesmaFaixa(periodoInicio, periodo)) {
        return false;
      }
      if (trabalhando.any(
        (a) =>
            a.idCurso == idCurso &&
            a.indiceDia == dia &&
            a.indicePeriodo == periodo,
      )) {
        return false;
      }

      final celula = CelulaGrade(indiceDia: dia, indicePeriodo: periodo);
      for (final idProfessor in [idProfessorA, idProfessorB]) {
        if (trabalhando.any(
          (a) =>
              a.idProfessor == idProfessor &&
              a.indiceDia == dia &&
              a.indicePeriodo == periodo,
        )) {
          return false;
        }
        if (_estaIndisponivel(indisponibilidades, idProfessor, celula)) {
          return false;
        }
      }

      if (idSala != null &&
          trabalhando.any(
            (a) =>
                a.idCurso != idCurso &&
                a.idSala == idSala &&
                a.indiceDia == dia &&
                a.indicePeriodo == periodo,
          )) {
        return false;
      }
    }
    return true;
  }

  void _registrarAula({
    required String idCurso,
    required String idMateria,
    required String idProfessor,
    required int dia,
    required int periodo,
    required String? idSala,
    required int grupo,
    required List<Aula> trabalhando,
    required List<Aula> novasAulas,
  }) {
    final aula = Aula(
      id: 'pending',
      idCurso: idCurso,
      indiceDia: dia,
      indicePeriodo: periodo,
      idMateria: idMateria,
      idProfessor: idProfessor,
      idSala: idSala,
      grupo: grupo,
    );
    trabalhando.add(aula);
    novasAulas.add(aula);
  }

  bool _tentarColocarBloco({
    required String idCurso,
    required String idMateria,
    required int dia,
    required int periodoInicio,
    required int tamanhoBloco,
    required String? idSala,
    required List<Professor> professoresMateria,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Aula> trabalhando,
    required List<Aula> novasAulas,
    bool permitirMesmoDia = false,
  }) {
    Professor? escolhido;
    for (final professor in professoresMateria) {
      if (_blocoCabe(
        idCurso: idCurso,
        idProfessor: professor.id,
        idMateria: idMateria,
        dia: dia,
        periodoInicio: periodoInicio,
        tamanhoBloco: tamanhoBloco,
        idSala: idSala,
        indisponibilidades: indisponibilidades,
        trabalhando: trabalhando,
        permitirMesmoDia: permitirMesmoDia,
      )) {
        escolhido = professor;
        break;
      }
    }
    if (escolhido == null) return false;

    for (var deslocamento = 0; deslocamento < tamanhoBloco; deslocamento++) {
      final aula = Aula(
        id: 'pending',
        idCurso: idCurso,
        indiceDia: dia,
        indicePeriodo: periodoInicio + deslocamento,
        idMateria: idMateria,
        idProfessor: escolhido.id,
        idSala: idSala,
      );
      trabalhando.add(aula);
      novasAulas.add(aula);
    }
    return true;
  }

  bool _blocoCabe({
    required String idCurso,
    required String idProfessor,
    required String idMateria,
    required int dia,
    required int periodoInicio,
    required int tamanhoBloco,
    required String? idSala,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Aula> trabalhando,
    bool permitirMesmoDia = false,
  }) {
    // Preferência: um bloco da mesma matéria por dia; só repete o dia
    // quando [permitirMesmoDia] (carga maior que 5 blocos).
    if (!permitirMesmoDia &&
        trabalhando.any(
          (a) =>
              a.idCurso == idCurso &&
              a.idMateria == idMateria &&
              a.indiceDia == dia,
        )) {
      return false;
    }

    for (var deslocamento = 0; deslocamento < tamanhoBloco; deslocamento++) {
      final periodo = periodoInicio + deslocamento;
      if (!GradeHoraria.periodosNaMesmaFaixa(periodoInicio, periodo)) {
        return false;
      }

      final celula = CelulaGrade(indiceDia: dia, indicePeriodo: periodo);

      if (trabalhando.any(
        (a) =>
            a.idCurso == idCurso &&
            a.indiceDia == dia &&
            a.indicePeriodo == periodo,
      )) {
        return false;
      }

      if (trabalhando.any(
        (a) =>
            a.idProfessor == idProfessor &&
            a.indiceDia == dia &&
            a.indicePeriodo == periodo,
      )) {
        return false;
      }

      // Conflito de sala só com outra turma (grupos da mesma turma podem dividir).
      if (idSala != null &&
          trabalhando.any(
            (a) =>
                a.idCurso != idCurso &&
                a.idSala == idSala &&
                a.indiceDia == dia &&
                a.indicePeriodo == periodo,
          )) {
        return false;
      }

      if (_estaIndisponivel(indisponibilidades, idProfessor, celula)) {
        return false;
      }
    }
    return true;
  }

  bool _estaIndisponivel(
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
}
