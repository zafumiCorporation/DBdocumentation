-- Objetivo : Confirmar que la instalacion termino correctamente.
-- Antes tenias: estado = instalando , Despues de esta funcion tendras estado = instalada.
create or replace function public.fn_confirmar_instalada(
    p_yo bigint, -- Id del usuario dueno de la instalacion. Ej: Usuario 7
    p_aplicacion_id bigint, -- Id de la aplicacion que acabas de instalar , Ej: 1 = VMware , 2 = VirtualBox , 3 = Launch4j
    p_ruta text, -- Es la ruta real donde quedo instalada. Ej: C:\Program Files\VMware o C:\Users\Yonatan\AppData\Local\AIAssistant\Portables\Notepad++
    p_exe text, -- Es la ruta del ejecutable principa , Ej: C:\Program Files\VMware\vmplayer.exe
    p_rastros jsonb default '{}'::jsonb -- Aqui guardas informacion para detectar o desinstalar la aplicacion despues.
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- jsonb_typeof(p_rastros) -> Obtiene el tipo del JSON
    -- is distinct from -> si no es un objeto.
    if jsonb_typeof(p_rastros) is distinct from 'object' then
        raise exception 'rastros debe ser objeto JSON, no %', jsonb_typeof(p_rastros);
    end if;

    -- Actualiza el registro de instalacion del usuario.
    update public.aplicaciones_usuario
    set estado = 'instalada',
        ruta_instalacion = p_ruta,
        exe_path = p_exe,
        rastros = p_rastros,
        instalada_en = now(),
        desistalada_en = null,
        error_texto = null,
        updated_at = now()
    where usuario_id = p_yo and aplicacion_id = p_aplicacion_id;

    if not found then -- El update no encontro ninguna fila.
        raise exception 'inicia la instalacion antes de confirmar';
    end if;

end;
$$;

-- PRUEBA 1 Confirmar una instalacion exitosa.
-- Objetivo: Verificar que fn_confirmar_instalada() registre correctamente la informacion final
-- Estado Inicial: Existe un registro en estado "instalando" , instalada_en es NULL
-- Accion: Informar la ruta real, el ejecutable principal y los rastros detectado por el agente.
-- Resultado esperado: estado cambia a "instalada". ruta_instalacion queda registrada.
-- exe_path queda registrado. rastros queda almacenado. instalada_en recibe fecha y hora
-- error_texto queda en NULL

select '--- PRUEBA 1: confirmar Notepad ---';

select estado, instalada_en
from public.aplicaciones_usuario
where usuario_id = 1
    and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable');
-- Esperado ahora: estado instalando, instalada_en null

-- 1 = Shiriaru, usuarios.id.
-- El subquery es notepadpp-portable. p_ruta y p_exe son lo que el agente vio en disco
-- p_rastros tiene que ser un objeto, no un array.
select public.fn_confirmar_instalada(
       1,
       (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable'),
       'C:\Users\Shiriaru\AppData\Local\AIAssistant\Portables\shiriaru\notepadpp-portable\8.6',
       'C:\Users\Shiriaru\AppData\Local\AIAssistant\Portables\shiriaru\notepadpp-portable\8.6\notepad++.exe',
       '{
        "carpeta": "C:\\Users\\Shiriaru\\AppData\\Local\\AIAssistant\\Portables\\shiriaru\\notepadpp-portable\\8.6",
        "accesos_directos": ["%UserProfile%\\Desktop\\Notepad++.lnk"],
        "appdata": [],
        "localappdata": [],
        "registro": ["HKCU\\Software\\Notepad++"]
    }'::jsonb
);

select estado, ruta_instalacion, exe_path, rastros->>'carpeta' as carpeta,
       instalada_en is not null as tiene_fecha, desistalada_en, error_texto
from public.aplicaciones_usuario
where usuario_id = 1
  and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable');
-- Esperado: estado instalada. error_texto nulll. desistalada_en null. tiene_fecha true.
-- ruta_instalacion y exe_path son las dos rutas de arriba.
-- carpeta = C:\Users\Shiriaru\AppData\Local\AIAssistant\Portables\shiriaru\notepadpp-portable\8.6

-- PRUEBA 2 validar el formato de los rastros
-- Objetivo: Verificar que fn_confirmar_instalada() unicamente acepte rastros en formato objeto JSON.
-- Estado inicial: Existe una aplicacion valida.
-- Accion: Intentar confirmar la instalacion enviando un array JSON en luga de un objeto JSON
-- Resultado esperado: La funcion rechaza la operacion. Se genera una excepcion. No se realiza ningun UPDATE
select '--- PRUEBA 2: rastros que no son objeto ---' as test;

-- 1 = Shiriaru. VirtualBox no se ha iniciado, pero el rechazo ocurre antes del update.
do $$
begin
    perform public.fn_confirmar_instalada(
        1,
        (select id from public.aplicaciones_catalogo where slug = 'virtualbox'),
        'C:\Program Files\Oracle\VirtualBox',
        'C:\Program Files\Oracle\VirtualBox\VirtualBox.exe',
        '[]'::jsonb
    );
    raise exception 'FALLO: acepto un array';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK rastros: %', sqlerrm;
end;
$$;
