import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';

// Regras para a Página 1 acompanhar o que se faz na grade da Página 3:
// criar ou excluir uma aula muda a carga do curso e, se for aula geminada,
// o par. Funções puras: recebem o cadastro atual do curso e devolvem o novo.

/// Carga e pares de aula geminada de um curso.
class CadastroCurso {
  const CadastroCurso({required this.cargas, required this.pares});

  final List<CargaCursoMateria> cargas;
  final List<AulaGeminadaCurso> pares;

  CargaCursoMateria? cargaDe(String idMateria) =>
      cargas.where((c) => c.idMateria == idMateria).firstOrNull;

  AulaGeminadaCurso? parDe(String idMateria1, String idMateria2) => pares
      .where((p) => p.formaPar(idMateria1, idMateria2))
      .firstOrNull;
}

CargaCursoMateria _comQuantidade(CargaCursoMateria c, int quantidade) =>
    CargaCursoMateria(
      idCurso: c.idCurso,
      idMateria: c.idMateria,
      quantidadeAulas: quantidade,
      // Bloco não pode passar da carga.
      tamanhoBloco: c.tamanhoBloco > quantidade ? quantidade : c.tamanhoBloco,
    );

List<AulaGeminadaCurso> _trocarPar(
  List<AulaGeminadaCurso> pares,
  AulaGeminadaCurso antigo,
  AulaGeminadaCurso? novo,
) => [
  for (final p in pares)
    if (p.chave != antigo.chave) p else ?novo,
];

/// Cadastro depois de criar [nova] na grade.
///
/// * Carga: matéria fora da carga entra com 1; carga já completa sobe 1;
///   se ainda faltava aula, não muda.
/// * Par (quando [naCelula] já tem uma aula e [nova] é o outro grupo): se as
///   duas matérias ainda não formam par, cria o par com 1 aula de cada em
///   1 bloco. Se já formam, a matéria nova soma 1, e a que já estava no
///   horário soma 1 se era aula completa (grupo 1 sozinha) — se era o
///   grupo 2 com o G1 livre, ela já fazia parte do par.
///
/// [aulasDoCurso] e [naCelula] são de antes de criar (sem [nova]).
CadastroCurso cadastroAoCriar(
  CadastroCurso atual, {
  required Aula nova,
  required List<Aula> aulasDoCurso,
  required List<Aula> naCelula,
}) {
  final idMateria = nova.idMateria;
  var cargas = List<CargaCursoMateria>.from(atual.cargas);
  final carga = atual.cargaDe(idMateria);
  final agendadas = aulasDoCurso.where((a) => a.idMateria == idMateria).length;
  if (carga == null) {
    cargas.add(
      CargaCursoMateria(
        idCurso: nova.idCurso,
        idMateria: idMateria,
        quantidadeAulas: 1,
      ),
    );
  } else if (agendadas >= carga.quantidadeAulas) {
    cargas = [
      for (final c in cargas)
        if (c.idMateria == idMateria)
          _comQuantidade(c, c.quantidadeAulas + 1)
        else
          c,
    ];
  }

  var pares = List<AulaGeminadaCurso>.from(atual.pares);
  if (naCelula.length == 1 && naCelula.single.idMateria != idMateria) {
    final outra = naCelula.single;
    final par = atual.parDe(outra.idMateria, idMateria);
    if (par == null) {
      pares.add(
        AulaGeminadaCurso(
          idCurso: nova.idCurso,
          idMateriaA: outra.idMateria,
          idMateriaB: idMateria,
          quantidadePeriodos: 1,
          quantidadePeriodosB: 1,
          quantidadeBlocos: 1,
        ),
      );
    } else {
      final outraJaNoPar = outra.grupo == 2;
      final atualizado = par
          .comQuantidade(idMateria, par.quantidadeDe(idMateria) + 1)
          .comQuantidade(
            outra.idMateria,
            par.quantidadeDe(outra.idMateria) + (outraJaNoPar ? 0 : 1),
          );
      pares = _trocarPar(pares, par, atualizado);
    }
  }

  return CadastroCurso(cargas: cargas, pares: pares);
}

/// Cadastro depois de excluir [excluida] da grade.
///
/// * Carga: desce 1; chegando a 0 a matéria sai da carga (e dos pares do
///   curso, que só valem para matérias da carga).
/// * Par: se a aula fazia parte de um par (os dois grupos juntos, ou o
///   grupo 2 com o G1 livre), a quantidade dela no par desce 1; chegando a
///   0, o par deixa de existir.
///
/// [naCelula] é de antes de excluir (com [excluida]).
CadastroCurso cadastroAoExcluir(
  CadastroCurso atual, {
  required Aula excluida,
  required List<Aula> naCelula,
}) {
  final idMateria = excluida.idMateria;
  var cargas = List<CargaCursoMateria>.from(atual.cargas);
  var pares = List<AulaGeminadaCurso>.from(atual.pares);

  final carga = atual.cargaDe(idMateria);
  if (carga != null) {
    if (carga.quantidadeAulas <= 1) {
      cargas.removeWhere((c) => c.idMateria == idMateria);
      pares.removeWhere((p) => p.contemMateria(idMateria));
      return CadastroCurso(cargas: cargas, pares: pares);
    }
    cargas = [
      for (final c in cargas)
        if (c.idMateria == idMateria)
          _comQuantidade(c, c.quantidadeAulas - 1)
        else
          c,
    ];
  }

  AulaGeminadaCurso? par;
  final outras = naCelula.where((a) => a.id != excluida.id).toList();
  if (outras.length == 1) {
    par = atual.parDe(idMateria, outras.single.idMateria);
  } else if (outras.isEmpty && excluida.grupo == 2) {
    // Grupo 2 com o G1 livre: de preferência o par em que ela é a maior.
    final candidatos = pares.where((p) => p.contemMateria(idMateria));
    par =
        candidatos.where((p) => p.idMateriaMaior == idMateria).firstOrNull ??
        candidatos.firstOrNull;
  }
  if (par != null) {
    final restante = par.quantidadeDe(idMateria) - 1;
    pares = _trocarPar(
      pares,
      par,
      restante < 1 ? null : par.comQuantidade(idMateria, restante),
    );
  }

  return CadastroCurso(cargas: cargas, pares: pares);
}
