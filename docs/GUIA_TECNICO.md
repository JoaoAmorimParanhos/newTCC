# Guia técnico do Projeto Timetable — por páginas

Este guia explica o projeto **a partir das três telas** do sistema. Para cada página, mostra cada classe, cada função e o trecho de código real que faz aquilo acontecer, além de quem chama quem e o que é enviado para onde. No fim de cada parte há perguntas que o orientador pode fazer, já respondidas.

> **Como ler**
>
> 1. Leia a **Parte 0 (Base comum)**. Ela mostra peças usadas pelas três páginas (inicialização, cabeçalho, providers, colunas, cartões). Sem ela, as outras partes ficam confusas.
> 2. Depois leia as páginas na ordem do sistema: **Parte 1 → Parte 2 → Parte 3**.
> 3. Abra cada arquivo citado no editor enquanto lê. Os trechos aqui são cópias do código; quando um pedaço foi cortado, aparece `// ...`.

---

## Sumário

- [Parte 0 — Base comum (usada pelas três páginas)](#parte-0--base-comum-usada-pelas-três-páginas)
- [Parte 1 — Página 1: Cadastros](#parte-1--página-1-cadastros)
- [Parte 2 — Página 2: Disponibilidade](#parte-2--página-2-disponibilidade)
- [Parte 3 — Página 3: Horário](#parte-3--página-3-horário)
- [Apêndice — Banco de dados e glossário](#apêndice--banco-de-dados-e-glossário)

---

## Parte 0 — Base comum (usada pelas três páginas)

### 0.1 Visão geral em uma figura

```
                         ┌───────────── main.dart ─────────────┐
                         │ Supabase.initialize + ProviderScope │
                         │ rotas: "/"  "/page2"  "/page3"      │
                         └──────┬───────────┬───────────┬──────┘
                                ▼           ▼           ▼
                             Page1        Page2       Page3      ← telas (lib/pages)
                                │           │           │
            lê dados com ref.watch(provedorX)   grava chamando ref.read(provedorRepositorioX).metodo()
                                │                       │
                    providers (lib/providers)     repositórios (lib/services/repositories)
                                └───────────┬───────────┘
                                            ▼
                                  Supabase (PostgreSQL)
```

- **Ler**: a tela chama `ref.watch(provedorCursos)`. O provider entrega a lista e redesenha a tela sempre que o banco muda.
- **Gravar**: a tela chama `ref.read(provedorRepositorioCurso).adicionar(...)`. Depois chama `ref.invalidate(provedorCursos)` para buscar de novo.
- **Regras** (validação, gerador, PDF) ficam em funções que só recebem listas e devolvem resultado. Elas não tocam no banco nem na tela.

### 0.2 `lib/main.dart` — ponto de partida

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ecofbovidfhsetaxjpaa.supabase.co',
    publishableKey: 'sb_publishable_...',
  );

  runApp(
    ProviderScope(
      child: MaterialApp(
        title: "Timetable project",
        theme: buildIfprTheme(),
        initialRoute: "/",
        routes: {
          "/": _page1,
          "/page2": _page2,
          "/page3": _page3},
      ),
    ),
  );
}

Widget _page1(BuildContext context) => const Page1();
Widget _page2(BuildContext context) => const Page2();
Widget _page3(BuildContext context) => const Page3();
```

| Linha | O que faz |
|---|---|
| `WidgetsFlutterBinding.ensureInitialized()` | prepara o Flutter antes de usar `await` no `main` |
| `Supabase.initialize(url, publishableKey)` | conecta no banco. Depois disso, `Supabase.instance.client` funciona em qualquer arquivo |
| `ProviderScope` | liga o Riverpod (a "caixa de dados" central) para o app inteiro |
| `buildIfprTheme()` | tema com as cores do IFPR (`lib/theme/app_theme.dart`, classe `IfprColors`) |
| `routes` | o nome de cada tela. `"/"` é a Página 1, `"/page2"` a 2 e `"/page3"` a 3 |

### 0.3 `lib/pages/layout_base.dart` — a moldura das três páginas

Toda página devolve um `LayoutBase(titulo: ..., body: ...)`. Ele desenha o cabeçalho verde com o símbolo do IF, os botões das páginas e o botão "Como usar".

**Classe `LayoutBase` (StatelessWidget)**. Recebe `titulo` e `body`. No `build`, decide o que cabe na largura da janela:

```dart
final largura = MediaQuery.sizeOf(context).width;
final mostrarTitulo = largura >= 1000;
final compacto = largura < 760;
```

- Janela larga (≥ 1000 px): mostra "PROJETO TIMETABLE".
- Janela estreita (< 760 px): os botões mostram só o número ("1", "2", "3"), e o nome completo vira dica (tooltip).

**Classe `_NavButton`**. É um botão de navegação. Fica desabilitado na página atual e troca de tela com `pushReplacementNamed`:

```dart
final currentRoute = ModalRoute.of(context)?.settings.name;
final selecionado = currentRoute == route;
// ...
onPressed: selecionado
    ? null
    : () => Navigator.pushReplacementNamed(context, route),
// ...
child: Text(compacto ? rotulo.split('.').first : rotulo),
```

`pushReplacementNamed` **substitui** a tela, em vez de empilhar. Assim o botão "voltar" do navegador não acumula telas.

**Classe `_BotaoManual`**. É o botão "Como usar". Chama `mostrarManual` passando a rota atual, para o manual abrir no assunto da tela:

```dart
onPressed: () => mostrarManual(
  context,
  rotaAtual: ModalRoute.of(context)?.settings.name,
),
```

### 0.4 Manual "Como usar" (`lib/components/manual/`)

| Peça | O que faz |
|---|---|
| `conteudo_manual.dart` → classe `SecaoManual` | um assunto do manual: `id`, `titulo`, `onde`, `icone`, `passos`, `dica` |
| `conteudo_manual.dart` → `const secoesManual = [...]` | os 13 assuntos. **Para mudar um texto do manual, mude aqui** |
| `conteudo_manual.dart` → `secaoInicialDaRota(rota)` | escolhe o assunto inicial: `/page2` abre "Disponibilidade", `/page3` abre "Gerar" e as outras abrem "Por onde começar" |
| `dialogo_manual.dart` → `mostrarManual(context, rotaAtual:)` | abre a janela `DialogoManual` |
| `dialogo_manual.dart` → `DialogoManual` / `_DialogoManualState` | índice à esquerda e passos à direita. `_ir(indice)` troca de assunto e volta a rolagem ao topo |
| `_Passo`, `_Dica` | desenham cada passo numerado e a caixa amarela de dica |

```dart
int secaoInicialDaRota(String? rota) {
  final id = switch (rota) {
    '/page2' => 'disponibilidade',
    '/page3' => 'gerar',
    _ => 'inicio',
  };
  return secoesManual.indexWhere((s) => s.id == id);
}
```

Nos textos do manual, o que estiver entre `**...**` sai em negrito.

### 0.5 Providers — de onde as páginas tiram os dados

São dois arquivos em `lib/providers/`. O `providers.dart` só reexporta os dois, por isso as telas fazem `import '.../providers/providers.dart'`.

**`repository_providers.dart`**: um `Provider` para cada repositório. Cada um entrega sempre o mesmo objeto:

```dart
final provedorRepositorioCurso = Provider<RepositorioCurso>(
  (ref) => RepositorioCurso(),
);
```

**`stream_providers.dart`**: um `StreamProvider` para cada lista. Cada um escuta o banco em tempo real:

```dart
final provedorCursos = StreamProvider<List<Curso>>((ref) {
  return ref.read(provedorRepositorioCurso).observarTodos();
});
```

| Provider | Entrega | Usado em |
|---|---|---|
| `provedorProfessores` | `List<Professor>` | Páginas 1, 2, 3 |
| `provedorProfessorMaterias` | vínculos professor–componente | Páginas 1, 3 |
| `provedorMaterias` | `List<Materia>` | Páginas 1, 3 |
| `provedorSalas` / `provedorTiposSala` | salas / tipos de sala | Páginas 1, 3 |
| `provedorCursos` | `List<Curso>` | Páginas 1, 3 |
| `provedorCargasCurso` | `List<CargaCursoMateria>` | Páginas 1, 3 |
| `provedorAulasGeminadasCurso` | `List<AulaGeminadaCurso>` (aulas divididas) | Páginas 1, 3 |
| `provedorAulas` | `List<Aula>` | Páginas 1 (avisos e exclusões), 3 |
| `provedorIndisponibilidades` | `List<IndisponibilidadeProfessor>` | Páginas 2, 3 |
| `provedorHorariosPeriodo` | texto da hora de cada período | Página 3 |

**As três palavras do Riverpod que aparecem em todas as páginas:**

| Chamada | Quando usar | O que faz |
|---|---|---|
| `ref.watch(p)` | dentro do `build` | lê **e se inscreve**. A tela se redesenha quando `p` muda |
| `ref.read(p)` | dentro de um clique ou ação | lê **uma vez**, sem se inscrever |
| `ref.invalidate(p)` | depois de gravar | descarta o valor e manda buscar de novo |

`ref.watch` de um `StreamProvider` devolve um `AsyncValue`, que pode estar carregando, com erro ou com dados. As páginas usam dois jeitos de abrir esse valor:

```dart
// 1) Mostrar carregando / erro / dados
cursosAsync.when(
  data: (cursos) => ListView(...),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, stack) => DicaColunaVazia(mensagem: 'Erro: $e'),
);

// 2) "Me dá a lista, ou uma vazia enquanto carrega"
final aulas = aulasAsync.valueOrNull ?? const <Aula>[];
```

### 0.6 Como os dados chegam em tempo real (`observar_tabela.dart`)

Todos os `observarTodos()` dos repositórios usam a função `observarTabela`:

```dart
Stream<List<T>> observarTabela<T>({
  required SupabaseClient client,
  required String tabela,
  required Future<List<T>> Function() buscar,
  Duration espera = const Duration(milliseconds: 300),
}) {
  final controller = StreamController<List<T>>();
  // ...
  final canal = client
      .channel('watch:$tabela:${_proximoCanal++}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tabela,
        callback: (_) {
          agendada?.cancel();
          agendada = Timer(espera, () => unawaited(emitir()));
        },
      )
      .subscribe();

  unawaited(emitir());   // primeira busca
  // ...
  return controller.stream;
}
```

1. Busca a tabela uma vez (`emitir()`).
2. Assina o **Realtime** do Supabase: o banco avisa quando a tabela muda.
3. Cada aviso reinicia um cronômetro de 300 ms. Só quando os avisos param ele busca de novo. Assim, "Gerar", que grava centenas de aulas, vira **uma** busca e não centenas.
4. `emitir()` guarda um número de "geração" (`minha == geracao`). Se uma resposta antiga chegar depois de uma nova, ela é descartada.

`buscarTodasLinhas` (`buscar_todas_linhas.dart`) busca de 1000 em 1000 linhas, porque o Supabase devolve no máximo 1000 por consulta.

### 0.7 Peças de tela usadas em várias páginas

#### `ColunaQuadro` (`lib/components/coluna_quadro.dart`)

É a coluna branca com cabeçalho verde. Aparece nas Páginas 1, 2 e 3.

| Parâmetro | Para quê |
|---|---|
| `titulo`, `icone` | o cabeçalho verde |
| `acoes` | botões à direita do título (ex.: `+`, lixeira, fechar) |
| `flex` | proporção da largura (Página 2: grade 7, lista 3) |
| `child` | conteúdo fixo, sem busca |
| `construirComBusca: (busca) => ...` | mostra o campo **Buscar** e monta o conteúdo com o texto digitado |

É um `StatefulWidget` porque guarda o texto da busca (`_controladorBusca`). A cada letra, `onChanged: (_) => setState(() {})` redesenha a coluna e chama de novo `construirComBusca(_controladorBusca.text)`:

```dart
final conteudo = construir == null
    ? widget.child!
    : construir(_controladorBusca.text);
```

No mesmo arquivo:
- `DicaColunaVazia(mensagem:)`: texto cinza centralizado ("Nenhum curso cadastrado").
- `DicaBuscaVazia(busca:)`: mostra "Nada encontrado para "..."".

#### `CartaoItem` (`lib/components/cartao_item.dart`)

É cada item das listas. Recebe `titulo`, `subtitulo`, `selecionado` e três callbacks opcionais: `aoTocar` (clicar no cartão), `aoEditar` (lápis) e `aoExcluir` (lixeira vermelha). O lápis e a lixeira só aparecem se o callback correspondente foi passado:

```dart
if (aoEditar != null)
  IconButton(onPressed: aoEditar, tooltip: 'Editar', icon: const Icon(Icons.edit_outlined, size: 20), /* ... */),
if (aoExcluir != null)
  IconButton(onPressed: aoExcluir, tooltip: 'Excluir', icon: const Icon(Icons.delete_outline, size: 20), /* ... */),
```

Por isso, na Página 2 e na lista de cursos da Página 3, os cartões não têm lápis nem lixeira: lá só se passa `aoTocar`.

#### `mostrarDialogoConfirmarExclusao` (`dialogs/dialogo_confirmar_exclusao.dart`)

É a janela "Tem certeza?" usada antes de toda exclusão e de "Gerar". Devolve `true` (confirmou) ou `false` (cancelou ou fechou):

```dart
Future<bool> mostrarDialogoConfirmarExclusao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String rotuloConfirmar = 'Excluir',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(rotuloConfirmar)),
      ],
    ),
  );
  return result ?? false;
}
```

**Padrão dos diálogos do projeto.** `showDialog` devolve um `Future` com o valor passado em `Navigator.pop(context, valor)`. Os formulários devolvem um objeto `Resultado...` preenchido, ou `null` se a pessoa cancelou. Por isso todas as páginas começam assim:

```dart
final result = await mostrarDialogoFormularioX(...);
if (result == null) return;   // cancelou
```

#### `GradeHoraria` e `CelulaGrade` (`lib/components/grade_horaria.dart`)

- `CelulaGrade(indiceDia, indicePeriodo)` identifica uma célula da grade. Dia vai de 0 (Seg) a 4 (Sex). Período vai de 0 a 15: 0–5 manhã, 6–11 tarde, 12–15 noite. O `==` e o `hashCode` foram reescritos para que duas células com os mesmos números sejam "iguais" (isso permite usá-las em `Set` e como chave de `Map`).
- `GradeHoraria` desenha a tabela 5 × 16, com as linhas "Almoço" e "Jantar". É usada pela Página 2 (modo `interativo`) e pela Página 3 (com `construirCelula`, que desenha cada célula).
- Constantes e funções estáticas usadas no projeto todo: `dias`, `periodos` (rótulos "1º M"...), `periodosManha`, `periodosTarde`, `periodosNoite`, `faixaDoPeriodo(p)` (0 manhã, 1 tarde, 2 noite) e `periodosNaMesmaFaixa(a, b)`.

```dart
children: [
  TableRow(/* cabeçalho Seg..Sex */),
  for (final p in periodosManha) _linhaPeriodo(p),
  _linhaSeparador('Almoço'),
  for (final p in periodosTarde) _linhaPeriodo(p),
  _linhaSeparador('Jantar'),
  for (final p in periodosNoite) _linhaPeriodo(p),
],
```

`_celulaSlot(celula)` decide o que desenhar em cada célula. Se há `construirCelula` (Página 3), usa ela. Se é `interativo` (Página 2), desenha um quadrado cinza, ou vermelho com o ícone de bloqueio se a célula está marcada, e chama `aoAlternar(celula)` no clique.

#### `correspondeBusca` (`lib/services/texto.dart`)

É a busca sem acento usada nas colunas:

```dart
String normalizarTexto(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  // troca cada letra acentuada pela sem acento e põe tudo em minúsculas
}

