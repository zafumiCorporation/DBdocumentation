-- Se usa cuando la aplicacion ya estaba instalada , Usuario instala VMware manualmente.
-- Ya venia instalada en el equipo , El agente la ecuenta , Entonces No instala nada , Solo la marca como detectada.
-- Objetivo: Registrar que una aplicacion ya existe en la computadora.
create or replace function public.fn_marcar_detectada(
    p_yo bigint, -- Usuario dueno de la instalacion. Ej: 7
    p_aplicacio_id bigint, -- Id de la aplicacion encontrada. Ej: 1 = VMware , 2 = VirtualBox , 3 = Launch4j
    p_exe text default null -- Ruta del ejecutable encontrado Ej: C:\Program Files\VMware\vmplayer.exe
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Crea una fila en Inventario del usuario.
    insert into public.aplicaciones_usuario(
        usuario_id, aplicacion_id, estado, origen, exe_path, instalada_en
    ) values (
        -- Quien tiene la aplicacion , Que aplicacion fue detectada , Estado actual , De donde vino, Ruta del exe , Fecha de deteccion.
        p_yo, p_aplicacio_id, 'instalada', 'detectada', p_exe, now()
    )
    -- Si ya existe una fila para este usuario y esta aplicacion.
    on conflict (usuario_id, aplicacion_id) do update set
        estado = 'instalada',
        origen = 'detectada', -- Indica la encontre automaticamente.
        -- usa el nuevo exe , si viene null , conserva el exe anterior.
        exe_path = coalesce(excluded.exe_path, public.aplicaciones_usuario.exe_path),
        updated_at = now();
end;
$$;

-- PRUEBA 1. El agente detecta VMware ya instalada. No ejecuta instalacion.
-- Solo registra que existe.
select '--- PRUEBA 1: detectar Player ---' as test;

select estado, origen
from public.aplicaciones_usuario
where usuario_id = 1
    and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'vmware-player');
-- Esperado ahora: estado = instalando , origen = tienda

-- 1 = Shiriaru, usuarios.id.
-- El subquery es vmware-player, aplicaciones_catalogo.id.
-- El exe es la ruta que el agente encontro en program files.
select public.fn_marcar_detectada(
    1,
    (select id from public.aplicaciones_catalogo where slug = 'vmware-player'),
    'C:\Program Files (x86)\VMware\VMware Player\vmplayer.exe'
);

select estado, origen, exe_path, ruta_instalacion, instalada_en is not null as tienda_fecha
from public.aplicaciones_usuario
where usuario_id = 1
    and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'vmware-player');
-- Esperado: estado instalada, origen detectada, tiene_fecha true .
-- exe_path = C:\Program Files (x86)\VMware\VMware Player\vmplayer.exe
-- ruta_instalacion null. Detectada puede estar instalada sin carpeta portable.
