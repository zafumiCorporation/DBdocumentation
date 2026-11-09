-- Pattern: Least Privilege Role + Force RLS + current_setting
-- Pattern -> Patron o modelo de buenas practicas
-- Least Privilege Role -> dar a cada rol solo los permisos minimos necesarios.
do $$
begin
    -- pg_roles -> catalogo interno de Postgres que guarda todos los roles creados.
    -- rolname -> nombre de rol.
    if not exists(select 1 from pg_roles where rolname = 'app_desktop_role') then
    -- create role -> Crea un nuevo rol en Postgres
    -- login Indica que este rol puede Iniciar sesion en la base de datos.
    -- password Aqui debes poner una contrase;a real y segura (minimo 32 caracteres en produccion).
        create role app_desktop_role login password '0004567';
    end if;
end $$;

-- Ver todos los roles existentes en tu base de datos
select rolname from pg_roles;

-- 2. ACTIVAR RLS - Con FORCE para que hasta el owner respeta las politicas
-- owner es el rol que creo la tabla u objeto.
-- RLS = Row Level Security Funcion de Postgres que controla que filas puede ver cada usuario.
-- enable -> Significa "activar" En este caso, activa una caracteristica especial en la tabla.
alter table public.amistades enable row level security;-- Solo activas RlS en la tabla amistades.
alter table public.amistades force row level security;

alter table public.notificaciones enable row level security;
alter table public.notificaciones force row level security ;

alter table public.sesiones_ram enable row level security;
alter table public.sesiones_ram force row level security ;

-- 3. POLITICAS SOLO MIS FILAS
-- Policy -> Sirve para definir que filas puede ver o modificar un usuario cuando esta activado Row Level Security (RLS)
drop policy if exists amistades_solo_mias on public.amistades;--Borra la politica
create policy amistades_solo_mias on public.amistades --Crea la politica
for all -- Aplica a todas las operaciones.
-- Grand Unified Configuration Sirve para almacenar y validar parametros de configuracion.
-- current_setting Devuelve el valor de una configuracion actual del servidor (parametro de sesion).
-- app.usuario_actual (Parametro de configuracion) Ese parametro no existe por defecto en Postgres , tu lo defines como Grand unified Configuration
-- true Evita error si la clave no existe(devuelve null).
-- El usuario actual puede ver las filas donde aparece su propio ID
-- Ese id puede estar en la columna seguidor_id o seguido_id(El que recibio la accion)
using (seguidor_id = current_setting('app.usuario_actual', true)::bigint -- Esto obtiene el id del usuario actual que esta usando la aplicacion.
    or seguido_id = current_setting('app.usuario_actual', true)::bigint)
-- with check Define que filas puede insertar o modificar el usuario.
-- Si intentas crear una maistad, tu id debe estar en seguidor_id o en seguido_id
with check (seguidor_id = current_setting('app.usuario_actual', true)::bigint
    or seguido_id = current_setting('app.usuario_actual', true)::bigint);

drop policy if exists notificaciones_solo_mias on public.notificaciones;
create policy notificaciones_solo_mias on public.notificaciones
for all
-- El usuario actual solo puede ver las filas donde su propio ID esta en la columna usuario_id
using (usuario_id = current_setting('app.usuario_actual', true)::bigint)
-- El usuario actual solo puede insertar o modificar filas donde su ID este en usuario_id.
with check (usuario_id = current_setting('app.usuario_actual', true)::bigint);

drop policy if exists sesiones_ram_solo_mias on public.sesiones_ram;
create policy sesiones_ram_solo_mias on public.sesiones_ram
for all
using (usuario_id = current_setting('app.usuario_actual', true)::bigint)
with check (usuario_id = current_setting('app.usuario_actual', true)::bigint);

-- 4. Grants - Principio de minimo privilegio
-- revoke -> Significa "quitar permisos"
-- all -> Indica que se quitan todo los permisos posibles sobre esas tablas.
-- from public (todos los usuarios) app_desktop_role Indica a quien le quitas los permisos.
revoke all on public.amistades, public.notificaciones, public.sesiones_ram from public , app_desktop_role;
-- grant -> Significa "dar permisos"  El rol podra hacer todas las operaciones basicas.
-- to -> Indica a quien se le dan los permisos.
-- app_desktop_role ese rol ahora puede leer, insertar, actualizar y borrar en las tablas indicadas.
grant select, insert, update, delete on public.amistades, public.notificaciones, public.sesiones_ram to app_desktop_role;
-- "secuencia" Objeto especial en PostgreSQL que genera numeros consecutivos automaticamente.
-- usage permisos para usar un objeto "secuencias"
-- select -> permisos para leer el valor actual de una se secuencia
-- on all sequences -> aplica permisos a todas las secuencias.
-- Esquema -> Carpeta donde viven las tablas y secuencias.
-- in schema public -> Indica que los permisos se aplican a todas las secuencias que estan dentro del esquema public.
grant usage, select on all sequences in schema public to app_desktop_role;