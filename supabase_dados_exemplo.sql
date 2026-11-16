-- =====================================================================
-- Projeto Timetable — dados de exemplo
-- =====================================================================
-- Rode DEPOIS de supabase_estrutura_completa.sql, num banco vazio.
-- São os dados entregues com o sistema: 7 cursos (Informática 1 a 4 e
-- Mecânica 1 a 3), 66 componentes, 19 professores, 11 salas e os
-- horários de cada período. As grades começam vazias: use "Gerar" na
-- tela 3. Horário para montar o horário de todas as turmas.
-- =====================================================================

begin;

insert into public.tb_tipo_sala (id, nome) overriding system value values (1, 'Sala de aula'), (2, 'Laboratório de informática'), (3, 'Quadra'), (4, 'Laboratório de mecânica') on conflict (id) do nothing;

insert into public.tb_sala (id, numero, id_tipo_sala) values (22, 1, 1), (23, 2, 1), (24, 3, 1), (25, 4, 1), (26, 5, 1), (27, 6, 1), (28, 7, 1), (29, 1, 2), (30, 2, 2), (31, 1, 4), (32, 1, 3);

insert into public.tb_materia (id, nome) values (33, 'Arte 1'), (34, 'Arte 2'), (35, 'Arte 3'), (36, 'Banco de Dados 1'), (37, 'Banco de Dados 2'), (38, 'Biologia 1'), (39, 'Biologia 2'), (40, 'Biologia 3'), (41, 'Biologia 4'), (42, 'Desenho Assistido por Computador'), (43, 'Desenho Técnico'), (44, 'Desenvolvimento Web 1'), (45, 'Desenvolvimento Web 2'), (46, 'Educação Física 1'), (47, 'Educação Física 2'), (48, 'Educação Física 3'), (49, 'Educação Física 4'), (50, 'Elementos de Máquinas'), (51, 'Engenharia de Software'), (52, 'Filosofia 1'), (53, 'Filosofia 2'), (54, 'Filosofia 3'), (55, 'Filosofia 4'), (56, 'Fundamentos de Computação'), (57, 'Física 1'), (58, 'Física 2'), (59, 'Física 3'), (60, 'Física 4'), (61, 'Geografia 1'), (62, 'Geografia 2'), (63, 'Geografia 3'), (64, 'Geografia 4'), (65, 'História 1'), (66, 'História 2'), (67, 'História 3'), (68, 'História 4'), (69, 'Inglês 1'), (70, 'Inglês 2'), (71, 'Inglês 3'), (72, 'Inglês 4'), (73, 'Língua Portuguesa 1'), (74, 'Língua Portuguesa 2'), (75, 'Língua Portuguesa 3'), (76, 'Língua Portuguesa 4'), (77, 'Lógica de Programação'), (78, 'Manutenção Industrial'), (79, 'Matemática 1'), (80, 'Matemática 2'), (81, 'Matemática 3'), (82, 'Matemática 4'), (83, 'Metrologia'), (84, 'Processos de Usinagem'), (85, 'Programação Orientada a Objetos'), (86, 'Programação para Dispositivos Móveis'), (87, 'Projeto Integrador'), (88, 'Química 1'), (89, 'Química 2'), (90, 'Química 3'), (91, 'Química 4'), (92, 'Redes de Computadores'), (93, 'Resistência dos Materiais'), (94, 'Sistemas Operacionais'), (95, 'Sociologia 1'), (96, 'Sociologia 3'), (97, 'Soldagem'), (98, 'Tecnologia dos Materiais');

insert into public.tb_professor (id, nome) values (29, 'Professor 1'), (30, 'Professor 2'), (31, 'Professor 3'), (32, 'Professor 4'), (33, 'Professor 5'), (34, 'Professor 6'), (35, 'Professor 7'), (36, 'Professor 8'), (37, 'Professor 9'), (38, 'Professor 10'), (39, 'Professor 11'), (40, 'Professor 12'), (41, 'Professor 13'), (42, 'Professor 14'), (43, 'Professor 15'), (44, 'Professor 16'), (45, 'Professor 17'), (46, 'Professor 18'), (47, 'Professor 19');

insert into public.tb_professor_materia (id_professor, id_materia) values (29, 79), (29, 80), (29, 81), (29, 82), (30, 79), (30, 80), (30, 81), (31, 73), (31, 74), (31, 75), (31, 76), (32, 73), (32, 74), (32, 75), (33, 57), (33, 58), (33, 59), (33, 60), (34, 88), (34, 89), (34, 90), (34, 91), (35, 38), (35, 39), (35, 40), (35, 41), (36, 65), (36, 66), (36, 67), (36, 68), (37, 61), (37, 62), (37, 63), (37, 64), (38, 69), (38, 70), (38, 71), (38, 72), (39, 46), (39, 47), (39, 48), (39, 49), (40, 51), (40, 77), (40, 85), (40, 86), (41, 36), (41, 37), (41, 44), (41, 45), (42, 56), (42, 87), (42, 92), (42, 94), (43, 42), (43, 43), (43, 50), (44, 93), (44, 97), (44, 98), (45, 78), (45, 83), (45, 84), (46, 33), (46, 34), (46, 35), (47, 52), (47, 53), (47, 54), (47, 55), (47, 95), (47, 96);

