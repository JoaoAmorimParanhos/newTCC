import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
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


    test('carga completa não bloqueia mais (a carga sobe ao salvar)', () {
      expect(
        _validar(
          aulas: [
            aula(dia: 1, periodo: 0, idMateria: matematica.id, idProfessor: carla.id),
          ],
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
        isNull,
      );
    });

    test('2º grupo com qualquer matéria é aceito (o par é criado)', () {
      expect(
        _validar(
          aulas: [
            aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
          ],
          idMateria: matematica.id,
          idProfessor: carla.id,
          grupo: 2,
        ),
        isNull,
      );
    });

    test('grupo já ocupado no horário', () {
      expect(
        _validar(
          aulas: [
            aula(dia: 0, periodo: 0, idMateria: informatica.id, idProfessor: ana.id),
          ],
          idMateria: matematica.id,
          idProfessor: carla.id,
        ),
        'O grupo 1 já está ocupado neste horário.',
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


    test('mesma matéria nos dois grupos', () {
      expect(
        _validar(
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

  });
}
