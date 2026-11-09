-- fn_overlay_heartbeat() , objetivo: Renovar la actividad de una sesion del overlay.
-- mientras el agente de escritorio continua enviando hearbeat.
-- funcionamiento: Busca la sesion correspondiente al usuario. Comprueba que su ultimo heartbeat
-- no supere los 15 minutos. Actualiza last_seen_at con la hora actual. Devuelve la nueva fecha
-- de actividad. Si la sesion no existe o esta caducada, rechaza el heartbeat mediante una excepcion.
-- Cada 10 segundos tu agente hace : UPDATE last_seen_at = now()  hace que mi fn_overlay_gc no borra lo de hace>5min por que siempre lo ve fresco.
create or replace function public.fn_overlay_heartbeat(p_yo bigint)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_seen timestamptz; -- Guarda la ultima vez visto que acabas de actualizar.
begin
    update public.overlay_sesion_ram
    set last_seen_at = now()
    where usuario_id = p_yo
      and last_seen_at > now() - interval '15 minutes' -- Solo si su latido fue hace menos de 15 minutos.
    returning last_seen_at into v_seen;

    if v_seen is null then
        delete from public.overlay_sesion_ram where usuario_id = p_yo;
        raise exception 'sesion overlay caduca; llama fn_overlay_iniciar';
    end if;

    return v_seen;
end;
$$;

-- PRUEBA 1 Renovar una sesion que todavia se encuentra activa.
-- Objetivo: Verificar que fn_overlay_heartbeat() actualice correctamente last_seen_at cuando
-- El usuario tiene una sesion vigente.
-- Estado inicial: Shiriaru existe en public.usuarios. Su id es 1.
-- Tiene una sesion registrada en overlay_sesion_ram. La sesion corresponde al instalador de VMware Player.
-- last_seen_at tiene menos de 15 minutos de antiguedad.
-- Accion: Consultar la ultima actividad registrada. Ejecutar fn_overlay_heartbeat(1) para renovar.
-- la actividad de la sesion. Consultar nuevamente la fila.
-- Resultado esperado: La funcion devuelve una fecha de ahora. La sesion continua existiendo.
-- aplicacion_id conserva el identificador de VMware Player. last_seen_at se actualiza con la nueva fecha.

select '--- PRUEBA 1: hearbeat vivo ---' as test;

select last_seen_at
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado ahora: una fila. 1 = Shiriaru. Anota last_seen_at.

-- 1 = Shiriaru, usuarios.id.
select public.fn_overlay_heartbeat(1);
-- Esperado: una fecha de ahora.

select usuario_id, aplicacion_id, last_seen_at
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado: La fila sigue. last_seen_at es la fecha que devolvio la funcion.

-- PRUEBA 2 Rechazar el heartbeat de una sesion  con mas de 15 minutos de inactividad.
-- Objetivo: Verificar que fn_overlay_heartbeat() impida renovar una sesion cuyo ultimo heartbeat
-- supera el limite de 15 minutos.
-- Estado inicial: Shiriaru existe en public.usuarios. Su id es 1.
-- La sesion anterior fue cerrada o eliminada por el procedimiento de 11_fn_overlay_cerrar.
-- Shiriaru puede volver a iniciar el tutorial.
-- Accion: Crear nuevamente una sesion para Shiriaru en el tutorial 1, paso 3.
-- Modificar artificialmente last_seen_at para simular que el ultimo heartbeat ocurrio hace 16 minutos.
-- Intentar renovar la sesion mediante fn_overlay_heartbeat(1).
-- Resultado esperado: La comprobacion de antiguedad devuelve true. El update no modifica ninguna fila.
-- v_seen permanece en null. Se lanza la excepcion: 'sesion overlay caduca; llama fn_overlay_iniciar'.
-- La sesion no se renueva.

select '--- PRUEBA 2: heartbeat caducado ---' as test;

-- vuelve a abrir el tutorial para tener una fila que envejecer.
-- 1 = Shiriaru. 1 = "Create Sheet in Word". 3 = paso insertar.
select public.fn_overlay_iniciar(1,1,null, null, 3);

update public.overlay_sesion_ram
set last_seen_at = now() - interval '16 minutes'
where usuario_id = 1;
-- Esperado ahora: caduca true.

do $$
begin
    perform public.fn_overlay_heartbeat(1);
    raise exception 'FALLO: lateo una sesion de 16 minutos';
exception
    when others then
        if sqlerrm like 'FALLLO:%' then
            raise;
        end if;
        raise notice 'OK caduca: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK caduca: sesion overlay caduca; Llama fn_overlay_iniciar.

select usuario_id
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado cero filas.



