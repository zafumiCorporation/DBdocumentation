-- fn_notificar_solicitud_amistad
create or replace function public.fn_notificar_solicitud_amistad()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_payload jsonb;
begin
    -- INSERT: NUEVA SOLICITUD
    if tg_op = 'INSERT' and new.estado = 'pending' then

        insert into public.notificaciones (usuario_id, actor_id, tipo, payload)
        values (new.seguido_id, new.seguidor_id, 'solicitud_amistad', jsonb_build_object('amistad_id', new.id));

        -- pg_notify: Push real-time a la app de escritorio (System Tray - Imagen 1)
        -- := Toma el resultado de la derecha y lo guarda en la variable izquierda(v_payload)
        v_payload := jsonb_build_object('tipo', 'solicitud_amistad', 'amistad_id', new.id);
        -- pg_notify funcion de postgres que envia un mensaje en tiempo real a un canal.
        -- pg_notify(nombre del canal + id del usuario convertido a texto + contenido del mensaje )
        perform pg_notify('canal_notif_' || NEW.seguido_id::TEXT, v_payload::TEXT);

    elsif tg_op = 'UPDATE' then

        if new.estado = 'accepted' and old.estado = 'pending' then
            insert into public.notificaciones(usuario_id, actor_id, tipo, payload)
            values (new.seguidor_id, new.seguido_id, 'amistad_aceptada', jsonb_build_object('amistad_id', new.id));

            v_payload := jsonb_build_object('tipo', 'amistad_aceptada', 'amistad_id', new.id);
            perform pg_notify('canal_notif_' || NEW.seguidor_id::TEXT, v_payload::TEXT);

        elsif new.estado = 'declined' and old.estado = 'pending' then
            insert into public.notificaciones (usuario_id, actor_id, tipo, payload)
            values (new.seguidor_id, new.seguido_id, 'amistad_rechazada', jsonb_build_object('amistad_id', new.id));

            v_payload := jsonb_build_object('tipo', 'amistad_rechazada', 'amistad_id', new.id);
            perform pg_notify('canal_notif_' || new.seguidor_id::text, v_payload::text);

            -- estado = 'blocked' intencionalmente sin INSERT ni NOTIFY
            -- Pattern FAANG: El bloqueado nunca sabe que fue bloqueado
        end if;
    end if;

    return null;
end;
$$;

drop trigger if exists trg_amistades_notificar on public.amistades;
create trigger trg_amistades_notificar
after insert or update  of estado on public.amistades
for each row execute function public.fn_notificar_solicitud_amistad();

select * from amistades;
select * from usuarios;
begin;
    -- Angela le envia solicitud a julio
    select public.fn_enviar_solicitud(4,2);
    select n.usuario_id, n.actor_id, n.tipo, n.payload from public.notificaciones n
        order by n.id desc limit 1;

    -- Esperado: usuario_id = 2 , actor_id = 4, tipo = solicitud_amistad, payload = {"amistad_id": <nuevo id>}
    select public.fn_contar_no_leidas(2);
    select id, username, solicitudes_pendientes_count from public.usuarios where id = 2;

rollback;

