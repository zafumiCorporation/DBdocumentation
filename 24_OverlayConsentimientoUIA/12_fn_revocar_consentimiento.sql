-- Stop, inturrumpe el tutorial en vivo , Es: "esta pintando el neon ahora mismo en word y el usuario dijo No"
-- Tu agente de overlay tiene un loop que cada X segundos hace hearbeat = "sigo vivo?" "sigo pintando?"
-- fn_revocar_consentimiento -> Boton "Quitar permiso" / "Revocar acceso".
create or replace function public.fn_revocar_consentimiento(
    p_yo bigint, -- Id del usuario que esta quitando su propio permiso.
    p_alcance public.uia_alcance -- Que permiso quita.
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.consentimiento_uia
    set concedido = false, -- Ahora es no
        revocado_en = now(), -- Guardas cuando dijo No, para auditoria.
        updated_at = now() -- Tocaste la fila
    where usuario_id = p_yo and alcance = p_alcance;

    if not found then -- True si el update anterior toco al menos una fila.
        raise exception 'no hay grant % para usuario %', p_alcance, p_yo;
    end if;

    -- Borra todas las sesiones de ese usuario.
    delete from public.overlay_sesion_ram
    where usuario_id = p_yo;

    perform pg_notify(
        'canal_overlay_' || p_yo::text,
        jsonb_build_object('tipo', 'overlay_kill', 'alcance', p_alcance)::text
    );
end;
$$;

-- PRUEBA 1: Revocar el consentimiento overlay_neon
-- Objetivo: Comprobar que retirar overlay_neon elimina la sesion activa, envia la notificacion
-- de interrupcion y no modifica los otros consentimientos.
-- Estado inicial: Uusarios: 1 (Shiriaru). Tutorial: 1 (Create Sheet in Word).
-- Paso: 3 (paso insertar). Deben existir los consentimientos necesarios para iniciar el overlay.
-- overlay_neon debe estar concedido y no revocado.
-- Resultados esperados: 1. Antes de revocar existe una sesion activa.
-- 2. overlay_neon cambia a concedido = false.
-- 3. revocado_en contiene una fecha. 4. Los otros tres consentimiento continuan vigentes.
-- 5. La sesion temporal desaparece. 6. Un nuevo inicio del overlay es rechazado.

select '--- PRUEBA 1: revocar el neon ---' as test;

-- 1 = Shiriaru. 1 = "Create Sheet in Word". 3 = paso insertar.
select public.fn_overlay_iniciar(1,1,null, null, 3);

select usuario_id
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado ahora: una fila.

select concedido, revocado_en
from public.consentimiento_uia
where usuario_id = 1
    and alcance = 'overlay_neon';
-- Esperado ahora: concedido true, revocado_en null.

-- 1 = Shiriaru, usuario.id. overlay_neon - solo ese radio.
select public.fn_revocar_consentimiento(1, 'overlay_neon');

select concedido, revocado_en is not null as tiene_revocacion, captura_pantalla
from public.consentimiento_uia
where usuario_id = 1
    and alcance = 'overlay_neon';
-- Esperado: concedido false. tiene_revocacion true. captura_pantalla false.

select public.fn_consentimiento_vigente(1, 'overlay_neon') as neon,
       public.fn_consentimiento_vigente(1, 'ejecucion_tutorial') as play,
       public.fn_consentimiento_vigente(1, 'cursor_fantasma') as ghost,
       public.fn_consentimiento_vigente(1, 'instalador_wizard') as wizard;
-- Esperado: neon false. play true. ghost true. wizard true.

select usuario_id
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado: cero filas.

-- Sin overlay_neon, el tutorial no vuelve a pintar.
do $$
begin
    perform public.fn_overlay_iniciar(1,1,null,null,3);
    raise exception 'FALLO: pinto despues de revocar';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK revocado: %', sqlerrm;
end;
$$;

-- PRUEBA 2 : Revocar un consentimiento inexistente
-- Objetivo: Comprobar que fn_revocar_consentimiento rechaza una operacion cuando el usuario nunca
-- tuvo registrado el consentimiento solicitado.
-- Estado inicial: Usuario: 2 (Julio). Alcance: overlay_neon.
-- no existe una fila de consentimiento para esa combinacion.
-- Resultado esperado: La funcion genera una excepcion: no hay grant overlay_neon para usuario 2.

select '--- PRUEBA 2: revocar un grant que no existe ---' as test;

-- 2 = Julio, usuarios.id overlay_neon no tiene fila para el.
do $$
begin
    perform public.fn_revocar_consentimiento(2, 'overlay_neon');
    raise exception 'FALLO: revoco un gran inexistente';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK sin grant: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK sin grant: no hay gran overlay_neon para usuario 2.
