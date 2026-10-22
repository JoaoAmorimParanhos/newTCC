import 'package:flutter/material.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';
import 'package:flutter_test_project/theme/app_theme.dart';

class CelulaHorario extends StatelessWidget {
  const CelulaHorario({
    super.key,
    required this.celula,
    required this.aulas,
    required this.materias,
    required this.professores,
    required this.salasPorId,
    required this.ocupado,
    required this.aoTocar,
    this.aoSoltar,
    this.motivoParaNaoSoltar,
  });

  final CelulaGrade celula;
  final List<Aula> aulas;
  final Map<String, Materia> materias;
  final Map<String, Professor> professores;
  final Map<String, Sala> salasPorId;
  final bool ocupado;
  final VoidCallback? aoTocar;

  /// Chamado quando uma aula arrastada é solta nesta célula.
  final void Function(Aula aula)? aoSoltar;

  /// Motivo para recusar a aula nesta célula (null = pode soltar).
  /// Usado só para pintar a célula enquanto a aula passa por cima.
  final String? Function(Aula aula)? motivoParaNaoSoltar;

  @override
  Widget build(BuildContext context) {
    final ordenadas = List<Aula>.from(aulas)
      ..sort((a, b) => a.grupo.compareTo(b.grupo));
    // Turma dividida com só o grupo 2 tendo aula: mostra o G1 livre ao lado.
    final dividida = turmaDivididaComGrupoLivre(ordenadas);

    return DragTarget<Aula>(
      // Aceita sempre para poder explicar a recusa na mensagem.
      onWillAcceptWithDetails: (_) => !ocupado && aoSoltar != null,
      onAcceptWithDetails: (details) => aoSoltar?.call(details.data),
      builder: (context, candidatas, _) {
        final arrastando = candidatas.whereType<Aula>().firstOrNull;
        final destaque = arrastando == null
            ? null
            : (motivoParaNaoSoltar?.call(arrastando) == null
                  ? Colors.green.shade100
                  : Colors.red.shade100);

        return Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color:
                destaque ??
                (ordenadas.isEmpty
                    ? Colors.grey.shade100
                    : IfprColors.verdeFundo),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: ocupado ? null : aoTocar,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: ordenadas.length > 1 || dividida ? 88 : 68,
                child: ordenadas.isEmpty
                    ? const Center(
                        child: Icon(Icons.add, color: IfprColors.cinzaClaro),
                      )
                    : ordenadas.length == 1 && !dividida
                    ? _arrastavel(ordenadas.first)
                    : Row(
                        children: [
                          if (dividida) ...[
                            const Expanded(child: _GrupoLivre()),
                            _divisoria(),
                          ],
                          for (var i = 0; i < ordenadas.length; i++) ...[
                            if (i > 0) _divisoria(),
                            Expanded(child: _arrastavel(ordenadas[i])),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _divisoria() => Container(
    width: 1,
    color: IfprColors.verde.withValues(alpha: 0.35),
  );

  Widget _arrastavel(Aula aula) {
    final conteudo = _conteudoAula(aula);
    if (aoSoltar == null) return conteudo;

    return Draggable<Aula>(
      data: aula,
      maxSimultaneousDrags: ocupado ? 0 : 1,
      feedback: Material(
        elevation: 6,
        color: IfprColors.verdeFundo,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 140, height: 68, child: conteudo),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: conteudo),
      child: conteudo,
    );
  }

  Widget _conteudoAula(Aula aula) {
    final nomeMateria = materias[aula.idMateria]?.nome;
    final nomeProfessor = professores[aula.idProfessor]?.nome;
    final sala = aula.idSala == null ? null : salasPorId[aula.idSala!];

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'G${aula.grupo}',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: IfprColors.verde,
            ),
          ),
          Text(
            nomeMateria ?? 'Matéria',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: IfprColors.verdeEscuro,
            ),
          ),
          Text(
            nomeProfessor ?? 'Professor',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: IfprColors.cinzaClaro,
            ),
          ),
          if (sala != null)
            Text(
              sala.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: IfprColors.verde,
              ),
            ),
        ],
      ),
    );
  }
}

/// Metade vazia da célula quando a turma está dividida e o grupo 1 não tem
/// aula (parte da aula geminada só com a matéria maior).
class _GrupoLivre extends StatelessWidget {
  const _GrupoLivre();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'G1',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: IfprColors.verde,
            ),
          ),
          Text(
            'Livre',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: IfprColors.cinzaClaro,
            ),
          ),
        ],
      ),
    );
  }
}
