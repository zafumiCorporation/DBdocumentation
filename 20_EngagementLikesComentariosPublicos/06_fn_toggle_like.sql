-- 06/07 Pattern Youtube: DELETE primero + INSERT ON CONFLICT = toggle atomico
create or replace function public.fn_toggle_like (p_yo bigint, p_tutorial_id bigint)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Intenta borrar primero. Si borro = tenia like, ahora no tiene = false
    delete from public.tutorial_likes
    where usuario_id = p_yo
    and tutorial_id = p_tutorial_id;

    -- found variable booleana interna que PostgreSQL actualiza automaticamente despues de:
    -- select into , insert , update , delete , perfom
    -- Found = true si la operacion afecto al menos 1 fia
    -- Found = false si no afecto ninguna fila.
    if found then
        return false; -- unlike
    end if;

    -- No existia, intenta insertar. ON CONFLICT DO NOTHING por si 2 taps entra a la vez
    insert  into public.tutorial_likes (usuario_id, tutorial_id)
    values (p_yo, p_tutorial_id)
    on conflict (usuario_id, tutorial_id) do nothing;

    return true; -- like
end;
$$;

-- PRUEBA 1. like. Patron Youtube: el tap da el like.
select '--- PRUEBA 1: dar like ---' as test;

-- Antes. Tabla public.tutoriales, id = 2
-- 2 = "Design Resume in Word", creador Shiriaru (usuarios.id 1).
select id, titulo, likes_count
from public.tutoriales
where id = 2;
-- Esperado ahora: likes_count = 95

-- Antes. Tabla public.tutorial_likes
-- 1 = Shiriaru, tabla public.usuarios.
-- 2 = "Design Resume in Word", tabla public.tutoriales.
select usuario_id, tutorial_id, created_at
from public.tutorial_likes
where usuario_id = 1
  and tutorial_id = 2;
-- Esperado ahora: cero filas.

-- fn_toggle_like(p_yo, p_tutorial_id)
-- 1 = Shiriaru, tabla public.usuarios, columna id.
-- 2 = "Desing Resume in Word", tabla public.tutoriales, columna id.
select public.fn_toggle_like(1,2);
-- Esperado: true. No habia fila, la funcion inserta el like.

-- Despues el contador sumo 1. Ese movimiento lo hace el trigger del archivo 07_trigger_likes_count.sql
-- Esperado: Likes_count = 96 . Linea 36
-- Despues la fila del like ya existe. Linea 44
-- Esperado: una fila. usuario_id 1 = Shiriaru. tutorial_id 2 = "Design resume in Word".

-- PRUEBA 2. Unlike. El segundo tap quitaa el like. La fila se borra
select '--- PRUEBA 2: quita like ---' as test;

-- Antes. El like de la prueba 1 sigue puesto. linea 36
-- Esperado ahora: likes_count = 96.

-- Linea 44
-- Esperado ahora : una fila

-- Mismos argumentos. 1 = Shiriaru, usuarios.id. 2 = "Design Resume in Word", tutoriales.id
select public.fn_toggle_like(1,2);
-- Esperado: false. La fila existia, La funcion la borra.

-- Despues. El contado vuelve a 95. Linea 36
-- Esperado: likes_count = 95.

-- Despues. Ya no hay fila. Linea 44
-- EsperadoL cero filas.