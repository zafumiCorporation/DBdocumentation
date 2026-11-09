-- TTL (Cuanto vive un permiso antes de morir) 90 dias con make_interval
-- fn_conceder_consentimiento -> boton "Aceptar" de tu app. Cuando el usuario da clic en "Si, permito overlay neon"
create or replace function public.fn_conceder_consentimiento(
    p_yo bigint, -- Id del usuario que esta concediendo el permiso.
    p_alcance public.uia_alcance, -- Tipo de permiso. overlay_neon , cursor_fantasma.
    p_dias int default 90, -- Cuantos dias dura el permiso.
    p_politica int default 1
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_caduca timestamptz; -- Guarda la fecha calculada de vencimiento.
begin
    if p_dias is null or p_dias <= 0 then
        raise exception 'dias de vigencia invalidos';
    end if;

    v_caduca := now() + make_interval(days => p_dias);

    -- Se inserta el permiso mapeado
    insert into public.consentimiento_uia(
        usuario_id, alcance, concedido, politica_version, captura_pantalla, concedido_en,
        caduca_en, revocado_en, updated_at
    )values (
        p_yo, p_alcance, true, p_politica,
        false, now(), v_caduca, null, now()
    )
    -- Si ya existe una fila con PK(usuario_id, alcance). Actualiza todo para re-activar permiso
    on conflict (usuario_id, alcance) do update set
        concedido = true,
        politica_version = excluded.politica_version,
        captura_pantalla = false,
        concedido_en = now(),
        caduca_en = excluded.caduca_en,
        revocado_en = null,
        updated_at = now();

    -- Notificacion en vivo , canal_overlay_1
    perform pg_notify(
        'canal_overlay_' || p_yo::text,
        jsonb_build_object('tipo', 'consentimiento_ok', 'alcance', p_alcance)::text
    );

    return v_caduca; -- Devuelve cuando caduca el permiso.
end;
$$;

-- PRUEBA 1 Conceder los cuatro consentimientos disponibles
-- Objetivo: verificar que fn_conceder_consentimiento(),
-- Registre correctamente los permisos aceptados por el usuario.
-- Estado inicial: No existe consentimientos para el usuario.
-- Accion: Aceptar: 1. overlay_neon , 2. cursor_fantasma , 3. instalar_wizard , 4. ejecucion_tutorial
-- Resultado esperado: Se crean 4 filas. concedido = true , politica_version = 1.
-- captura_pantalla = false. concedido_en contiene fecha.

select '--- PRUEBA 1: conceder los cuatro alcances ---' as test;

-- 1 = Shiriaru, tabla public.usuarios, columna id.
select alcance, concedido
from public.consentimiento_uia
where usuario_id = 1;
-- Esperado ahora: cero filas.

-- 1 = Shiriaru. 90 = dias. 2 = politica_version.
-- overlay_neon = el rectangulo. cursor_fantasma = el ghost.
-- instalador_wizard = el wizard del 23. ejecucion_tutorial = el Play del blueprint.
select public.fn_conceder_consentimiento(1,'overlay_neon',90, 1);
select public.fn_conceder_consentimiento(1,'cursor_fantasma', 90, 1);
select public.fn_conceder_consentimiento(1,'instalador_wizard', 90, 1);
select public.fn_conceder_consentimiento(1, 'ejecucion_tutorial', 90, 1);
-- Esperado en cada una: una fecha cerca de ahora + 90 dias. Es caduca_en.

select alcance, concedido, politica_version, captura_pantalla,
       concedido_en is not null as tiene_concesion,
       caduca_en > now() + interval '89 days' as vive_90_dias,
       revocado_en
from public.consentimiento_uia
where usuario_id = 1
order by alcance;
-- Esperado: cuatro filas. concedido true. politica_version 1.
-- captura_pantalla false en las cuatro. tiene_concesion true. vive_90_dias true. revocado_en null.

-- PRUEBA 2. Renovar un consentimiento existente.
-- Objetivo : Verificar que la aceptacion de un permiso previamente concedido actualice la fila
-- existente en lugar de crear una nueva.
-- Estado inicial: Existe un consentimiento overlay_neon. politica_version = 2.
-- Accion: Ejecutar fn_conceder_consentimiento() nuevamente para overlay_neon usando
-- politica_version = 2.
-- Resultado esperado: No se crea una  segunda fila. politica_version cambia a 2.
-- concedido continua en true. revocado_en permanece null , Se renueva la fecha de expiracion.

select '--- PRUEBA 2: renovar overlay_neon ---' as test;

select count(*) as filas
from public.consentimiento_uia
where usuario_id = 1
    and alcance = 'overlay_neon';
-- Esperado ahora: 1.

-- 1 = Shiriaru. overlay_neon ya existe. 90 dias otra vez. politica 2.
select public.fn_conceder_consentimiento(1,'overlay_neon', 90,2);

select alcance, concedido, politica_version, captura_pantalla, revocado_en
from public.consentimiento_uia
where usuario_id = 1
    and alcance = 'overlay_neon';
-- Esperado: sigue una fila. politica_version 2. concedido true.
-- captura_pantalla false. revocado_en null.

-- PRUEBA 3 Rechazar vigencias invalidas.
-- Objetivo: Verificar que fn_conceder_consentimiento() no permita crear o actualizar permisos con
-- una duracion menor o igual a cero dias.
-- Estado inicial: Existe un consentimiento cursor_fantasma, politica_version = 1.
-- Accion: Intentar conceder nuevamente el permiso. usando p_dias = 0.
-- Resultado esperado: Se genera la excepcion: 'dias de vigencia invalidos'
-- No se modifica la fila existente, politica_version permanece en 1 , concedido continua en true.

select '--- PRUEBA 3: dias invalidos ---' as test;

-- 1 = Shiriaru. cursor_fantasma ya esta concedido. 0 dias no debe pisarlo.
do $$
begin
    perform public.fn_conceder_consentimiento(1, 'cursor_fantasma',0, 1);
    raise exception 'FALLO: acepto 0 dias';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK dias: %', sqlerrm;
end;
$$;
-- Esperado en Messages: Ok dias: dias de vigencia invalidos.

select concedido, politica_version
from public.consentimiento_uia
where usuario_id = 1
    and alcance = 'cursor_fantasma';
-- Esperado: concedido true. politica_version sigue en 1.