--Guardar Tutorial
create or replace function public.fn_guardar_tutorial(p_yo bigint, p_tutorial_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.tutorial_guardados (usuario_id, tutorial_id)
    values (p_yo, p_tutorial_id)
    on conflict (usuario_id, tutorial_id) do update
        set eliminado_at = null,
            guardado_at = now()
        -- Si cuenta con una fecha de eliminado Indica que el video ya fue borrado.
        where public.tutorial_guardados.eliminado_at is not null;
end;
$$;

-- Quitar Guardado
create or replace function public.fn_quitar_guardado(p_yo bigint, p_tutorial_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- No borra , solo oculta.
    update public.tutorial_guardados
    set eliminado_at = now()
    where usuario_id = p_yo
        and tutorial_id = p_tutorial_id
        and eliminado_at is null;
end;
$$;

drop function public.fn_guardados_after_change();
select * from usuarios;
create or replace function public.fn_guardados_after_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' then
        update public.usuarios
        set guardados_count = usuarios.guardados_count + 1
        -- El id del usuario que acaba de guardar un tutorial.
        where id = new.usuario_id;
        return null;

    elsif tg_op = 'UPDATE' then
        -- Si mi campo elimado_at en mi tabla tutorial_guardado  pasa a ser marcado como eliminado
        if old.eliminado_at is null and new.eliminado_at is not null then
            update public.usuarios
            set guardados_count = greatest(guardados_count - 1, 0)
            where id = new.usuario_id;
        -- Si no era null y pasa a ser null
        elsif old.eliminado_at is not null and new.eliminado_at is null then
            update public.usuarios
            set guardados_count = guardados_count + 1
            where id = new.usuario_id;
        end if;
        return null;
    end if;
    return null;
end;
$$;

drop trigger if exists trg_guardados_count on public.tutorial_guardados;
create trigger trg_guardados_count
after insert or update of eliminado_at on public.tutorial_guardados
for each row execute function public.fn_guardados_after_change();

--Prueba 1 Guaradar un tutorial que aun no esta en la lista
select '--- PRUEBA 1: guardar tutorial nuevo ---' as test;

-- Consulta : tabla usuarios , columna id = 1 "Shiriraru" , guardados_count antes de guardar
select id, username , guardados_count
from public.usuarios
where id = 1;
-- Esperado ahora: una fila, username Shiriaru, guardados_count = 0

-- Consulta : Tabla tutorial_guardados, filas del usuario 1 (Shiriaru)
select usuario_id, tutorial_id , estado , eliminado_at, guardado_at
from public.tutorial_guardados
where usuario_id = 1
order by tutorial_id;
-- Dos filas activas
-- tutorial_id 2 = "Design Resume in Word", estado activo, eliminado_at null
-- tutorial_id 4 = "Create Video Game in Unreal Engine", estado activo, eliminado_at null.

-- fn_guardar_tutorial(p_yo, p_tutorial_id)
-- 1 = Shiriraru, tabla public.usuarios, columna id.
-- 3 = "Guardar Hoja en Blanco", tabla public.tutoriales, columna id. Creador: Shiriaru (usuarios.id 1)
select public.fn_guardar_tutorial(1,3);

-- Despues Misma fila de Shiriaru linea 79
-- Esperado:  guardados_count = 1.

-- Despues Lista de guardados de Shiriaru linea 85
-- Esperado: tres filas, El 2 y el 4 siguen activos
-- Aparece el 3 con estado activo y eliminado_at null.

-- Prueba 2. Quitar un guardado Youtube no borra la fila: la oculta.
select '--- PRUEBA 2: QUITAR GUARDADO ---' as test;

-- Antes- Shiriaru , tabla usuarios linea 79
-- Esperado ahora: guardados_count = 1

-- Antes. Guardados de Shiriaru linea 85
-- Esperado ahora: tutoriales 2,3,4 activos, eliminado_at null

-- fn_quitar_guardado(p_yo, p_tutorial_id)
-- 1 = Shiriraru, tabla public.usuarios, columna id
-- 2 = "Desing Resume in Word", tabla public.tutoriales, columna id. CreadorL Shiriaru
select public.fn_quitar_guardado(1,2);

-- Despues. El contador resta 1. linea 75
-- Esperado: guardados_count = 0

-- Despues. La fila del tutorial 2 sigue existiendo, ahora oculta line 85
-- Esperado: el tutorial 2 paso a estado eliminado y eliminado_at tiene fecha.
-- El 3 y el 4 siguen activos.

-- Prueba 3. Volver a guardar el que acabas de quitar
-- Patron Youtube: si ya estaba oculto, se reactiva y guardado_at se renueva
select '--- PRUEBA 3: reactivar guardado ---' as test;

-- Antes. Shiriaru linea 79
-- Esperado ahora: guardados_count = 0
-- Antes. El tutorial 2 debe verse eliminado linea 85
-- Esperado ahora: tutorial 2 eliminado. Tutoriales 3 y 4 activos

-- Mismo argumentos que la prueba 2.
-- 1 = Shiriaru, tabla usuarios
-- 2 = "Design Resume in Word", tabla public.tutoriales.
select public.fn_guardar_tutorial(1,2);

-- Despues. El contador vuelve a sumar. linea 75
-- Esperado: guardados_count = 1

-- Despues el tutorial 2 queda activo otra vez y su guardado_at es mas reciente. 85
-- Esperado: tutoriales 2, 3 y 4 activos, eliminado_at null en los tres.


