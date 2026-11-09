-- fn_reportar_evento -> 1. Recibe un error detectado. 2. Genera una huella unica (firma).
-- 3. Busca si ese tipo de error ya existe. 4. Si no existe, crea un nuevo tipo_error.
-- 5. Registra el evento que sufrio el usuario. 6.Busca una guia para resolverlo.
-- 7. Crea una notificacion. 8. Notifica al overlay. 9. Devuelve la informacion necesaria
-- para ayudar al usuario.
create or replace function public.fn_reportar_evento(
    p_yo bigint, -- Id del usuario al que le ocurrio el error.
    p_origen public.error_origen, -- Origen del error.
    p_titulo text, -- Titulo del error.
    p_cuerpo text default null, -- Descripcion del error.
    p_uia text default null, -- Identificador tecnico del dialogo o control UI.
    p_aplicacion_id bigint default null, -- Aplicacion relacionada.
    p_tutorial_id bigint default null, -- Tutorial relacionado. puede ser null.
    p_ejecucion_id bigint default null, -- Id de la ejecucion.
    p_payload jsonb default '{}'::jsonb, -- Informacion extra
    p_gravedad public.error_gravedad default 'error' -- Gravedad del error.
)
returns table (
    evento_id bigint, -- Id del evento registrado.
    tipo_error_id bigint, -- Id del tipo de error.
    guia_id bigint, -- Guia encontrada para resolverlo.
    tutorial_id bigint, -- Tutorial asociado a la guia puede ser null.
    pasos jsonb -- pasos JSON para resolver el problema.
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_firma text; -- La huella SHA256.
    v_tipo bigint; -- Id del tipo de herror.
    v_slug text; -- Nombre amigable del tipo del error.
    v_evento bigint; -- Id del evento recien creado.
    v_guia bigint; -- Id de la guia.
    v_tut bigint; -- Id del tutorial asociado.
    v_pasos jsonb; -- Los pasos de resolucion.
    v_payload jsonb := coalesce(p_payload, '{}'::jsonb); -- Datos exttra del error.
begin
    if btrim(coalesce(p_titulo, '')) = '' then
        raise exception 'titulo vacio para reporte de error';
    end if;

    if jsonb_typeof(v_payload) is distinct from 'object' then
        raise exception 'payload debe ser objeto JSON, no %', jsonb_typeof(v_payload);
    end if;

    -- No queremos el valor devuelvo , solo que exista la particion.
    perform public.fn_asegurar_particion_eventos(now());

    -- La huella que identifica al error.
    v_firma := public.fn_firma_error(p_titulo, p_cuerpo, p_uia);

    -- Busca el tipo de error.
    select id into v_tipo -- Id del tipo de error.
    from public.tipos_error
    where firma_hash = v_firma
      and activa = true
    limit 1;

    -- Id del tipo de error es null.
    if v_tipo is null then
        v_slug := "left"( -- left(texto, cantidad) -> Devuelve: los primeros N caracteres.
            public.fn_normalizar_slug(
                (coalesce(p_uia, '') || '-' || coalesce(p_titulo, 'error'))::public.citext
            ) || '-' || "left"(v_firma, 8),
            80
        );

        -- Primero registra el catalogo del error. antes de registrar el evento debes saber el tipo de error.
        insert into public.tipos_error(
            slug, origen, gravedad, aplicacion_id,
            titulo_patron, cuerpo_patron, uia_clave, firma_hash
        ) values (
            -- nombre tecnico amgiable, De donde viene el error, Nivel de gravedad , Aplicacion relacionada.
            v_slug, p_origen, p_gravedad, p_aplicacion_id,
            -- Titulo limpio, Descripcion, Identificador UI, Huella SHA256
            btrim(p_titulo), p_cuerpo, p_uia, v_firma
        )
        on conflict (slug) do update set -- Si ya existe slug.
            updated_at = now()
        returning id into v_tipo; -- Id del tipo de error.

        if v_tipo is null then
            select id into v_tipo
            from public.tipos_error
            where firma_hash = v_firma
            limit 1;
        end if;
    end if;

    -- Registra la aparicion concreta del error.
    insert into public.eventos_sistema(
        usuario_id, tipo_error_id, origen, aplicacion_id, tutorial_id, ejecucion_id,
        titulo, cuerpo, uia_clave, firma_hash, payload, captura_pantalla
    ) values (
        -- Usuairo que sufrio el error, Tipo del error, Origen del error, Aplicacion involucrada , Tutorial involucrado.
        p_yo, v_tipo, p_origen, p_aplicacion_id, p_tutorial_id,
        -- Ejecucion especifica, Titulo del error, Descripcion , Identificador UI, Firma SHA256 , Datos extra.
        p_ejecucion_id, btrim(p_titulo), p_cuerpo, p_uia, v_firma, v_payload, false
    )
    returning id into v_evento;

    -- Buscar guia. Obtiene:
    -- Guia para resolver el error
    select g.id, g.tutorial_id, g.pasos
    into v_guia, v_tut, v_pasos
    from public.guias as g
    where g.tipo_error_id = v_tipo
      and g.activa = true
    limit 1;

    -- Crea una notificacion para el usuario.
    insert into public.notificaciones (usuario_id, actor_id, tipo, payload)
    values (
        p_yo, -- Usuario destinatario.
        0, -- Respresentante Sistema.
        'error_sistema', -- Tipo de notificacion.
        json_build_object(
            'evento_id', v_evento, -- Evento concreto ocurrido.
            'tipo_error_id', v_tipo, --  Tipo de error.
            'guia_id', v_guia, -- Guia encontrada.
            'origen', p_origen -- Origen del error.
        )
    );

    perform pg_notify( -- Envia una notificacion interna de PostgreSQL.
        'canal_overlay_' || p_yo::text,
        json_build_object(
            'tipo', 'error_detectado',
            'evento_id', v_evento,
            'tipo_error_id', v_tipo,
            'guia_id', v_guia
        )::text
    );

    return query select v_evento, v_tipo, v_guia, v_tut, v_pasos;
end;
$$;

-- PRUEBA 1: Reportar un error conocido.
-- Escenario: Hyper-V ya esta registrado en tipos_error y tiene una guia activa.
-- Objetivo: Comprobar que la funcion reconozca el tipo de error existente, registre una nueva
-- ocurrencia(evento) y recupere la guia correspondiente.
select '---PRUEBA 1: error conocido ---' as test;
-- Consulta: Busca el registro hyperv-hypervisor-bloqueado en tipos_error.
-- Objetivo: Conocer el valor inicial de veces_visto antes del nuevo reporte.
-- Resultado esperado: una fila con veces_visto = 0, segun el estado inicial preparado.
-- Codigo de la funcion relacionado: select id into v_tipo.

select veces_visto
from public.tipos_error
where slug = 'hyperv-hypervisor-bloqueado';
-- Esperado ahora: 0.

select count(*) as eventos from public.eventos_sistema;
-- Esperado ahora: 0.

-- Reportar el error conocido de HYPER-V.
-- Escenario: Usuario 1 = Shiriaru, usuario.id. Experimenta el error Hypervisor bloqueado.
-- Objetivo: Comprobar que la funcion encuentre el tipo de error existente y recupere la guia activa asociada a este tipo.
select *
from public.fn_reportar_evento(
    1, -- Usuario.
    'sistema', -- Origen sistema.
    'Hypervisor bloqueado', -- Titulo hypervisor bloqueado.
    'No se pudo iniciar Hyper-V', -- Descripcion No se pudo iniciar Hyper-V.
    'HyperV.ErrorDialog', -- Identificador UIA HyperV.ErrorDialog.
    (select id from public.aplicaciones_catalogo where slug = 'hyper-v'), -- Id de la aplicacion hyper-v
    1, -- Tutorial relaciona con ID 1.
    null, -- Sin ejecucion especifica.
    '{"dialogo":"HyperV.ErrorDialog"}'::jsonb,
    'critico'
);
-- Esperado: evento_id nuevo. tipo_error_id = el id de hyperv-hypervisor-bloqueado.
-- guia_id = la guia "Activar Hyper-V". tutorial_id 1.
-- jsonb_array_length(pasos) = 2.

-- Verificar el evento, la captura y la particion fisica.
-- Objetivo: Comprobar que el evento fue registrado y que se almaceno en particon mensual correpondiente.
select t.veces_visto, e.captura_pantalla, c.relname as particion
from public.eventos_sistema e
join public.tipos_error t on t.id = e.tipo_error_id
join pg_class c on c.oid = e.TABLEOID
where t.slug = 'hyperv-hypervisor-bloqueado';
-- Esperado: una fila. veces_visto 1. captura_pantalla false.
-- particion eventos_sistema_202611.

-- Verificar la notificacion.
select n.tipo::text, n.actor_id, n.leida,
       (n.payload->>'guia_id') is not null as trae_guia
from public.notificaciones n
where n.usuario_id = 1
  and n.tipo = 'error_sistema'
order by n.id desc
limit 1;
-- Esperado: tipo error_sistema. actor_id 0, el usuario system.
-- leida false. trae_guia true.


-- PREUBA 2: reportar un erro nuevo.
-- Escenario: Pantalla azul de la muerte no existe previamente en el catalogo.
-- Tampoco tiene una guia de resoucion.
-- Objetivo: Comprobar que la funcion pueda crear un nuevo tipo de error, registrar su ocurrencia y devolver una respuesta sin guia.
select '--- PRUEBA 2: error nuevo ---' as test;

-- Comprobar que el tipo de error no existe.
select id
from public.tipos_error
where titulo_patron = 'Pantalla azul de la muerte';
-- Esperado ahora: cero filas.

-- Reportar el error nuevo.
select *
from public.fn_reportar_evento(
    1,
    'sistema',
    'Pantalla azul de la muerte',
    'El equipo se reinicio',
    'Windows.BSOD',
    null,
    null,
    null,
    '{}'::jsonb,
    'critico'
);
-- Esperado: evento_id nuevo. tipo_error_id nuevo.
-- guia_id null. tutorial_id null. pasos null.

-- Verificar el nuevo tipo de error.
select slug, veces_visto, gravedad
from public.tipos_error
where titulo_patron = 'Pantalla azul de la muerte';
-- Esperado: slug windows-bsod-panalla-azul-muerte-7eea-689

SELECT * from public.eventos_sistema;

-- PRUEBA 3: Rechazar reportes invalidos.
-- Se intenta reportar un error sin titulo y otro con un payload que no cumple la estructura JSON esperada.
-- Objetivo: Comprobar que las validaciones iniciales impidan registrar eventos, con informacion invalida.

-- Contar los eventos antes de los reportes invalidos.
-- Objetivo Establecer el numero de eventos que debera mantenerse despues de ejecutar las dos pruebas de validacion.
select '--- PRUEBA 3: reporte invalido ---' as test;

select count(*) as eventos
from public.eventos_sistema;
-- Esperado ahora: 2.

-- Rechazar un titulo vacio. Entrada: Titulo compuesto unicamente por espacios.
-- Objetivo: Comprobar que BTRIM y coalesce detecten un titulo sin contenido.

do $$
begin
    perform *
    from public.fn_reportar_evento(1, 'sistema', ' ');
    raise exception 'FALLO: acepto titulo vacio';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK titulo: %', sqlerrm;
end;
$$;
-- Esperado en Mesages: OK titulo: titulo: titulo vacio para reporte de error.


-- PRUEBA 3: Rechazar un payload que se un arreglo JSON.
-- Entrada: Titulo valido. Payload = [].
-- Objetivo: Comprobar que la funcion solo acepte objetos JSON y rechace arreglos.

do $$
begin
    perform *
    from public.fn_reportar_evento(
        1, 'sistema', 'Hypervisor bloqueado', null, null,
        null, null, null, '[]'::jsonb
    );
    raise exception 'FALLO: acepto payload array';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK payload: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK payload: payload deber ser objeto JSON, no array.

-- Comprobar que no se agregaron eventos invalidos.
select count(*) as eventos from public.eventos_sistema;
-- Eperado: 2.



