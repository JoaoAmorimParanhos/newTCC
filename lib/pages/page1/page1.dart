import 'package:flutter/material.dart';
import 'package:flutter_test_project/pages/page1/columns/coluna_curso.dart';
import 'package:flutter_test_project/pages/page1/columns/coluna_professor.dart';
import 'package:flutter_test_project/pages/page1/columns/coluna_sala.dart';
import 'package:flutter_test_project/pages/page1/columns/coluna_materia.dart';
import 'package:flutter_test_project/pages/layout_base.dart';

class Page1 extends StatelessWidget {
  const Page1({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBase(
      titulo: 'Cadastros',
      body: const Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColunaProfessor(),
            ColunaMateria(),
            ColunaSala(),
            ColunaCurso(),
          ],
        ),
      ),
    );
  }
}
