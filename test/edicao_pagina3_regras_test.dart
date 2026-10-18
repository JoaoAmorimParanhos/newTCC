import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/pages/page3/helpers/regras_horario.dart';

import 'apoio/dados.dart';

/// Chama a regra que a página 3 usa antes de salvar uma aula.
String? _validar({
  Curso? turma,
  CelulaGrade? em,
  required String idMateria,
  required String idProfessor,
  String? idSala,
  Aula? existente,
  int grupo = 1,
  List<CargaCursoMateria>? cargas,
  List<AulaGeminadaCurso> pares = const [],
  List<Aula> aulas = const [],
  List<IndisponibilidadeProfessor> indisponibilidades = const [],
}) {
  return validarSalvarAula(
    curso: turma ?? curso(),
    celula: em ?? celula(0, 0),
    idMateria: idMateria,
    idProfessor: idProfessor,
    idSala: idSala,
    existente: existente,
    grupo: grupo,
    cargas:
        cargas ??
        [carga(informatica.id, 4), carga(ingles.id, 4), carga(matematica.id, 4)],
    aulasGeminadas: pares,
    todasAulas: aulas,
    ligacoes: ligacoesPadrao,
    indisponibilidades: indisponibilidades,
  );
}

void main() {
  group('Página 3: regras ao salvar uma aula', () {
    test('aula nova válida pode ser salva', () {
      expect(
        _validar(idMateria: matematica.id, idProfessor: carla.id),
        isNull,
      );
    });

    test('matéria fora da carga do curso', () {
      expect(
        _validar(
          cargas: [carga(informatica.id, 2)],
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
        'Matéria não pertence à carga deste curso.',
      );
    });

    test('carga da matéria já completa', () {
      expect(
        _validar(
          cargas: [carga(matematica.id, 1)],
          aulas: [
            aula(dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
          ],
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
        'Carga completa para esta matéria (1 aula(s)).',
      );
    });

    test('editar a própria aula não conta como carga a mais', () {
      final existente = aula(
        dia: 0,
        periodo: 0,
        idMateria: matematica.id,
        idProfessor: carla.id,
      );
      expect(
        _validar(
          cargas: [carga(matematica.id, 1)],
          aulas: [existente],
          existente: existente,
          idMateria: matematica.id,
          idProfessor: diego.id,
        ),
        isNull,
      );
    });

    test('professor que não dá a matéria', () {
      expect(
        _validar(idMateria: matematica.id, idProfessor: ana.id),
        'Este professor não está vinculado a esta matéria.',
      );
    });

    test('professor indisponível no horário (página 2)', () {
      expect(
        _validar(
          idMateria: matematica.id,
          idProfessor: carla.id,
          indisponibilidades: [indisponivel(carla.id, dia: 0, periodo: 0)],
        ),
        'Professor indisponível neste horário (Página 2).',
      );
    });

    test('professor já alocado em outra turma no horário', () {
      expect(
        _validar(
          aulas: [
            aula(
              idCurso: '2',
              dia: 0,
              periodo: 0,
              idMateria: matematica.id,
              idProfessor: carla.id,
            ),
          ],
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
        'Este professor já está alocado neste horário.',
      );
    });

    test('2º grupo sem par geminado cadastrado', () {
      expect(
        _validar(
          aulas: [
            aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
          ],
          idMateria: ingles.id,
          idProfessor: bruno.id,
          grupo: 2,
        ),
        'Cadastre um par de aula geminada para usar 2 grupos.',
      );
    });

    test('2º grupo com o par geminado é aceito', () {
      expect(
        _validar(
          pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
          aulas: [
            aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
          ],
          idMateria: ingles.id,
          idProfessor: bruno.id,
          grupo: 2,
        ),
        isNull,
      );
    });

    test('2º grupo com matéria que não forma o par', () {
      expect(
        _validar(
          pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
          aulas: [
            aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
          ],
          idMateria: matematica.id,
          idProfessor: carla.id,
          grupo: 2,
        ),
        'Estas matérias não formam uma aula geminada nesta turma.',
      );
    });

    test('mesma matéria nos dois grupos', () {
      expect(
        _validar(
          pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
          aulas: [
            aula(dia: 0, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
          ],
          idMateria: matematica.id,
          idProfessor: diego.id,
          grupo: 2,
        ),
        'Esta matéria já está neste horário (outro grupo).',
      );
    });

    test('horário com os 2 grupos ocupados', () {
      expect(
        _validar(
          pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
          aulas: [
            aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
            aula(
              dia: 0,
              periodo: 0,
              idMateria: ingles.id,
              idProfessor: bruno.id,
              grupo: 2,
            ),
          ],
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
        'Este horário já tem 2 grupos nesta turma.',
      );
    });

    test('sala ocupada por outra turma', () {
      expect(
        _validar(
          aulas: [
            aula(
              idCurso: '2',
              dia: 0,
              periodo: 0,
              idMateria: informatica.id,
              idProfessor: ana.id,
              idSala: sala1.id,
            ),
          ],
          idMateria: matematica.id,
          idProfessor: carla.id,
          idSala: sala1.id,
        ),
        'Esta sala já está ocupada por outra turma neste horário.',
      );
    });

    test('grupos da mesma turma podem dividir a sala', () {
      expect(
        _validar(
          pares: [par(informatica.id, ingles.id, aulas: 2, blocos: 1)],
          aulas: [
            aula(
              dia: 0,
              periodo: 0,
              idMateria: informatica.id,
              idProfessor: ana.id,
              idSala: sala1.id,
            ),
          ],
          idMateria: ingles.id,
          idProfessor: bruno.id,
          idSala: sala1.id,
          grupo: 2,
        ),
        isNull,
      );
    });
  });

  group('Página 3: listas do diálogo de aula', () {
    test('próximo grupo livre', () {
      final g1 = aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id);
      final g2 = aula(
        dia: 0,
        periodo: 0,
        idMateria: ingles.id,
        idProfessor: bruno.id,
        grupo: 2,
      );
      expect(proximoGrupoLivre(const []), 1);
      expect(proximoGrupoLivre([g1]), 2);
      expect(proximoGrupoLivre([g1, g2]), isNull);
      expect(proximoGrupoLivre([g1, g2], idAulaExcluida: g1.id), 1);
    });

    test('só oferece professores livres e vinculados à matéria', () {
      final lista = professoresParaDialogoAula(
        idMateria: matematica.id,
        celula: celula(0, 0),
        professores: professoresPadrao,
        ligacoes: ligacoesPadrao,
        indisponibilidades: [indisponivel(diego.id, dia: 0, periodo: 0)],
        todasAulas: const [],
      );
      expect(lista.map((p) => p.nome), ['Carla']);
    });

    test('ao editar, mantém o professor atual mesmo se ficou bloqueado', () {
      final existente = aula(
        dia: 0,
        periodo: 0,
        idMateria: matematica.id,
        idProfessor: carla.id,
      );
      final lista = professoresParaDialogoAula(
        idMateria: matematica.id,
        celula: celula(0, 0),
        professores: professoresPadrao,
        ligacoes: ligacoesPadrao,
        indisponibilidades: [indisponivel(carla.id, dia: 0, periodo: 0)],
        todasAulas: [existente],
        existente: existente,
      );
      expect(lista.map((p) => p.nome), containsAll(['Carla', 'Diego']));
    });

    test('ao editar aula de matéria que saiu da carga, ela continua na lista', () {
      final existente = aula(
        dia: 0,
        periodo: 0,
        idMateria: matematica.id,
        idProfessor: carla.id,
      );
      final lista = materiasParaDialogoAula(
        materiasCurso: [informatica],
        todasMaterias: materiasPadrao,
        existente: existente,
      );
      expect(lista.map((m) => m.nome), ['Informática', 'Matemática']);
    });
  });
}
