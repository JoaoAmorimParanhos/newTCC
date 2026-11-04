# Projeto Timetable

Aplicação web para montar o horário de turmas de uma escola. O cadastro fica na página 1, a indisponibilidade dos professores na página 2 e a grade, a geração automática e o PDF na página 3.

Site: https://new-tcc-jvarparanhos-9069s-projects.vercel.app/

## Páginas

Página 1 — cadastro

Quatro colunas: professores, matérias, salas e cursos. Cada lista aparece na ordem em que os itens foram criados.

- O professor é ligado às matérias que pode dar aula.
- A sala tem tipo e número. Os tipos são cadastrados pelo usuário no próprio diálogo da sala; o banco já vem com "Sala de aula", "Laboratório de informática" e "Quadra". O mesmo número pode existir em tipos diferentes, porém não pode existir duas salas do mesmo tipo com o mesmo número.
- Os cursos têm nome, sala padrão opcional e um turno:
  - Manhã, Tarde ou Noite: o gerador usa só esse turno.
  - Manhã CT: Tarde: preenche a manhã e o que não couber vai para a tarde (contraturno).
  - Tarde CT: Manhã: preenche a tarde e o que não couber vai para a manhã.
- Cada matéria do curso tem quantidade de aulas e tamanho de bloco. O bloco é o número de aulas consecutivas no mesmo turno, de 1 até a carga da matéria, limitado pelo turno: no máximo 6 de manhã ou à tarde e no máximo 4 à noite. O formulário e o gerador respeitam esse limite.
- Uma aula geminada é um par de matérias que acontecem juntas, pensando na funcionalidade de uma turma ser dividida em 2 grupos para ter uma aula específica. Cada matéria do par tem a sua quantidade de aulas (campos "Aulas de A" e "Aulas de B"), e o campo Blocos diz em quantos conjuntos de aulas seguidas o par é dividido ao longo dos dias. O par ocupa max(A, B) horários: em min(A, B) deles os dois grupos têm aula; no resto só a matéria maior tem aula, no grupo 2, e o grupo 1 fica livre ("G1 livre"). Por exemplo, A = 2 e B = 4 em 1 bloco = 4 horários seguidos, 2 com os dois grupos e 2 só com B. Já 8 e 8 em 2 blocos = 2 conjuntos de 4 aulas geminadas. O restante de cada matéria é distribuído sozinho.

Página 2 — indisponibilidade

A grade do professor marca os horários em que ele não pode dar aula. A geração e a edição da página 3 usam essas marcações como parâmetros para ver quando os professores podem dar aula.

Página 3 — horário

No topo ficam os botões "Gerar" e "PDF", em destaque e sempre visíveis; os dois valem para todas as turmas. Abaixo, a página mostra a grade de uma turma, permite editar uma célula, limpar a grade de uma turma, gerar o horário de todas as turmas e criar um PDF com tudo que foi falado em folhas. Cada folha é uma turma e mostra os turnos da turma e também qualquer outro turno em que ela tenha aula, com as linhas ajustadas para caber numa folha A4 deitada. No PDF, aulas seguidas iguais (mesma matéria, professor e sala) aparecem como uma só, ocupando o espaço dos horários juntos.

O "Gerar" monta o horário primeiro e depois troca a grade inteira de uma vez, numa transação no banco: se a gravação falhar, a grade anterior continua como estava.

Ao tocar numa célula abre o diálogo da aula. Ele confere as regras antes de fechar: se algo impedir a gravação, o diálogo continua aberto mostrando o motivo.

Também dá para arrastar uma aula para outra célula. Soltar numa célula ocupada (ou com professor ocupado, indisponível ou sala de outra turma) é recusado com uma mensagem embaixo. Uma aula geminada anda em conjunto: os dois grupos e todos os horários seguidos do par (inclusive os com G1 livre) vão juntos, mantendo a distância do horário pego, e precisam de horários vazios seguidos no mesmo turno.

Na coluna dos rótulos dá para digitar o horário de cada período, no formato "HH:MM - HH:MM". O campo só aceita números e coloca o ":" e o " - " sozinho; hora acima de 23 ou minuto acima de 59 não é salvo. O horário vale para todas as turmas e também sai no PDF.

A grade é de segunda a sexta, com 16 períodos: 6 de manhã, o intervalo "Almoço", 6 de tarde, o intervalo "Jantar" e 4 à noite.

