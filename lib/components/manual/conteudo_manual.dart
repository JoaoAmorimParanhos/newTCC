import 'package:flutter/material.dart';

/// Um assunto do manual ("Como usar").
///
/// Nos textos, o que estiver entre **asteriscos duplos** aparece em
/// negrito: use para o nome exato dos botões e campos da tela.
class SecaoManual {
  const SecaoManual({
    required this.id,
    required this.titulo,
    required this.onde,
    required this.icone,
    required this.passos,
    this.dica,
  });

  /// Identificador (usado para abrir o manual direto neste assunto).
  final String id;
  final String titulo;

  /// Em que parte do sistema isso fica (aparece acima do título).
  final String onde;
  final IconData icone;
  final List<String> passos;
  final String? dica;
}

/// Espaço que não quebra linha: mantém "1. Cadastros" inteiro na mesma
/// linha (sem o número sobrar sozinho no fim de uma linha).
const _nb = '\u00a0';

/// Todos os assuntos, na ordem em que o sistema é usado.
///
/// Para corrigir uma frase do manual, basta mudar o texto aqui.
const List<SecaoManual> secoesManual = [
  SecaoManual(
    id: 'inicio',
    titulo: 'Por onde começar',
    onde: 'Visão geral',
    icone: Icons.flag_outlined,
    passos: [
      'O sistema tem três partes, nos botões do topo da tela: '
          '**1.${_nb}Cadastros**, **2.${_nb}Disponibilidade** e **3.${_nb}Horário**.',
      'Comece por **1.${_nb}Cadastros**: cadastre as salas, os componentes, '
          'os professores e os cursos (turmas).',
      'Depois, em **2.${_nb}Disponibilidade**, marque os horários em que cada '
          'professor não pode dar aula.',
      'Por último, em **3.${_nb}Horário**, clique em **Gerar** para montar o '
          'horário de todas as turmas.',
      'Confira o resultado, ajuste o que precisar e clique em **PDF** para '
          'imprimir.',
    ],
    dica:
        'O que você salva fica guardado. Pode fechar o navegador e continuar '
        'outro dia, do ponto em que parou.',
  ),
  SecaoManual(
    id: 'salas',
    titulo: 'Cadastrar salas',
    onde: '1. Cadastros',
    icone: Icons.meeting_room_outlined,
    passos: [
      'Na coluna **Salas**, clique no botão **+** que fica no alto da coluna.',
      'Escolha o **Tipo** da sala, por exemplo Sala de aula ou Laboratório. '
          'Se precisar de um tipo que ainda não existe, como Quadra, '
          'clique no **+** ao lado do campo **Tipo**, escreva o nome e '
          'clique no sinal de confirmar.',
      'Digite o **Número da sala** e clique em **Salvar**.',
    ],
    dica:
        'Para mudar uma sala, clique no lápis ao lado dela. Para apagar, '
        'clique na lixeira vermelha.',
  ),
  SecaoManual(
    id: 'componentes',
    titulo: 'Cadastrar componentes',
    onde: '1. Cadastros',
    icone: Icons.menu_book_outlined,
    passos: [
      '"Componente" é cada matéria ou disciplina, como Matemática ou Física.',
      'Na coluna **Componentes**, clique no botão **+** no alto da coluna.',
      'Escreva o **Nome** e marque os professores que dão esse componente.',
      'Clique em **Salvar**.',
    ],
    dica:
        'Apagar um componente também apaga as aulas dele no horário. O '
        'sistema pergunta antes de apagar.',
  ),
  SecaoManual(
    id: 'professores',
    titulo: 'Cadastrar professores',
    onde: '1. Cadastros',
    icone: Icons.person_outline,
    passos: [
      'Na coluna **Professores**, clique no botão **+** no alto da coluna.',
      'Escreva o nome e marque os componentes que ele dá.',
      'Clique em **Salvar**.',
    ],
    dica:
        'Para achar alguém rápido, escreva parte do nome no campo **Buscar**, '
        'logo acima da lista. Funciona com ou sem acento.',
  ),
  SecaoManual(
    id: 'cursos',
    titulo: 'Cadastrar cursos e a carga',
    onde: '1. Cadastros',
    icone: Icons.school_outlined,
    passos: [
      'Na coluna **Cursos**, clique no botão **+** no alto da coluna.',
      'Escreva o nome da turma, por exemplo Informática 1.',
      'Escolha o **Turno**: Manhã, Tarde, Noite, **Manhã - CT: Tarde** '
          '(começa pela manhã e o que não couber vai para a tarde) ou '
          '**Tarde - CT: Manhã**.',
      'Se a turma tem uma sala fixa, escolha a **Sala padrão**.',
      'Em **Componentes, carga e blocos**, clique em **+ Linha** para cada '
          'componente da turma. Escolha o componente e escreva a '
          '**Qtd. de aulas** por semana.',
      '**Bloco** é quantas aulas desse componente acontecem seguidas, no '
          'mesmo dia. Clique no **?** ao lado do título para ver um exemplo.',
      'Clique em **Salvar**.',
    ],
    dica:
        'Se algo estiver errado, a mensagem aparece em vermelho embaixo do '
        'campo, e o formulário só fecha depois de corrigido.',
  ),
  SecaoManual(
    id: 'dividida',
    titulo: 'Aula dividida (dois grupos)',
    onde: '1. Cadastros',
    icone: Icons.call_split,
    passos: [
      'Use quando a turma se divide em dois grupos no mesmo horário: o '
          '**Grupo 1 (G1)** tem um componente e o **Grupo 2 (G2)** tem outro.',
      'Os dois componentes precisam estar na carga do curso.',
      'No formulário do curso, em **Aulas divididas**, clique em **+ Aula**.',
      'Escolha o **Componente A**, o **Componente B** e a **Qtd. de aulas** '
          'de cada um. Se o campo do B ficar vazio, ele usa a mesma '
          'quantidade do A.',
      '**Blocos** é em quantas partes essas aulas são divididas na semana. '
          'O **?** ao lado do título mostra um exemplo.',
    ],
    dica:
        'Quando um componente tem menos aulas que o outro, aparece '
        '**G1 livre** nos horários em que só o G2 tem aula. Isso é normal.',
  ),
  SecaoManual(
    id: 'disponibilidade',
    titulo: 'Horários em que o professor não pode',
    onde: '2. Disponibilidade',
    icone: Icons.event_busy_outlined,
    passos: [
      'Clique em **2.${_nb}Disponibilidade**, no topo da tela.',
      'Na lista **Professores**, à direita, clique no nome do professor.',
      'Na grade, clique nos horários em que ele **não pode** dar aula. Eles '
          'ficam vermelhos.',
      'Clicou no lugar errado? Clique de novo no mesmo horário para '
          'desmarcar.',
    ],
    dica:
        'Não precisa salvar: cada clique já fica guardado. O **Gerar** nunca '
        'coloca aula nos horários vermelhos.',
  ),
  SecaoManual(
    id: 'gerar',
    titulo: 'Gerar o horário',
    onde: '3. Horário',
    icone: Icons.auto_awesome_outlined,
    passos: [
      'Clique em **3.${_nb}Horário**, no topo da tela.',
      'Clique em **Gerar**. O sistema monta o horário de **todas** as '
          'turmas de uma vez.',
      'Confirme. Atenção: isso apaga o horário atual e faz um novo.',
      'Na lista **Cursos**, à esquerda, clique numa turma para ver a grade '
          'dela.',
      'Embaixo da grade aparecem os avisos, por exemplo aulas que não '
          'couberam.',
    ],
    dica:
        'Se aparecer "Parcial", algumas aulas não couberam. Leia os avisos: '
        'em geral falta professor disponível ou horário livre no turno.',
  ),
  SecaoManual(
    id: 'editar',
    titulo: 'Colocar, mudar ou apagar uma aula',
    onde: '3. Horário',
    icone: Icons.edit_outlined,
    passos: [
      'Com a turma aberta, clique num horário vazio para colocar uma aula. '
          'Escolha o **Componente**, o **Professor** e a **Sala** e clique '
          'em **Salvar**.',
      'Só aparecem os componentes da carga do curso. Para usar um '
          'componente novo, coloque-o antes no curso, em **1.${_nb}Cadastros**.',
      'Clique numa aula para trocar o professor ou a sala, ou para '
          '**Excluir** a aula.',
      'Se o horário tem dois grupos, o sistema pergunta qual grupo você '
          'quer mudar.',
    ],
    dica:
        'Se o professor escolhido não pode naquele horário, aparece um aviso '
        'laranja e o sistema não deixa salvar até trocar.',
  ),
  SecaoManual(
    id: 'arrastar',
    titulo: 'Mudar aulas de lugar',
    onde: '3. Horário',
    icone: Icons.open_with,
    passos: [
      'Clique na aula, segure o botão do mouse e arraste até outro horário. '
          'Depois solte.',
      'Enquanto você arrasta, o horário fica **verde** se pode soltar ali e '
          '**vermelho** se não pode.',
      'Soltar em cima de outra aula **troca as duas de lugar**.',
      'A aula dividida anda inteira: os dois grupos e os horários seguidos '
          'vão juntos.',
    ],
    dica:
        'Se não der para soltar, o motivo aparece embaixo da grade, por '
        'exemplo professor ocupado em outra turma.',
  ),
  SecaoManual(
    id: 'relogio',
    titulo: 'Hora de cada aula',
    onde: '3. Horário',
    icone: Icons.schedule,
    passos: [
      'Na primeira coluna da grade, ao lado de cada aula (1º, 2º...), há um '
          'campo para a hora.',
      'Clique nele e digite só os números, por exemplo 07300820. O sistema '
          'escreve "07:30 - 08:20" sozinho.',
      'Aperte **Enter** ou clique fora do campo para salvar.',
    ],
    dica:
        'A hora vale para todas as turmas e também sai no PDF. Se a hora do '
        'fim for antes da hora do início, o sistema avisa e não salva.',
  ),
  SecaoManual(
    id: 'pdf',
    titulo: 'Imprimir o horário',
    onde: '3. Horário',
    icone: Icons.picture_as_pdf_outlined,
    passos: [
      'Em **3.${_nb}Horário**, clique em **PDF**.',
      'O sistema monta uma folha por turma, em ordem alfabética.',
      'Na janela que abrir, escolha imprimir ou salvar o arquivo.',
    ],
    dica:
        'A sala padrão da turma aparece no alto da folha. Quando uma aula usa '
        'outra sala, ela aparece junto do nome do professor.',
  ),
  SecaoManual(
    id: 'avisos',
    titulo: 'Avisos e dúvidas',
    onde: '3. Horário',
    icone: Icons.help_outline,
    passos: [
      '**Faltam X aula(s)**: a turma ainda não tem todas as aulas da carga. '
          'Coloque as que faltam clicando nos horários vazios ou use '
          '**Gerar**.',
      '**Carga completa**: o componente já tem todas as aulas da semana. '
          'Para colocar mais, aumente a **Qtd. de aulas** no curso.',
      '**G1 livre**: na aula dividida, só o Grupo 2 tem aula naquele horário.',
      '**No horário errado**: o professor está com esse horário marcado '
          'como indisponível em **2.${_nb}Disponibilidade**. Mude a aula de lugar '
          'ou troque o professor.',
      '**Par sem aula dividida cadastrada**: há dois grupos no mesmo horário, '
          'mas o curso não tem essa aula dividida. Cadastre-a no curso ou '
          'apague uma das aulas.',
      'Para apagar a grade inteira de uma turma, use o botão de lixeira no '
          'alto da grade (**Limpar grade**).',
    ],
    dica:
        'Na dúvida, abra este manual de novo pelo botão **Como usar**, no '
        'topo de qualquer tela.',
  ),
];

/// Assunto que o manual mostra primeiro, conforme a tela aberta.
int secaoInicialDaRota(String? rota) {
  final id = switch (rota) {
    '/page2' => 'disponibilidade',
    '/page3' => 'gerar',
    _ => 'inicio',
  };
  return secoesManual.indexWhere((s) => s.id == id);
}
