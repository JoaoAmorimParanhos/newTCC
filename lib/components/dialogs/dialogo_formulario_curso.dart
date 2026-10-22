import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test_project/model/curso/aula_geminada_curso.dart';
import 'package:flutter_test_project/model/curso/preferencia_periodo.dart';
import 'package:flutter_test_project/model/curso/carga_curso_materia.dart';
import 'package:flutter_test_project/model/sala/sala.dart';
import 'package:flutter_test_project/model/materia/materia.dart';

class ResultadoFormularioCurso {
  const ResultadoFormularioCurso({
    required this.nome,
    required this.cargas,
    required this.aulasGeminadas,
    this.idSala,
    this.preferenciaPeriodo = PreferenciaPeriodo.manhaTarde,
  });

  final String nome;
  final String? idSala;
  final PreferenciaPeriodo preferenciaPeriodo;
  final List<CargaCursoMateria> cargas;
  final List<AulaGeminadaCurso> aulasGeminadas;
}

class _LinhaCarga {
  _LinhaCarga({this.idMateria, int quantidadeAulas = 1, this.tamanhoBloco = 1})
    : controladorQuantidade = TextEditingController(text: '$quantidadeAulas');

  String? idMateria;
  final TextEditingController controladorQuantidade;
  int tamanhoBloco;

  void dispose() => controladorQuantidade.dispose();
}

class _LinhaAulaGeminada {
  _LinhaAulaGeminada({
    this.idMateriaA,
    this.idMateriaB,
    int quantidadePeriodos = 1,
    int? quantidadePeriodosB,
    this.quantidadeBlocos = 1,
  }) : controladorPeriodos = TextEditingController(text: '$quantidadePeriodos'),
       // Vazio = mesma quantidade da matéria A.
       controladorPeriodosB = TextEditingController(
         text: quantidadePeriodosB == null ||
                 quantidadePeriodosB == quantidadePeriodos
             ? ''
             : '$quantidadePeriodosB',
       );

  String? idMateriaA;
  String? idMateriaB;

  /// Aulas da matéria A dentro da geminada.
  final TextEditingController controladorPeriodos;

  /// Aulas da matéria B (vazio = igual à A).
  final TextEditingController controladorPeriodosB;
  int quantidadeBlocos;

  void dispose() {
    controladorPeriodos.dispose();
    controladorPeriodosB.dispose();
  }
}

Future<ResultadoFormularioCurso?> mostrarDialogoFormularioCurso(
  BuildContext context, {
  required String titulo,
  required List<Materia> materias,
  required List<Sala> salas,
  String? nomeInicial,
  String? idSalaInicial,
  PreferenciaPeriodo preferenciaPeriodoInicial = PreferenciaPeriodo.manhaTarde,
  List<CargaCursoMateria> cargasIniciais = const [],
  List<AulaGeminadaCurso> aulasGeminadasIniciais = const [],
  String idCurso = '0',
}) {
  return showDialog<ResultadoFormularioCurso>(
    context: context,
    builder: (context) => _CourseFormDialog(
      titulo: titulo,
      materias: materias,
      salas: salas,
      nomeInicial: nomeInicial,
      idSalaInicial: idSalaInicial,
      preferenciaPeriodoInicial: preferenciaPeriodoInicial,
      cargasIniciais: cargasIniciais,
      aulasGeminadasIniciais: aulasGeminadasIniciais,
      idCurso: idCurso,
    ),
  );
}

class _CourseFormDialog extends StatefulWidget {
  const _CourseFormDialog({
    required this.titulo,
    required this.materias,
    required this.salas,
    this.nomeInicial,
    this.idSalaInicial,
    required this.preferenciaPeriodoInicial,
    required this.cargasIniciais,
    required this.aulasGeminadasIniciais,
    required this.idCurso,
  });

