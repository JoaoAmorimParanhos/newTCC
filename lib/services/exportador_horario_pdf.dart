import 'dart:typed_data';

import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
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

  static const double _alturaCabecalho = 18;
  static const double _alturaAlmoco = 16;
  static const double _alturaLinha = 34;
  static const double _larguraRotulo = 42;
  static const _corBorda = PdfColors.grey600;
  static const double _espessuraBorda = 0.5;

  Future<Uint8List> gerar({
    required List<Curso> cursos,
    required List<Aula> aulas,
    required List<Materia> materias,
    required List<Professor> professores,
    required List<Sala> salas,
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
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                curso.nome,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (salaPadrao != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Sala padrão: ${salaPadrao.rotulo}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
              pw.SizedBox(height: 12),
              _grade(
                porCelula: porCelula,
                mapaMaterias: mapaMaterias,
                mapaProfessores: mapaProfessores,
              ),
            ],
          ),
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
  pw.Widget _grade({
    required Map<CelulaGrade, List<Aula>> porCelula,
    required Map<String, String> mapaMaterias,
    required Map<String, String> mapaProfessores,
  }) {
    final manha = [
      for (var p = 0; p < GradeHoraria.quantidadePeriodosManha; p++) p,
    ];
    final tarde = [
      for (var p = GradeHoraria.inicioTarde; p < GradeHoraria.periodos.length; p++)
        p,
    ];

    List<pw.Widget> turno(int dia, List<int> periodos) => [
      for (final segmento in agruparAulasSeguidas([
        for (final p in periodos)
          porCelula[CelulaGrade(indiceDia: dia, indicePeriodo: p)] ?? const [],
      ]))
        _celula(
          altura: _alturaLinha * segmento.tamanho,
          child: _conteudoAulas(
            segmento.aulas,
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
                for (final p in manha)
                  _celula(
                    altura: _alturaLinha,
                    child: _texto(GradeHoraria.periodos[p], negrito: true),
                  ),
                _celula(
                  altura: _alturaAlmoco,
                  cor: PdfColors.grey200,
                  child: _texto('Almoço', negrito: true),
                ),
                for (final p in tarde)
                  _celula(
                    altura: _alturaLinha,
                    child: _texto(GradeHoraria.periodos[p], negrito: true),
                  ),
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
                  ...turno(dia, manha),
                  _celula(
                    altura: _alturaAlmoco,
                    cor: PdfColors.grey200,
                    child: pw.SizedBox(),
                  ),
                  ...turno(dia, tarde),
                ],
              ),
            ),
        ],
      ),
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
    required Map<String, String> mapaMaterias,
    required Map<String, String> mapaProfessores,
  }) {
    if (aulas.isEmpty) return pw.SizedBox();

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
              maxLines: 2,
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

    if (aulas.length == 1) return umaAula(aulas.single, comGrupo: false);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < aulas.length; i++) ...[
          if (i > 0)
            pw.Container(width: _espessuraBorda, color: PdfColors.grey400),
          pw.Expanded(child: umaAula(aulas[i], comGrupo: true)),
        ],
      ],
    );
  }
}
