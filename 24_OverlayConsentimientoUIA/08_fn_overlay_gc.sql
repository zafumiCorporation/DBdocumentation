-- fn_overlay_gc() -> Eliminar sesiones temporales abandonadas del overlay.
-- Cuando llevan mas de 5 minutos sin enviar heartbeat.
-- Funcionamiento: Consulta las sesiones almacenadas en overlay_sesion_ram
-- Compara last_seen_at con la hora actual.
-- Elimina las sesion que superan los 5 minutos de inactividad.
-- Cuenta cuantas filas fueron eliminadas.
-- Devuelve el total de sesiones eliminadas.
-- Retorno: int = cantidad de sesiones eliminadas.
create or replace function public.fn_overlay_gc()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_n int; -- Almacena cuantas filas se borraron.
begin
    delete from public.overlay_sesion_ram
    where last_seen_at < now() - make_interval(mins => 5) -- Borrar sesiones cuyo hearbeat fue hace mas de 5 minutos.
    returning 1 into v_n;
    -- get diagnostics cuantas filas tocaste en el ultimo comando , row_count numero de filas borradas.
    get diagnostics v_n = row_count;
    return coalesce(v_n, 0);
end;
$$;

-- PRUEBA 1 eliminar una sesion que lleva mas de 5 minutos sin hearbeat.
-- Objetivo: verificar que fn_overlay_gc() , elimine las sesiones temporales que superan
-- el limite de 5 minutos de inactivida.
-- Estado inicial : La tabla overlay_sesion_ram esta vacia.
-- Angela existe en public.usarios. Su id es 4. El tutorial 1 corresponde a "Create Sheet in Word"
-- No existe una sesion previa para Angela.
select '--- PRUEBA 1: gc de 5 minutos ---' as test;

select usuario_id
from public.overlay_sesion_ram;
-- Esperado ahora: cero filas.

-- 4 = Angela, usuarios.id. No va a usar el overlay en las pruebas siguientes.
-- tutorial_id 1 = "Create shee in Word". aplicacion_id queda null: un solo objetivo.
-- Last_seen_at de hace 6 minutos.
insert into public.overlay_sesion_ram(usuario_id, tutorial_id, last_seen_at)
values (4, 1, now() - interval '6 minutes');

select usuario_id, tutorial_id, last_seen_at < now() - interval '5 minutes' as vieja
from  public.overlay_sesion_ram
where usuario_id = 4;
-- Esperado ahora: una fila. tutorial_id 1. vieja true.

-- fn_overlay_gc() no recibe argumentos.
select public.fn_overlay_gc() as borradas;
-- Esperado: 1.

select usuario_id
from public.overlay_sesion_ram
where usuario_id = 4;
-- Esperado: cero filas.
