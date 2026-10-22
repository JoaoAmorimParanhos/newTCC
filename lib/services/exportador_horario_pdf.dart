import 'dart:typed_data';

import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Trecho de um turno de um dia no PDF: [tamanho] horários seguidos a partir
/// de [inicio] (posição dentro do turno) com as mesmas [aulas].
class SegmentoGrade {
  const SegmentoGrade({
    required this.inicio,
    required this.tamanho,
    required this.aulas,
  });

  final int inicio;
  final int tamanho;

  /// Aulas do primeiro horário do trecho (vazio = horário sem aula).
  final List<Aula> aulas;
}

/// Junta horários seguidos com exatamente as mesmas aulas (matéria,
/// professor, sala e grupo) num só trecho. Horários vazios ficam separados.
///
/// [celulas] são as aulas de cada horário de um turno de um dia, em ordem.
List<SegmentoGrade> agruparAulasSeguidas(List<List<Aula>> celulas) {
  String assinatura(List<Aula> aulas) {
    final partes = [
      for (final a in aulas)
        '${a.grupo}|${a.idMateria}|${a.idProfessor}|${a.idSala}',
    ]..sort();
    return partes.join(';');
  }

  final segmentos = <SegmentoGrade>[];
  var i = 0;
  while (i < celulas.length) {
    final atual = celulas[i];
    var tamanho = 1;
    if (atual.isNotEmpty) {
      final chave = assinatura(atual);
      while (i + tamanho < celulas.length &&
          celulas[i + tamanho].isNotEmpty &&
          assinatura(celulas[i + tamanho]) == chave) {
        tamanho++;
      }
    }
    segmentos.add(SegmentoGrade(inicio: i, tamanho: tamanho, aulas: atual));
    i += tamanho;
  }
  return segmentos;
}

/// Gera PDF paisagem: uma página por turma (incluindo grades vazias).
class ExportadorHorarioPdf {
  const ExportadorHorarioPdf();

  static const double _margem = 24;
  static const double _alturaTitulo = 24;
  static const double _alturaSalaPadrao = 18;
  static const double _espacoAntesDaGrade = 12;
  static const double _folga = 6;
  static const double _alturaCabecalho = 18;
  static const double _alturaAlmoco = 14;
  static const double _alturaLinha = 34;
  static const double _larguraRotulo = 56;
  static const _corBorda = PdfColors.grey600;
  static const double _espessuraBorda = 0.5;

