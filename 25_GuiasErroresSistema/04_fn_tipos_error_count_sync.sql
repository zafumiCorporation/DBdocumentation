-- Se registro un nuevo evento de error > veces_visto aumenta.
-- Se elimino un evento de error > veces_visto disminuye.
create or replace function public.fn_tipos_error_count_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Incrementa cuando insert into eventos_sistema.
    -- new.tipo_error_id Valor de la nueva fila insertada en eventos_sistema.
    if tg_op = 'INSERT' and new.tipo_error_id is not null then
        update public.tipos_error
        set veces_visto = veces_visto + 1,
            updated_at = now()
        where id = new.tipo_error_id;
        return new; -- Devuelve la fila nueva.
    -- Decrementa cuando delete from eventos_sistema
    -- old.tipo_error_id valor de la fila que existia antes de ser eliminada.
    elsif tg_op = 'DELETE' and old.tipo_error_id is not null then
        update public.tipos_error
        set veces_visto = greatest(veces_visto - 1, 0),
            updated_at = now()
        where id = old.tipo_error_id;
        return old; -- Devuelve la fila eliminada.
    end if;

    return coalesce(new, old);
end;
$$;

-- PRUEBA 1. borrar el evento de la pantalla azul baja su contador.
select '--- PRUEBA 1: borrar un evento ---' as test;

select veces_visto
from public.tipos_error
where titulo_patron = 'Pantalla azul de la muerte';
-- Esperado ahora: 1.

select veces_visto
from public.tipos_error
where slug = 'hyperv-hypervisor-bloqueado';
-- Esperado ahora: 1.

delete from public.eventos_sistema where titulo = 'Pantalla azul de la muerte';

-- Linea 35
-- Esperado ahora : 0.