bool correspondeBusca(String texto, String busca) {
  final termo = normalizarTexto(busca.trim());
  if (termo.isEmpty) return true;
  return normalizarTexto(texto).contains(termo);
}
```

### 0.8 O índice 0 da tela e o índice 1 do banco

No Dart, dia e período começam em **0**. No banco começam em **1**. A conversão é feita **só** nos models e repositórios. Exemplo de `lib/model/aula/aula.dart`:

```dart
// banco → Dart (fromJson)
indiceDia: (json['dia_semana'] as num).toInt() - 1,
indicePeriodo: (json['periodo'] as num).toInt() - 1,

// Dart → banco (toInsertJson)
'dia_semana': indiceDia + 1,
'periodo': indicePeriodo + 1,
```

Os ids também mudam de tipo: são `String` no Dart e número no banco (por isso aparece `int.parse(id)` em todos os repositórios).

---

## Parte 1 — Página 1: Cadastros

### 1.1 O que a página faz

Cadastra os quatro tipos de dado que o resto do sistema usa: **professores**, **componentes** (matérias), **salas** e **cursos** (turmas, com carga e aulas divididas).

### 1.2 Mapa de arquivos

```
lib/pages/page1/page1.dart                    Page1
lib/pages/page1/columns/coluna_professor.dart ColunaProfessor ── dialogo_formulario_professor.dart ── RepositorioProfessor
lib/pages/page1/columns/coluna_materia.dart   ColunaMateria   ── dialogo_formulario_materia.dart   ── RepositorioMateria
lib/pages/page1/columns/coluna_sala.dart      ColunaSala      ── dialogo_numero.dart               ── RepositorioSala / RepositorioTipoSala
lib/pages/page1/columns/coluna_curso.dart     ColunaCurso     ── dialogo_formulario_curso.dart     ── RepositorioCurso
                                                              ── impacto_edicao_curso.dart, arrumacao_grupos.dart
```

**As quatro colunas seguem o mesmo molde.** Se você entender uma, entende as quatro:

| Método | Quando roda | Sequência |
|---|---|---|
| `build` | ao desenhar | `ref.watch` da lista → `ColunaQuadro` → `CartaoItem` para cada item filtrado pela busca |
| `_criar` | botão **+** | abre o formulário vazio → `repositorio.adicionar(...)` → `ref.invalidate(...)` |
| `_editar` | lápis | busca os dados atuais → abre o formulário preenchido → `repositorio.atualizar(...)` → `invalidate` |
| `_excluir` | lixeira | `mostrarDialogoConfirmarExclusao` → `repositorio.excluir(id)` → ajustes → `invalidate` |
| `_mostrarErro` | se der erro | mostra um `SnackBar` com `'Erro: $e'` |

### 1.3 `Page1` (`page1.dart`)

Só organiza as quatro colunas lado a lado. Não tem estado nem lógica:

```dart
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
```

Cada coluna é um `ColunaQuadro`, e o `ColunaQuadro` já é um `Expanded` com `flex: 1`. Por isso as quatro dividem a largura igualmente.

---

### 1.4 `ColunaProfessor` (`columns/coluna_professor.dart`)

`ConsumerWidget`, ou seja, um widget sem estado que recebe `ref` para usar os providers.

#### `build` — desenhar a lista

```dart
final professorsAsync = ref.watch(provedorProfessores);
final linksAsync = ref.watch(provedorProfessorMaterias);

return ColunaQuadro(
  titulo: 'Professores',
  icone: Icons.person_outline,
  acoes: [
    IconButton(
      onPressed: () => _criar(context, ref),
      tooltip: 'Adicionar professor',
      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
      // ...
    ),
  ],
  construirComBusca: (busca) => professorsAsync.when(
    data: (todos) {
      if (todos.isEmpty) {
        return const DicaColunaVazia(mensagem: 'Nenhum professor cadastrado');
      }
      final professores = todos
          .where((p) => correspondeBusca(p.nome, busca))
          .toList();
      if (professores.isEmpty) return DicaBuscaVazia(busca: busca);

      final ligacoes = linksAsync.valueOrNull ?? const [];
      return ListView(
        children: professores.map((professor) {
          final count = ligacoes
              .where((link) => link.idProfessor == professor.id)
              .length;
          return CartaoItem(
            titulo: professor.nome,
            subtitulo: count == 1 ? '1 componente' : '$count componentes',
            aoEditar: () => _editar(context, ref, professor),
            aoExcluir: () => _excluir(context, ref, professor),
          );
        }).toList(),
      );
    },
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, stack) => DicaColunaVazia(mensagem: 'Erro: $e'),
  ),
);
```

- Observa **duas** listas: professores e vínculos. O vínculo é usado para contar "3 componentes".
- A busca filtra por nome com `correspondeBusca`, que ignora acento e maiúsculas.

#### `_criar` — novo professor

```dart
Future<void> _criar(BuildContext context, WidgetRef ref) async {
  final materias = _materiasOuVazio(ref.read(provedorMaterias));
  final result = await mostrarDialogoFormularioProfessor(
    context,
    titulo: 'Novo professor',
    materias: materias,
  );
  if (result == null) return;

  try {
    await ref.read(provedorRepositorioProfessor).adicionar(
          result.nome,
          idsMaterias: result.idsMaterias,
        );
    ref.invalidate(provedorProfessores);
    ref.invalidate(provedorProfessorMaterias);
  } catch (e) {
    if (!context.mounted) return;
    _mostrarErro(context, e);
  }
}
```

**O que vai para onde:** a lista de componentes vai para o formulário, que devolve `ResultadoFormularioProfessor(nome, idsMaterias)`. Esse resultado vai para `RepositorioProfessor.adicionar(nome, idsMaterias:)`.

`_materiasOuVazio` é só `subjectsAsync.valueOrNull ?? const []`. Se os componentes ainda não carregaram, o formulário abre com a lista vazia.

`if (!context.mounted) return;` aparece depois de todo `await`. Ele evita usar a tela se o usuário já saiu dela enquanto o banco respondia.

#### `_editar` — editar professor

```dart
final List<String> currentIds;
try {
  currentIds = await ref
      .read(provedorRepositorioProfessor)
      .buscarIdsMaterias(professor.id);
} catch (e) { /* mostra erro e sai */ }
if (!context.mounted) return;

final result = await mostrarDialogoFormularioProfessor(
  context,
  titulo: 'Editar professor',
  materias: materias,
  nomeInicial: professor.nome,
  idsMateriasIniciais: currentIds,
);
if (result == null) return;

await ref.read(provedorRepositorioProfessor).atualizar(
      Professor(id: professor.id, nome: result.nome),
      idsMaterias: result.idsMaterias,
    );
ref.invalidate(provedorProfessores);
ref.invalidate(provedorProfessorMaterias);
```

Antes de abrir o formulário, busca no banco quais componentes o professor já dá (`buscarIdsMaterias`), para as caixinhas já virem marcadas.

#### `_excluir` — excluir professor

```dart
final confirmed = await mostrarDialogoConfirmarExclusao(
  context,
  titulo: 'Excluir professor',
  mensagem:
      'Excluir "${professor.nome}"? Também remove suas aulas na grade '
      'e indisponibilidades.',
);
if (!confirmed) return;

final repoAula = ref.read(provedorRepositorioAula);
final todasAulas = await repoAula.buscarTodos();
final pares = await ref.read(provedorRepositorioCurso).buscarTodasAulasGeminadas();
// Se ele dava o grupo 2 de um par, o grupo 1 que sobra passa para o
// grupo 2 (G1 livre), como ao excluir o grupo 2 na grade.
final paraGrupo2 = aulasQueVaoParaGrupo2(
  excluidas: todasAulas.where((a) => a.idProfessor == professor.id).toList(),
  todasAulas: todasAulas,
  pares: pares,
);
await ref.read(provedorRepositorioProfessor).excluir(professor.id);
for (final aula in paraGrupo2) {
  await repoAula.atualizar(aula);
}
ref.invalidate(provedorProfessores);
ref.invalidate(provedorProfessorMaterias);
ref.invalidate(provedorAulas);
ref.invalidate(provedorIndisponibilidades);
```

Por que tanto passo? O banco apaga em **cascata** os vínculos, as indisponibilidades e as aulas do professor. Mas, se ele dava uma das metades de uma aula dividida (G1/G2), a outra metade fica sozinha. A regra do sistema é: uma aula dividida que perdeu uma metade fica no **grupo 2**, com o G1 livre. `aulasQueVaoParaGrupo2` calcula **antes** de excluir quais aulas precisam mudar de grupo. Depois da exclusão, cada uma é atualizada.

#### Formulário do professor (`dialogs/dialogo_formulario_professor.dart`)

| Peça | O que é |
|---|---|
| `ResultadoFormularioProfessor(nome, idsMaterias)` | o que o formulário devolve |
| `mostrarDialogoFormularioProfessor(context, titulo:, materias:, nomeInicial:, idsMateriasIniciais:)` | abre o formulário |
| `_ProfessorFormDialog` / `_ProfessorFormDialogState` | o formulário em si. Guarda `_controlador` (nome), `_idsSelecionados` (um `Set` com as caixinhas marcadas) e `_erro` |

```dart
void _enviar() {
  final nome = _controlador.text.trim();
  if (nome.isEmpty) {
    setState(() => _erro = 'Informe um nome');
    return;
  }
  Navigator.of(context).pop(
    ResultadoFormularioProfessor(
      nome: nome,
      idsMaterias: _idsSelecionados.toList(),
    ),
  );
}
```

Cada componente vira um `CheckboxListTile`. Marcar faz `_idsSelecionados.add(subject.id)`, desmarcar faz `remove`.

#### Repositório (`RepositorioProfessor`)

```dart
Future<String> adicionar(String nome, {List<String> idsMaterias = const []}) async {
  final row = await _client.from(_table).insert({'nome': nome}).select('id').single();
  final id = row['id'].toString();
  await definirMaterias(id, idsMaterias);
  return id;
}

Future<void> definirMaterias(String idProfessor, List<String> idsMaterias) async {
  final parsedProfessorId = int.parse(idProfessor);
  await _client.from(_linkTable).delete().eq('id_professor', parsedProfessorId);
  if (idsMaterias.isEmpty) return;
  await _client.from(_linkTable).insert(
        idsMaterias.map((idMateria) => {
              'id_professor': parsedProfessorId,
              'id_materia': int.parse(idMateria),
            }).toList(),
      );
}
```

`definirMaterias` **apaga todos os vínculos e insere de novo** os marcados. É mais simples que calcular o que entrou e o que saiu. As tabelas usadas são `tb_professor` e `tb_professor_materia`.

---

### 1.5 `ColunaMateria` (`columns/coluna_materia.dart`) — Componentes

Tem o mesmo molde da coluna de professores, com três diferenças.

**1) Clicar no cartão também edita:**

```dart
return CartaoItem(
  titulo: subject.nome,
  subtitulo: count == 1 ? '1 professor' : '$count professores',
  // Clicar na matéria abre o mesmo formulário de edição.
  aoTocar: () => _editar(context, ref, subject),
  aoEditar: () => _editar(context, ref, subject),
  aoExcluir: () => _excluir(context, ref, subject),
);
```

**2) `_editar` usa os vínculos já carregados.** Assim o formulário abre na hora. Só vai ao banco se ainda não carregou:

```dart
final ligacoes = ref.read(provedorProfessorMaterias).value;
final List<String> idsAtuais;
if (ligacoes != null) {
  idsAtuais = ligacoes
      .where((link) => link.idMateria == subject.id)
      .map((link) => link.idProfessor)
      .toList();
} else {
  idsAtuais = await repo.buscarIdsProfessores(subject.id);
}
// ...
await repo.atualizar(
  Materia(id: subject.id, nome: result.nome),
  idsProfessores: result.idsProfessores,
);
```

**3) `_excluir` conserta os grupos depois:**

```dart
await ref.read(provedorRepositorioMateria).excluir(subject.id);
// O banco apaga os pares de aula geminada com essa matéria; as aulas
// da outra matéria do par que ficaram sozinhas viram aulas completas.
await arrumarGruposSemPar(
  repoAula: ref.read(provedorRepositorioAula),
  repoCurso: ref.read(provedorRepositorioCurso),
);
ref.invalidate(provedorMaterias);
ref.invalidate(provedorCargasCurso);
ref.invalidate(provedorAulasGeminadasCurso);
ref.invalidate(provedorProfessorMaterias);
ref.invalidate(provedorAulas);
```

Excluir um componente apaga em cascata as aulas dele, a carga, os vínculos **e as aulas divididas que o usavam**. Como o par deixa de existir, a aula do outro componente que estava no grupo 2 vira aula da turma inteira (grupo 1). É isso que `arrumarGruposSemPar` faz (ver 1.8).

O formulário (`dialogo_formulario_materia.dart`) é uma cópia do formulário de professor com os lados trocados: `ResultadoFormularioMateria(nome, idsProfessores)`, com caixinhas de professores. O repositório usa `definirProfessores(idMateria, ids)`, que grava na mesma tabela `tb_professor_materia`, vista pelo outro lado.

---

### 1.6 `ColunaSala` (`columns/coluna_sala.dart`)

#### `build`

```dart
final roomsAsync = ref.watch(provedorSalas);
// Mantém a lista de tipos carregada para o diálogo de sala.
ref.watch(provedorTiposSala);
// ... filtra por correspondeBusca(s.rotulo, busca) e mostra CartaoItem(titulo: room.rotulo, ...)
```

`room.rotulo` vem do model: `'${tipo.nome} $numero'`, por exemplo "Laboratório de informática 1". O `ref.watch(provedorTiposSala)` não usa o valor. Ele existe só para a lista de tipos já estar pronta quando o formulário abrir.

#### `_criarTipo` — criar um tipo novo de dentro do formulário

```dart
Future<TipoSala> _criarTipo(WidgetRef ref, String nome) async {
  final novo = await ref.read(provedorRepositorioTipoSala).adicionar(nome);
  ref.invalidate(provedorTiposSala);
  return novo;
}
```

A função é passada para o formulário como callback (`aoCriarTipo`). O formulário cria o tipo "Quadra" sem fechar.

#### `_criar` e `_editar`

```dart
final dados = await mostrarDialogoNumero(
  context,
  titulo: 'Nova sala',
  rotulo: 'Número da sala',
  tipos: ref.read(provedorTiposSala).valueOrNull ?? const [],
  aoCriarTipo: (nome) => _criarTipo(ref, nome),
);
if (dados == null) return;

