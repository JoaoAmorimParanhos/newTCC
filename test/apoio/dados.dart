import 'package:flutter_test_project/components/grade_horaria.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/model/sala/sala.dart';

// Dados de exemplo usados pelos testes. Os ids seguem o banco (números).

final informatica = Materia(id: '10', nome: 'Informática');
final ingles = Materia(id: '11', nome: 'Inglês');
final matematica = Materia(id: '12', nome: 'Matemática');
final materiasPadrao = [informatica, ingles, matematica];

final ana = Professor(id: '20', nome: 'Ana'); // Informática
final bruno = Professor(id: '21', nome: 'Bruno'); // Inglês
final carla = Professor(id: '22', nome: 'Carla'); // Matemática
final diego = Professor(id: '23', nome: 'Diego'); // Matemática (reserva)
final professoresPadrao = [ana, bruno, carla, diego];

final ligacoesPadrao = [
  ProfessorMateria(idProfessor: ana.id, idMateria: informatica.id),
  ProfessorMateria(idProfessor: bruno.id, idMateria: ingles.id),
  ProfessorMateria(idProfessor: carla.id, idMateria: matematica.id),
  ProfessorMateria(idProfessor: diego.id, idMateria: matematica.id),
];

const tipoSalaAula = TipoSala(id: '1', nome: 'Sala de aula');
const tipoLaboratorio = TipoSala(id: '2', nome: 'Laboratório de informática');
const tipoQuadra = TipoSala(id: '3', nome: 'Quadra');

final sala1 = Sala(id: '30', numero: 1, tipo: tipoSalaAula);
final lab1 = Sala(id: '31', numero: 1, tipo: tipoLaboratorio);
final salasPadrao = [sala1, lab1];

Curso curso({
  String id = '1',
  String nome = 'Info 1',
  String? idSala,
  PreferenciaPeriodo preferencia = PreferenciaPeriodo.manhaTarde,
}) => Curso(
  id: id,
  nome: nome,
  idSala: idSala,
  preferenciaPeriodo: preferencia,
);

CargaCursoMateria carga(
  String idMateria,
  int aulas, {
  String idCurso = '1',
  int bloco = 1,
}) => CargaCursoMateria(
  idCurso: idCurso,
  idMateria: idMateria,
  quantidadeAulas: aulas,
  tamanhoBloco: bloco,
);

AulaGeminadaCurso par(
  String idMateriaA,
  String idMateriaB, {
  required int aulas,
  required int blocos,
  int? aulasB,
  String idCurso = '1',
}) => AulaGeminadaCurso(
  idCurso: idCurso,
  idMateriaA: idMateriaA,
  idMateriaB: idMateriaB,
  quantidadePeriodos: aulas,
  quantidadePeriodosB: aulasB,
  quantidadeBlocos: blocos,
);

var _proximoIdAula = 1000;

Aula aula({
  String? id,
  String idCurso = '1',
  required int dia,
  required int periodo,
  required String idMateria,
  required String idProfessor,
  String? idSala,
  int grupo = 1,
}) => Aula(
  id: id ?? '${_proximoIdAula++}',
  idCurso: idCurso,
  indiceDia: dia,
  indicePeriodo: periodo,
  idMateria: idMateria,
  idProfessor: idProfessor,
  idSala: idSala,
  grupo: grupo,
);

IndisponibilidadeProfessor indisponivel(
  String idProfessor, {
  required int dia,
  required int periodo,
}) => IndisponibilidadeProfessor(
  id: '$idProfessor-$dia-$periodo',
  idProfessor: idProfessor,
  indiceDia: dia,
  indicePeriodo: periodo,
);

/// Indisponibilidade do professor no dia inteiro.
List<IndisponibilidadeProfessor> diaInteiroIndisponivel(
  String idProfessor,
  int dia,
) => [
  for (var p = 0; p < GradeHoraria.periodos.length; p++)
    indisponivel(idProfessor, dia: dia, periodo: p),
];

CelulaGrade celula(int dia, int periodo) =>
    CelulaGrade(indiceDia: dia, indicePeriodo: periodo);