insert into public.tb_curso (id, nome, id_sala, periodo_preferencia) values (27, 'Informática 1', 22, 'apenas_manha'), (28, 'Informática 2', 23, 'apenas_tarde'), (29, 'Informática 3', 24, 'apenas_manha'), (30, 'Informática 4', 25, 'apenas_tarde'), (31, 'Mecânica 1', 26, 'manha_tarde'), (32, 'Mecânica 2', 27, 'tarde_manha'), (33, 'Mecânica 3', 28, 'manha_tarde');

insert into public.tb_curso_materia (id_curso, id_materia, quantidade_aulas, tamanho_bloco) values (27, 33, 2, 2), (27, 38, 2, 2), (27, 44, 2, 2), (27, 46, 2, 2), (27, 52, 1, 1), (27, 56, 2, 2), (27, 57, 2, 2), (27, 61, 2, 1), (27, 65, 2, 1), (27, 69, 2, 2), (27, 73, 3, 1), (27, 77, 2, 2), (27, 79, 3, 1), (27, 88, 2, 2), (28, 36, 2, 2), (28, 39, 2, 2), (28, 47, 2, 2), (28, 53, 1, 1), (28, 58, 2, 2), (28, 62, 2, 1), (28, 66, 2, 1), (28, 70, 2, 2), (28, 74, 3, 1), (28, 80, 3, 1), (28, 85, 2, 2), (28, 89, 2, 2), (28, 92, 2, 2), (29, 35, 2, 2), (29, 40, 2, 2), (29, 45, 2, 2), (29, 48, 2, 2), (29, 51, 2, 2), (29, 54, 1, 1), (29, 59, 2, 2), (29, 63, 2, 1), (29, 67, 2, 1), (29, 71, 2, 2), (29, 75, 3, 1), (29, 81, 3, 1), (29, 90, 2, 2), (29, 94, 2, 2), (29, 96, 1, 1), (30, 37, 2, 2), (30, 41, 2, 2), (30, 49, 2, 2), (30, 55, 1, 1), (30, 60, 2, 2), (30, 64, 2, 1), (30, 68, 2, 1), (30, 72, 2, 2), (30, 76, 3, 1), (30, 82, 3, 1), (30, 86, 2, 2), (30, 87, 2, 2), (30, 91, 2, 2), (31, 33, 2, 2), (31, 38, 2, 2), (31, 43, 2, 2), (31, 46, 2, 2), (31, 52, 1, 1), (31, 57, 2, 2), (31, 61, 2, 1), (31, 65, 2, 1), (31, 69, 2, 2), (31, 73, 3, 1), (31, 79, 3, 1), (31, 83, 2, 2), (31, 88, 2, 2), (31, 95, 1, 1), (31, 98, 2, 2), (32, 34, 2, 2), (32, 39, 2, 2), (32, 42, 2, 2), (32, 47, 2, 2), (32, 58, 2, 2), (32, 62, 2, 1), (32, 66, 2, 1), (32, 70, 2, 2), (32, 74, 3, 1), (32, 80, 3, 1), (32, 84, 2, 2), (32, 89, 2, 2), (32, 93, 2, 2), (33, 35, 2, 2), (33, 40, 2, 2), (33, 48, 2, 2), (33, 50, 2, 2), (33, 54, 1, 1), (33, 59, 2, 2), (33, 63, 2, 1), (33, 67, 2, 1), (33, 71, 2, 2), (33, 75, 3, 1), (33, 78, 2, 2), (33, 81, 3, 1), (33, 90, 2, 2), (33, 96, 1, 1), (33, 97, 2, 2);

insert into public.tb_horario_periodo (periodo, texto) values (1, '07:15 - 08:05'), (2, '08:05 - 08:55'), (3, '08:55 - 09:45'), (4, '10:05 - 10:55'), (5, '10:55 - 11:50'), (6, '11:50 - 12:35'), (7, '13:15 - 14:05'), (8, '14:05 - 14:55'), (9, '14:55 - 15:45'), (10, '16:05 - 17:00'), (11, '17:00 - 17:50'), (12, '17:50 - 18:30');

-- Os próximos cadastros feitos pelo app continuam depois destes números.
select setval(pg_get_serial_sequence('public.tb_tipo_sala', 'id'), (select max(id) from public.tb_tipo_sala));
select setval(pg_get_serial_sequence('public.tb_sala', 'id'), (select max(id) from public.tb_sala));
select setval(pg_get_serial_sequence('public.tb_materia', 'id'), (select max(id) from public.tb_materia));
select setval(pg_get_serial_sequence('public.tb_professor', 'id'), (select max(id) from public.tb_professor));
select setval(pg_get_serial_sequence('public.tb_curso', 'id'), (select max(id) from public.tb_curso));

commit;