try {
  await ref.read(provedorRepositorioSala).adicionar(dados.numero, dados.tipo);
  ref.invalidate(provedorSalas);
} on SalaDuplicada {
  _mostrarErro(context, 'Esse número já está em uso para ${dados.tipo.nome}.');
} catch (e) {
  _mostrarErro(context, e);
}
```

`on SalaDuplicada` trata um erro específico. O banco tem uma regra única `(id_tipo_sala, numero)`, que impede duas "Sala de aula 1". Quando o banco recusa, ele devolve o código `23505`. O repositório transforma esse código numa exceção com nome:

```dart
// RepositorioSala.adicionar
} on PostgrestException catch (e) {
  if (e.code == '23505') throw const SalaDuplicada();
  rethrow;
}
```

`_editar` é igual, passando `numeroInicial: room.numero` e `tipoInicial: room.tipo`, e chamando `atualizar(Sala(id:, numero:, tipo:))`.

#### `_excluir`

```dart
mensagem: 'Excluir ${room.rotulo}? Cursos e aulas que usavam esta '
    'sala ficam sem sala.',
// ...
await ref.read(provedorRepositorioSala).excluir(room.id);
ref.invalidate(provedorSalas);
ref.invalidate(provedorCursos);
ref.invalidate(provedorAulas);
```

Aqui não há cascata de exclusão. O banco usa `on delete set null`: a sala some e as aulas e os cursos que a usavam ficam com `id_sala = null`. Por isso também invalida cursos e aulas.

#### Formulário de sala (`dialogs/dialogo_numero.dart`)

| Peça | O que é |
|---|---|
| `DadosSala(numero, tipo)` | o que o formulário devolve |
| `_NumberFormDialogState` | guarda `_tipos` (cópia da lista), `_tipo` (escolhido), `_criandoTipo` (se está mostrando o campo "Novo tipo"), `_erro` e `_erroTipo` |
| `_salvarNovoTipo()` | cria o tipo. Se já existe um com o mesmo nome (sem diferença de maiúsculas), só seleciona ele |
| `_enviar()` | valida e devolve `DadosSala` |

```dart
void _enviar() {
  final tipo = _tipo;
  if (tipo == null) {
    setState(() => _erro = 'Escolha ou crie um tipo de sala');
    return;
  }
  final raw = _controlador.text.trim();
  final numero = int.tryParse(raw);
  if (numero == null || numero < 1) {
    setState(() => _erro = 'Informe um número válido (≥ 1)');
    return;
  }
  Navigator.of(context).pop(DadosSala(numero: numero, tipo: tipo));
}
```

O campo de número usa `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`, então só aceita dígitos.

---

### 1.7 `ColunaCurso` (`columns/coluna_curso.dart`) — a coluna mais completa

#### `build` — o subtítulo de cada curso

A coluna observa quatro listas: cursos, cargas, aulas divididas e salas. Para cada curso, monta o subtítulo "Manhã · 14 componentes · 29 aulas · Sala de aula 1":

```dart
final courseLoads = cargas.where((load) => load.idCurso == course.id);
final totalAulas = courseLoads.fold<int>(0, (sum, load) => sum + load.quantidadeAulas);
final materiaCount = courseLoads.length;
final geminatedCount = aulasGeminadas.where((pair) => pair.idCurso == course.id).length;
final room = course.idSala == null ? null : salasPorId[course.idSala!];

final parts = <String>[
  course.preferenciaPeriodo.rotulo,
  if (geminatedCount > 0) '$geminatedCount aula(s) dividida(s)',
  if (materiaCount == 0)
    'Sem componentes'
  else
    '$materiaCount ${materiaCount == 1 ? 'componente' : 'componentes'}'
        ' · $totalAulas ${totalAulas == 1 ? 'aula' : 'aulas'}',
  if (room != null) room.rotulo,
];
```

`fold` soma os itens de uma lista: começa em 0 e vai somando `quantidadeAulas`.

#### `_criar` — novo curso

```dart
final result = await mostrarDialogoFormularioCurso(
  context,
  titulo: 'Novo curso',
  materias: materias,
  salas: salas,
);
if (result == null) return;

await ref.read(provedorRepositorioCurso).adicionar(
      result.nome,
      idSala: result.idSala,
      preferenciaPeriodo: result.preferenciaPeriodo,
      cargas: result.cargas,
      aulasGeminadas: result.aulasGeminadas,
    );
ref.invalidate(provedorCursos);
ref.invalidate(provedorCargasCurso);
ref.invalidate(provedorAulasGeminadasCurso);
```

#### `_editar` — editar curso (o fluxo mais importante da Página 1)

```dart
final repo = ref.read(provedorRepositorioCurso);
cargas = await repo.buscarCargas(course.id);
aulasGeminadas = await repo.buscarAulasGeminadas(course.id);

final result = await mostrarDialogoFormularioCurso(
  context,
  titulo: 'Editar curso',
  materias: materias,
  salas: salas,
  nomeInicial: course.nome,
  idSalaInicial: course.idSala,
  preferenciaPeriodoInicial: course.preferenciaPeriodo,
  cargasIniciais: cargas,
  aulasGeminadasIniciais: aulasGeminadas,
  idCurso: course.id,
  // Antes de fechar: avisa se a edição apaga aulas da grade (componente
  // tirado da carga) ou deixa aulas fora do novo turno.
  confirmarAntesDeSalvar: (r) async {
    final impacto = impactoEdicaoCurso(
      idCurso: course.id,
      turnoAntigo: course.preferenciaPeriodo,
      turnoNovo: r.preferenciaPeriodo,
      cargasNovas: r.cargas,
      aulas: ref.read(provedorAulas).valueOrNull ?? const [],
      nomesComponentes: {for (final m in materias) m.id: m.nome},
    );
    final mensagem = impacto.mensagem;
    if (mensagem == null || !context.mounted) return true;
    return mostrarDialogoConfirmarExclusao(
      context,
      titulo: 'Salvar curso?',
      mensagem: mensagem,
      rotuloConfirmar: 'Salvar',
    );
  },
);
if (result == null) return;

await repo.atualizar(
  Curso(id: course.id, nome: result.nome, idSala: result.idSala, preferenciaPeriodo: result.preferenciaPeriodo),
  anterior: course,
  cargas: result.cargas,
  aulasGeminadas: result.aulasGeminadas,
);
// Par tirado do curso: aulas que estavam sozinhas no grupo 2 viram
// aulas completas.
await arrumarGruposSemPar(repoAula: ref.read(provedorRepositorioAula), repoCurso: repo);
ref.invalidate(provedorCursos);
ref.invalidate(provedorCargasCurso);
ref.invalidate(provedorAulasGeminadasCurso);
ref.invalidate(provedorAulas);
```

**Passo a passo:**

1. Busca no banco a carga e as aulas divididas do curso, para preencher o formulário.
2. Abre o formulário e passa uma função `confirmarAntesDeSalvar`. O formulário chama essa função depois de validar os campos e antes de fechar.
3. A função calcula o **impacto** (`impactoEdicaoCurso`). Se a edição apaga aulas ou deixa aulas fora do turno, pergunta "Salvar curso?". Se a pessoa cancela, o formulário **continua aberto** com tudo o que ela digitou.
4. Grava com `repo.atualizar(..., anterior: course, ...)`.
5. `arrumarGruposSemPar` conserta aulas que perderam o par.
6. Invalida quatro providers, porque a edição pode mudar cursos, cargas, pares e aulas.

#### `_excluir`

```dart
mensagem: 'Excluir "${course.nome}", sua carga e todas as aulas da grade?',
// ...
await ref.read(provedorRepositorioCurso).excluir(course.id);
```

O banco apaga em cascata a carga, os pares e as aulas do curso.

#### Formulário de curso (`dialogs/dialogo_formulario_curso.dart`)

É o maior arquivo da Página 1 (≈ 900 linhas), mas tem só estas classes:

| Classe | Papel |
|---|---|
| `ResultadoFormularioCurso` | o que volta: `nome`, `idSala`, `preferenciaPeriodo`, `cargas` (`List<CargaCursoMateria>`) e `aulasGeminadas` (`List<AulaGeminadaCurso>`) |
| `_LinhaCarga` | uma linha de "Componentes, carga e blocos": `idMateria`, `controladorQuantidade` (texto da Qtd. de aulas) e `tamanhoBloco` |
| `_LinhaAulaGeminada` | uma linha de "Aulas divididas": `idMateriaA`, `idMateriaB`, `controladorPeriodos` (aulas do A), `controladorPeriodosB` (aulas do B; vazio = igual ao A) e `quantidadeBlocos` |
| `_CourseFormDialog` / `_CourseFormDialogState` | o formulário. Guarda as listas `_linhas` e `_linhasGeminadas`, `_idSala`, `_preferenciaPeriodo` e os erros `_erroNome`, `_errosCarga[i]`, `_errosDividida[i]` |
| `_TextoErro` | o texto vermelho embaixo de uma linha com erro |
| `BotaoAjudaBloco`, `BotaoAjudaBlocosGeminada` (em `dialogo_ajuda_bloco.dart`) | os botões **?** que abrem um exemplo desenhado numa mini grade (`_MiniGrade`) |

**Campos do formulário:**
- `Nome do curso` (`TextField`).
- `Turno` (`DropdownButtonFormField<PreferenciaPeriodo>`) com os 5 valores do enum.
- `Sala padrão (opcional)`.
- Linhas de carga, com os botões `+ Linha` (`_adicionarLinha`) e `X` (`_removerLinha`).
- Linhas de aula dividida, com os botões `+ Aula` (`_adicionarLinhaGeminada`) e `_removerLinhaGeminada`.

**Funções de cálculo do formulário:**

```dart
int _limiteBloco(_LinhaCarga row) {
  final pelaCarga = _quantidadeAulas(row);
  final turno = _preferenciaPeriodo.maxAulasPorBloco;
  return pelaCarga < turno ? pelaCarga : turno;
}
```

O bloco não pode passar da carga do componente nem do tamanho do turno (6 de manhã e de tarde, 4 à noite). O dropdown "Bloco" mostra de 1 até `_limiteBloco`:

```dart
items: [
  for (var value = 1; value <= _limiteBloco(_linhas[i]); value++)
    DropdownMenuItem(value: value, child: Text('$value')),
],
```

Para aula dividida, `_minimoBlocosGeminada` calcula o menor número de blocos que não deixa nenhum bloco maior que um turno. A conta é `(aulas + max - 1) ~/ max`, ou seja, a divisão arredondada para cima.

**`_enviar()` — validações, na ordem em que acontecem:**

| # | Regra | Mensagem |
|---|---|---|
| 1 | nome vazio | "Informe o nome do curso" |
| 2 | Qtd. de aulas não é número ≥ 1 | "Quantidade de aulas deve ser um número ≥ 1" |
| 3 | componente repetido | "Cada componente só pode aparecer uma vez" |
| 4 | bloco maior que a carga | "Bloco não pode ser maior que a carga do componente" |
| 5 | aula dividida com só um componente | "Informe os dois componentes da aula dividida" |
| 6 | A igual a B | "Aula dividida precisa de dois componentes diferentes" |
| 7 | componente fora da carga | "Aulas divididas devem usar componentes da carga do curso" |
| 8 | qtd. inválida na aula dividida | "Qtd. de aulas da aula dividida deve ser um número ≥ 1" |
| 9 | blocos fora da faixa | "Blocos da aula dividida devem ir de 1 até a quantidade de aulas" |
| 10 | bloco maior que um turno | "Cada bloco da aula dividida pode ter no máximo N aulas (um turno)" |
| 11 | aula dividida passa da carga | "Aulas divididas não podem passar da carga dos componentes" |
| 12 | várias divididas somadas passam da carga | "A soma das aulas divididas passa da carga de um componente" |
| 13 | par repetido | "Par de aula dividida repetido" |

Cada erro é guardado em `_errosCarga[i]` ou `_errosDividida[i]` (a chave é o número da linha) e aparece embaixo daquela linha. O getter `_resumoErro` mostra, ao lado do botão Salvar, onde está o erro ("Corrija a linha 3 dos componentes."), porque a lista pode estar rolada.

Trecho real do começo e do fim de `_enviar`:

```dart
Future<void> _enviar() async {
  setState(_limparErros);
  final nome = _controladorNome.text.trim();
  if (nome.isEmpty) {
    setState(() => _erroNome = 'Informe o nome do curso');
    return;
  }
  // ... monta `cargas` e `aulasGeminadas` validando cada linha ...

  setState(_limparErros);
  final resultado = ResultadoFormularioCurso(
    nome: nome,
    idSala: _idSala,
    preferenciaPeriodo: _preferenciaPeriodo,
    cargas: cargas,
    aulasGeminadas: aulasGeminadas,
  );
  // Ex.: componente tirado da carga apaga aulas da grade; quem abriu o
  // formulário pergunta antes. Cancelando, o formulário continua aberto.
  final confirmar = widget.confirmarAntesDeSalvar;
  if (confirmar != null && !await confirmar(resultado)) return;
  if (!mounted) return;
  Navigator.of(context).pop(resultado);
}
```

Linhas com o componente vazio são ignoradas (`if (idMateria == null) continue;`). Por isso uma linha em branco não dá erro.

#### `impactoEdicaoCurso` (`services/impacto_edicao_curso.dart`)

É uma função pura (não acessa banco nem tela) que calcula o aviso:

```dart
final naCarga = {for (final c in cargasNovas) c.idMateria};
final doCurso = aulas.where((a) => a.idCurso == idCurso).toList();

final apagadas = doCurso.where((a) => !naCarga.contains(a.idMateria));
// ...
if (turnoNovo != turnoAntigo) {
  final periodos = {for (final t in turnoNovo.turnos) ...t};
  foraDoTurno = doCurso
      .where((a) => naCarga.contains(a.idMateria) && !periodos.contains(a.indicePeriodo))
      .length;
}
```

- **Aulas apagadas**: aulas de componentes que saíram da carga. O banco apaga essas aulas ao salvar, dentro da função `salvar_carga_e_pares`.
- **Aulas fora do turno**: só conta quando o turno mudou. Essas aulas **não** são apagadas, só avisadas ("use Gerar para refazer").

O resultado é `ImpactoEdicaoCurso(aulasApagadas, componentesRemovidos, aulasForaDoTurno)`. O getter `mensagem` monta o texto, ou devolve `null` se não há nada a avisar.

#### Repositório (`RepositorioCurso`)

```dart
Future<String> adicionar(String nome, {String? idSala, PreferenciaPeriodo preferenciaPeriodo = ..., List<CargaCursoMateria> cargas = const [], List<AulaGeminadaCurso> aulasGeminadas = const []}) async {
  // ...
  final row = await _client.from(_table).insert(curso.toInsertJson()).select('id').single();
  final id = row['id'].toString();
  try {
    await salvarCargaEPares(id, cargas: cargas, aulasGeminadas: aulasGeminadas);
  } catch (_) {
    // Sem a carga o curso ficaria pela metade: desfaz a criação.
    try { await excluir(id); } catch (_) {}
    rethrow;
  }
  return id;
}