  final String titulo;
  final List<Materia> materias;
  final List<Sala> salas;
  final String? nomeInicial;
  final String? idSalaInicial;
  final PreferenciaPeriodo preferenciaPeriodoInicial;
  final List<CargaCursoMateria> cargasIniciais;
  final List<AulaGeminadaCurso> aulasGeminadasIniciais;
  final String idCurso;

  @override
  State<_CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends State<_CourseFormDialog> {
  late final TextEditingController _controladorNome;
  late final List<_LinhaCarga> _linhas;
  late final List<_LinhaAulaGeminada> _linhasGeminadas;
  String? _idSala;
  late PreferenciaPeriodo _preferenciaPeriodo;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _controladorNome = TextEditingController(text: widget.nomeInicial ?? '');
    _idSala = widget.idSalaInicial;
    _preferenciaPeriodo = widget.preferenciaPeriodoInicial;
    if (widget.cargasIniciais.isEmpty) {
      _linhas = [_LinhaCarga()];
    } else {
      _linhas = widget.cargasIniciais
          .map(
            (load) => _LinhaCarga(
              idMateria: load.idMateria,
              quantidadeAulas: load.quantidadeAulas,
              tamanhoBloco: load.tamanhoBloco,
            ),
          )
          .toList();
    }
    _linhasGeminadas = widget.aulasGeminadasIniciais
        .map(
          (par) => _LinhaAulaGeminada(
            idMateriaA: par.idMateriaA,
            idMateriaB: par.idMateriaB,
            quantidadePeriodos: par.quantidadeA,
            quantidadePeriodosB: par.quantidadeB,
            quantidadeBlocos: par.quantidadeBlocos,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _controladorNome.dispose();
    for (final row in _linhas) {
      row.dispose();
    }
    for (final row in _linhasGeminadas) {
      row.dispose();
    }
    super.dispose();
  }

  void _adicionarLinha() => setState(() => _linhas.add(_LinhaCarga()));

  void _adicionarLinhaGeminada() {
    setState(() => _linhasGeminadas.add(_LinhaAulaGeminada()));
  }

  void _removerLinha(int index) {
    setState(() {
      _linhas[index].dispose();
      _linhas.removeAt(index);
      if (_linhas.isEmpty) _linhas.add(_LinhaCarga());
    });
  }

  void _removerLinhaGeminada(int index) {
    setState(() {
      _linhasGeminadas[index].dispose();
      _linhasGeminadas.removeAt(index);
    });
  }

  int _quantidadeAulas(_LinhaCarga row) {
    final count = int.tryParse(row.controladorQuantidade.text.trim());
    return count == null || count < 1 ? 1 : count;
  }

  int _limiteBloco(_LinhaCarga row) {
    final pelaCarga = _quantidadeAulas(row);
    return pelaCarga < 6 ? pelaCarga : 6;
  }

  int _valorBloco(_LinhaCarga row) {
    final limite = _limiteBloco(row);
    if (row.tamanhoBloco < 1) return 1;
    if (row.tamanhoBloco > limite) return limite;
    return row.tamanhoBloco;
  }

  List<Materia> _materiasComCarga() {
    final ids = _linhas.map((row) => row.idMateria).whereType<String>().toSet();
    return widget.materias
        .where((materia) => ids.contains(materia.id))
        .toList();
  }

  void _ajustarBloco(_LinhaCarga row) {
    final valor = _valorBloco(row);
    if (row.tamanhoBloco != valor) {
      row.tamanhoBloco = valor;
    }
  }

  int _aulasA(_LinhaAulaGeminada row) {
    final count = int.tryParse(row.controladorPeriodos.text.trim());
    return count == null || count < 1 ? 1 : count;
  }

  int _aulasB(_LinhaAulaGeminada row) {
    final texto = row.controladorPeriodosB.text.trim();
    if (texto.isEmpty) return _aulasA(row);
    final count = int.tryParse(texto);
    return count == null || count < 1 ? 1 : count;
  }

  /// Horários ocupados pelo par: a matéria com mais aulas define.
  int _aulasGeminada(_LinhaAulaGeminada row) {
    final a = _aulasA(row);
    final b = _aulasB(row);
    return a > b ? a : b;
  }

  /// Menos blocos que isso deixaria um bloco maior que um turno.
  int _minimoBlocosGeminada(_LinhaAulaGeminada row) {
    const maximo = AulaGeminadaCurso.maxAulasPorBloco;
    return (_aulasGeminada(row) + maximo - 1) ~/ maximo;
  }

  int _valorBlocosGeminada(_LinhaAulaGeminada row) {
    final minimo = _minimoBlocosGeminada(row);
    final maximo = _aulasGeminada(row);
    if (row.quantidadeBlocos < minimo) return minimo;
    if (row.quantidadeBlocos > maximo) return maximo;
    return row.quantidadeBlocos;
  }

  void _enviar() {
    final nome = _controladorNome.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe o nome do curso');
      return;
    }

    final cargas = <CargaCursoMateria>[];
    final seenSubjects = <String>{};

    for (final row in _linhas) {
      final idMateria = row.idMateria;
      if (idMateria == null) continue;

      final count = int.tryParse(row.controladorQuantidade.text.trim());
      if (count == null || count < 1) {
        setState(() => _erro = 'Quantidade de aulas deve ser um número ≥ 1');
        return;
      }
      if (!seenSubjects.add(idMateria)) {
        setState(() => _erro = 'Cada matéria só pode aparecer uma vez');
        return;
      }

      _ajustarBloco(row);
      if (row.tamanhoBloco > count) {
        setState(
          () => _erro = 'Bloco não pode ser maior que a carga da matéria',
        );
        return;
      }

      cargas.add(
        CargaCursoMateria(
          idCurso: widget.idCurso,
          idMateria: idMateria,
          quantidadeAulas: count,
          tamanhoBloco: row.tamanhoBloco,
        ),
      );
    }

    final idsCargas = cargas.map((carga) => carga.idMateria).toSet();
    final cargaPorMateria = {
      for (final carga in cargas) carga.idMateria: carga.quantidadeAulas,
    };
    final periodosPorMateria = <String, int>{};
    final aulasGeminadas = <AulaGeminadaCurso>[];
    final paresVistos = <String>{};
    for (final row in _linhasGeminadas) {
      final idMateriaA = row.idMateriaA;
      final idMateriaB = row.idMateriaB;
      if (idMateriaA == null && idMateriaB == null) continue;
      if (idMateriaA == null || idMateriaB == null) {
        setState(() => _erro = 'Informe as duas matérias da aula geminada');
        return;
      }
      if (idMateriaA == idMateriaB) {
        setState(
          () => _erro = 'Aula geminada precisa de duas matérias diferentes',
        );
        return;
      }
      if (!idsCargas.contains(idMateriaA) || !idsCargas.contains(idMateriaB)) {
        setState(
          () => _erro = 'Aulas geminadas devem usar matérias da carga do curso',
        );
        return;
      }

      final periodosA = int.tryParse(row.controladorPeriodos.text.trim());
      final textoB = row.controladorPeriodosB.text.trim();
      final periodosB = textoB.isEmpty ? periodosA : int.tryParse(textoB);
      if (periodosA == null ||
          periodosA < 1 ||
          periodosB == null ||
          periodosB < 1) {
        setState(() => _erro = 'Aulas da aula geminada deve ser um número ≥ 1');
        return;
      }
      final periodos = periodosA > periodosB ? periodosA : periodosB;
      final blocos = row.quantidadeBlocos;
      if (blocos < 1 || blocos > periodos) {
        setState(
          () => _erro =
              'Blocos da aula geminada devem ir de 1 até o número de aulas',
        );
        return;
      }
      if (dividirEmBlocos(periodos, blocos).first >
          AulaGeminadaCurso.maxAulasPorBloco) {
        setState(
          () => _erro =
              'Cada bloco geminado pode ter no máximo '
              '${AulaGeminadaCurso.maxAulasPorBloco} aulas (um turno)',
        );
        return;
      }
      final cargaA = cargaPorMateria[idMateriaA] ?? 0;
      final cargaB = cargaPorMateria[idMateriaB] ?? 0;
      if (periodosA > cargaA || periodosB > cargaB) {
        setState(
          () =>
              _erro = 'Aulas geminadas não podem passar da carga das matérias',
        );
        return;
      }
      final usadoA = (periodosPorMateria[idMateriaA] ?? 0) + periodosA;
      final usadoB = (periodosPorMateria[idMateriaB] ?? 0) + periodosB;
      if (usadoA > cargaA || usadoB > cargaB) {
        setState(
          () => _erro =
              'A soma das aulas geminadas passa da carga de uma matéria',
        );
        return;
      }
      periodosPorMateria[idMateriaA] = usadoA;
      periodosPorMateria[idMateriaB] = usadoB;

      final par = AulaGeminadaCurso(
        idCurso: widget.idCurso,
        idMateriaA: idMateriaA,
        idMateriaB: idMateriaB,
        quantidadePeriodos: periodosA,
        quantidadePeriodosB: periodosB,
        quantidadeBlocos: blocos,
      );
      if (!paresVistos.add(par.chave)) {
        setState(() => _erro = 'Par de aula geminada repetido');
        return;
      }
      aulasGeminadas.add(par);
    }

    setState(() => _erro = null);
    Navigator.of(context).pop(
      ResultadoFormularioCurso(
        nome: nome,
        idSala: _idSala,
        preferenciaPeriodo: _preferenciaPeriodo,
        cargas: cargas,
        aulasGeminadas: aulasGeminadas,
      ),
    );
  }

  Widget _secaoAulasGeminadas() {
    final materiasComCarga = _materiasComCarga();
    final podeCadastrarPares = materiasComCarga.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Aulas geminadas',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: podeCadastrarPares ? _adicionarLinhaGeminada : null,
              icon: const Icon(Icons.add),
              label: const Text('Aula'),
            ),
          ],
        ),
        if (podeCadastrarPares && _linhasGeminadas.isNotEmpty) ...[
          const Text(
            'Aulas: quantas aulas o par tem junto na semana. '
            'Blocos: em quantos conjuntos de aulas seguidas elas são '
            'divididas ao longo dos dias (ex.: 8 aulas em 2 blocos = '
            '2 conjuntos de 4).',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              for (var i = 0; i < _linhasGeminadas.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(
                                'gem-a-$i-${_linhasGeminadas[i].idMateriaA}',
                              ),
                              initialValue:
                                  materiasComCarga.any(
                                    (m) =>
                                        m.id == _linhasGeminadas[i].idMateriaA,
                                  )
                                  ? _linhasGeminadas[i].idMateriaA
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Matéria A',
                                isDense: true,
                              ),
                              items: materiasComCarga
                                  .map(
                                    (subject) => DropdownMenuItem(
                                      value: subject.id,
                                      child: Text(subject.nome),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(
                                  () => _linhasGeminadas[i].idMateriaA = value,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(
                                'gem-b-$i-${_linhasGeminadas[i].idMateriaB}',
                              ),
                              initialValue:
                                  materiasComCarga.any(
                                    (m) =>
                                        m.id == _linhasGeminadas[i].idMateriaB,
                                  )
                                  ? _linhasGeminadas[i].idMateriaB
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Matéria B',
                                isDense: true,
                              ),
                              items: materiasComCarga
                                  .map(
                                    (subject) => DropdownMenuItem(
                                      value: subject.id,
                                      child: Text(subject.nome),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(
                                  () => _linhasGeminadas[i].idMateriaB = value,
                                );
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removerLinhaGeminada(i),
                            tooltip: 'Remover par',
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: ValueKey('gem-aulas-$i'),
                              controller:
                                  _linhasGeminadas[i].controladorPeriodos,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) {
                                setState(() {
                                  final row = _linhasGeminadas[i];
                                  row.quantidadeBlocos = _valorBlocosGeminada(
                                    row,
                                  );
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Aulas de A',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: ValueKey('gem-aulas-b-$i'),
                              controller:
                                  _linhasGeminadas[i].controladorPeriodosB,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) {
                                setState(() {
                                  final row = _linhasGeminadas[i];
                                  row.quantidadeBlocos = _valorBlocosGeminada(
                                    row,
                                  );
                                });
                              },
                              decoration: const InputDecoration(
                                labelText: 'Aulas de B',
                                hintText: 'igual a A',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey(
                                'gem-blocos-$i-'
                                '${_linhasGeminadas[i].quantidadeBlocos}-'
                                '${_aulasGeminada(_linhasGeminadas[i])}',
                              ),
                              initialValue: _valorBlocosGeminada(
                                _linhasGeminadas[i],
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Blocos',
                                isDense: true,
                              ),
                              items: [
                                for (
                                  var value = _minimoBlocosGeminada(
                                    _linhasGeminadas[i],
                                  );
                                  value <= _aulasGeminada(_linhasGeminadas[i]);
                                  value++
                                )
                                  DropdownMenuItem(
                                    value: value,
                                    child: Text('$value'),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(
                                    () => _linhasGeminadas[i].quantidadeBlocos =
                                        value,
                                  );
                                }
                              },
                            ),
                          ),
                          // Mesmo espaço do botão de remover da linha de cima.
                          const SizedBox(width: 48),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controladorNome,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nome do curso',
                  errorText: _erro,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PreferenciaPeriodo>(
                key: ValueKey('period-$_preferenciaPeriodo'),
                initialValue: _preferenciaPeriodo,
                decoration: const InputDecoration(
                  labelText: 'Período das aulas',
                ),
                items: PreferenciaPeriodo.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.rotulo),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _preferenciaPeriodo = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey('room-$_idSala'),
                initialValue: _idSala,
                decoration: const InputDecoration(
                  labelText: 'Sala padrão (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nenhuma'),
                  ),
                  ...widget.salas.map(
                    (room) => DropdownMenuItem<String?>(
                      value: room.id,
                      child: Text(room.rotulo),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _idSala = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Matérias, carga e blocos',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.materias.isEmpty ? null : _adicionarLinha,
                    icon: const Icon(Icons.add),
                    label: const Text('Linha'),
                  ),
                ],
              ),
              if (widget.materias.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 0; i < _linhas.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'load-$i-${_linhas[i].idMateria}',
                                    ),
                                    initialValue: _linhas[i].idMateria,
                                    decoration: const InputDecoration(
                                      labelText: 'Matéria',
                                      isDense: true,
                                    ),
                                    items: widget.materias
                                        .map(
                                          (subject) => DropdownMenuItem(
                                            value: subject.id,
                                            child: Text(subject.nome),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      setState(
                                        () => _linhas[i].idMateria = value,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller:
                                        _linhas[i].controladorQuantidade,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (_) {
                                      setState(() => _ajustarBloco(_linhas[i]));
                                    },
                                    decoration: const InputDecoration(
                                      labelText: 'Aulas',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    key: ValueKey(
                                      'block-$i-${_linhas[i].tamanhoBloco}-${_quantidadeAulas(_linhas[i])}',
                                    ),
                                    initialValue: _valorBloco(_linhas[i]),
                                    decoration: const InputDecoration(
                                      labelText: 'Bloco',
                                      isDense: true,
                                    ),
                                    items: [
                                      for (
                                        var value = 1;
                                        value <= _limiteBloco(_linhas[i]);
                                        value++
                                      )
                                        DropdownMenuItem(
                                          value: value,
                                          child: Text('$value'),
                                        ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(
                                          () => _linhas[i].tamanhoBloco = value,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _removerLinha(i),
                                  tooltip: 'Remover linha',
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _secaoAulasGeminadas(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _enviar, child: const Text('Salvar')),
      ],
    );
  }
}
