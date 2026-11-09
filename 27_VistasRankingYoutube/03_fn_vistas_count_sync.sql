-- fn_vistas_count_sync : Mantiene sincronizado el contador. tutoriales.vistas_count
-- Su trabajo es: Se registra una vista -> Cuenta como vista unica ? -> Si si -> Aumenta vistas_count.
-- Se elimina una vista -> Era una vista uncia ? -> Si si -> Disminuye vistas_count.
create or replace function public.fn_vistas_count_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Se inserto una nueva fila.
    if tg_op = 'INSERT' and new.cuenta_unica is true then
        update public.tutoriales -- Actualizar el tutorial visto.
        set vistas_count = tutoriales.vistas_count + 1,
            updated_at = now()
        where id = new.tutorial_id;
        return new; -- Devuelve la fila recien insertada.
    -- Se elimino una fila.
    elsif tg_op = 'DELETE' and old.cuenta_unica is true then
        update public.tutoriales
        set vistas_count = greatest(vistas_count - 1, 0),
            updated_at = now()
        where id = old.tutorial_id;
        return old; -- Devuelve la fila eliminada.
    end if;

    return coalesce(new, old);
end;
$$;

drop trigger if exists trg_vistas_count on public.tutorial_vistas;
create trigger trg_vistas_count
after insert or delete on public.tutorial_vistas
for each row execute function public.fn_vistas_count_sync();

-- PRUEBA 1. Borrar una vista que no era unica no mueve el contador. Borrar una unica si.
-- Estado inicial: El tutorial Word tiene id = 1. vistas_count = 2.
-- Shiriaru tiene una vista unica y otra no unica. Sebastian tiene una vista unica.
-- Accion: Eliminar primero la vista no unica de Shiriaru y despues la vista unica de Sebastian.
-- Resultado esperado: Eliminar la vista de overlay no modifica vistas_count.
-- El contador permanece en 2. Eliminar la vista unica de Sebastian disminuye el contador.
-- vistas_count cambia a 1. Permanece la vista unica de Shiriaru.
select '--- PRUEBA 1: borrar vistas ---' as test;

select vistas_count
from public.tutoriales
where id = 1;
-- Esperado ahora: 2.

delete from public.tutorial_vistas
where usuario_id = 1
    and tutorial_id = 1
    and cuenta_unica = true;

-- Linea 45
-- Esperado ahora: 2.

delete from public.tutorial_vistas
where usuario_id = 3
    and tutorial_id = 1
    and cuenta_unica = true;

-- Linea 45
-- Esperado: 1. Queda la unica de Shiriaru

-- Sebastian vuelve a entrar: el ranking de 7 dias la necesita.
select public.fn_registrar_vista(3, 1, 'busqueda', 2::smallint);

-- Linea 45
-- Esperado ahora: 2.

