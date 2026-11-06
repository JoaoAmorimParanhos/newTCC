# Projeto Timetable

Aplicação web para montar o horário de turmas de uma escola. O cadastro fica em **1. Cadastros**, a indisponibilidade dos professores em **2. Disponibilidade** e a grade, a geração automática e o PDF em **3. Horário** (no código, `page1`, `page2` e `page3`). O botão **Como usar**, no topo de todas as telas, abre um manual passo a passo para quem vai usar o sistema.

Site: https://new-tcc-jvarparanhos-9069s-projects.vercel.app/

## Páginas

### 1. Cadastros

Quatro colunas: professores, componentes, salas e cursos. Cada lista aparece na ordem em que os itens foram criados e tem um campo "Buscar" no topo, que filtra pelo nome sem diferenciar maiúsculas e acentos.

- O professor é ligado aos componentes que pode dar aula.
- A sala tem tipo e número. Os tipos são cadastrados pelo usuário no próprio diálogo da sala; o banco já vem com "Sala de aula", "Laboratório de informática" e "Quadra". O mesmo número pode existir em tipos diferentes, porém não pode existir duas salas do mesmo tipo com o mesmo número.
- Os cursos têm nome, sala padrão opcional e um turno:
  - Manhã, Tarde ou Noite: o gerador usa só esse turno.
  - Manhã - CT: Tarde: preenche a manhã e o que não couber vai para a tarde (contraturno).
  - Tarde - CT: Manhã: preenche a tarde e o que não couber vai para a manhã.
- Cada componente do curso tem quantidade de aulas e tamanho de bloco. O bloco é o número de aulas consecutivas no mesmo turno, de 1 até a carga do componente, limitado pelo turno: no máximo 6 de manhã ou à tarde e no máximo 4 à noite. O formulário e o gerador respeitam esse limite.
- Uma aula dividida é um par de componentes que acontecem juntos, pensando na funcionalidade de uma turma ser dividida em 2 grupos para ter uma aula específica. Cada componente do par tem a sua quantidade de aulas (campos "Qtd. de aulas" do Componente A e do Componente B), e o campo Blocos diz em quantos conjuntos de aulas seguidas o par é dividido ao longo dos dias. O par ocupa max(A, B) horários: em min(A, B) deles os dois grupos têm aula; no resto só o componente maior tem aula, no grupo 2, e o grupo 1 fica livre ("G1 livre"). Por exemplo, A = 2 e B = 4 em 1 bloco = 4 horários seguidos, 2 com os dois grupos e 2 só com B. Já 8 e 8 em 2 blocos = 2 conjuntos de 4 aulas divididas. O restante de cada componente é distribuído sozinho.

### 2. Disponibilidade

A grade do professor marca os horários em que ele não pode dar aula. A geração e a edição da tela de Horário usam essas marcações como parâmetros para ver quando os professores podem dar aula.

### 3. Horário

No topo ficam os botões "Gerar" e "PDF", em destaque e sempre visíveis; os dois valem para todas as turmas. Abaixo, a página mostra a grade de uma turma, permite editar uma célula, limpar a grade de uma turma, gerar o horário de todas as turmas e criar um PDF com tudo que foi falado em folhas. Cada folha é uma turma e mostra os turnos da turma e também qualquer outro turno em que ela tenha aula, com as linhas ajustadas para caber numa folha A4 deitada. No PDF, aulas seguidas iguais (mesmo componente, professor e sala) aparecem como uma só, ocupando o espaço dos horários juntos. A sala padrão da turma sai no topo da folha; quando uma aula usa outra sala, ela aparece ao lado do professor. As folhas seguem a ordem alfabética das turmas, sem diferenciar acentos e maiúsculas.

O "Gerar" monta o horário primeiro e depois troca a grade inteira de uma vez, numa transação no banco: se a gravação falhar, a grade anterior continua como estava.