## Regras do horário

- Um professor não fica em dois lugares no mesmo horário.
- Uma sala não é usada por duas turmas no mesmo horário, e em alguns casos dois grupos da mesma turma podem dividir a sala.
- A aula geminada coloca as duas matérias no mesmo horário, em grupos diferentes, com matérias diferentes (logo professores também). Cada horário tem no máximo 2 grupos.
- Na página 3, o segundo grupo de uma célula só pode ser colocado se o par já estiver cadastrado no curso.
- Excluir um dos grupos de um par deixa o outro no grupo 2 (G1 livre); excluir esse também deixa o horário vazio.
- O gerador coloca primeiro os blocos geminados, e depois distribui o que sobrou de cada matéria, em blocos, usando só os turnos do curso (na ordem do turno escolhido). Ele tenta um bloco por matéria por dia e só repete o dia quando a carga não cabe na semana.
- A edição manual (tocar ou arrastar) pode colocar uma aula em qualquer turno, sem aviso.
- Ao excluir uma matéria ou um professor, ou tirar um par de um curso, os grupos são arrumados: uma aula sozinha no grupo 2 que não tem mais par vira aula completa (grupo 1); se o professor excluído dava o grupo 2 de um par que ainda existe, o grupo 1 que sobra passa para o grupo 2. Duas aulas juntas que não formam mais par ficam como estão, e o validador avisa "Par não geminado".
- O painel de avisos da página 3 também aponta: aulas faltando ou sobrando, professor indisponível ou em dois lugares, sala ocupada por outra turma, professor não vinculado à matéria, grupo 2 sozinho sem par, aula geminada configurada com mais aulas que a carga da matéria e a contagem de horários de cada geminada (contada por matéria quando dois pares dividem a mesma matéria maior).

## Stack

- Flutter Web, Dart SDK `^3.12.0`
- Riverpod, para o estado e os dados em tempo real
- Supabase, como banco Postgres (com funções que gravam em uma transação)
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

Eles cobrem o gerador (inclusive aulas geminadas em blocos), o validador da página 3, o formulário do curso e a edição da grade na página 3. Os arquivos `geminada_cargas_diferentes_test.dart` (geminada com cargas diferentes: gerador, validador, exclusão e arraste), `noite_horarios_salas_test.dart` (turno da noite, PDF, horários dos períodos e tipos de sala) e `formato_horario_test.dart` (máscara e validação do horário) cobrem as partes mais novas.

O aplicativo já aponta para o projeto Supabase usado em produção. As tabelas principais são `tb_professor`, `tb_materia`, `tb_sala`, `tb_tipo_sala`, `tb_curso`, `tb_curso_materia`, `tb_professor_materia`, `tb_professor_indisponibilidade`, `tb_curso_aula_geminada`, `tb_horario_periodo` e `tb_aula`.

Para preparar o banco, rode no SQL Editor do Supabase, nesta ordem:

1. `supabase_aulas_geminadas.sql`
2. `supabase_noite_tipos_horarios.sql`
3. `supabase_turnos_transacoes.sql` — a última parte dele (`alter publication supabase_realtime ...`) só deve ser rodada depois de publicar a versão nova do app.

O terceiro script cria as funções `substituir_aulas` (usada pelo "Gerar") e `salvar_carga_e_pares` (salva a carga e os pares do curso e apaga as aulas de matérias que saíram da carga), e faz o banco apagar em cascata: excluir matéria, professor ou curso apaga as aulas ligadas a eles, e excluir uma sala deixa as aulas sem sala. Enquanto a parte do tempo real não for rodada, as telas se atualizam depois de cada ação feita no próprio app, mas não percebem mudanças feitas em outra aba ou por outra pessoa.

## Publicação

O arquivo `vercel.json` baixa o Flutter 3.47.7 (versão fixa), gera o Flutter Web no build da Vercel e publica a pasta `build/web`. Um push na branch `master` do repositório [FenixPelada/newTCC](https://github.com/FenixPelada/newTCC) dispara o deploy de produção, e é assim que a versão do site é atualizada.

Também dá para rodar com Docker: o `Dockerfile` usa a mesma versão do Flutter e serve o build com Nginx. O `docker/nginx.conf` manda `no-cache` para o `index.html` e o service worker, para o navegador não ficar com a versão antiga depois de um deploy.
