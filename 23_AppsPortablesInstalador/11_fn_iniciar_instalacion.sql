-- Tres llamadas: iniciar -> confirmar con rastros -> desinstalar devuelve rastros
-- rastros Ej: {"carpeta":"C:\\Apps\\Notepad++", "exe":"notepad++.exe", "registro":"HKCU\\Software\\Notepad++"}
-- Sirve para saber donde quedo instalada , Saber que borrar , Saber que detectar.
-- PostgreSQL no hace rd /s no elimina carpetas  , Solo guarda JSON para agente tray
-- La base de datos guarda datos , El agente de Windows es quien realmente , Instala , Desinstala , Elimina carpetas , Ejecuta EXE.
-- Idea general : Iniciar instalacion , Confirmar que quedo instalada , Desinstalar.

-- fn_iniciar_instalacion su objetivo es : Preparar una instalacion.
-- Devuelve : Que tipo de aplicacion es , Donde instalarla , Que pasos Seguir.
create or replace function public.fn_iniciar_instalacion(
    p_yo bigint, -- Es el usuario que quiere instalar. Ej: 7
    p_aplicacion_id bigint -- Es la aplicacion que quiere instalar. Ej: VMware, VirtualBox, Launch4j
)
returns table (
    instalacion_id bigint, -- Id del registro creado en: aplicaciones_usuario. Ej: 150.
    ruta_objetivo text, -- Es la ruta donde deber instalarse. Ej: C:\Users\Yonatan\AppData\Local\AIAssistant\Portables\yonatan\notepadpp-portable\8.6
    pasos jsonb, -- Son los pasos de instalacion , Ej: [{"orden":1, "etiqueta":"Next"}, {"orden":2, "etiqueta":"Install"}]
    tipo public.app_tipo_paquete -- Tipo de la aplicacion: portable , instalada , runtime.
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tipo public.app_tipo_paquete; -- Guardara: portable , instalada , runtime
    v_ruta text; -- Guarda la ruta de instalacion. Ej: C:\Apps\Notepad++
    v_pasos jsonb; -- Guardara el JSON de pasos.
    v_id bigint; -- Guardara el ID del registro de instalacion.
begin
    -- Respuesta de la consulta , obtiene: Tipo , Ruta , Pasos.
    -- c.tipo ej: portable , Se guarda en : v_tipo.
    select c.tipo,
        -- Segundo valor pregunta tipo es portable ? si si :
        case when c.tipo = 'portable'
            -- Devuelve algo como: C:\Users\Yonatan\AppData\Local\AIAssistant\Portables\yonatan\notepadpp-portable\8.6
            -- Y se guarda en: v_ruta
            then public.fn_ruta_portable(p_yo, c.id)
            else null -- Si no es portable: Null.
        end,
        -- Tercer valor aqi obtienes los pasos.
        -- busca la IA genero pasos personalizados ?
        -- Si encuentra algo: usa esos, Si devuelve null usa los pasos estandar.
        coalesce((
            select r.pasos_overlay
            from public.recomendaciones_instalacion as r
            where r.usuario_id = p_yo
            and r.aplicacion_id = c.id
            order by r.created_at desc
            limit 1
        ), c.pasos_wizard)
    into v_tipo, v_ruta, v_pasos
    from public.aplicaciones_catalogo as c
    where c.id = p_aplicacion_id and c.activa;

    -- Si no encontro la aplicacion o esta deshabilitada.
    if v_tipo is null then
        raise exception 'aplicacion % no activa', p_aplicacion_id;
    end if;

    -- Aqui registrar el usuario inicio una instalcion.
    insert into public.aplicaciones_usuario(
        usuario_id, aplicacion_id, estado, origen, ruta_instalacion
    ) values (
        -- Usuario , Aplicacion , Estado actual, Origen , ruta de instalacion
        p_yo, p_aplicacion_id, 'instalando', 'tienda', v_ruta
    )
    -- Si ya existe un registro para esa aplicacion y ese usuario.
    on conflict (usuario_id, aplicacion_id) do update set
        estado = 'instalando',
        origen = 'tienda',
        -- Se lee usa la nueva ruta , Si viene Null: Manten la antigua.
        ruta_instalacion = coalesce(excluded.ruta_instalacion , public.aplicaciones_usuario.ruta_instalacion),
        error_texto = null, -- Limpia errores anteriores.
        updated_at = now() -- Fecha de actualizacion
    returning id into v_id; -- Obtiene el id del registro.

    return query select v_id, v_ruta, v_pasos, v_tipo;
end;
$$;

-- PRUEBA 1 Preparar la instalacion de una aplicacion portable.
-- Objetivo: Verificar que fn_iniciar_instalacion()
-- calcule correctamente la ruta destino y registre el inico de instalacion.
-- Estado inicial: Notepad++ Portable esta activa , No existe recomendacion personalizada de IA.
-- El usuario aun no tiene la aplicacion instalada.
-- Accion: Iniciar la instalacion.
-- Resultado esperado: Se genera una ruta portable personalizada.
-- Se utilizan los pasos estandar del catalogo , Se crea un registro en aplicaciones_usuario.
-- estado = instalando. origen = tienda.

select '--- PRUEBA 1: iniciar Notepad portable ---' as test;

select id, estado
from public.aplicaciones_usuario
where usuario_id = 1
  and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable');
-- Esperado ahora: cero filas.

-- 1 = Shiriaru, usuarios.id.
-- El subquery es notepadpp-portable, aplicaciones_catalogo.id.
select instalacion_id, ruta_objetivo, pasos, tipo
from public.fn_iniciar_instalacion(1, (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable'));
-- Esperado un id nuevo. tipo portable
-- ruta_objetivo = {localappdata}\AIAssistant\Portables\shiriaru\notepadpp-portable\8.6
-- pasos = [].

select estado, origen, ruta_instalacion
from public.aplicaciones_usuario
where usuario_id = 1
  and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable');
-- Esperado: estado instalando, origen tienda, ruta_instalacion igual a la ruta de arriba.

-- PRUEBA 2 Aplicar un overlay de instalacion generado por IA.
-- Objetivo verificar que una recomendacion personalizada tenga prioridad sobre los pasos estandar del catalogo.
-- Estado inicial: VMware Player esta activa. Existe una recomendacion personalizada.
-- VMware es una aplicacion instalada, no portable.
-- Accion: Iniciar la instalacion.
-- Resultado esperado: Se utiliza los pasos del overlay .
-- No se utilizan los pasos_wizard originales.
-- ruta_objetivo = null. estado = instalando. origen = tienda.
select '--- Prueba 2: iniciar player con overlay ---';

-- 1 = Shiriaru. El subquery es vmware-player.
select instalacion_id, ruta_objetivo, pasos, tipo
from public.fn_iniciar_instalacion(
    1,
    (select id from public.aplicaciones_catalogo where slug = 'vmware-player')
);
-- Esperado: tipo instalada. ruta_objetivo null, porque no es portable.
-- pasos = [{"orden": 1, "etiqueta": "Launch4j"}]. No es el paso Siguiente del wizard.

select estado, origen
from public.aplicaciones_usuario
where usuario_id = 1
  and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'vmware-player');
-- Esperado: estado instalando, origen tienda.

-- Entender mejor esta.