Future<void> atualizar(Curso course, {Curso? anterior, required List<CargaCursoMateria> cargas, required List<AulaGeminadaCurso> aulasGeminadas}) async {
  await _gravarCurso(course);
  try {
    await salvarCargaEPares(course.id, cargas: cargas, aulasGeminadas: aulasGeminadas);
  } catch (_) {
    if (anterior != null) {
      try { await _gravarCurso(anterior); } catch (_) {}
    }
    rethrow;
  }
}

Future<void> salvarCargaEPares(String idCurso, {required List<CargaCursoMateria> cargas, required List<AulaGeminadaCurso> aulasGeminadas}) async {
  // ...
  await _client.rpc(
    'salvar_carga_e_pares',
    params: {
      'p_id_curso': int.parse(idCurso),
      'p_cargas': [for (final c in cargas) c.toInsertJson()],
      'p_pares': [for (final par in pares.values) par.toInsertJson(idCursoOverride: idCurso)],
    },
  );
}
```

- O curso fica em `tb_curso`, a carga em `tb_curso_materia` e as aulas divididas em `tb_curso_aula_geminada`.
- `salvar_carga_e_pares` é uma **função do banco** (RPC) que roda numa **transação**: troca a carga e os pares e apaga as aulas de componentes que saíram, tudo ou nada.
- `adicionar` desfaz o curso se a carga falhar. `atualizar` volta o nome, o turno e a sala para `anterior` se a carga falhar. Assim nunca fica "turno novo com carga antiga".

#### Models usados pelo curso

**`PreferenciaPeriodo`** (enum, `model/curso/preferencia_periodo.dart`), que é o turno:

```dart
enum PreferenciaPeriodo {
  manha, tarde, noite, manhaTarde, tardeManha;

  String toDb() => switch (this) {
    PreferenciaPeriodo.manha => 'apenas_manha',
    PreferenciaPeriodo.tarde => 'apenas_tarde',
    PreferenciaPeriodo.noite => 'noite',
    PreferenciaPeriodo.manhaTarde => 'manha_tarde',
    PreferenciaPeriodo.tardeManha => 'tarde_manha',
  };

  String get rotulo => switch (this) {
    // 'Manhã', 'Tarde', 'Noite', 'Manhã - CT: Tarde', 'Tarde - CT: Manhã'
  };

  /// Turnos que o gerador usa, na ordem em que preenche.
  List<List<int>> get turnos {
    // manha → [manhã]; manhaTarde → [manhã, tarde]; tardeManha → [tarde, manhã]; noite → [noite]
  }

  int get maxAulasPorBloco =>
      turnos.map((t) => t.length).reduce((a, b) => a > b ? a : b);
}
```

"CT" significa **contraturno**: o gerador preenche primeiro o turno principal, e o que não couber vai para o outro.

**`CargaCursoMateria`**: `idCurso`, `idMateria`, `quantidadeAulas` e `tamanhoBloco`. Exemplo: "Informática 1 tem 4 aulas de Matemática 1, em blocos de 2".

**`AulaGeminadaCurso`** é a **aula dividida**. No código o nome é "geminada"; na tela, "dividida". É um par de componentes no mesmo horário, com a turma separada em G1 e G2.

```dart
/// Ex.: A = 2 e B = 4 ocupam 4 horários: nos 2 primeiros G1 tem A e G2 tem B;
/// nos 2 últimos só G2 tem aula (B) e o G1 fica livre.
int get juntas => math.min(quantidadeA, quantidadeB);            // horários com os dois grupos
int get periodosOcupados => math.max(quantidadeA, quantidadeB);  // horários usados pelo par
int get periodosSoMaior => periodosOcupados - juntas;            // horários de "G1 livre"
String get idMateriaMaior => quantidadeA > quantidadeB ? idMateriaA : idMateriaB; // vai no G2
List<int> get tamanhosBlocos => dividirEmBlocos(periodosOcupados, quantidadeBlocos); // 5 em 2 → [3, 2]
```

O construtor (`factory AulaGeminadaCurso(...)`) sempre guarda o par com o **menor id primeiro**, porque o banco exige `id_materia_a < id_materia_b`. Se precisar inverter, as quantidades trocam junto.

---

### 1.8 Arrumação de grupos (`services/arrumacao_grupos.dart`)

Quando um par de aula dividida deixa de existir, ou perde uma metade, as aulas que sobram precisam continuar coerentes:

| Função | Regra | Quem chama |
|---|---|---|
| `aulasQueViramCompletas(aulas, pares)` | aula **sozinha no grupo 2** cujo componente não está mais em nenhum par vira aula comum (grupo 1) | `arrumarGruposSemPar` |
| `aulasQueVaoParaGrupo2(excluidas:, todasAulas:, pares:)` | numa célula com par, se a aula excluída era o G2, a que sobra no G1 passa para o G2 (G1 livre) | `ColunaProfessor._excluir` |
| `arrumarGruposSemPar(repoAula:, repoCurso:)` | busca aulas e pares no banco e grava as correções | `ColunaMateria._excluir`, `ColunaCurso._editar` |

```dart
Future<void> arrumarGruposSemPar({
  required RepositorioAula repoAula,
  required RepositorioCurso repoCurso,
}) async {
  final aulas = await repoAula.buscarTodos();
  final pares = await repoCurso.buscarTodasAulasGeminadas();
  for (final aula in aulasQueViramCompletas(aulas, pares)) {
    await repoAula.atualizar(aula);
  }
}
```

### 1.9 Perguntas prováveis sobre a Página 1

**"Onde fica a validação do cadastro de curso?"**
Em `_CourseFormDialogState._enviar()` (`dialogo_formulario_curso.dart`). São 13 regras (tabela em 1.7). Os erros aparecem embaixo do campo e o formulário só fecha quando está tudo certo.

**"O que acontece se eu tirar um componente da carga de um curso que já tem horário?"**
`impactoEdicaoCurso` conta as aulas que serão apagadas e pergunta antes. Ao salvar, a função do banco `salvar_carga_e_pares` apaga essas aulas na mesma transação.

**"E se eu mudar o turno do curso?"**
As aulas que ficam fora do novo turno **não** são apagadas, só avisadas. O usuário decide se clica em "Gerar".

**"Por que vocês apagam e inserem de novo os vínculos professor–componente?"**
`definirMaterias` / `definirProfessores` apagam os vínculos e inserem os marcados. É mais simples e não deixa vínculo esquecido. A tabela é pequena.

**"Como funciona a busca sem acento?"**
`correspondeBusca` em `services/texto.dart` troca letras acentuadas por sem acento (`normalizarTexto`) nos dois lados e usa `contains`.

**"O que acontece ao excluir uma sala?"**
O banco usa `on delete set null`: aulas e cursos ficam sem sala. Nada é apagado.

**"Por que existem `SalaDuplicada` e `TipoSalaDuplicado`?"**
O banco tem regras únicas. O repositório traduz o código de erro `23505` (violação de unicidade) nessas exceções, para a tela mostrar uma mensagem clara.

**"Por que o formulário não fecha quando cancelo o aviso 'Salvar curso?'?"**
`confirmarAntesDeSalvar` é chamado antes do `Navigator.pop`. Se devolve `false`, `_enviar` faz `return` sem fechar.

---

## Parte 2 — Página 2: Disponibilidade

### 2.1 O que a página faz

Marca os horários em que cada professor **não pode** dar aula. Cada clique grava na hora. O gerador e as edições da Página 3 respeitam essas marcações.

### 2.2 Mapa de arquivos

```
lib/pages/page2/page2.dart                Page2 / _Page2State
lib/components/grade_horaria.dart         GradeHoraria(interativo: true)
lib/components/coluna_quadro.dart         ColunaQuadro (grade e lista)
lib/components/cartao_item.dart           CartaoItem (cada professor)
lib/services/repositories/repositorio_indisponibilidade.dart
lib/model/professor/indisponibilidade_professor.dart
tabela: tb_professor_indisponibilidade (id_professor, dia_semana 1–5, periodo 1–16)
```

### 2.3 `Page2` e `_Page2State`

`Page2` é um `ConsumerStatefulWidget`. Precisa de estado local para lembrar **qual professor está selecionado** e **se está gravando**:

```dart
class _Page2State extends ConsumerState<Page2> {
  Professor? _professorSelecionado;
  bool _salvando = false;
  // ...
}
```

#### `_celulasDoProfessor` — quais células pintar de vermelho

```dart
Set<CelulaGrade> _celulasDoProfessor(
  String idProfessor,
  List<IndisponibilidadeProfessor> linhas,
) {
  return linhas
      .where((r) => r.idProfessor == idProfessor)
      .map((r) => r.celula)
      .toSet();
}
```

Transforma as linhas do banco num `Set<CelulaGrade>`. O `Set` deixa a pergunta "esta célula está marcada?" rápida (`contains`). Isso só funciona porque `CelulaGrade` reescreveu `==` e `hashCode` (Parte 0.7).

#### `_alternarCelula` — o clique numa célula

```dart
Future<void> _alternarCelula(
  CelulaGrade celula,
  Set<CelulaGrade> current,
) async {
  final professor = _professorSelecionado;
  if (professor == null || _salvando) return;

  setState(() => _salvando = true);
  final repo = ref.read(provedorRepositorioIndisponibilidade);

  try {
    if (current.contains(celula)) {
      await repo.excluirPorProfessorCelula(
        idProfessor: professor.id,
        celula: celula,
      );
    } else {
      await repo.adicionar(idProfessor: professor.id, celula: celula);
    }
    ref.invalidate(provedorIndisponibilidades);
  } catch (e) {
    _mostrarErro(e);
  } finally {
    if (mounted) setState(() => _salvando = false);
  }
}
```

- Se a célula já está marcada, apaga a linha. Se não está, insere.
- `_salvando` evita dois cliques ao mesmo tempo: enquanto grava, `aoAlternar` vira `null`, a grade não responde e aparece uma barra de progresso fina.
- O `finally` sempre libera `_salvando`, mesmo se der erro.

#### `build` — montando a tela

```dart
final professorsAsync = ref.watch(provedorProfessores);
final unavailabilityAsync = ref.watch(provedorIndisponibilidades);
final professores = professorsAsync.valueOrNull ?? const <Professor>[];
final linhas = unavailabilityAsync.valueOrNull ?? const <IndisponibilidadeProfessor>[];

// Se o professor foi excluído na Página 1, limpa a seleção.
final selecionado = _professorSelecionado == null
    ? null
    : professores.where((p) => p.id == _professorSelecionado!.id).firstOrNull;
if (_professorSelecionado != null && selecionado == null) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() => _professorSelecionado = null);
  });
}
```

- `selecionado` é sempre buscado na lista **atual** (que vem do tempo real), não na cópia guardada. Se o nome do professor mudou em outro computador, a tela mostra o nome novo.
- Se o professor sumiu (foi excluído), a seleção é limpa. Isso é feito com `addPostFrameCallback`, que roda logo **depois** de desenhar, porque o Flutter não deixa chamar `setState` no meio do `build`.

A tela tem duas colunas:

```dart
Row(
  children: [
    if (selecionado != null)
      ColunaQuadro(
        flex: 7,
        titulo: 'Indisponibilidade — ${selecionado.nome}',
        icone: Icons.calendar_month_outlined,
        acoes: [ /* botão X: setState(() => _professorSelecionado = null) */ ],
        child: unavailabilityAsync.when(
          data: (data) {
            final marked = _celulasDoProfessor(selecionado.id, data);
            return Column(children: [
              const Text('Toque nos horários indisponíveis. Salvo no banco automaticamente.'),
              if (_salvando) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: GradeHoraria(
                  interativo: true,
                  celulasMarcadas: marked,
                  aoAlternar: _salvando ? null : (celula) => _alternarCelula(celula, marked),
                ),
              ),
            ]);
          },
          // loading / error ...
        ),
      )
    else
      const Expanded(flex: 7, child: DicaColunaVazia(mensagem: 'Selecione um professor para marcar dias e horários indisponíveis')),
    ColunaQuadro(
      flex: 3,
      titulo: 'Professores',
      icone: Icons.person_outline,
      child: /* ListView de CartaoItem */,
    ),
  ],
)
```

A lista de professores mostra quantos horários estão bloqueados e usa `selecionado: isSelected` para destacar o escolhido. Clicar de novo no mesmo professor desmarca:

```dart
final blocked = linhas.where((r) => r.idProfessor == professor.id).length;
return CartaoItem(
  titulo: professor.nome,
  subtitulo: blocked == 0 ? null : '$blocked horário(s) bloqueado(s)',
  selecionado: isSelected,
  aoTocar: () {
    setState(() {
      _professorSelecionado = isSelected ? null : professor;
    });
  },
);
```

### 2.4 Repositório e model

```dart
// RepositorioIndisponibilidade
Future<void> adicionar({required String idProfessor, required CelulaGrade celula}) async {
  await _client.from(_table).insert({
    'id_professor': int.parse(idProfessor),
    'dia_semana': celula.indiceDia + 1,
    'periodo': celula.indicePeriodo + 1,
  });
}

Future<void> excluirPorProfessorCelula({required String idProfessor, required CelulaGrade celula}) async {
  await _client
      .from(_table)
      .delete()
      .eq('id_professor', int.parse(idProfessor))
      .eq('dia_semana', celula.indiceDia + 1)
      .eq('periodo', celula.indicePeriodo + 1);
}
```

O model `IndisponibilidadeProfessor` tem `id`, `idProfessor`, `indiceDia`, `indicePeriodo` e o getter `celula`. O banco tem uma regra única `(id_professor, dia_semana, periodo)`, então não existe marcação duplicada.

### 2.5 Onde a disponibilidade é usada depois

| Lugar | Função | Efeito |
|---|---|---|
| Gerador | `_blocoCabe` → `estaIndisponivel(...)` | nunca coloca aula em horário vermelho |
| Diálogo de aula | `professoresDaMateriaNaCelula` | professor indisponível não aparece na lista |
| Salvar aula | `validarSalvarAula` | "Professor indisponível neste horário (Disponibilidade)." |
| Arrastar | `validarMoverAulas` | "X está indisponível em Seg 1º M (Disponibilidade)." |
| Avisos | `ValidadorHorario` | "X no horário errado (Seg 1º M)", para aulas que já estavam lá antes da marcação |

```dart
// regras_horario.dart
bool estaIndisponivel(
  List<IndisponibilidadeProfessor> linhas,
  String idProfessor,
  CelulaGrade celula,
) {
  return linhas.any(
    (u) =>
        u.idProfessor == idProfessor &&
        u.indiceDia == celula.indiceDia &&
        u.indicePeriodo == celula.indicePeriodo,
  );
}
```

### 2.6 Perguntas prováveis sobre a Página 2

**"Por que não tem botão Salvar?"**
Cada clique já chama `adicionar` ou `excluirPorProfessorCelula`. O usuário principal tem pouca familiaridade com computador, e assim não corre o risco de esquecer de salvar.

**"E se eu marcar um horário em que o professor já tem aula?"**
A marcação é gravada normalmente. A aula não é apagada, mas a Página 3 passa a mostrar o aviso "X no horário errado", e o próximo "Gerar" respeita a marcação.

**"Por que `Page2` é Stateful e as colunas da Página 1 não?"**
A Página 2 guarda o professor selecionado e o "gravando". As colunas da Página 1 não guardam nada: tudo vem dos providers.

**"O que é o `addPostFrameCallback`?"**
Agenda uma função para logo depois de desenhar. É usado para limpar a seleção se o professor foi excluído, porque não se pode chamar `setState` durante o `build`.

---

## Parte 3 — Página 3: Horário

### 3.1 O que a página faz

- Mostra a grade de cada turma.
- **Gera** o horário de todas as turmas automaticamente.
- Permite **incluir, editar, excluir, arrastar e trocar** aulas, sempre validando as regras.
- Edita a **hora** de cada período.
- Mostra **avisos** de problemas.
- Exporta o **PDF**.

### 3.2 Mapa de arquivos

```
lib/pages/page3/
├─ page3.dart                          Page3 / _Page3State    ← lê os providers e distribui
├─ helpers/
│  ├─ acoes_horario.dart               AcoesHorario           ← o que cada ação faz (gerar, tocar, mover, limpar)
│  ├─ regras_horario.dart              funções puras          ← "pode ou não pode?"
│  └─ formato_horario.dart             máscara "00:00 - 00:00"
└─ widgets/
   ├─ barra_acoes_horario.dart         BarraAcoesHorario      (Gerar / PDF)
   ├─ lista_cursos_horario.dart        ListaCursosHorario     (lista à direita)
   ├─ painel_grade_curso.dart          PainelGradeCurso       (grade da turma)
   ├─ celula_horario.dart              CelulaHorario, _GrupoLivre
   ├─ campo_horario_periodo.dart       CampoHorarioPeriodo    (hora do período)
   └─ painel_validacao_horario.dart    PainelValidacaoHorario (avisos)