Ao tocar numa célula vazia abre o diálogo de aula nova, que só oferece os componentes que estão na carga do curso (Cadastros); um componente novo precisa ser adicionado na carga do curso para aparecer aqui. Tocar numa aula abre a edição dela (com 2 grupos, pergunta qual). O diálogo confere as regras antes de fechar: se algo impedir a gravação (por exemplo "Carga completa" ou dois componentes que não formam aula dividida no curso), ele continua aberto mostrando o motivo. A tela de Horário não muda a carga nem as aulas divididas: excluir uma aula só tira a aula da grade, e o painel passa a mostrar "Faltam X aula(s)".

Também dá para arrastar uma aula para outra célula. Soltar uma aula comum em cima de outra aula comum troca as duas de lugar (pode ser entre turnos diferentes), desde que cada professor possa dar aula no horário da outra e a sala esteja livre; se não puder, aparece o motivo embaixo. Soltar onde o professor está ocupado ou indisponível, ou onde a sala é de outra turma, também é recusado com uma mensagem. Uma aula dividida anda em conjunto: os dois grupos e todos os horários seguidos do par (inclusive os com G1 livre) vão juntos, mantendo a distância do horário pego, e precisam de horários vazios seguidos no mesmo turno.

Na coluna dos rótulos dá para digitar o horário de cada período, no formato "HH:MM - HH:MM". O campo só aceita números e coloca o ":" e o " - " sozinho; hora acima de 23, minuto acima de 59 ou fim antes do início não é salvo. Colar um horário (ex.: "7:30 - 8:20"), mesmo por cima de outro, já encaixa no molde. O horário vale para todas as turmas e também sai no PDF.

A grade é de segunda a sexta, com 16 períodos: 6 de manhã, o intervalo "Almoço", 6 de tarde, o intervalo "Jantar" e 4 à noite.

### Como usar (manual)

O botão **Como usar**, no topo de todas as telas, abre um manual com 13 assuntos na ordem em que o sistema é usado: por onde começar, cadastros (salas, componentes, professores, cursos e aula dividida), disponibilidade, gerar, mudar e arrastar aulas, hora de cada aula, PDF e o que significa cada aviso. Cada assunto tem passos numerados com letra grande e uma dica. O manual abre no assunto da tela em que a pessoa está e tem botões Anterior e Próximo para ler tudo em ordem. Os textos ficam em `lib/components/manual/conteudo_manual.dart`: para corrigir uma frase, basta mudar o texto lá (o que estiver entre `**` sai em negrito).

## Regras do horário

- Um professor não fica em dois lugares no mesmo horário.
- Uma sala não é usada por duas turmas no mesmo horário, e em alguns casos dois grupos da mesma turma podem dividir a sala.
- A aula dividida coloca os dois componentes no mesmo horário, em grupos diferentes, com componentes diferentes (logo professores também). Cada horário tem no máximo 2 grupos.
- Na tela de Horário, o segundo grupo de uma célula só pode ser colocado se o par já estiver cadastrado no curso.
- Excluir um dos grupos de um par deixa o outro no grupo 2 (G1 livre); excluir esse também deixa o horário vazio. Se os dois componentes não formam mais par na tela de Cadastros, a aula que sobra vira aula comum (grupo 1). Trocar o componente de uma aula sozinha no grupo 2 por um que não está em nenhuma aula dividida também a torna aula comum.
- Editar professor ou sala de uma aula que já está na grade não esbarra em "Carga completa" (mesmo se a carga diminuiu depois); a carga só é conferida quando entra uma aula nova do componente. Se o professor atual ficou indisponível ou ocupado, o diálogo mostra o aviso em laranja.
- Na tela de Cadastros, salvar um curso que tira componentes da carga pergunta antes, dizendo quantas aulas serão apagadas da grade; mudar o turno com aulas fora do turno novo também avisa (elas continuam na grade até o próximo "Gerar"). Se a gravação da carga falhar, o curso volta como estava.
- O gerador coloca primeiro os blocos das aulas divididas, e depois distribui o que sobrou de cada componente, em blocos, usando só os turnos do curso (na ordem do turno escolhido). Ele tenta um bloco por componente por dia e só repete o dia quando a carga não cabe na semana. Prefere manter o mesmo professor em todos os blocos de um componente da turma. Quando um bloco não cabe em lugar nenhum, divide em blocos menores (ex.: 4 vira 2 + 2) e avisa. Curso ainda sem carga é ignorado sem contar como falha.
- A edição manual (tocar ou arrastar) pode colocar uma aula em qualquer turno, sem aviso.
- Ao excluir um componente ou um professor, ou tirar um par de um curso, os grupos são arrumados: uma aula sozinha no grupo 2 que não tem mais par vira aula completa (grupo 1); se o professor excluído dava o grupo 2 de um par que ainda existe, o grupo 1 que sobra passa para o grupo 2. Duas aulas juntas que não formam mais par ficam como estão, e o validador avisa "Par sem aula dividida cadastrada".
- O painel de avisos da tela de Horário também aponta: aulas faltando ou sobrando, professor indisponível ou em dois lugares, sala ocupada por outra turma, professor não vinculado ao componente, grupo 2 sozinho sem par, aula dividida configurada com mais aulas que a carga do componente e a contagem de horários de cada aula dividida (contada por componente quando dois pares dividem o mesmo componente maior).

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

