-- Es el patron de seguridad antes de reproducir verifica permisos
-- fn_consentimiento_vigente -> Solo responde true / false : Este permiso esta vivo AHORA ?
create or replace function public.fn_consentimiento_vigente(
    p_yo bigint, -- Id del usuario del que queremos conocer los permisos vigentes.
    p_alcance public.uia_alcance -- Que permiso quieres chequear.
)
returns boolean
language sql
stable
parallel safe
set search_path = ''
as $$
    select exists(
        select 1
        from public.consentimiento_uia as c
        where c.usuario_id = p_yo -- Que sea el usuario que preguntamos
        and c.alcance = p_alcance -- Alcance exacto que preguntamos.
        and c.concedido -- Tiene que estar en True.
        and c.revocado_en is null -- No puede estar revocado.
        and c.captura_pantalla = false
        and (c.caduca_en is null or c.caduca_en > now())
    );
$$;

-- PRUEBA 1 validar consentimiento activo contra ausencia de consentimiento.
-- Objetivo: Verificar que fn_consentimiento_vigente() permita funcionalidades unicamente a los
-- usuarios que poseen un consentimiento activo.
-- Estado inicial: Shiriaru posee consentimiento vigente para overlay_neon.
-- Julio no posee ningun consentimiento para overlay_neon.
-- Accion: Consultar fn_consentimiento_vigente() para ambos usuarios.
-- Resultado esperado: Shiriaru devuelve TRUE. Julio devuelve False.

select '--- PRUEBA 1: gate del grant ---' as tes;

-- 1 = Shiriaru, usuarios.id. overlay_neon = el radio del rectangulo.
select public.fn_consentimiento_vigente(1, 'overlay_neon') as vigente;
-- Esperado true.

-- 2 = Julio, usuarios.id No tiene fila en consentimiento_uia.
select public.fn_consentimiento_vigente(2, 'overlay_neon') as vigente;
-- Esperado: false;