lib/services/gerador_horario.dart      GeradorHorario
lib/services/validador_horario.dart    ValidadorHorario
lib/services/exportador_horario_pdf.dart ExportadorHorarioPdf
lib/components/dialogs/dialogo_formulario_aula.dart  formulário de aula
lib/services/repositories/repositorio_aula.dart      RepositorioAula
```

**Como as peças conversam:**

```
Page3  (ref.watch de 10 providers → listas)
 ├─ BarraAcoesHorario(aoGerar, aoPdf) ─────────────────► Page3._gerarTodos / _exportarPdf
 ├─ PainelGradeCurso(curso, listas..., callbacks)
 │    ├─ GradeHoraria
 │    │    ├─ CampoHorarioPeriodo(aoSalvar) ──────────► Page3._salvarHorario
 │    │    └─ CelulaHorario(aoTocar, aoSoltar, motivoParaNaoSoltar)
 │    │          aoTocar  ───────────────────────────► Page3._aoTocarCelula
 │    │          aoSoltar ───────────────────────────► Page3._aoSoltarAula
 │    │          motivoParaNaoSoltar ────────────────► AcoesHorario.motivoParaNaoSoltar (pinta verde/vermelho)
 │    └─ PainelValidacaoHorario(ValidadorHorario().validarCurso(...))
 └─ ListaCursosHorario(aoSelecionar) ────────────────► setState(_cursoSelecionado = curso)

Page3._executar(acao) → AcoesHorario.xxx(...) → regras_horario (pode?) / GeradorHorario (calcula)
                                              → RepositorioAula (grava) → ref.invalidate(provedorAulas)
```

**Ideia central:** só `Page3` lê os providers. Os widgets filhos recebem tudo pronto por parâmetro e devolvem os cliques por **callbacks** (funções passadas como parâmetro). Toda ação que grava passa por `AcoesHorario`.

---

### 3.3 `Page3` e `_Page3State` (`page3.dart`)

Estado local:

```dart
class _Page3State extends ConsumerState<Page3> {
  Curso? _cursoSelecionado;
  bool _ocupado = false;

  // Usa o container do ProviderScope (não o ref da tela): as ações
  // continuam funcionando se a pessoa trocar de página no meio de uma
  // gravação.
  AcoesHorario get _acoes =>
      AcoesHorario(ProviderScope.containerOf(context, listen: false));
```

- `_cursoSelecionado`: qual turma está aberta.
- `_ocupado`: se uma gravação está em andamento. Trava botões e arrastes.
- `_acoes`: cria um `AcoesHorario` com o **container** do Riverpod. Se o usuário trocar de página no meio de um "Gerar", o `ref` da tela deixaria de valer, mas o container continua válido.

#### `_executar` — o funil de todas as ações

```dart
/// Roda [acao] e mostra a mensagem que ela devolver. A grade só trava
/// quando a ação chama `iniciarGravacao` (depois das confirmações), não
/// enquanto a pessoa ainda está decidindo num diálogo.
Future<void> _executar(
  Future<String?> Function(VoidCallback iniciarGravacao) acao,
) async {
  if (_ocupado) return;
  void iniciarGravacao() {
    if (mounted) setState(() => _ocupado = true);
  }

  try {
    final mensagem = await acao(iniciarGravacao);
    if (mensagem != null) _mostrarMensagem(mensagem);
  } catch (e) {
    _mostrarErro(e);
  } finally {
    if (mounted && _ocupado) setState(() => _ocupado = false);
  }
}
```

1. Se já tem ação rodando, ignora o novo clique.
2. Entrega para a ação uma função `iniciarGravacao`. A ação chama essa função **só depois** das confirmações. Assim a grade não fica travada enquanto o usuário ainda decide num diálogo.
3. Se a ação devolve um texto, mostra num `SnackBar`. Se lança erro, mostra "Erro: ...".
4. No fim, sempre destrava.

#### Os métodos que chamam `AcoesHorario`

Todos seguem a forma `_executar((iniciarGravacao) => _acoes.metodo(...))`:

| Método de `_Page3State` | Chama | Disparado por |
|---|---|---|
| `_gerarTodos(...)` | `_acoes.gerarTodos(...)` | botão **Gerar** |
| `_limparCurso(curso)` | `_acoes.limparCurso(...)` | lixeira do painel ("Limpar grade") |
| `_aoTocarCelula(...)` | `_acoes.aoTocarCelula(...)` | clique numa célula |
| `_aoSoltarAula(...)` | `_acoes.moverAula(...)` | soltar uma aula arrastada |
| `_salvarHorario(indicePeriodo, texto)` | `_acoes.salvarHorarioPeriodo(...)` | campo de hora (não passa por `_executar`; devolve `true`/`false` para o campo) |
| `_exportarPdf(...)` | `ExportadorHorarioPdf().gerar(...)` + `Printing.layoutPdf(...)` | botão **PDF** |

```dart
Future<void> _exportarPdf({ /* cursos, aulas, materias, professores, salas, horarios */ }) {
  // Trava enquanto monta o PDF: evita dois diálogos de impressão e
  // exportar no meio de um "Gerar".
  return _executar((iniciarGravacao) async {
    iniciarGravacao();
    final bytes = await const ExportadorHorarioPdf().gerar(
      cursos: cursos, aulas: aulas, materias: materias,
      professores: professores, salas: salas, horarios: horarios,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'horarios');
    return null;
  });
}
```

`Printing.layoutPdf` (pacote `printing`) abre a janela de impressão do navegador, onde dá para imprimir ou salvar o PDF.

#### `build` — ler tudo e distribuir

```dart
final cursosAsync = ref.watch(provedorCursos);
final aulasAsync = ref.watch(provedorAulas);
final cargasAsync = ref.watch(provedorCargasCurso);
final aulasGeminadasAsync = ref.watch(provedorAulasGeminadasCurso);
final materiasAsync = ref.watch(provedorMaterias);
final professoresAsync = ref.watch(provedorProfessores);
final ligacoesAsync = ref.watch(provedorProfessorMaterias);
final indisponibilidadesAsync = ref.watch(provedorIndisponibilidades);
final salasAsync = ref.watch(provedorSalas);
// Os horários são só rótulos: se a tabela falhar, a grade segue sem eles.
final horarios = {
  for (final h in ref.watch(provedorHorariosPeriodo).valueOrNull ?? const <HorarioPeriodo>[])
    h.indicePeriodo: h.texto,
};
// ... cada um vira lista com `valueOrNull ?? const []`

// Só permite gerar com todos os dados carregados (lista vazia por
// carregamento faria o gerador apagar a grade sem recriá-la).
final dadosProntos = [
  cursosAsync, aulasAsync, cargasAsync, aulasGeminadasAsync, materiasAsync,
  professoresAsync, ligacoesAsync, indisponibilidadesAsync, salasAsync,
].every((async) => async.hasValue && !async.hasError);
```

**`dadosProntos` é uma proteção importante.** Enquanto uma lista ainda está carregando, ela aparece vazia. Se o gerador rodasse nesse momento, acharia que não há professores e apagaria a grade. Por isso os botões só ficam ativos com tudo carregado:

```dart
BarraAcoesHorario(
  aoGerar: _ocupado || !dadosProntos || cursos.isEmpty ? null : () => _gerarTodos(/* ... */),
  aoPdf:   _ocupado || !dadosProntos || cursos.isEmpty ? null : () => _exportarPdf(/* ... */),
),
```

Depois, monta a linha com o painel da grade (se há curso selecionado) e a lista de cursos:

```dart
if (selecionado != null)
  PainelGradeCurso(
    curso: selecionado, cursos: cursos, aulas: aulas, cargas: cargas,
    aulasGeminadas: aulasGeminadas, materias: materias, professores: professores,
    ligacoes: ligacoes, indisponibilidades: indisponibilidades, salas: salas,
    horarios: horarios,
    // Tocar e arrastar só com todos os dados carregados (sem as
    // indisponibilidades, o arraste aceitaria horário bloqueado).
    ocupado: _ocupado || !dadosProntos,
    aoSalvarHorario: (indicePeriodo, texto) => _salvarHorario(indicePeriodo, texto),
    aoLimpar: _ocupado ? null : () => _limparCurso(selecionado),
    aoFechar: () => setState(() => _cursoSelecionado = null),
    aoSoltarAula: ({required Aula aula, required CelulaGrade destino}) => _aoSoltarAula(/* ... */),
    aoTocarCelula: ({required CelulaGrade celula}) => _aoTocarCelula(/* ... */),
  )
else
  const Expanded(flex: 7, child: DicaColunaVazia(mensagem: 'Selecione um curso para abrir a grade horária')),
ListaCursosHorario(
  cursoSelecionado: selecionado, cargas: cargas, aulas: aulas,
  aoSelecionar: (curso) { setState(() => _cursoSelecionado = curso); },
),
```

Como na Página 2, `selecionado` é buscado na lista atual. Se o curso foi excluído, a seleção é limpa com `addPostFrameCallback`.

---

### 3.4 Widgets da Página 3

#### `BarraAcoesHorario` (`widgets/barra_acoes_horario.dart`)

`StatelessWidget` com dois botões: **Gerar** (`FilledButton.icon`) e **PDF** (`OutlinedButton.icon`). Recebe `aoGerar` e `aoPdf`. Se o callback for `null`, o botão fica cinza (desabilitado). Os dois têm `key` (`'botao-gerar'`, `'botao-pdf'`), que os testes usam para achá-los.

#### `ListaCursosHorario` (`widgets/lista_cursos_horario.dart`)

Lista à direita. Cada curso vira um `CartaoItem` com o progresso:

```dart
return CartaoItem(
  titulo: curso.nome,
  subtitulo: subtituloProgresso(curso, cargas, aulas),
  selecionado: estaSelecionado,
  aoTocar: () {
    aoSelecionar(estaSelecionado ? null : curso);
  },
);
```

```dart
// regras_horario.dart
String subtituloProgresso(Curso curso, List<CargaCursoMateria> cargas, List<Aula> aulas) {
  final cargasDoCurso = cargas.where((l) => l.idCurso == curso.id).toList();
  if (cargasDoCurso.isEmpty) return 'Sem carga definida';
  final necessario = cargasDoCurso.fold<int>(0, (s, l) => s + l.quantidadeAulas);
  final alocado = aulas.where((a) => a.idCurso == curso.id).length;
  return '$alocado/$necessario aulas alocadas';
}
```

#### `PainelGradeCurso` (`widgets/painel_grade_curso.dart`)

É a coluna "Horário — Informática 1". Tem a lixeira (`aoLimpar`, tooltip "Limpar grade") e o X (`aoFechar`). No `build`, prepara os mapas, roda o validador e monta a grade:

```dart
final porCelula = aulasPorCelulaDoCurso(aulas, curso.id);
final mapaMaterias = materiaPorId(materias);
final mapaProfessores = professorPorId(professores);
final mapaSalas = salaPorId(salas);

final validacao = const ValidadorHorario().validarCurso(
  idCurso: curso.id, todasAulas: aulas, cursos: cursos, cargas: cargas,
  aulasGeminadas: aulasGeminadas, professores: professores, materias: materias,
  salas: salas, indisponibilidades: indisponibilidades, ligacoes: ligacoes,
);

return Column(children: [
  Text(subtituloProgresso(curso, cargas, aulas)),
  if (ocupado) const LinearProgressIndicator(minHeight: 2),
  Expanded(
    child: GradeHoraria(
      larguraRotulo: 120,
      construirRotuloPeriodo: (indicePeriodo) => CampoHorarioPeriodo(
        key: ValueKey('horario-$indicePeriodo'),
        rotulo: GradeHoraria.periodos[indicePeriodo],
        texto: horarios[indicePeriodo] ?? '',
        aoSalvar: aoSalvarHorario == null ? null : (texto) => aoSalvarHorario!(indicePeriodo, texto),
      ),
      construirCelula: (celula) {
        return CelulaHorario(
          celula: celula,
          aulas: porCelula[celula] ?? const [],
          materias: mapaMaterias, professores: mapaProfessores, salasPorId: mapaSalas,
          ocupado: ocupado,
          aoTocar: () => aoTocarCelula(celula: celula),
          aoSoltar: aoSoltarAula == null ? null : (aula) => aoSoltarAula!(aula: aula, destino: celula),
          motivoParaNaoSoltar: (aula) => AcoesHorario.motivoParaNaoSoltar(
            aula: aula, destino: celula, todasAulas: aulas,
            aulasGeminadas: aulasGeminadas, professores: professores,
            indisponibilidades: indisponibilidades,
          ),
        );
      },
    ),
  ),
  PainelValidacaoHorario(validacao: validacao),
]);
```

- `aulasPorCelulaDoCurso` agrupa as aulas da turma por célula (`Map<CelulaGrade, List<Aula>>`), já ordenadas por grupo. Cada célula pega a sua lista com `porCelula[celula]`.
- `materiaPorId`, `professorPorId` e `salaPorId` transformam listas em mapas (id → objeto), para achar nomes rápido.
- O validador roda a cada redesenho. Os avisos sempre refletem a grade atual.

#### `CelulaHorario` e `_GrupoLivre` (`widgets/celula_horario.dart`)

Cada célula é **ao mesmo tempo** um alvo de soltar (`DragTarget<Aula>`) e, se tem aula, um item arrastável (`Draggable<Aula>`).

```dart
@override
Widget build(BuildContext context) {
  final ordenadas = List<Aula>.from(aulas)..sort((a, b) => a.grupo.compareTo(b.grupo));
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
      // ... Material(color: destaque ?? (vazia ? cinza : verdeFundo),
      //       InkWell(onTap: ocupado ? null : aoTocar, ...))
    },
  );
}
```

**O que a célula mostra:**
- Vazia: o ícone `+`.
- Uma aula da turma inteira: componente, professor e sala.
- Dois grupos: duas metades lado a lado, com "G1" e "G2".
- Só o G2 (aula dividida com G1 livre): a metade `_GrupoLivre` ("G1 Livre") e o G2.

**Cores enquanto arrasta:** quando uma aula passa por cima, `motivoParaNaoSoltar(aula)` é chamado. `null` pinta a célula de **verde** (pode soltar); um texto pinta de **vermelho** (não pode).

A célula **sempre aceita** o soltar (`onWillAcceptWithDetails` devolve `true` quando não está ocupada). A recusa de verdade acontece em `AcoesHorario.moverAula`, que devolve a mensagem explicando o motivo. Se a célula recusasse no `DragTarget`, o usuário não saberia por quê.

```dart
Widget _arrastavel(Aula aula, {required bool comGrupo}) {
  final conteudo = _conteudoAula(aula, comGrupo: comGrupo);
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
```

- `data: aula` é o que chega no `onAcceptWithDetails` da célula de destino (`details.data`).
- `feedback` é o "fantasma" que segue o mouse.
- `childWhenDragging` deixa a aula original meio transparente enquanto arrasta.
- `maxSimultaneousDrags: ocupado ? 0 : 1` impede arrastar enquanto grava.

`_conteudoAula` escreve "G1"/"G2" (só se a turma está dividida), o nome do componente, o professor e a sala.

#### `CampoHorarioPeriodo` (`widgets/campo_horario_periodo.dart`)

É a primeira coluna da grade: o rótulo "1º M" e, embaixo, a hora editável. `StatefulWidget` com:
- `_controlador`: o texto.
- `_foco`: sabe quando o campo perde o foco.
- `_erro`.
- `_enviado`: o texto já mandado para salvar, para não salvar duas vezes.

```dart
@override
void initState() {
  super.initState();
  _foco.addListener(() {
    if (!_foco.hasFocus) _confirmar();
  });
}

Future<void> _confirmar() async {
  if (!mounted) return;
  final texto = _controlador.text.trim();
  if (texto == widget.texto || texto == _enviado) return;
  final erro = validarHorario(texto);
  if (erro != null) {
    // Não salva: volta ao horário que já estava gravado.
    setState(() {
      _erro = erro;
      _controlador.text = widget.texto;
    });
    return;
  }
  final aoSalvar = widget.aoSalvar;
  if (aoSalvar == null) return;
  setState(() => _erro = null);
  _enviado = texto;
  final salvou = await aoSalvar(texto);
  if (!mounted || salvou) return;
  // Não gravou (ex.: sem conexão): mostra de novo o que está gravado.
  setState(() {
    _enviado = null;
    _controlador.text = widget.texto;
  });
}
```

Salva ao apertar Enter (`onSubmitted`) ou ao sair do campo (listener do foco). Hora inválida não é salva e o campo volta ao valor anterior. `didUpdateWidget` atualiza o texto quando chega um valor novo do banco, mas **nunca** enquanto a pessoa está digitando (`if (!_foco.hasFocus)`).

O caminho até o banco: `aoSalvar(texto)` → `Page3._salvarHorario` → `AcoesHorario.salvarHorarioPeriodo` → `RepositorioHorarioPeriodo.salvar` (`upsert` em `tb_horario_periodo`, com `onConflict: 'periodo'`). A hora vale para **todas** as turmas.

#### `formato_horario.dart` — máscara e validação da hora

| Peça | O que faz |
|---|---|
| `moldeHorario = '00:00 - 00:00'` | o texto de exemplo do campo |
| `formatarDigitosHorario(digitos)` | "07300820" → "07:30 - 08:20" |
| `MascaraHorarioFormatter` | `TextInputFormatter`: só deixa digitar números e encaixa no molde enquanto digita. Também entende horários colados ("7:30 - 8:20", "07h30 às 8h20") e mantém o cursor no lugar certo |
| `validarHorario(texto)` | devolve o erro ou `null` |

```dart
String formatarDigitosHorario(String digitos) {
  final d = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
  final texto = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 2 || i == 6) texto.write(':');
    if (i == 4) texto.write(' - ');
    texto.write(d[i]);
  }
  return texto.toString();
}

