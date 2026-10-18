# Projeto Timetable

Aplicação web para montar o horário de turmas de uma escola. O cadastro fica na página 1, a indisponibilidade dos professores na página 2 e a grade, a geração automática e o PDF na página 3.

Site: https://new-tcc-jvarparanhos-9069s-projects.vercel.app/

## Páginas

Página 1 — cadastro

Quatro colunas: professores, matérias, salas e cursos.

- O professor é ligado às matérias que pode dar aula.
- A sala tem tipo e número. Os tipos são "Sala de aula" e "Laboratório de informática". O mesmo número pode existir nos dois tipos, porém não pode existir duas salas do mesmo tipo com o mesmo número.
- Os cursos tem nome, sala padrão opcional e uma destas ordens de preenchimento:
  - Manhã, depois tarde: preenche a manhã e o que não couber vai para a tarde.
  - Tarde, depois manhã: preenche a tarde e o que não couber vai para a manhã.
- Cada matéria do curso tem quantidade de aulas e tamanho de bloco. O bloco é o número de aulas consecutivas no mesmo turno, de 1 até a carga da matéria, no máximo 6.
- Uma aula geminada é um par de matérias que acontecem juntas, pensando na funcionalidade de uma turma ser dividida em 2 grupos para ter uma aula específica. O campo Aulas diz quantas aulas o par tem junto na semana, e o campo Blocos diz em quantos conjuntos de aulas seguidas elas são divididas ao longo dos dias (de 1 até o número de aulas, no máximo 6 aulas por bloco). Por exemplo, 8 aulas em 2 blocos = 2 conjuntos de 4 aulas geminadas. O restante de cada matéria é distribuído sozinho.

Página 2 — indisponibilidade

A grade do professor marca os horários em que ele não pode dar aula. A geração e a edição da página 3 usam essas marcações como parâmetros para ver quando os professores podem dar aula.

Página 3 — horário

Mostra a grade de uma turma, permite editar uma célula, gerar o horário de todas as turmas, limpar a grade de uma turma e criar um PDF com tudo que foi falado em folhas. Cada folha é uma turma. No PDF, aulas seguidas iguais (mesma matéria, professor e sala) aparecem como uma só, ocupando o espaço dos horários juntos.

Também dá para arrastar uma aula para outra célula. Soltar numa célula ocupada (ou com professor ocupado, indisponível ou sala de outra turma) é recusado com uma mensagem embaixo. Uma aula geminada anda em conjunto: os dois grupos e todos os horários seguidos do par vão juntos, mantendo a distância do horário pego, e precisam de horários vazios seguidos no mesmo turno.

A grade é de segunda a sexta, com 6 períodos de manhã, o intervalo de almoço/descanso e 6 períodos de tarde.

## Regras do horário

- Um professor não fica em dois lugares no mesmo horário.
- Uma sala não é usada por duas turmas no mesmo horário, e em alguns casos dois grupos da mesma turma podem dividir a sala.
- A aula geminada coloca as duas matérias no mesmo horário, em grupos diferentes, com matériasdiferentes (logo professores também).
- Na página 3, o segundo grupo de uma célula só pode ser colocado se o par já estiver cadastrado no curso.
- O gerador coloca primeiro os blocos geminados, e depois distribui o que sobrou de cada matéria, em blocos, começando pelo turno escolhido no curso. Ele tenta um bloco por matéria por dia e só repete o dia quando a carga não cabe na semana.

## Stack

- Flutter Web, Dart SDK `^3.12.0`
- Riverpod, para o estado e os dados em tempo real
- Supabase, como banco Postgres
- Pacotes `pdf` e `printing`, para exportar a grade
- Vercel, para publicar o build web

O pacote Flutter se chama `flutter_test_project`. A interface usa o título **PROJETO TIMETABLE**.

## Como rodar

É preciso ter o [Flutter](https://docs.flutter.dev/get-started/install) instalado.

```bash
flutter pub get
flutter run -d chrome
```

Os testes ficam na pasta `test/` e não acessam o Supabase (usam dados em memória):

```bash
flutter test
```

Eles cobrem o gerador (inclusive aulas geminadas em blocos), o validador da página 3, o formulário do curso e a edição da grade na página 3.

O aplicativo já aponta para o projeto Supabase usado em produção. As tabelas principais são `tb_professor`, `tb_materia`, `tb_sala`, `tb_curso`, `tb_curso_materia`, `tb_professor_materia`, `tb_professor_indisponibilidade`, `tb_curso_aula_geminada` e `tb_aula`.

## Publicação

O arquivo `vercel.json` gera o Flutter Web no build da Vercel e publica a pasta `build/web`. Um push na branch `master` do repositório [FenixPelada/newTCC](https://github.com/FenixPelada/newTCC) dispara o deploy de produção. Isso é necessário para rodá-lo
