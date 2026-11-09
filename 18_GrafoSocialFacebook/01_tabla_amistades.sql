-- MINI SCRIPT TEMPORAL SIRVE PARA EJECUTAR CODIGO PL/pgSQL LO EJECUTAS Y SE BORRA
do $$ begin
-- create type ESTAS CREANDO UN TIPO DE DATO PERSONALIZADO
-- ('''')SON LOS UNICOS VALORES QUE PUEDE TENER ESTE TIPO
    create type public.amistad_estado as enum ('pending', 'accepted', 'blocked', 'declined');
-- exception SE EJECUTA SOLO SI OCURRE UN ERROR DENTRO DEL BLOQUE BEGIN ... END
exception
-- duplicate_object ES EL ERROR QUE APARECE CUANDO INTENTAS CREAR ALGO QUE YA EXISTE.
-- then null "SI OCURRE ESE ERROR NO HAGAS NADA"
   when duplicate_object then null;
end $$;

create table if not exists public.amistades(
    id bigint generated always as identity primary key,
    seguidor_id bigint not null,
    seguido_id bigint not null,
    estado public.amistad_estado not null default 'pending',
    created_at timestamptz not null default now(),
    accepted_at timestamptz,
    blocked_at timestamptz,

    -- REGLAS foreing key
    constraint fk_amistad_usuarios_seguidor
        foreign key (seguidor_id) references public.usuarios(id)
            on delete cascade,

    constraint fk_amistad_usuarios_seguido
        foreign key (seguido_id) references public.usuarios(id)
            on delete cascade,

    -- REGLAS CONSTRAINT COMPUESTA - RELACION DIRIGIDA
    -- RELACION DIRIGIDA FLECHA QUE CONECTA NODOS (1->2) EL USUARIO 1 SIGUE AL USUARIO 2 O (2->1)
    -- uq_amistad_direccion unique GARANTIZA QUE NO HAYAN FLECHAS DUPLICADAS (1->2)
    constraint uq_amistad_direccion unique (seguidor_id, seguido_id),

    -- REGLA DE INTEGRIDAD ASEGURA QUE NINGUN USUARIO PUEDA SEGUIRSE ASI MISMO
    -- <> significa "distinto de" EL VALOR DE  NO PUEDE SER IGUAL AL DE seguido_id (1,1)
    constraint ck_no_self_follow check (seguidor_id <> seguido_id),

    -- SI NO ESTA ACEPTADO NO DEBE TENER FECHA DE ACEPTACION
    constraint ck_accepted_at check (
    -- SI EL ESTADO ES 'accepted' ENTONCES LA COLUMNA accepted_at DEBE TENER UNA FECHA
      (estado = 'accepted' and accepted_at is not null) or
    -- SI EL estado ES DISTINTO DE 'accepted', ENTONCES accepted_at DEBE ESTAR VACIO.
      (estado <> 'accepted' and accepted_at is null)
    ),

    constraint ck_blocked_at check (
        (estado = 'blocked' and blocked_at is not null) or
        (estado <> 'blocked' and blocked_at is null)
    )
);

-- comment on table SIRVE PARA AÑADIR UNA DESCRICPION A UNA TABLA , NO AFECTA LA LOGICA NI LOS DATOS METADATA
comment on table public.amistades is 'Grafo social para IA Desktop. Una fila por direccion. Amistad real = 2 filas accepted.';

alter table public.usuarios
    add column if not exists amigos_count int not null default 0 check (amigos_count >= 0),
    add column if not exists solicitudes_pendientes_count int not null default 0 check (solicitudes_pendientes_count >= 0);

comment on column public.usuarios.amigos_count is 'total de amistades bidireccionales aceptadas';
comment on column public.usuarios.solicitudes_pendientes_count is 'solicitudes de amistad pendientes';

-- DATOS DE PRUEBA - Cubrimos PENDING, ACCEPTED , DECLINED, BLOCKED
-- REQUIERE: Haber creado las funciones (fn_enviar_solicitud, fn_aceptar_solicitud)
do $$
declare
    v_amistad_id bigint;
begin
    -- 1 -> 2 : ACCEPTED - Usuario Shiriaru (1) envia solicitud (amigo) Usuario Julio (2)
    If not exists(select 1 from public.amistades where seguidor_id=1 and seguido_id=2) then
        perform public.fn_enviar_solicitud(1,2);
    end if;
    --Guardamos el ID de esa solicitud.
    select id into v_amistad_id from public.amistades where seguidor_id = 1 and seguido_id = 2 and estado = 'pending';
    -- Si existe esa solicitud (no es NULL)
    if v_amistad_id is not null then
        perform public.fn_aceptar_solicitud(v_amistad_id, 2);
    end if;

    -- 1 -> 3 : ACCEPTED - Shiriaru (1) amigo de Sebastian (3)
    if not exists(select 1 from public.amistades where seguidor_id = 1 and seguido_id = 3) then
        perform public.fn_enviar_solicitud(1,3);
    end if;
    select id into v_amistad_id from public.amistades where seguidor_id = 1 and seguido_id = 3 and estado = 'pending';
    if v_amistad_id is not null then
        perform public.fn_aceptar_solicitud(v_amistad_id, 3);
    end if;

    -- 1 -> 4 : ACCEPTED - Shiriaru (1) amigo de Angela (4)
    if not exists(select 1 from public.amistades where seguidor_id = 1 and seguido_id = 4) then
        perform public.fn_enviar_solicitud(1,4);
    end if;
    select id into v_amistad_id from public.amistades where seguidor_id = 1 and seguido_id = 4 and estado = 'pending';
    if v_amistad_id is not null then
        perform public.fn_aceptar_solicitud(v_amistad_id, 4);
    end if;

    -- 2 -> 4 : PENDING - Julio (2) a Angela (4) - queda pendiente para badge.
    if not exists(select 1 from public.amistades where seguidor_id = 2 and seguido_id = 4) then
        perform public.fn_enviar_solicitud(2,4);
    end if;

    -- 3 -> 2 DECLINED - Sebastian (3) a Julio (2) - rechazado
    if not exists(select 1 from public.amistades where seguidor_id = 3 and seguido_id = 2) then
        perform public.fn_enviar_solicitud(3,2);
    end if;
    select id into v_amistad_id from public.amistades where seguidor_id = 3 and seguido_id = 2  and estado = 'pending';
    if v_amistad_id is not null then
        perform public.fn_rechazar_solicitud(v_amistad_id, 2);
    end if;

    -- 4 -> 3 Blocked Angela (4) Bloquea a Sebastian (3) - sin notificacion
    if not exists(select 1 from public.amistades where seguidor_id = 4 and seguido_id = 3 and estado = 'blocked') then
        perform public.fn_bloquear_usuario(4,3);
    end if;

end;
$$;

-- Verificacion
select amistades.seguidor_id , amistades.seguido_id, amistades.estado from public.amistades
order by seguidor_id, seguido_id;