String? validarHorario(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'^(\d{2}):(\d{2}) - (\d{2}):(\d{2})$').firstMatch(t);
  if (m == null) return 'Use $moldeHorario';
  final numeros = [for (var i = 1; i <= 4; i++) int.parse(m.group(i)!)];
  if (numeros[0] > 23 || numeros[2] > 23) return 'Hora vai até 23';
  if (numeros[1] > 59 || numeros[3] > 59) return 'Minuto vai até 59';
  final inicio = numeros[0] * 60 + numeros[1];
  final fim = numeros[2] * 60 + numeros[3];
  if (fim <= inicio) return 'O fim deve ser depois do início';
  return null;
}
```

Campo vazio é aceito: apaga o horário do período.

#### `PainelValidacaoHorario` (`widgets/painel_validacao_horario.dart`)

A barra embaixo da grade. Recebe um `ValidacaoHorario`. Se `validacao.ok`, mostra "Sem problemas" em verde. Senão, mostra "N problema(s)" e a lista em vermelho, com altura máxima de 140 px e rolagem, para muitos problemas não empurrarem a grade para fora da tela.

---

### 3.5 `ValidadorHorario` (`services/validador_horario.dart`) — os avisos

`validarCurso(...)` recebe todas as listas e devolve `ValidacaoHorario(problemas: [...])`. O getter `ok` é `problemas.isEmpty`. Verificações, na ordem do código:

| Verificação | Mensagem |
|---|---|
| componente com aulas a mais | "Aulas de X demais" |
| componente com aulas a menos | "Faltam N aula(s) de X (a/b)" |
| dois grupos num horário sem aula dividida no curso | "2 grupos em Seg 1º M sem aula dividida" |
| dois grupos que não formam par cadastrado | "Par sem aula dividida cadastrada em ..." |
| par pedindo mais aulas do que a carga | "Aula dividida A + B pede mais aulas do que a carga..." |
| par com menos/mais horários juntos do que o configurado | "Aula dividida A + B: j/n aulas juntas" |
| quantidade de horários "G1 livre" diferente do esperado | "...: s/n aulas só de B (grupo 1 livre)" |
| G2 sozinho de componente sem par | "Grupo 2 sem aula dividida em ..." |
| professor em horário marcado na Página 2 | "X no horário errado (Seg 1º M)" |
| professor que deixou de dar o componente | "X não está vinculado a Y (...)" |
| professor em duas aulas ao mesmo tempo | "X já está dando aula no curso Z (...)" |
| sala usada por outra turma no mesmo horário | "Sala ... ocupada por Z (...)" |

Trecho real (contagem de aulas):

```dart
for (final load in cargas.where((l) => l.idCurso == idCurso)) {
  final nomeMateria = subjectById[load.idMateria] ?? 'Componente';
  final scheduled = courseAulas.where((a) => a.idMateria == load.idMateria).length;
  if (scheduled > load.quantidadeAulas) {
    problemas.add('Aulas de $nomeMateria demais');
  } else if (scheduled < load.quantidadeAulas) {
    final missing = load.quantidadeAulas - scheduled;
    problemas.add(
      'Faltam $missing aula(s) de $nomeMateria '
      '($scheduled/${load.quantidadeAulas})',
    );
  }
}
```

No fim, `_deduplicar` tira mensagens repetidas (a mesma colisão apareceria duas vezes, uma vez por aula).

**Diferença entre validador e regras:** o **validador** só *avisa* sobre o estado atual da grade. As **regras** (`regras_horario.dart`) *impedem* que uma alteração errada seja gravada.

---

### 3.6 `AcoesHorario` (`helpers/acoes_horario.dart`) — o que cada ação faz

É uma classe sem widgets. Recebe um `ProviderContainer` (chamado `ref`) e usa `ref.read(...)` e `ref.invalidate(...)`.

#### `salvarHorarioPeriodo(indicePeriodo, texto)`

```dart
Future<void> salvarHorarioPeriodo(int indicePeriodo, String texto) async {
  await ref
      .read(provedorRepositorioHorarioPeriodo)
      .salvar(HorarioPeriodo(indicePeriodo: indicePeriodo, texto: texto));
  ref.invalidate(provedorHorariosPeriodo);
}
```

#### `limparCurso(context:, iniciarGravacao:, curso:)`

```dart
final confirmado = await mostrarDialogoConfirmarExclusao(
  context,
  titulo: 'Limpar grade',
  mensagem: 'Remover todas as aulas de "${curso.nome}"? '
      'Esta ação não pode ser desfeita.',
);
if (!confirmado) return null;

iniciarGravacao();
await ref.read(provedorRepositorioAula).excluirPorCurso(curso.id);
ref.invalidate(provedorAulas);
return 'Grade de "${curso.nome}" limpa.';
```

#### `gerarTodos(...)` — botão Gerar

```dart
final confirmado = await mostrarDialogoConfirmarExclusao(
  context,
  titulo: 'Gerar horários',
  mensagem: 'Regenerar os horários de todas as turmas? '
      'Isso apaga os horários atuais e recria com base nas '
      'configurações de Cadastros e na Disponibilidade dos '
      'professores. Esta ação não pode ser desfeita.',
  rotuloConfirmar: 'Gerar',
);
if (!confirmado) return null;

iniciarGravacao();
// Gera antes de apagar: se nada couber, a grade atual fica intacta.
final resultado = const GeradorHorario().gerarTodos(
  cursos: cursos, cargas: cargas, professores: professores, ligacoes: ligacoes,
  indisponibilidades: indisponibilidades, aulasGeminadas: aulasGeminadas,
  nomesMaterias: {for (final m in materias) m.id: m.nome},
  nomesCursos: {for (final c in cursos) c.id: c.nome},
);

if (resultado.novasAulas.isEmpty) {
  final motivo = resultado.falhas.isEmpty ? 'nenhuma aula a alocar.' : resultado.falhas.first;
  return 'Não foi possível gerar (grade atual mantida): $motivo';
}

final repo = ref.read(provedorRepositorioAula);
try {
  // Troca a grade inteira numa transação só: se falhar, nada muda.
  await repo.substituirTodas(resultado.novasAulas);
} catch (e) {
  final detalhe = e is PostgrestException ? e.message : '$e';
  return 'Não foi possível salvar o horário gerado (grade anterior mantida): $detalhe';
} finally {
  ref.invalidate(provedorAulas);
}

if (resultado.completo) {
  return 'Horários gerados: ${resultado.novasAulas.length} aula(s) alocadas.';
}
return 'Parcial: ${resultado.novasAulas.length} aula(s). ${resultado.falhas.take(3).join(' ')}';
```

**Ordem segura:**
1. Confirma.
2. **Calcula** a grade nova em memória.
3. Só se deu algo, **troca** a grade no banco de uma vez, pela função `substituir_aulas`.

Se o cálculo não colocar nenhuma aula, ou a gravação falhar, a grade antiga fica intacta.

#### `aoTocarCelula(...)` — clique numa célula

1. **Descobre o que há na célula:**
   ```dart
   final naCelula = aulasNaCelula(todasAulas, curso.id, celula);
   Aula? existente;
   if (naCelula.length == 1) {
     existente = naCelula.single;
   } else if (naCelula.length > 1) {
     existente = await _escolherGrupoParaEditar(context, naCelula, mapaMaterias);
     if (existente == null) return null;
   }
   final grupo = existente?.grupo ?? 1;
   ```
   Com 0 aulas, cria uma nova. Com 1, edita. Com 2, pergunta "Qual grupo editar?" (`_escolherGrupoParaEditar`, um `SimpleDialog`).
2. **Monta o título:** "Nova aula — Seg 1º M" ou "Editar — Seg 1º M · Grupo 2". O sufixo de grupo só aparece se a turma está dividida naquele horário.
3. **Abre o formulário** passando funções:
   ```dart
   final resultado = await mostrarDialogoFormularioAula(
     context,
     validar: (r) => motivoRecusa(r, aulas: todasAulas, cargas: cargas, pares: aulasGeminadas, ligacoes: ligacoes, indisponibilidades: indisponibilidades),
     avisoProfessor: (idMateria, idProfessor) => avisoProfessorNaCelula(
       idProfessor: idProfessor, celula: celula,
       indisponibilidades: indisponibilidades, todasAulas: todasAulas,
       idAulaExcluida: existente?.id,
     ),
     titulo: titulo,
     // Só os componentes da carga do curso (Cadastros). Ao editar, o atual
     // continua na lista mesmo se saiu da carga.
     materias: materiasParaDialogoAula(
       materiasCurso: materiasDoCurso(curso.id, cargas, todasMaterias),
       todasMaterias: todasMaterias,
       existente: existente,
     ),
     salas: salas,
     professoresDaMateria: (idMateria) => professoresParaDialogoAula(/* ... */),
     idMateriaInicial: existente?.idMateria,
     idProfessorInicial: existente?.idProfessor,
     idSalaInicial: existente?.idSala ?? curso.idSala,
     permitirExcluir: existente != null,
     // mensagemExclusao: 'Excluir a aula de Seg 1º M?' ...
   );
   ```
   `motivoRecusa` é uma função local que chama `validarSalvarAula(...)` com os dados da célula. Numa aula nova, a sala começa com a **sala padrão** do curso.
4. **Relê os dados mais recentes.** Enquanto o diálogo estava aberto, outra pessoa pode ter mudado algo:
   ```dart
   final aulasAgora = ref.read(provedorAulas).valueOrNull ?? todasAulas;
   final paresAgora = ref.read(provedorAulasGeminadasCurso).valueOrNull ?? aulasGeminadas;
   ```
5. **Se a pessoa clicou Excluir** (`resultado is ExclusaoFormularioAula`): exclui. Se sobrou uma aula na célula, `grupoDaQueSobra` decide o grupo dela: continua no G2 se ainda forma par, senão vira grupo 1.
   ```dart
   await repo.excluir(excluida.id);
   final restante = aulasNaCelula(aulasAgora, curso.id, celula).where((a) => a.id != excluida.id).toList();
   if (restante.length == 1) {
     final novoGrupo = grupoDaQueSobra(idCurso: curso.id, excluida: excluida, restante: restante.single, aulasGeminadas: paresAgora);
     if (novoGrupo != restante.single.grupo) {
       await repo.atualizar(_comGrupo(restante.single, novoGrupo));
     }
   }
   ```
6. **Se a pessoa clicou Salvar**: valida **de novo** com os dados recentes, monta a `Aula` e grava:
   ```dart
   final erro = motivoRecusa(resultado, aulas: aulasAgora, /* cargas, pares, ligacoes e indisponibilidades atuais */);
   if (erro != null) return erro;
   iniciarGravacao();

   final aula = Aula(
     id: existente?.id ?? '0',
     idCurso: curso.id,
     indiceDia: celula.indiceDia,
     indicePeriodo: celula.indicePeriodo,
     idMateria: resultado.idMateria,
     idProfessor: resultado.idProfessor,
     idSala: resultado.idSala,
     grupo: grupoAoSalvar(/* ... */),
   );
   if (existente == null) {
     await repo.adicionar(aula);
   } else {
     await repo.atualizar(aula);
   }
   ref.invalidate(provedorAulas);   // no finally
   ```

`_comGrupo(a, grupo)` cria uma cópia da aula com outro grupo. Os models são imutáveis (campos `final`), então para "mudar" é preciso criar outro objeto.

#### `motivoParaNaoSoltar(...)` (estático) — pintar verde/vermelho

```dart
static String? motivoParaNaoSoltar({ required Aula aula, required CelulaGrade destino, /* listas */ }) {
  // Aula comum solta em cima de outra aula comum: as duas trocam de lugar.
  final outra = aulaParaTrocar(aula: aula, destino: destino, todasAulas: todasAulas, aulasGeminadas: aulasGeminadas);
  if (outra != null) {
    return validarTrocaAulas(a: aula, b: outra, todasAulas: todasAulas, professores: professores, indisponibilidades: indisponibilidades);
  }
  final originais = aulasQueMovemJunto(aula: aula, todasAulas: todasAulas, aulasGeminadas: aulasGeminadas);
  return validarMoverAulas(
    originais: originais,
    movidas: deslocarAulas(originais, origem: aula.celula, destino: destino),
    todasAulas: todasAulas, professores: professores, indisponibilidades: indisponibilidades,
  );
}
```

É **estático** porque não precisa do banco: é só um cálculo, chamado muitas vezes enquanto o mouse se move.

#### `moverAula(...)` — soltar uma aula

```dart
if (aula.celula == destino) return null;

