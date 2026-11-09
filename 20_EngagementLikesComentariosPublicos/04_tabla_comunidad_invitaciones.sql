-- 04 Invitaciones (clon de solicitud de amistad, TTL 8 h)
DO $$
begin
    create type public.invitacion_estado as enum('pending', 'accepted', 'declined', 'ignored');
end;
$$;

do $$
begin
    alter type public.notificacion_tipo add value if not exists 'mencion_tutorial';
exception when others then null;
end;
$$;

do $$
begin
    alter type public.notificacion_tipo add value if not exists 'invitacion_comunidad';
exception when others then null;
end;
$$;

create table if not exists public.comunidad_invitaciones(
    id bigint generated always as identity primary key,
    comentario_id bigint not null,
    actor_id bigint not null,
    destinatario_id bigint not null,
    estado public.invitacion_estado not null default 'pending',
    created_at timestamptz not null default now(),
    expira_at timestamptz not null default now() + make_interval(hours => 8),
    respondida_at timestamptz,

    -- foreign
    constraint fk_comunidad_invitaciones_tutorial_comentarios_comentario
        foreign key (comentario_id) references public.tutorial_comentarios(id)
            on delete cascade,

    constraint fk_comunidad_invitaciones_usuarios_actor
        foreign key (actor_id) references public.usuarios(id)
            on delete cascade,

    constraint fk_comunidad_invitaciones_usuarios_destinatario
        foreign key (destinatario_id) references public.usuarios(id)
            on delete cascade,

    constraint ck_inv_no_yo check ( actor_id <> destinatario_id),
    constraint ck_inv_ttl check ( expira_at > created_at),
    constraint ck_inv_respondida_futuro check ( respondida_at is null or respondida_at > created_at),
    constraint uq_inv_pendiente unique (comentario_id, destinatario_id)
);

comment on table public.comunidad_invitaciones is 'Solicitud de union comentario-comunidad. Ticket = la fila. 8h. Sin token. Clon de solicitud amistad';

-- Julio (usuarios.id 2) invita a Angela (usuarios.id 4) a UnrealHQ. Angela aun no es miembro.
insert into public.comunidad_invitaciones(comentario_id, actor_id, destinatario_id)
select c.id, 2, 4
from public.tutorial_comentarios as c
where c.codigo = 'UnrealHQ';

-- Shiriaru (usuarios.id 1) invita a Sebastian (usuarios.id 3) a WordDudas. Sebastian aun no es miembro.
insert into public.comunidad_invitaciones (comentario_id, actor_id, destinatario_id)
select c.id, 1, 3
from public.tutorial_comentarios as c
where c.codigo = 'WordDudas';
