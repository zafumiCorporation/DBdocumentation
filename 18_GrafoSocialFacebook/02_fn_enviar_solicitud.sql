-- 1) ENVIAR SOLICITUD , 2 NUMEROS GRANDES QUE REPRESENTAN EL USUARIO QUE ENVIA LA SOLICITUD Y EL USUARIO QUE LA RECIBE
create or replace function public.fn_enviar_solicitud(p_de bigint, p_para bigint)
returns bigint
language plpgsql
-- ASEGURA QUE LA FUNCION CORRE CON LOS PERMISOS DEL CREADOR
security definer
set search_path = ''
as $$
declare
    v_id bigint;
    -- ALIAS
    v_emisor_id bigint := p_de;     -- El que envia la solicitud
    v_receptor_id bigint := p_para; -- El que recibe la solicitud
begin
        if v_emisor_id = v_receptor_id then
            -- errcode = 'P0001' ES UN CODIGO PERSONALIZADO PARA IDENTIFICAR EL TIPO DE ERROR
            raise exception using message = 'No puedes enviarte solicitud a ti mismo', errcode = 'P0001';
        end if;

        -- Caso 1: el Receptor me bloqueo
        if exists(select 1 from public.amistades
                  where seguidor_id = v_receptor_id
                    and seguido_id = v_emisor_id
                    and estado = 'blocked') then
            raise exception using message = 'Usuario bloqueado', errcode = 'P0001';
        end if;

        -- Caso 2: yo bloquee al receptor
        if exists(select 1 from public.amistades
                  where seguidor_id = v_emisor_id
                    and seguido_id = v_receptor_id
                    and estado = 'blocked')then
            raise exception using message = 'No puedes enviar solicitud a este usuario', errcode = 'P0001';
        end if;

        insert into public.amistades as a (seguidor_id, seguido_id , estado)
        values (p_de, p_para, 'pending')
        on conflict (seguidor_id, seguido_id) do update                     -- SI EXISTE UN REGISTRO CON ESA COMBINACION DE SEGUIDOR Y SEGUIDO
            set estado = 'pending',
                blocked_at = null,
                accepted_at = null
            where a.estado = 'declined'                                     -- SOLO SE ACTUALIZA SI EL ESTADO ACTUAL ERA 'declined'
        returning a.id into v_id;

        -- SI YA EXISTIA COMO pending/accepted RETORAN EL id existente
        if v_id is null then
            select a.id into v_id
            from public.amistades as a
            where a.seguidor_id = p_de and a.seguido_id = p_para;
        end if;

        return v_id;
end;
$$;