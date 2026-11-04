# Diagramas de sequência — Timetable

App Flutter + Riverpod + Supabase para montagem de horários escolares.

---

## 1. Visão geral dos fluxos

```mermaid
sequenceDiagram
    actor U as Usuário
    participant P1 as Página 1
    participant P2 as Página 2
    participant P3 as Página 3
    participant Prov as Providers
    participant Repo as Repositórios
    participant SB as Supabase
    participant Ger as GeradorHorario
    participant Val as ValidadorHorario
    participant PDF as ExportadorHorarioPdf

    Note over U,SB: 1. Cadastro (Página 1)
    U->>P1: Cria salas (e tipos de sala), matérias, professores, cursos
    P1->>Repo: adicionar / atualizar
    Repo->>SB: INSERT/UPDATE (curso: rpc salvar_carga_e_pares)
    SB-->>Repo: OK
    P1->>Prov: invalidate providers (a coluna invalida, não o repositório)
    Prov->>Repo: observarTodos (SELECT + realtime)
    Prov-->>P1: listas atualizadas (ordem de criação)

    Note over U,SB: 2. Indisponibilidade (Página 2)
    U->>P2: Seleciona professor e marca células
    P2->>Repo: adicionar/excluir indisponibilidade
    Repo->>SB: INSERT/DELETE
    SB-->>Repo: OK (salvo)
    P2->>Prov: invalidate provedorIndisponibilidades

    Note over U,PDF: 3. Gerar horários (Página 3)
    U->>P3: Clica "Gerar" (barra do topo, todas as turmas)
    P3->>U: Confirma regeneração
    U-->>P3: Confirma
    P3->>Ger: gerarTodos(cursos, cargas, professores, ligações, indisponibilidades, geminadas)
    Ger-->>P3: novasAulas + falhas
    alt Nenhuma aula gerada
        P3-->>U: "Não foi possível gerar (grade atual mantida)"
    else Gerou aulas
        P3->>Repo: substituirTodas(novasAulas)
        Repo->>SB: rpc substituir_aulas(novas) — uma transação
        alt Erro
            SB-->>P3: erro: nada muda (grade anterior mantida)
        else OK
            SB-->>P3: grade trocada inteira
        end
    end
    P3->>Prov: invalidate provedorAulas
    Prov->>Repo: observar/buscar aulas
    Repo->>SB: SELECT
    SB-->>P3: aulas
    P3->>Val: validarCurso(turma selecionada)
    Val-->>P3: Sem problemas / lista de erros
    P3-->>U: Grade + painel de validação

    Note over U,SB: 4. Editar célula (Página 3)
    U->>P3: Toca célula
    P3->>U: Dialog matéria / professor / sala
    U-->>P3: Salvar ou Excluir
    alt Excluir
        P3->>Repo: excluir(aula)
        opt Era um grupo de um par
            P3->>Repo: atualizar(aula que sobra → grupo 2, G1 livre)
        end
    else Salvar
        P3->>P3: validarSalvarAula (regras) antes de fechar o diálogo
        Note right of P3: se recusar, o diálogo continua aberto com o motivo
        P3->>Repo: adicionar ou atualizar
    end
    Repo->>SB: escrita
    P3->>Prov: invalidate
    P3->>Val: validarCurso
    Val-->>U: painel atualizado

    Note over U,PDF: 5. Exportar PDF
    U->>P3: Clica "PDF" (barra do topo)
    P3->>PDF: gerar(todas turmas, aulas, nomes, horários dos períodos)
    PDF-->>P3: bytes do PDF (A4 paisagem, 1 pág/turma, turnos do curso + turnos com aula)
    P3-->>U: Preview / impressão (Printing)
```

---

## 2. Detalhe — Gerador de horário

```mermaid
sequenceDiagram
    participant P3 as Página 3
    participant Ger as GeradorHorario

    P3->>Ger: gerarTodos()
    Ger->>Ger: Ordena cursos (maior carga primeiro)

    loop Cada curso
        Ger->>Ger: Aloca primeiro os blocos geminados (max(A, B) horários, o resto da maior no G2)
        Ger->>Ger: Para cada matéria da carga
        Ger->>Ger: Quebra em blocos (até 6 de manhã/tarde, 4 à noite)
        Ger->>Ger: Usa só os turnos do curso (Manhã, Tarde, Noite ou CT, na ordem)

        loop Cada bloco
            Ger->>Ger: Percorre dias e horários
            Ger->>Ger: Checa turma livre, professor, sala, 1 bloco/matéria/dia
            alt Cabe
                Ger->>Ger: Coloca bloco em memória
            else Não cabe
                Ger->>Ger: Registra falha
            end
        end
    end

    Ger-->>P3: ResultadoGeracaoCompleta
```

---

## 3. Detalhe — Cadastro de curso (Página 1)

```mermaid
sequenceDiagram
    actor U as Usuário
    participant Col as ColunaCurso
    participant Dialog as DialogoFormularioCurso
    participant Repo as RepositorioCurso
    participant SB as Supabase
    participant Prov as Providers

    U->>Col: Adicionar / Editar curso
    Col->>Dialog: abrir (nome, turno, sala, matérias, blocos, geminadas)
    U->>Dialog: Preenche e Salvar
    Dialog-->>Col: ResultadoFormularioCurso
    Col->>Repo: adicionar / atualizar (cargas + pares)
    Repo->>SB: INSERT / UPDATE tb_curso
    Repo->>SB: rpc salvar_carga_e_pares(p_id_curso, p_cargas, p_pares)
    Note right of SB: numa transação: troca tb_curso_materia e<br/>tb_curso_aula_geminada e apaga as aulas<br/>de matérias que saíram da carga
    SB-->>Repo: OK
    opt Editar
        Col->>Repo: arrumarGruposSemPar (aula sozinha no G2 sem par vira grupo 1)
    end
    Col->>Prov: invalidate cursos, cargas, geminadas (e aulas ao editar)
    Prov-->>Col: lista atualizada
```

---

## 4. Participantes (resumo)

| Participante | Papel |
|--------------|--------|
| Página 1 | CRUD de salas (e tipos de sala), matérias, professores e cursos; invalida os providers depois de gravar |
| Página 2 | Indisponibilidade de professores na grade |
| Página 3 | Visualizar, gerar, editar aulas, editar o horário dos períodos e exportar PDF |
| Providers | Riverpod — streams e repositórios |
| Repositórios | Acesso REST/RPC/Realtime ao Supabase (não invalidam providers) |
| GeradorHorario | Aloca blocos respeitando regras, só nos turnos do curso |
| ValidadorHorario | Avisos na faixa abaixo da grade |
| ExportadorHorarioPdf | PDF A4 paisagem, uma página por turma |

---

## Como visualizar

- **GitHub / GitLab:** o Mermaid renderiza no próprio `.md`
- **VS Code / Cursor:** extensão “Markdown Preview Mermaid Support” ou preview nativo
- **Online:** [mermaid.live](https://mermaid.live) — cole os blocos `mermaid`
