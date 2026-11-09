-- Crea una nueva coleccion (playlist) para un usuario.
create or replace function public.fn_coleccion_crear(
    p_yo bigint, -- Id del suuario que crea la coleccion.
    p_titulo text, -- Nombre de la coleccion.
    p_visibilidad public.coleccion_visibilidad default 'privada', -- Quien puede ver la coleccion.
    p_descripcion text default null -- Decripcion de la coleccion.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Almacena el id de la nueva coleccion creada.
    v_slug text; -- Almacenara el slug generado para la coleccion.
begin

    if btrim(coalesce(p_titulo, '')) = '' then
        raise exception 'titulo vacio';
    end if;

    v_slug := "left"(
        public.fn_normalizar_slug(p_titulo::public.citext)
              || '-' || encode(public.gen_random_bytes(2), 'hex'),
        80
    );

    -- Inserta la nueva coleccion (playlist).
    insert into public.colecciones (
        dueno_id, titulo, slug, visibilidad, tipo, descripcion
    ) values (
        -- Usuario que la crea, titulo, slug generado , privada, publica o no listada.
        p_yo, btrim(p_titulo), v_slug, p_visibilidad, 'usuario', p_descripcion
    )
    returning id into v_id;

    return v_id; -- Devuelve el id de la nueva coleccion.
end;
$$;

-- PRUEBA 1: Crear una coleccion (playlist)
-- Accion: Crear una coleccion llamada Word + Excel. Establecer su visibilidad como privada.
-- Asignar una descripcion. Consultar el registro creado para verificar sus campos.
-- Resultado esperado: Se crea una coleccion co ID 1. El propietario corresponde al usuario 1.
-- El titulo es Word + Excel. La visibilidad es privada. El tipo es usuario.
-- El contador items_count comienza en cero. El slug contiene el prefijo word-excel y un sufijo hexadecimal.
-- La expresion regula slug_ok devuelve true.

select '--- PRUEBA 1: crear playlist ---' as test;

select id
from public.colecciones;
-- Esperado ahora: cero filas.

-- 1 = Shiriaru, usuario.id.
select public.fn_coleccion_crear(
    1,
    'Word + Excel',
    'privada',
    'Cola de Word el overlay'
);
-- Esperado: 1. Con la tabla vacia, es el primer identity.

select dueno_id, titulo, visibilidad, tipo, items_count,
        slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' as slug_ok,
        "left"(slug, 10) as slug_prefijo
from public.colecciones
where id = 1;
-- Esperado: dueno 1. titulo "Word + Excel". visibilidad privada. tipo usuario.
-- items_count 0. slug_ok true. slug_prefijo word-excel.

-- PRUEBA 2: Rechazar un titulo vacio
-- Estado inicial: Existe una coleccion creada en la prueba anterior.
-- La tabla colecciones contiene un registro.
-- Accion: Intentar crear una coleccion para el usuario 1.
-- Enviar un titulo compuesto unicamente por espacios.
-- Capturar la excepcion generada por la validacion.
select '--- PRUEBA 2: titulo vacio ---' as test;

do $$
begin
    perform public.fn_coleccion_crear(1, '  ', 'publica');
    raise exception 'FALLO: acepto titulo vacio';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK titulo: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK titulo: titulo vacio.

select count(*) as filas
from public.colecciones;
-- Esperado: 1.