final outra = aulaParaTrocar(/* ... */);
if (outra != null) {
  return _trocar(iniciarGravacao: iniciarGravacao, a: aula, b: outra, /* ... */);
}

final originais = aulasQueMovemJunto(aula: aula, todasAulas: todasAulas, aulasGeminadas: aulasGeminadas);
final movidas = deslocarAulas(originais, origem: aula.celula, destino: destino);
final motivo = validarMoverAulas(originais: originais, movidas: movidas, /* ... */);
if (motivo != null) return 'Não foi possível mover. $motivo';
iniciarGravacao();

final repo = ref.read(provedorRepositorioAula);
final deslocamento = destino.indicePeriodo - aula.indicePeriodo;
try {
  await repo.moverAulas(movidas, deslocamentoPeriodos: deslocamento);
} catch (e) {
  // Falhou no meio de um conjunto: devolve todas à posição original
  // para não deixar o conjunto dividido entre dois lugares.
  try {
    await repo.moverAulas(originais, deslocamentoPeriodos: -deslocamento);
  } catch (_) {}
  rethrow;
} finally {
  ref.invalidate(provedorAulas);
}
return null;
```

1. Soltou sobre outra aula comum: **troca** as duas (`_trocar`).
2. Senão, descobre o conjunto que se move junto: uma aula comum anda sozinha; uma aula dividida anda com os dois grupos e os horários seguidos do mesmo par.
3. Calcula as posições novas e valida.
4. Grava. Se falhar no meio, tenta desfazer.

#### `_trocar(...)`

Valida com `validarTrocaAulas` e grava com `repo.trocarAulas(a, b)`. Se falhar no meio, devolve `b` para a célula dela (`moverAulas([b], deslocamentoPeriodos: 0)`) e `a` para o grupo 1 (`atualizar(a)`).

---

### 3.7 `regras_horario.dart` — "pode ou não pode?"

Todas são **funções puras**: recebem listas e devolvem resultado, sem banco nem tela. Por isso têm muitos testes (`test/edicao_pagina3_regras_test.dart`, `test/mover_aulas_regras_test.dart`).

#### Ajudantes de consulta

| Função | Devolve |
|---|---|
| `materiaPorId`, `professorPorId`, `salaPorId` | mapa id → objeto |
| `aulasPorCelulaDoCurso(aulas, idCurso)` | `Map<CelulaGrade, List<Aula>>` da turma, ordenado por grupo |
| `aulasNaCelula(aulas, idCurso, celula)` | aulas da turma naquela célula |
| `turmaDivididaComGrupoLivre(lista)` | `true` se a célula tem só uma aula e ela é do grupo 2 ("G1 livre") |
| `proximoGrupoLivre(lista)` | 1 ou 2 (o grupo vago), ou `null` se a célula está cheia |
| `estaIndisponivel(linhas, idProfessor, celula)` | se o professor marcou esse horário na Página 2 |
| `maxGruposDoCurso(curso, pares)` | 2 se o curso tem alguma aula dividida, senão 1 |
| `rotuloCelula(c)` | "Seg 1º M" |
| `subtituloProgresso(...)` | "29/29 aulas alocadas" |

#### Listas do formulário de aula

```dart
/// Componentes da carga do curso (os que a Página 3 oferece numa aula nova).
List<Materia> materiasDoCurso(String idCurso, List<CargaCursoMateria> cargas, List<Materia> materias) {
  final ids = {for (final c in cargas.where((c) => c.idCurso == idCurso)) c.idMateria};
  return materias.where((m) => ids.contains(m.id)).toList();
}
```

- `materiasParaDialogoAula`: a lista de `materiasDoCurso` e, ao editar, também o componente atual, mesmo que tenha saído da carga.
- `professoresDaMateriaNaCelula`: professores **vinculados** ao componente, **disponíveis** no horário e **livres** (sem outra aula naquele horário).
- `professoresParaDialogoAula`: a lista acima e, ao editar, também o professor atual mesmo se ficou bloqueado. Assim o formulário não abre com o campo vazio; aparece o aviso laranja e o Salvar recusa até trocar.
- `avisoProfessorNaCelula`: o texto laranja ("O professor atual está indisponível neste horário...").

#### Grupos

```dart
int grupoAoSalvar({ required String idCurso, required String idMateria, required int grupoAtual,
                    required List<Aula> outrasNaCelula, required List<AulaGeminadaCurso> aulasGeminadas }) {
  if (grupoAtual != 2 || outrasNaCelula.isNotEmpty) return grupoAtual;
  final temPar = materiasGeminadasCom(idCurso: idCurso, idMateria: idMateria, aulasGeminadas: aulasGeminadas).isNotEmpty;
  return temPar ? 2 : 1;
}
```

Uma aula sozinha no grupo 2 só continua no grupo 2 se o componente ainda faz parte de uma aula dividida do curso. Senão, vira aula comum. `grupoDaQueSobra` aplica a mesma ideia depois de uma exclusão.

#### `validarSalvarAula(...)` — as regras ao salvar pelo formulário

Cada `if` devolve um texto de recusa. `null` no final significa "pode salvar".

```dart
// A carga só conta quando entra uma aula nova do componente (aula nova
// ou troca de componente). Editar professor/sala de uma aula que já
// existe não aumenta nada, mesmo que a carga tenha diminuído depois.
final mudaComponente = existente == null || existente.idMateria != idMateria;
if (mudaComponente) {
  final maximo = cargaMaxima(cargas, curso.id, idMateria);
  if (maximo == null) {
    return 'Este componente não está na carga do curso (Cadastros).';
  }
  final jaAgendada = quantidadeAgendada(todasAulas, curso.id, idMateria, idAulaExcluida: existente?.id);
  if (jaAgendada >= maximo) {
    return 'Carga completa para este componente ($maximo aula(s)).';
  }
}

if (!vinculado) return 'Este professor não está vinculado a este componente.';
if (estaIndisponivel(indisponibilidades, idProfessor, celula)) {
  return 'Professor indisponível neste horário (Disponibilidade).';
}
if (professorOcupado) return 'Este professor já está alocado neste horário.';

if (naCelula.length >= maxGruposPorCelula) return 'Este horário já tem $maxGruposPorCelula grupos nesta turma.';
if (naCelula.any((a) => a.grupo == grupo)) return 'O grupo $grupo já está ocupado neste horário.';
if (naCelula.any((a) => a.idMateria == idMateria)) return 'Este componente já está neste horário (outro grupo).';
if (naCelula.isNotEmpty && !existeAulaGeminada(/* ... */)) {
  return 'Estes componentes não formam uma aula dividida nesta turma (Cadastros).';
}

// Sala: grupos da mesma turma podem dividir; outra turma conflita.
if (idSala != null) {
  // ... outra turma com a mesma sala no mesmo horário
  if (salaOcupada) return 'Esta sala já está ocupada por outra turma neste horário.';
}
return null;
```

Em todas as comparações, `a.id != existente?.id` ignora a própria aula que está sendo editada. Sem isso, a aula entraria em conflito com ela mesma.

#### Mover e trocar

| Função | O que faz |
|---|---|
| `aulasQueMovemJunto(aula:, todasAulas:, aulasGeminadas:)` | aula comum: `[aula]`. Aula dividida: os dois grupos daquela célula e das células vizinhas (acima e abaixo, mesmo dia e turno) com o mesmo par |
| `deslocarAulas(aulas, origem:, destino:)` | cópias das aulas deslocadas, mantendo a distância entre elas |
| `aulaParaTrocar(aula:, destino:, ...)` | a aula com que vai trocar, ou `null`. Só troca duas aulas **comuns**, cada uma sozinha na célula e fora de qualquer aula dividida |
| `aulasTrocadas(a, b)` | as duas na posição uma da outra |
| `validarTrocaAulas(a:, b:, ...)` | cada uma precisa caber no lugar da outra |
| `validarMoverAulas(originais:, movidas:, ...)` | as regras do arraste (abaixo) |

```dart
List<Aula> deslocarAulas(List<Aula> aulas, {required CelulaGrade origem, required CelulaGrade destino}) {
  final dDia = destino.indiceDia - origem.indiceDia;
  final dPeriodo = destino.indicePeriodo - origem.indicePeriodo;
  return [
    for (final a in aulas)
      Aula(
        id: a.id, idCurso: a.idCurso,
        indiceDia: a.indiceDia + dDia,
        indicePeriodo: a.indicePeriodo + dPeriodo,
        idMateria: a.idMateria, idProfessor: a.idProfessor, idSala: a.idSala, grupo: a.grupo,
      ),
  ];
}
```

**Regras de `validarMoverAulas`**, na ordem:
1. Todas as aulas movidas cabem na grade e no **mesmo turno**. Senão: "Não cabe aqui: a aula dividida precisa de N horário(s) seguidos no mesmo turno."
2. O destino não é um horário "G1 livre" de outra aula dividida.
3. O destino está **vazio** na turma. Senão: "Horário ocupado: solte a aula numa célula vazia...".
4. O professor não dá outra aula naquele horário.
5. O professor está disponível.
6. A sala não é usada por outra turma.

O mover não bloqueia turno do curso. Como diz `preferencia_periodo.dart`, "Na edição manual (tocar/arrastar) não há bloqueio: qualquer turno é aceito". O turno vale para o gerador.

---

### 3.8 `GeradorHorario` (`services/gerador_horario.dart`) — a geração automática

Só **calcula**. Não grava nada. Devolve objetos de resultado:

```dart
class ResultadoGeracaoCompleta {
  final List<Aula> novasAulas;
  final List<String> falhas;
  bool get completo => falhas.isEmpty;
}
```

#### `gerarTodos(...)` — todas as turmas

```dart
final trabalhando = <Aula>[];
final novasAulas = <Aula>[];
final falhas = <String>[];

final ordenados = List<Curso>.from(cursos)
  ..sort((a, b) {
    final cargaA = _totalNecessario(cargas, a.id);
    final cargaB = _totalNecessario(cargas, b.id);
    return cargaB.compareTo(cargaA);
  });

