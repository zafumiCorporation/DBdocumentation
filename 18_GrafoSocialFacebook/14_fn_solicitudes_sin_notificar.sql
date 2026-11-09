-- ANTI JOIN pattern: filas que no tienen correspondencia
create or replace function public.fn_solicitudes_sin_notificar()
returns table(amistad_id bigint, seguidor_id bigint, created_at timestamptz)
language sql
stable
set search_path = ''
as $$
    -- a.seguidor_id -> El usuario que envio la solicitud
    select a.id as amistad_id, a.seguidor_id , a.created_at
    from public.amistades as a
    -- ANTI JOIN: LEFT JOIN + WHERE n.id IS NULL
    -- "Dame todas las solicitudes pending que NO generaron notificacion"
    -- left join trae todas las filas de amistades y lo que coincida en notificaciones
    left join public.notificaciones as n
        on n.tipo = 'solicitud_amistad'
       and n.usuario_id = a.seguido_id
       and n.actor_id = a.seguidor_id -- Usuario que la envio (el actor)
    -- @> operador "contiene". Pregunta si el JSON guarda esa clave/valor
    -- jsonb_build_object('amistad_id', a.id) construye un ojeto JSON como {"amistad_id": 123}
       and n.payload @> jsonb_build_object('amistad_id', a.id)
    -- Solo solicitudes que aun estan pendientes.
    where a.estado = 'pending'
       and n.id is null;-- Significa que no existe una notificacion asociada.
$$;

-- Verificacion Esperando 0 filas
select * from public.fn_solicitudes_sin_notificar();

-- Prueba B: borro su notificacion, miro , y revierto todo
select * from public.notificaciones;
-- Transaccion manual.
begin;
    -- Los cambios que hagas(INSERT, UPDATE , DELETE) quedan 'pendientes' dentro de esa transaccion.
    delete from public.notificaciones where tipo = 'solicitud_amistad' and usuario_id = 4 and actor_id = 2;
    select * from public.fn_solicitudes_sin_notificar();
    -- Esperando: 1 fila -> amistad_id = 7
    -- amistad_id = 7, seguidor_id = 2, created_at
rollback;-- Todos los cambios hechos desde el begin se deshacen.