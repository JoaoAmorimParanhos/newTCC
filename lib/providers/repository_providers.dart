import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test_project/services/repositories/repositorio_aula.dart';
import 'package:flutter_test_project/services/repositories/repositorio_curso.dart';
import 'package:flutter_test_project/services/repositories/repositorio_horario_periodo.dart';
import 'package:flutter_test_project/services/repositories/repositorio_professor.dart';
import 'package:flutter_test_project/services/repositories/repositorio_tipo_sala.dart';
import 'package:flutter_test_project/services/repositories/repositorio_indisponibilidade.dart';
import 'package:flutter_test_project/services/repositories/repositorio_sala.dart';
import 'package:flutter_test_project/services/repositories/repositorio_materia.dart';

// providers que entregam os repositórios (acesso ao supabase)

final provedorRepositorioSala = Provider<RepositorioSala>(
  (ref) => RepositorioSala(),
);

final provedorRepositorioProfessor = Provider<RepositorioProfessor>(
  (ref) => RepositorioProfessor(),
);

final provedorRepositorioMateria = Provider<RepositorioMateria>(
  (ref) => RepositorioMateria(),
);

final provedorRepositorioCurso = Provider<RepositorioCurso>(
  (ref) => RepositorioCurso(),
);

final provedorRepositorioAula = Provider<RepositorioAula>(
  (ref) => RepositorioAula(),
);

final provedorRepositorioHorarioPeriodo = Provider<RepositorioHorarioPeriodo>(
  (ref) => RepositorioHorarioPeriodo(),
);

final provedorRepositorioTipoSala = Provider<RepositorioTipoSala>(
  (ref) => RepositorioTipoSala(),
);

final provedorRepositorioIndisponibilidade =
    Provider<RepositorioIndisponibilidade>(
  (ref) => RepositorioIndisponibilidade(),
);
