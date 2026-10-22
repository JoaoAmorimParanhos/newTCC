import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/model/aula/aula.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/curso.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/horario/horario_periodo.dart';
import 'package:flutter_test_project/model/professor/professor.dart';
import 'package:flutter_test_project/model/professor/professor_materia.dart';
import 'package:flutter_test_project/model/professor/indisponibilidade_professor.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/model/materia/materia.dart';
import 'package:flutter_test_project/providers/repository_providers.dart';

// streamProviders: escutam os streams realtime dos repos

/// usa .when(loading:, error:, data:) pra renderizar
final provedorSalas = StreamProvider<List<Sala>>((ref) {
  return ref.read(provedorRepositorioSala).observarTodos();
});

final provedorProfessores = StreamProvider<List<Professor>>((ref) {
  return ref.read(provedorRepositorioProfessor).observarTodos();
});

final provedorProfessorMaterias = StreamProvider<List<ProfessorMateria>>((ref) {
  return ref.read(provedorRepositorioProfessor).observarLigacoesMaterias();
});

final provedorMaterias = StreamProvider<List<Materia>>((ref) {
  return ref.read(provedorRepositorioMateria).observarTodos();
});

final provedorCursos = StreamProvider<List<Curso>>((ref) {
  return ref.read(provedorRepositorioCurso).observarTodos();
});

final provedorCargasCurso = StreamProvider<List<CargaCursoMateria>>((ref) {
  return ref.read(provedorRepositorioCurso).observarCargas();
});

final provedorAulasGeminadasCurso = StreamProvider<List<AulaGeminadaCurso>>((
  ref,
) {
  return ref.read(provedorRepositorioCurso).observarAulasGeminadas();
});

final provedorAulas = StreamProvider<List<Aula>>((ref) {
  return ref.read(provedorRepositorioAula).observarTodos();
});

final provedorHorariosPeriodo = StreamProvider<List<HorarioPeriodo>>((ref) {
  return ref.read(provedorRepositorioHorarioPeriodo).observarTodos();
});

final provedorTiposSala = StreamProvider<List<TipoSala>>((ref) {
  return ref.read(provedorRepositorioTipoSala).observarTodos();
});

final provedorIndisponibilidades =
    StreamProvider<List<IndisponibilidadeProfessor>>((ref) {
      return ref.read(provedorRepositorioIndisponibilidade).observarTodos();
    });
