-- fn_catalogo_upsert -> Es para crear o actualizar una app en la tienda.
-- Si no existe la crea, si ya existe la actualiza.
-- Objetivo : Crear aplicaciones nuevas o Actualizar aplicaciones existentes
create or replace function public.fn_catalogo_upsert(
    p_slug text, -- Identificador unico sin espacions. Ej: vmware-workstatio-player.
    p_nombre text, -- Nombre visible. Ej: VMware Workstatio Player.
    p_publisher text, -- Quien la hizo. Ej: Broadcom , Microsoft
    p_version text, -- Version. Ej: 17, 8.6
    p_tipo public.app_tipo_paquete, -- Tipo del paquete: portable, instalada , runtime.
    p_familia text, -- A que categoria grande pertenece. Ej: Tools = 6. Puede ser NULL
    p_categoria_id bigint default null, -- A que categoria grande pertenece. Ej: Tools = 6. Puede ser null
    p_exe text default null, --  Nombre del .exe principal. Ej: vmplayer.exe
    p_peso int default 100, -- Que tan recomendada es. Numero bajo = mas recomendada. 10 gana sobre 90. Por defecto 100.
    p_url public.url_http default null, -- Link de descarga.
    p_silent text default null -- Argumentos para instalar en silencio. Ej: /S o /quiet . Si es null , significa que necisita clicks con tu overlay.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Aqui se guarda el ID de la app que se creo o actualizo, para devolverlo al final.
    v_slug text := public.fn_normalizar_slug(p_slug::public.citext);
begin
    if v_slug is null then
        raise exception 'slug vacio';
    end if;

    -- Intentas insertar la nueva app con todos los datos que te pasaron.
    insert into public.aplicaciones_catalogo(
        slug, nombre, publisher, version_paquete, tipo, familia_slug,
        categoria_id, exe_relativo, peso_recomendacion, url_descarga, silent_args
    ) values (
        v_slug, btrim(p_nombre), p_publisher, p_version,
        p_tipo, public.fn_normalizar_slug(p_familia::public.citext),
        p_categoria_id, p_exe, p_peso, p_url, p_silent
    )
    -- Si el slug ya existe, no da error. En vez de insertar, actualiza la fila existente con los datos nuevos que ibas a insertar.
    on conflict (slug) do update set
        nombre = excluded.nombre, -- Excluded fila que intentas insertar.
        publisher = excluded.publisher,
        version_paquete = excluded.version_paquete,
        tipo = excluded.tipo,
        familia_slug = excluded.familia_slug,
        categoria_id = excluded.categoria_id,
        exe_relativo = excluded.exe_relativo,
        peso_recomendacion = excluded.peso_recomendacion,
        url_descarga = excluded.url_descarga,
        silent_args = excluded.silent_args,
        updated_at = now()
    returning id into v_id; -- Id de esa fila o registro.

    return v_id;
end;
$$;

-- PRUEBA 1 Registrar una aplicacion nueva en el catalogo.
-- Objetivo: Verificar que fn_catalogo_upsert() cree un nuevo registro cuando el slug todavia no existe.
-- Estado inicial: No existe la aplicacion 7-zip-portable.
-- Accion: Registrar la aplicacion 7-Zip Portable.
-- Resultado esperado: 1. Se crea una nueva fila. 2. Se normaliza el slug , 3. Se guardan todos los datos.
-- 4. Se devuelve el ID generado.

select '--- PRUBA 1: alta de catalogo ---' as test;
-- Valida insert into public.aplicaciones_catalogo(...) values(...)

select id, slug
from public.aplicaciones_catalogo
where slug = '7-zip-portable';
-- Esperado ahora: cero filas.

-- '7-Zip Portable' pasa por fn_normalizar_slug y queda 7-zip-portable.
-- 6 = Tools, categorias.id
-- portable = tipo. compresion = familia. 50 = peso. La url y el silent van null
select public.fn_catalogo_upsert(
    '7-Zip Portable', '7-Zip', 'Igor Pavlov', '24.08',
    'portable', 'compresion', 6, '7zFM.exe', 50 , null, null
);
-- Esperado: id nuevo.

select slug, nombre, publisher, version_paquete, tipo, familia_slug, peso_recomendacion, exe_relativo
from public.aplicaciones_catalogo
where slug = '7-zip-portable';
-- Esperado: una fila. nombre 7-Zip, publisher Igor pavlov, version 24.08
-- tipo portable, familia compresion, peso 50, exe 7zFM.exe.

-- PRUEBA 2 Actualizar una aplicacion existente.
-- Objetivo: Verificar que fn_catalogo_upsert() actualice una aplicacion cuando el slug ya existe.
-- Estado inicial: Existe una fila con slug vmware-player.
-- Accion : Ejecutar nuevamente fn_catalogo_upsert() utilizando el mismo slug.
-- Resultado esperado: No se crea una nueva fila. Se conserva el mismo ID , Los datos son actualizados
-- publisher cambia a "Broadcom Inc"

select '--- PRUEBA 2: actualizar sku ---' as test;
-- on conflict (slug) do update

select id, publisher
from public.aplicaciones_catalogo
where slug = 'vmware-player';
-- Esperado ahora: una fila, publisher Broadcom. Anota el id.

select public.fn_catalogo_upsert(
    'vmware-player', 'VMware Workstation Player', 'Broadcom Inc', '17',
    'instalada', 'virtualizacion', 6, 'vmplayer.exe', 10,
    'https://cdn.ejemplo.com/vmware-player.exe', '/s'
);
-- Esperado: el mismo id de arriba. No uno nuevo.

select slug, publisher
from public.aplicaciones_catalogo
where slug = 'vmware-player';
-- Esperado: una sola fila. publisher = Broadcom Inc.