for (final curso in ordenados) {
  final resultado = gerar(
    curso: curso, cargas: cargas, professores: professores, ligacoes: ligacoes,
    indisponibilidades: indisponibilidades, aulasGeminadas: aulasGeminadas,
    aulasExistentes: trabalhando, nomesMaterias: nomesMaterias,
  );
  trabalhando.addAll(resultado.novasAulas);
  novasAulas.addAll(resultado.novasAulas);
  final rotuloCurso = nomesCursos[curso.id] ?? curso.nome;
  falhas.addAll(resultado.falhas.map((f) => '$rotuloCurso: $f'));
}
```

- Os cursos com **mais aulas** são gerados primeiro, porque são os mais difíceis de encaixar.
- `trabalhando` acumula as aulas já colocadas de todas as turmas. É assim que o gerador enxerga que um professor já está ocupado em outra turma.

#### `gerar(...)` — uma turma

1. Curso sem carga não é falha: devolve vazio.
2. Ordena a carga pelos componentes com **menos professores** primeiro, porque são os mais restritos.
3. Coloca primeiro as **aulas divididas** (`_alocarGeminadas`).
4. Para cada componente:
   - calcula quanto falta (`restante`);
   - pega os professores vinculados (se não há nenhum: "nenhum professor vinculado");
   - divide em blocos (`_blocosPara`), sem passar do tamanho do turno;
   - tenta colocar cada bloco com `_colocarBlocoComum`, preferindo o professor que já dá o componente para a turma (`_professoresJaUsados`);
   - se um bloco não cabe, **divide ao meio** e tenta de novo.

```dart
final fila = [for (final b in blocos) (tamanho: b, dividido: false)];
var emBlocosMenores = 0;
while (fila.isNotEmpty) {
  final (tamanho: tamanhoBloco, dividido: dividido) = fila.removeAt(0);
  // Prefere o professor que já dá este componente para a turma, para
  // não trocar de professor a cada bloco.
  final preferidos = _professoresJaUsados(trabalhando, idCurso, carga.idMateria, professoresMateria);
  final alocado = _colocarBlocoComum(
    idCurso: idCurso, idMateria: carga.idMateria, tamanhoBloco: tamanhoBloco,
    idSala: curso.idSala, fasesPeriodo: fasesPeriodo,
    listasProfessores: [
      if (preferidos.isNotEmpty && preferidos.length < professoresMateria.length) preferidos,
      professoresMateria,
    ],
    indisponibilidades: indisponibilidades, trabalhando: trabalhando, novasAulas: novasAulas,
  );
  if (alocado) {
    restante -= tamanhoBloco;
    if (dividido) emBlocosMenores += tamanhoBloco;
  } else if (tamanhoBloco > 1) {
    final metade = (tamanhoBloco + 1) ~/ 2;
    fila.insertAll(0, [
      (tamanho: metade, dividido: true),
      (tamanho: tamanhoBloco - metade, dividido: true),
    ]);
  }
}
```

`(tamanho: b, dividido: false)` é um **record** do Dart: um pequeno pacote de valores com nome, sem precisar criar uma classe. Se sobrar `restante > 0`, vira a falha "Faltam N aula(s) de X".

#### `_colocarBlocoComum(...)` — a ordem de tentativa

```dart
for (final permitirMesmoDia in const [false, true]) {
  for (final professoresMateria in listasProfessores) {
    for (final faixaPeriodos in fasesPeriodo) {
      for (var dia = 0; dia < GradeHoraria.dias.length; dia++) {
        for (final periodoInicio in _periodosInicio(faixaPeriodos, tamanhoBloco)) {
          if (_tentarColocarBloco(/* ... */)) {
            return true;
          }
        }
      }
    }
  }
}
return false;
```

Ordem de preferência, de fora para dentro:
1. No máximo um bloco do componente por dia. Só depois aceita repetir o dia.
2. Primeiro o professor que já dá a matéria, depois qualquer um.
3. Primeiro o turno principal, depois o contraturno (`curso.preferenciaPeriodo.turnos`).
4. Dia por dia, de segunda a sexta.
5. Horário por horário dentro do turno.

É um algoritmo **guloso**: coloca cada bloco no primeiro lugar válido e não volta atrás. Se não couber, avisa em `falhas`.

#### `_tentarColocarBloco(...)` e `_blocoCabe(...)`

`_tentarColocarBloco` procura o primeiro professor da lista para quem `_blocoCabe` dá `true`. Depois cria as aulas (com `id: 'pending'`) e as adiciona em `trabalhando` e `novasAulas`.

`_blocoCabe` confere cada horário do bloco:

```dart
if (!permitirMesmoDia && trabalhando.any((a) =>
    a.idCurso == idCurso && a.idMateria == idMateria && a.indiceDia == dia)) {
  return false;                                               // já tem bloco desse componente no dia
}
for (var deslocamento = 0; deslocamento < tamanhoBloco; deslocamento++) {
  final periodo = periodoInicio + deslocamento;
  if (!GradeHoraria.periodosNaMesmaFaixa(periodoInicio, periodo)) return false;   // passou do turno
  // turma já tem aula nesse horário → false
  // professor já tem aula nesse horário (qualquer turma) → false
  // sala ocupada por outra turma → false
  if (estaIndisponivel(indisponibilidades, idProfessor, celula)) return false;    // Página 2
}
return true;
```

#### `_alocarGeminadas(...)` — aulas divididas

Para cada par do curso:
1. Precisa de professor nos dois componentes e de **dois professores diferentes**. Senão, falha.
2. Limita pela carga livre de cada componente (`caber`).
3. Garante que nenhum bloco passe do tamanho do turno (`blocosMinimos`).
4. G1 recebe o componente de **menos** aulas e G2 o de **mais** (que fica sozinho nos horários de "G1 livre").
5. Para cada bloco, `_tentarColocarBlocoPar` coloca os dois grupos juntos, com os mesmos dois professores no bloco inteiro.
6. O que não couber vira falha, e essas aulas são tentadas depois como aulas comuns.

---

### 3.9 `ExportadorHorarioPdf` (`services/exportador_horario_pdf.dart`)

Usa o pacote `pdf`, que tem widgets próprios com o prefixo `pw.` (`pw.Page`, `pw.Text`, `pw.Column`...).

| Função | O que faz |
|---|---|
| `gerar(cursos:, aulas:, materias:, professores:, salas:, horarios:)` | monta o documento: **uma página A4 deitada por turma**, em ordem alfabética, e devolve os bytes (`Uint8List`) |
| `chaveOrdenacao(nome)` | ordena sem diferenciar acento e maiúsculas (usa `normalizarTexto`) |
| `salaParaImprimir(aula, idSalaPadrao:, salas:)` | a sala só aparece na aula quando é **diferente** da sala padrão, que já sai no topo da folha |
| `turnosDoCurso(curso, porCelula)` | quais turnos imprimir: Noite → só a noite; os outros → manhã e tarde, mais qualquer turno que tenha aula |
| `alturaLinhaParaCaber(...)` | calcula a altura de cada linha para a grade caber numa página |
| `agruparAulasSeguidas(celulas)` | junta horários seguidos com exatamente a mesma aula numa célula só (um bloco de 2 aulas vira um retângulo alto) |

```dart
final listaCursos = List<Curso>.from(cursos)
  ..sort((a, b) => chaveOrdenacao(a.nome).compareTo(chaveOrdenacao(b.nome)));

for (final curso in listaCursos) {
  // ... agrupa as aulas do curso por célula
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(_margem),
      build: (context) {
        final turnos = turnosDoCurso(curso, porCelula);
        // ... título com curso.nome, 'Sala padrão: ...', e _grade(...)
      },
    ),
  );
}
```

---

### 3.10 Formulário de aula (`dialogs/dialogo_formulario_aula.dart`)

| Peça | O que é |
|---|---|
| `ResultadoFormularioAula(idMateria, idProfessor, idSala)` | devolvido ao clicar em Salvar |
| `ExclusaoFormularioAula()` | devolvido ao confirmar Excluir |
| `mostrarDialogoFormularioAula(...)` | devolve `Future<Object?>`: um dos dois resultados acima, ou `null` (cancelou) |
| `_AulaFormDialogState` | guarda `_idMateria`, `_idProfessor`, `_idSala` e `_erro` |

Recebe **funções** em vez de listas prontas. Por isso o formulário não precisa saber as regras:
- `professoresDaMateria(idMateria)`: chamada de novo sempre que o componente muda, porque a lista de professores depende do componente escolhido.
- `validar(resultado)`: devolve o motivo da recusa ou `null`.
- `avisoProfessor(idMateria, idProfessor)`: o aviso laranja.

```dart
void _enviar() {
  // ... confere se escolheu componente e professor disponível ...
  final resultado = ResultadoFormularioAula(idMateria: idMateria, idProfessor: idProfessor, idSala: _idSala);
  // Ex.: professor atual ficou indisponível ou matéria saiu da carga:
  // avisa aqui, sem fechar, para a pessoa corrigir sem perder a edição.
  final recusa = widget.validar?.call(resultado);
  if (recusa != null) {
    setState(() => _erro = recusa);
    return;
  }
  Navigator.of(context).pop(resultado);
}

Future<void> _confirmarExclusao() async {
  final confirmed = await mostrarDialogoConfirmarExclusao(
    context,
    titulo: 'Excluir aula',
    mensagem: widget.mensagemExclusao ?? 'Excluir esta aula?',
  );
  if (!confirmed || !mounted) return;
  Navigator.of(context).pop(const ExclusaoFormularioAula());
}
```

Na abertura (`initState`), `_seEm(id, validos)` só aceita o valor inicial se ele estiver na lista. Isso evita erro do dropdown com um valor que não existe mais.

---

### 3.11 `RepositorioAula` (`services/repositories/repositorio_aula.dart`)

| Método | O que grava |
|---|---|
| `adicionar(aula)` | `insert` em `tb_aula`, devolve o id |
| `atualizar(aula)` | muda componente, professor, sala e grupo |
| `excluir(id)` / `excluirPorCurso(idCurso)` | apaga uma aula / a grade da turma |
| `substituirTodas(aulas)` | RPC `substituir_aulas`: apaga **todas** as aulas e insere as novas numa transação |
| `moverAulas(aulas, deslocamentoPeriodos:)` | muda dia e período, na ordem segura |
| `trocarAulas(a, b)` | troca duas aulas de lugar |

O banco proíbe duas aulas no mesmo `(curso, dia, período, grupo)`. Por isso mover e trocar precisam de cuidado:

```dart
/// Ordem segura para gravar um conjunto deslocado: descendo, de baixo
/// para cima; subindo, de cima para baixo.
static List<Aula> ordemParaMover(List<Aula> aulas, int deslocamentoPeriodos) {
  final ordenadas = List<Aula>.from(aulas)..sort((a, b) => a.indicePeriodo.compareTo(b.indicePeriodo));
  return deslocamentoPeriodos > 0 ? ordenadas.reversed.toList() : ordenadas;
}

/// Por causa da chave única (curso, dia, período, grupo), [a] passa um
/// instante pelo grupo 2 da própria célula (que está livre) antes de ir
/// para o lugar de [b].
Future<void> trocarAulas(Aula a, Aula b) async {
  // gravar(aula, celula, grupo) = update dia_semana/periodo/grupo
  await gravar(a, a.celula, 2);
  await gravar(b, a.celula, 1);
  await gravar(a, b.celula, 1);
}
```

Exemplo de `ordemParaMover`: um bloco de 2 aulas (1º e 2º M) desce 1 horário. Se gravasse a do 1º M primeiro, ela iria para o 2º M, que ainda está ocupado, e o banco recusaria. Por isso grava primeiro a de baixo.

---

### 3.12 Perguntas prováveis sobre a Página 3

**"Como funciona o algoritmo de geração?"**
É guloso, com ordem de preferência (3.8):
- turmas com mais aulas primeiro;
- componentes com menos professores primeiro;
- aulas divididas antes das comuns;
- um bloco por dia, o mesmo professor, o turno principal antes do contraturno;
- se o bloco não cabe, divide ao meio.

Ele respeita professor ocupado, sala ocupada, turno e disponibilidade (`_blocoCabe`). O que não cabe vira aviso.

**"Por que não usaram um algoritmo que garante a melhor solução?"**
O problema de horário escolar é NP-completo: o tempo para achar a solução ótima cresce de forma explosiva. A abordagem gulosa resolve os casos do campus em segundos (no conjunto de teste, as 201 aulas foram alocadas). Quando algo não cabe, o sistema avisa e o usuário ajusta manualmente.

**"E se o Gerar falhar no meio?"**
O cálculo é feito todo em memória. A gravação usa `substituir_aulas`, uma transação: ou troca tudo, ou nada muda. Se nenhuma aula couber, a grade antiga é mantida.

**"Como o sistema impede professor em duas turmas ao mesmo tempo?"**
Em três lugares:
- no gerador (`_blocoCabe`);
- ao salvar pelo formulário (`validarSalvarAula`: "Este professor já está alocado neste horário.");
- ao arrastar (`validarMoverAulas`).

E o validador avisa se acontecer por outro caminho.

**"Como funciona o arrastar e soltar?"**
`Draggable<Aula>` na aula e `DragTarget<Aula>` na célula (3.4). Enquanto arrasta, `motivoParaNaoSoltar` pinta verde ou vermelho. Ao soltar, `AcoesHorario.moverAula` valida e grava. Sobre outra aula comum, as duas trocam de lugar.

**"O que é G1 livre?"**
Numa aula dividida em que um componente tem menos aulas que o outro (ex.: A = 2, B = 4), nos horários restantes só o G2 tem aula. Ela fica sozinha no grupo 2 e a célula mostra "G1 Livre".

**"Por que validar duas vezes ao salvar uma aula?"**
A primeira validação mostra o erro dentro do formulário. A segunda usa os dados mais recentes, porque outra pessoa pode ter mudado o banco enquanto o formulário estava aberto.

**"Onde é feito o PDF?"**
Em `ExportadorHorarioPdf.gerar` (pacote `pdf`). `Printing.layoutPdf` (pacote `printing`) abre a janela de impressão do navegador.

**"O que acontece se dois computadores editarem ao mesmo tempo?"**
O Realtime (`observarTabela`) avisa as duas telas e as listas se atualizam sozinhas. As ações releem os dados antes de gravar, e o banco recusa duplicatas pelas regras únicas.

**"Por que o botão Gerar às vezes fica cinza?"**
Fica desabilitado enquanto `_ocupado` (gravando), enquanto `!dadosProntos` (alguma lista carregando ou com erro) ou se não há cursos.

---

## Apêndice — Banco de dados e glossário

### Tabelas

```
tb_tipo_sala ──< tb_sala >──────────── (sala padrão do curso, sala da aula)
tb_professor ──< tb_professor_materia >── tb_materia
     └──< tb_professor_indisponibilidade
tb_curso ──< tb_curso_materia (carga)  >── tb_materia
   ├──< tb_curso_aula_geminada (aulas divididas: id_materia_a < id_materia_b)
   └──< tb_aula (id_curso, dia_semana 1–5, periodo 1–16, id_materia, id_professor, id_sala, grupo 1–2)
tb_horario_periodo (periodo 1–16, texto)
```

| Regra do banco | Efeito no sistema |
|---|---|
| `unique (id_curso, dia_semana, periodo, grupo)` em `tb_aula` | não existem duas aulas no mesmo grupo e horário (por isso `ordemParaMover` e `trocarAulas`) |
| índice único `(id_sala, dia_semana, periodo, grupo)` | a mesma sala não é usada duas vezes no mesmo horário e grupo |
| `unique (id_tipo_sala, numero)` em `tb_sala` | `SalaDuplicada` |
| `unique (nome)` em `tb_tipo_sala` | `TipoSalaDuplicado` |
| `tamanho_bloco` entre 1 e `quantidade_aulas`, e ≤ 6 | o formulário de curso já limita o mesmo |
| `on delete cascade` (curso, professor, componente) | apagar leva junto aulas, carga, vínculos e indisponibilidades |
| `on delete set null` (sala) | aulas e cursos ficam sem sala |
| funções `substituir_aulas`, `salvar_carga_e_pares` | transações usadas pelo Gerar e pelo salvar do curso |
| políticas RLS `anon_all_*` | a chave pública lê e escreve (o sistema não tem login) |

Script completo: `supabase_estrutura_completa.sql`.

### Glossário

| Termo | Significado |
|---|---|
| Widget | peça de tela do Flutter. `build` descreve o que desenhar |
| `StatelessWidget` / `StatefulWidget` | sem / com estado próprio (`setState` redesenha) |
| `ConsumerWidget` / `ConsumerStatefulWidget` | versões do Riverpod que recebem `ref` |
| Provider / StreamProvider | entrega um objeto / uma lista que muda ao longo do tempo |
| `AsyncValue` | carregando, erro ou dados (`.when`, `.valueOrNull`) |
| Repositório | classe que concentra o acesso ao banco de uma tabela |
| Model | classe que representa uma linha de tabela (`fromJson` / `toInsertJson`) |
| Callback | função passada como parâmetro (`aoTocar`, `aoSoltar`...) |
| Função pura | só recebe dados e devolve resultado, sem banco ou tela (regras, gerador, validador) |
| RPC | chamar uma função SQL do banco (`_client.rpc(...)`) |
| Transação | "tudo ou nada": se uma parte falhar, o banco desfaz o resto |
| Realtime | aviso do Supabase quando uma tabela muda |
| `context.mounted` / `mounted` | se a tela ainda está aberta depois de um `await` |
| `addPostFrameCallback` | roda algo logo depois de desenhar |
| Componente | matéria (`Materia`, `tb_materia`) |
| Carga | aulas por semana de cada componente no curso (`CargaCursoMateria`) |
| Bloco | aulas seguidas no mesmo dia |
| Turno / CT | período do curso / contraturno (`PreferenciaPeriodo`) |
| Aula dividida (geminada) | turma separada em G1 e G2 no mesmo horário (`AulaGeminadaCurso`, `Aula.grupo`) |
| G1 livre | horário em que só o G2 tem aula (a aula fica sozinha no grupo 2) |