Eles cobrem o gerador (inclusive aulas divididas em blocos), o validador da tela de Horário, o formulário do curso e a edição da grade na tela de Horário. Os arquivos `geminada_cargas_diferentes_test.dart` (aula dividida com cargas diferentes: gerador, validador, exclusão e arraste), `noite_horarios_salas_test.dart` (turno da noite, PDF, horários dos períodos e tipos de sala) e `formato_horario_test.dart` (máscara e validação do horário) cobrem as partes mais novas. As correções mais recentes estão em `correcoes_revisao_logica_test.dart`, `troca_busca_erros_test.dart`, `textos_e_cabecalho_test.dart`, `coluna_curso_test.dart` e `manual_test.dart` (manual e nomes das páginas).

O aplicativo já aponta para o projeto Supabase usado em produção. As tabelas principais são `tb_professor`, `tb_materia`, `tb_sala`, `tb_tipo_sala`, `tb_curso`, `tb_curso_materia`, `tb_professor_materia`, `tb_professor_indisponibilidade`, `tb_curso_aula_geminada`, `tb_horario_periodo` e `tb_aula`.

Para preparar o banco, rode no SQL Editor do Supabase, nesta ordem:

1. `supabase_aulas_geminadas.sql`
2. `supabase_noite_tipos_horarios.sql`
3. `supabase_turnos_transacoes.sql` — a última parte dele (`alter publication supabase_realtime ...`) só deve ser rodada depois de publicar a versão nova do app.

O terceiro script cria as funções `substituir_aulas` (usada pelo "Gerar") e `salvar_carga_e_pares` (salva a carga e os pares do curso e apaga as aulas de componentes que saíram da carga), e faz o banco apagar em cascata: excluir componente, professor ou curso apaga as aulas ligadas a eles, e excluir uma sala deixa as aulas sem sala. Enquanto a parte do tempo real não for rodada, as telas se atualizam depois de cada ação feita no próprio app, mas não percebem mudanças feitas em outra aba ou por outra pessoa.

O arquivo `supabase_aula_e_cadastro.sql` não é mais usado (era de uma versão em que a tela de Horário mudava a carga) e não precisa ser rodado.

## Publicação

O arquivo `vercel.json` baixa o Flutter 3.47.7 (versão fixa), gera o Flutter Web no build da Vercel e publica a pasta `build/web`. Um push na branch `master` do repositório [FenixPelada/newTCC](https://github.com/FenixPelada/newTCC) dispara o deploy de produção, e é assim que a versão do site é atualizada.

Também dá para rodar com Docker: o `Dockerfile` usa a mesma versão do Flutter e serve o build com Nginx. O `docker/nginx.conf` manda `no-cache` para o `index.html` e o service worker, para o navegador não ficar com a versão antiga depois de um deploy.
