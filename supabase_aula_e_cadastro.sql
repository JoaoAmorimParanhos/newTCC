-- SEM USO: a Página 3 voltou a não mexer na carga nem nos pares, e o app
-- não chama mais esta função. Não precisa rodar. Para apagá-la do banco:
--   drop function if exists public.salvar_aula_e_cadastro(bigint, jsonb, jsonb, jsonb, jsonb, jsonb);
-- (confira a assinatura em Database > Functions antes de rodar).
--
-- Rode no SQL Editor do Supabase depois de supabase_turnos_transacoes.sql.
-- Criar, editar ou excluir uma aula na Página 3 também muda a carga e os
-- pares de aula geminada do curso (Página 1). Esta função faz tudo numa
-- transação: se algo falhar, nada muda.

create or replace function public.salvar_aula_e_cadastro(
  p_id_curso bigint,
  p_inserir jsonb,
  p_atualizar jsonb,
  p_excluir jsonb,
  p_cargas jsonb,
  p_pares jsonb
)
returns bigint
language plpgsql
set search_path = public
as $$
declare
  v_id bigint;
begin
  delete from tb_aula
  where id_curso = p_id_curso
    and id in (
      select x::bigint
      from jsonb_array_elements_text(coalesce(p_excluir, '[]'::jsonb)) as x
    );

  update tb_aula as a
  set id_materia = (u->>'id_materia')::bigint,
      id_professor = (u->>'id_professor')::bigint,
      id_sala = nullif(u->>'id_sala', '')::bigint,
      grupo = coalesce((u->>'grupo')::int, a.grupo)
  from jsonb_array_elements(coalesce(p_atualizar, '[]'::jsonb)) as u
  where a.id = (u->>'id')::bigint
    and a.id_curso = p_id_curso;

  if p_inserir is not null and jsonb_typeof(p_inserir) = 'object' then
    insert into tb_aula
      (id_curso, dia_semana, periodo, id_materia, id_professor, id_sala, grupo)
    values (
      p_id_curso,
      (p_inserir->>'dia_semana')::int,
      (p_inserir->>'periodo')::int,
      (p_inserir->>'id_materia')::bigint,
      (p_inserir->>'id_professor')::bigint,
      nullif(p_inserir->>'id_sala', '')::bigint,
      coalesce((p_inserir->>'grupo')::int, 1)
    )
    returning id into v_id;
  end if;

  -- Carga e pares do curso (e aulas de matérias que saíram da carga).
  perform public.salvar_carga_e_pares(
    p_id_curso,
    coalesce(p_cargas, '[]'::jsonb),
    coalesce(p_pares, '[]'::jsonb)
  );

  -- Grupo 2 sozinho de matéria que não está mais em nenhum par vira aula
  -- completa (grupo 1).
  update tb_aula as a
  set grupo = 1
  where a.id_curso = p_id_curso
    and a.grupo = 2
    and not exists (
      select 1 from tb_aula b
      where b.id_curso = a.id_curso
        and b.dia_semana = a.dia_semana
        and b.periodo = a.periodo
        and b.id <> a.id
    )
    and not exists (
      select 1 from tb_curso_aula_geminada p
      where p.id_curso = a.id_curso
        and (p.id_materia_a = a.id_materia or p.id_materia_b = a.id_materia)
    );

  return v_id;
end;
$$;
