-- Rode no SQL Editor do Supabase depois de supabase_noite_tipos_horarios.sql.
-- 1) Novos turnos  2) Exclusões em cascata  3) Gravações em uma transação
-- 4) Tempo real (rodar só DEPOIS de publicar o app novo)

-- 1) Turnos: Manhã, Tarde, Noite, Manhã CT: Tarde, Tarde CT: Manhã -----------
alter table public.tb_curso drop constraint if exists tb_curso_periodo_preferencia_check;
alter table public.tb_curso
  add constraint tb_curso_periodo_preferencia_check
  check (periodo_preferencia in
    ('apenas_manha', 'apenas_tarde', 'noite', 'manha_tarde', 'tarde_manha'));

-- 2) Excluir matéria ou professor apaga as aulas dela/dele no próprio banco
--    (um só comando, sem ficar pela metade).
alter table public.tb_aula drop constraint if exists tb_aula_id_materia_fkey;
alter table public.tb_aula
  add constraint tb_aula_id_materia_fkey
  foreign key (id_materia) references public.tb_materia(id) on delete cascade;

alter table public.tb_aula drop constraint if exists tb_aula_id_professor_fkey;
alter table public.tb_aula
  add constraint tb_aula_id_professor_fkey
  foreign key (id_professor) references public.tb_professor(id) on delete cascade;

-- 3a) "Gerar": troca a grade inteira numa transação. Se algo falhar,
--     nada muda (a grade anterior continua).
create or replace function public.substituir_aulas(novas jsonb)
returns void
language plpgsql
set search_path = public
as $$
begin
  delete from tb_aula where true;
  insert into tb_aula
    (id_curso, dia_semana, periodo, id_materia, id_professor, id_sala, grupo)
  select
    (a->>'id_curso')::bigint,
    (a->>'dia_semana')::int,
    (a->>'periodo')::int,
    (a->>'id_materia')::bigint,
    (a->>'id_professor')::bigint,
    nullif(a->>'id_sala', '')::bigint,
    coalesce((a->>'grupo')::int, 1)
  from jsonb_array_elements(novas) as a;
end;
$$;

-- 3b) Salvar a carga e os pares de aula geminada de um curso de uma vez,
--     apagando as aulas de matérias que saíram da carga.
create or replace function public.salvar_carga_e_pares(
  p_id_curso bigint,
  p_cargas jsonb,
  p_pares jsonb
)
returns void
language plpgsql
set search_path = public
as $$
begin
  delete from tb_curso_materia where id_curso = p_id_curso;
  insert into tb_curso_materia (id_curso, id_materia, quantidade_aulas, tamanho_bloco)
  select
    p_id_curso,
    (c->>'id_materia')::int,
    (c->>'quantidade_aulas')::int,
    (c->>'tamanho_bloco')::int
  from jsonb_array_elements(p_cargas) as c;

  delete from tb_curso_aula_geminada where id_curso = p_id_curso;
  insert into tb_curso_aula_geminada
    (id_curso, id_materia_a, id_materia_b,
     quantidade_periodos, quantidade_periodos_b, quantidade_blocos)
  select
    p_id_curso,
    (p->>'id_materia_a')::bigint,
    (p->>'id_materia_b')::bigint,
    (p->>'quantidade_periodos')::int,
    (p->>'quantidade_periodos_b')::int,
    (p->>'quantidade_blocos')::int
  from jsonb_array_elements(p_pares) as p;

  delete from tb_aula
  where id_curso = p_id_curso
    and id_materia not in (
      select (c->>'id_materia')::bigint from jsonb_array_elements(p_cargas) as c
    );
end;
$$;

-- 4) Tempo real: as telas atualizam sozinhas quando outra pessoa (ou outra
--    aba) muda os dados. RODAR SÓ DEPOIS de publicar a versão nova do app,
--    que espera um instante e busca uma vez só quando chegam várias
--    mudanças juntas (a versão antiga buscaria tudo uma vez por linha).
--
-- alter publication supabase_realtime add table
--   public.tb_aula, public.tb_curso, public.tb_curso_materia,
--   public.tb_curso_aula_geminada, public.tb_materia, public.tb_professor,
--   public.tb_professor_materia, public.tb_professor_indisponibilidade,
--   public.tb_sala, public.tb_tipo_sala, public.tb_horario_periodo;