  Future<Uint8List> gerar({
    required List<Curso> cursos,
    required List<Aula> aulas,
    required List<Materia> materias,
    required List<Professor> professores,
    required List<Sala> salas,
    Map<int, String> horarios = const {},
  }) async {
    final doc = pw.Document();
    final mapaMaterias = {for (final m in materias) m.id: m.nome};
    final mapaProfessores = {for (final p in professores) p.id: p.nome};
    final mapaSalas = {for (final s in salas) s.id: s};

    final listaCursos = List<Curso>.from(cursos)
      ..sort((a, b) => a.nome.compareTo(b.nome));

    for (final curso in listaCursos) {
      final porCelula = <CelulaGrade, List<Aula>>{};
      for (final a in aulas.where((a) => a.idCurso == curso.id)) {
        porCelula.putIfAbsent(a.celula, () => []).add(a);
      }
      for (final lista in porCelula.values) {
        lista.sort((a, b) => a.grupo.compareTo(b.grupo));
      }
      final salaPadrao = curso.idSala == null ? null : mapaSalas[curso.idSala!];

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(_margem),
          build: (context) {
            final turnos = turnosDoCurso(curso, porCelula);
            final alturaLinha = alturaLinhaParaCaber(
              quantidadeLinhas: turnos.fold(0, (s, t) => s + t.length),
              quantidadeSeparadores: turnos.length - 1,
              comSalaPadrao: salaPadrao != null,
            );
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Alturas fixas: entram na conta de [alturaLinhaParaCaber].
                pw.SizedBox(
                  height: _alturaTitulo,
                  child: pw.Text(
                    curso.nome,
                    maxLines: 1,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (salaPadrao != null)
                  pw.SizedBox(
                    height: _alturaSalaPadrao,
                    child: pw.Text(
                      'Sala padrão: ${salaPadrao.rotulo}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                pw.SizedBox(height: _espacoAntesDaGrade),
                _grade(
                  turnos: turnos,
                  alturaLinha: alturaLinha,
                  porCelula: porCelula,
                  mapaMaterias: mapaMaterias,
                  mapaProfessores: mapaProfessores,
                  horarios: horarios,
                ),
              ],
            );
          },
        ),
      );
    }

    if (listaCursos.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) => pw.Center(
            child: pw.Text('Nenhum curso cadastrado.'),
          ),
        ),
      );
    }

    return doc.save();
  }

  /// Grade montada em colunas (uma por dia) para que aulas seguidas iguais
  /// ocupem várias linhas sem mudar o tamanho da grade.
  /// Turnos impressos: os da turma (noturna: noite; as outras: manhã e
  /// tarde) e, além deles, qualquer turno que tenha aula, para nenhuma aula
  /// ficar de fora. Ex.: turma diurna com aula à noite imprime o Jantar e a
  /// noite; sem aula à noite, não imprime.
  static List<List<int>> turnosDoCurso(
    Curso curso,
    Map<CelulaGrade, List<Aula>> porCelula,
  ) {
    final noturna = curso.preferenciaPeriodo == PreferenciaPeriodo.noite;
    bool temAula(int faixa) => porCelula.entries.any(
      (e) =>
          e.value.isNotEmpty &&
          GradeHoraria.faixaDoPeriodo(e.key.indicePeriodo) == faixa,
    );
    return [
      if (!noturna || temAula(0)) GradeHoraria.periodosManha,
      if (!noturna || temAula(1)) GradeHoraria.periodosTarde,
      if (noturna || temAula(2)) GradeHoraria.periodosNoite,
    ];
  }

  /// Altura de cada linha de período para a grade caber numa página A4
  /// deitada: o que sobra depois do título, cabeçalho e separadores,
  /// dividido pelos períodos (no máximo [_alturaLinha]).
  static double alturaLinhaParaCaber({
    required int quantidadeLinhas,
    required int quantidadeSeparadores,
    required bool comSalaPadrao,
  }) {
    final disponivel =
        PdfPageFormat.a4.landscape.height -
        2 * _margem -
        _alturaTitulo -
        (comSalaPadrao ? _alturaSalaPadrao : 0) -
        _espacoAntesDaGrade -
        _alturaCabecalho -
        quantidadeSeparadores * _alturaAlmoco -
        _folga;
    final altura = disponivel / quantidadeLinhas;
    return altura < _alturaLinha ? altura : _alturaLinha;
  }

  static String _separadorAntes(List<int> turno) =>
      GradeHoraria.faixaDoPeriodo(turno.first) == 2 ? 'Jantar' : 'Almoço';

  pw.Widget _grade({
    required List<List<int>> turnos,
    required double alturaLinha,
    required Map<CelulaGrade, List<Aula>> porCelula,
    required Map<String, String> mapaMaterias,
    required Map<String, String> mapaProfessores,
    required Map<int, String> horarios,
  }) {

    List<pw.Widget> turno(int dia, List<int> periodos) => [
      for (final segmento in agruparAulasSeguidas([
        for (final p in periodos)
          porCelula[CelulaGrade(indiceDia: dia, indicePeriodo: p)] ?? const [],
      ]))
        _celula(
          altura: alturaLinha * segmento.tamanho,
          child: _conteudoAulas(
            segmento.aulas,
            altura: alturaLinha * segmento.tamanho,
            mapaMaterias: mapaMaterias,
            mapaProfessores: mapaProfessores,
          ),
        ),
    ];

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: _corBorda, width: _espessuraBorda),
          top: pw.BorderSide(color: _corBorda, width: _espessuraBorda),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: _larguraRotulo,
            child: pw.Column(
              children: [
                _celula(
                  altura: _alturaCabecalho,
                  cor: PdfColors.grey300,
                  child: _texto('', negrito: true),
                ),
                for (var i = 0; i < turnos.length; i++) ...[
                  if (i > 0)
                    _celula(
                      altura: _alturaAlmoco,
                      cor: PdfColors.grey200,
                      child: _texto(_separadorAntes(turnos[i]), negrito: true),
                    ),
                  for (final p in turnos[i])
                    _celula(
                      altura: alturaLinha,
                      child: _rotuloPeriodo(p, horarios[p]),
                    ),
                ],
              ],
            ),
          ),
          for (var dia = 0; dia < GradeHoraria.dias.length; dia++)
            pw.Expanded(
              child: pw.Column(
                children: [
                  _celula(
                    altura: _alturaCabecalho,
                    cor: PdfColors.grey300,
                    child: _texto(GradeHoraria.dias[dia], negrito: true),
                  ),
                  for (var i = 0; i < turnos.length; i++) ...[
                    if (i > 0)
                      _celula(
                        altura: _alturaAlmoco,
                        cor: PdfColors.grey200,
                        child: pw.SizedBox(),
                      ),
                    ...turno(dia, turnos[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// "1º M" e, embaixo, o horário digitado na Página 3 (se houver).
  pw.Widget _rotuloPeriodo(int indicePeriodo, String? horario) {
    // A fonte padrão do PDF (Helvetica) não desenha travessões (– —).
    final texto = (horario ?? '').trim().replaceAll(RegExp('[–—]'), '-');
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _texto(GradeHoraria.periodos[indicePeriodo], negrito: true),
        if (texto.isNotEmpty)
          pw.Text(
            texto,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 6),
          ),
      ],
    );
  }

  /// Célula com borda à direita e embaixo (o contorno de fora fecha o resto).
  pw.Widget _celula({
    required double altura,
    required pw.Widget child,
    PdfColor? cor,
  }) {
    return pw.Container(
      height: altura,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: cor,
        border: const pw.Border(
          right: pw.BorderSide(color: _corBorda, width: _espessuraBorda),
          bottom: pw.BorderSide(color: _corBorda, width: _espessuraBorda),
        ),
      ),
      child: child,
    );
  }

  pw.Widget _texto(String texto, {bool negrito = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        texto,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: negrito ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Uma aula, ou os dois grupos de uma aula geminada lado a lado.
  pw.Widget _conteudoAulas(
    List<Aula> aulas, {
    required double altura,
    required Map<String, String> mapaMaterias,
    required Map<String, String> mapaProfessores,
  }) {
    if (aulas.isEmpty) return pw.SizedBox();
    // Com a grade inteira (16 períodos) a linha é baixa: nome da matéria
    // em 2 linhas só cabe quando o trecho ocupa mais de um horário.
    final linhasMateria = altura >= 30 ? 2 : 1;

    pw.Widget umaAula(Aula aula, {required bool comGrupo}) {
      final materia = mapaMaterias[aula.idMateria] ?? 'Matéria';
      return pw.Padding(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              comGrupo ? 'G${aula.grupo} $materia' : materia,
              textAlign: pw.TextAlign.center,
              maxLines: linhasMateria,
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              mapaProfessores[aula.idProfessor] ?? 'Professor',
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 6),
            ),
          ],
        ),
      );
    }

    // Turma dividida só com o grupo 2: o grupo 1 aparece como livre.
    final dividida = aulas.length == 1 && aulas.single.grupo == 2;
    if (aulas.length == 1 && !dividida) {
      return umaAula(aulas.single, comGrupo: false);
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (dividida) ...[
          pw.Expanded(
            child: pw.Text(
              'G1 livre',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
            ),
          ),
          pw.Container(width: _espessuraBorda, color: PdfColors.grey400),
        ],
        for (var i = 0; i < aulas.length; i++) ...[
          if (i > 0)
            pw.Container(width: _espessuraBorda, color: PdfColors.grey400),
          pw.Expanded(child: umaAula(aulas[i], comGrupo: true)),
        ],
      ],
    );
  }
}
