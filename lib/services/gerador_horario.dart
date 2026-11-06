import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';

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

    // Curso ainda sem carga (ex.: acabou de ser criado): não há o que
    // gerar e não é falha; a Página 3 já mostra "Sem carga definida".
    if (cargasCurso.isEmpty) {
      return const ResultadoGeracao(
        novasAulas: [],
        totalAlocado: 0,
        totalNecessario: 0,
        falhas: [],
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
        nomesMaterias[idMateria] ?? 'componente $idMateria';

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

      // Bloco não passa do tamanho do turno (noite: 4), mesmo se a carga
      // foi salva com um bloco maior.
      final limiteBloco = curso.preferenciaPeriodo.maxAulasPorBloco;
      final blocos = _blocosPara(
        restante,
        carga.tamanhoBloco > limiteBloco ? limiteBloco : carga.tamanhoBloco,
      );
      final fasesPeriodo = _fasesPeriodo(curso.preferenciaPeriodo);

      // Bloco que não cabe em lugar nenhum é dividido em blocos menores
      // (ex.: 4 → 2 + 2) antes de desistir; avisa quantas aulas ficaram
      // assim, porque o bloco pedido na Página 1 não foi respeitado.
      final fila = [for (final b in blocos) (tamanho: b, dividido: false)];
      var emBlocosMenores = 0;
      while (fila.isNotEmpty) {
        final (tamanho: tamanhoBloco, dividido: dividido) = fila.removeAt(0);
        // Prefere o professor que já dá este componente para a turma, para
        // não trocar de professor a cada bloco.
        final preferidos = _professoresJaUsados(
          trabalhando,
          idCurso,
          carga.idMateria,
          professoresMateria,
        );
        final alocado = _colocarBlocoComum(
          idCurso: idCurso,
          idMateria: carga.idMateria,
          tamanhoBloco: tamanhoBloco,
          idSala: curso.idSala,
          fasesPeriodo: fasesPeriodo,
          listasProfessores: [
            if (preferidos.isNotEmpty &&
                preferidos.length < professoresMateria.length)
              preferidos,
            professoresMateria,
          ],
          indisponibilidades: indisponibilidades,
          trabalhando: trabalhando,
          novasAulas: novasAulas,
        );
        if (alocado) {
          restante -= tamanhoBloco;
          if (dividido) emBlocosMenores += tamanhoBloco;
        } else if (tamanhoBloco > 1) {
          final metade = (tamanhoBloco + 1) ~/ 2;
          fila.insertAll(0, [
            (tamanho: metade, dividido: true),
            (tamanho: tamanhoBloco - metade, dividido: true),
          ]);
        }
      }
      if (emBlocosMenores > 0) {
        falhas.add(
          '${rotulo(carga.idMateria)}: $emBlocosMenores aula(s) ficaram em '
          'blocos menores que ${blocos.first} (o bloco inteiro não coube).',
        );
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

  List<List<int>> _fasesPeriodo(PreferenciaPeriodo preferencia) =>
      preferencia.turnos;

  Iterable<int> _periodosInicio(
    List<int> faixaPeriodos,
    int tamanhoBloco,
  ) sync* {
    for (var i = 0; i <= faixaPeriodos.length - tamanhoBloco; i++) {
      yield faixaPeriodos[i];
    }
  }

  /// Professores (da lista [candidatos]) que já dão [idMateria] para a turma.
  List<Professor> _professoresJaUsados(
    List<Aula> trabalhando,
    String idCurso,
    String idMateria,
    List<Professor> candidatos,
  ) {
    final ids = {
      for (final a in trabalhando)
        if (a.idCurso == idCurso && a.idMateria == idMateria) a.idProfessor,
    };
    return candidatos.where((p) => ids.contains(p.id)).toList();
  }

  /// Procura lugar para um bloco de aula comum (turma inteira).
  ///
  /// Ordem de preferência: um bloco do componente por dia; depois, cada
  /// lista de [listasProfessores] (a 1ª é a dos professores preferidos);
  /// só então aceita repetir o dia.
  bool _colocarBlocoComum({
    required String idCurso,
    required String idMateria,
    required int tamanhoBloco,
    required String? idSala,
    required List<List<int>> fasesPeriodo,
    required List<List<Professor>> listasProfessores,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Aula> trabalhando,
    required List<Aula> novasAulas,
  }) {
    for (final permitirMesmoDia in const [false, true]) {
      for (final professoresMateria in listasProfessores) {
        for (final faixaPeriodos in fasesPeriodo) {
          for (var dia = 0; dia < GradeHoraria.dias.length; dia++) {
            for (final periodoInicio in _periodosInicio(
              faixaPeriodos,
              tamanhoBloco,
            )) {
              if (_tentarColocarBloco(
                idCurso: idCurso,
                idMateria: idMateria,
                dia: dia,
                periodoInicio: periodoInicio,
                tamanhoBloco: tamanhoBloco,
                idSala: idSala,
                professoresMateria: professoresMateria,
                indisponibilidades: indisponibilidades,
                trabalhando: trabalhando,
                novasAulas: novasAulas,
                permitirMesmoDia: permitirMesmoDia,
              )) {
                return true;
              }
            }
          }
        }
      }
    }
    return false;
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
          'Aula dividida de $nomeA e $nomeB: falta professor em um dos componentes.',
        );
        continue;
      }
      final temProfessoresDiferentes = professoresA.any(
        (a) => professoresB.any((b) => b.id != a.id),
      );
      if (!temProfessoresDiferentes) {
        falhas.add(
          'Aula dividida de $nomeA e $nomeB precisa de dois professores diferentes.',
        );
        continue;
      }

      // Cada matéria fica limitada pela própria carga ainda livre.
      int caber(String idMateria) {
        final pedido = par.quantidadeDe(idMateria);
        final livre =
            (cargaPorMateria[idMateria] ?? 0) - jaAlocado(idMateria);
        final nome = rotulo(idMateria);
        if (livre < pedido) {
          falhas.add(
            'Aula dividida de $nomeA e $nomeB pede $pedido aula(s) de '
            '$nome, mas a carga só comporta ${livre < 0 ? 0 : livre}.',
          );
        }
        return livre < 0 ? 0 : (livre < pedido ? livre : pedido);
      }

      final cabeA = caber(par.idMateriaA);
      final cabeB = caber(par.idMateriaB);
      if (cabeA == 0 || cabeB == 0) continue;
      // Nenhum bloco pode passar do tamanho do turno da turma (noite: 4).
      // Par antigo com bloco maior é dividido em mais blocos.
      final limite = curso.preferenciaPeriodo.maxAulasPorBloco;
      final ocupados = cabeA > cabeB ? cabeA : cabeB;
      final blocosMinimos = (ocupados + limite - 1) ~/ limite;
      final cabe = AulaGeminadaCurso(
        idCurso: curso.id,
        idMateriaA: par.idMateriaA,
        idMateriaB: par.idMateriaB,
        quantidadePeriodos: cabeA,
        quantidadePeriodosB: cabeB,
        quantidadeBlocos: par.quantidadeBlocos < blocosMinimos
            ? blocosMinimos
            : par.quantidadeBlocos,
      );

      // G1 = matéria de menos aulas; G2 = a de mais aulas (fica sozinha
      // nos horários em que o G1 está livre).
      final idG1 = cabe.idMateriaMenor;
      final idG2 = cabe.idMateriaMaior;
      final professoresG1 = idG1 == par.idMateriaA ? professoresA : professoresB;
      final professoresG2 = idG2 == par.idMateriaA ? professoresA : professoresB;

      // Divide o par em blocos de aulas seguidas
      // (ex.: 8 aulas em 2 blocos = 2 conjuntos de 4).
      var faltando = 0;
      final tamanhos = cabe.tamanhosBlocos;
      final juntas = cabe.juntasPorBloco;
      for (var i = 0; i < tamanhos.length; i++) {
        bool tentar(List<Professor> g1, List<Professor> g2) =>
            _tentarColocarBlocoPar(
              curso: curso,
              idMateriaG1: idG1,
              idMateriaG2: idG2,
              tamanhoBloco: tamanhos[i],
              juntasNoBloco: juntas[i],
              professoresG1: g1,
              professoresG2: g2,
              indisponibilidades: indisponibilidades,
              trabalhando: trabalhando,
              novasAulas: novasAulas,
            );
        // Depois do 1º bloco, tenta antes com os mesmos professores.
        final usadosG1 = _professoresJaUsados(
          trabalhando,
          curso.id,
          idG1,
          professoresG1,
        );
        final usadosG2 = _professoresJaUsados(
          trabalhando,
          curso.id,
          idG2,
          professoresG2,
        );
        final temPreferencia =
            (usadosG1.isNotEmpty || usadosG2.isNotEmpty) &&
            (usadosG1.length < professoresG1.length ||
                usadosG2.length < professoresG2.length);
        final colocou =
            (temPreferencia &&
                tentar(
                  usadosG1.isEmpty ? professoresG1 : usadosG1,
                  usadosG2.isEmpty ? professoresG2 : usadosG2,
                )) ||
            tentar(professoresG1, professoresG2);
        if (!colocou) faltando += tamanhos[i];
      }
      if (faltando > 0) {
        // As aulas que não couberam juntas entram depois como aulas comuns
        // (turma inteira), se ainda houver espaço; o que nem assim couber
        // aparece como "Faltam".
        falhas.add(
          'Não coube aula dividida de $nomeA e $nomeB em $faltando '
          'horário(s); essas aulas serão tentadas como aulas comuns.',
        );
      }
    }
  }

  /// Coloca um bloco de aulas seguidas do par, com os mesmos dois professores
  /// durante todo o bloco: nos [juntasNoBloco] primeiros horários G1 tem uma
  /// matéria e G2 a outra; no resto só o G2 tem aula (G1 livre).
  bool _tentarColocarBlocoPar({
    required Curso curso,
    required String idMateriaG1,
    required String idMateriaG2,
    required int tamanhoBloco,
    required int juntasNoBloco,
    required List<Professor> professoresG1,
    required List<Professor> professoresG2,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Aula> trabalhando,
    required List<Aula> novasAulas,
  }) {
    // Bloco só com o G2 (sem horário junto): não precisa de professor do G1.
    final opcoesG1 = juntasNoBloco == 0 ? <Professor?>[null] : professoresG1;
    // 1ª tentativa: blocos do par em dias diferentes; 2ª: aceita repetir o dia.
    for (final permitirMesmoDia in const [false, true]) {
      for (final faixaPeriodos in _fasesPeriodo(curso.preferenciaPeriodo)) {
        for (var dia = 0; dia < GradeHoraria.dias.length; dia++) {
          for (final periodoInicio in _periodosInicio(
            faixaPeriodos,
            tamanhoBloco,
          )) {
            for (final professorG1 in opcoesG1) {
              for (final professorG2 in professoresG2) {
                if (professorG1?.id == professorG2.id) continue;
                if (!_blocoParCabe(
                  idCurso: curso.id,
                  idMateriaG1: idMateriaG1,
                  idMateriaG2: idMateriaG2,
                  idProfessorG1: professorG1?.id,
                  idProfessorG2: professorG2.id,
                  dia: dia,
                  periodoInicio: periodoInicio,
                  tamanhoBloco: tamanhoBloco,
                  juntasNoBloco: juntasNoBloco,
                  idSala: curso.idSala,
                  indisponibilidades: indisponibilidades,
                  trabalhando: trabalhando,
                  permitirMesmoDia: permitirMesmoDia,
                )) {
                  continue;
                }
                for (var d = 0; d < tamanhoBloco; d++) {
                  if (d < juntasNoBloco) {
                    _registrarAula(
                      idCurso: curso.id,
                      idMateria: idMateriaG1,
                      idProfessor: professorG1!.id,
                      dia: dia,
                      periodo: periodoInicio + d,
                      idSala: curso.idSala,
                      grupo: 1,
                      trabalhando: trabalhando,
                      novasAulas: novasAulas,
                    );
                  }
                  _registrarAula(
                    idCurso: curso.id,
                    idMateria: idMateriaG2,
                    idProfessor: professorG2.id,
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
    required String idMateriaG1,
    required String idMateriaG2,
    required String? idProfessorG1,
    required String idProfessorG2,
    required int dia,
    required int periodoInicio,
    required int tamanhoBloco,
    required int juntasNoBloco,
    required String? idSala,
    required List<IndisponibilidadeProfessor> indisponibilidades,
    required List<Aula> trabalhando,
    bool permitirMesmoDia = false,
  }) {
    if (!permitirMesmoDia &&
        trabalhando.any(
          (a) =>
              a.idCurso == idCurso &&
              (a.idMateria == idMateriaG1 || a.idMateria == idMateriaG2) &&
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
      // O professor do G1 só dá aula nos horários juntos; depois fica livre.
      final professores = [
        idProfessorG2,
        if (d < juntasNoBloco && idProfessorG1 != null) idProfessorG1,
      ];
      for (final idProfessor in professores) {
        if (trabalhando.any(
          (a) =>
              a.idProfessor == idProfessor &&
              a.indiceDia == dia &&
              a.indicePeriodo == periodo,
        )) {
          return false;
        }
        if (estaIndisponivel(indisponibilidades, idProfessor, celula)) {
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

      if (estaIndisponivel(indisponibilidades, idProfessor, celula)) {
        return false;
      }
    }
    return true;
  }
}
