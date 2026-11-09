-- fn_coleccion_ver_luego: Obtiene o crea la coleccion nueva.
create or replace function public.fn_coleccion_ver_luego(
    p_yo bigint -- Usuario propietario de la coleccion.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Almacenara el id de la coleccion "Ver luego".
begin

    -- Busca la coleccion "Ver luego" del usuario actual.
    select id into v_id
    from public.colecciones
    where dueno_id = p_yo
        and tipo = 'ver_luego';

    -- Si encontro la coleccion : no crea otra , simplemente devuelve: v_id
    if v_id is not null then
        return v_id;
    end if;

    -- Crea automaticamente una coleccion
    insert into public.colecciones(
        dueno_id, titulo, slug, visibilidad, tipo
    ) values (
        p_yo, 'Ver luego', 'ver-luego', 'privada', 'ver_luego'
    )
    -- si hay conflicto en uq_coleccion_ver_luego. Un usuario solo puede tener una coleccion ver luego.
    -- si dos procesos intentan crearla Ej: Proceso A , Proceso B -> conflicto.
    on conflict (dueno_id) where tipo = 'ver_luego' do update
    set updated_at = now()
    returning id into v_id;

    return v_id; -- Devuelve el id de la coleccion ver luego.
end;
$$;

-- PRUEBA 1: Crear la coleccion "Ver luego". El usuario no tiene una coleccion de tipo ver_luego.
-- Ya existe una coleccion de tipo usuario con ID 1.
-- Accion: Consultar si existe una coleccion ver_luego para Shiriaru.
-- Ejecutar fn_coleccion_ver_luego(1). Consultar los datos de la coleccion creada.
-- Resultado esperado: La funcion crea una nueva coleccion con ID 2. El propietario corresponde al usuario 1.
-- El titulo es Ver luego. El slug es ver-luego. La visibilidad es privada. El tipo es ver_luego.
-- El contador items_count comienza en cero.

select '--- PRUEBA 1: alta de ver luego ---' as test;

select id
from public.colecciones
where dueno_id = 1
    and tipo = 'ver_luego';
-- Esperado ahora: cero filas.

-- 1 = Shiriaru, usuarios.id.
select public.fn_coleccion_ver_luego(1);
-- Esperado: 2. La playlist de usuario ya ocupa el 1.

select id, titulo, slug, visibilidad, tipo, items_count
from public.colecciones
where dueno_id = 1
    and tipo = 'ver_luego';
-- Esperado: titulo "ver luego". slug ver-luego. visibilidad privada.
-- tipo ver_luego. items_count 0.

-- PRUEBA 2: Evitar colecciones duplicadas por usuario.
-- Accion: Ejecutar nuevamente fn_coleccion_ver_luego(1).
-- Comprobar cuantas colecciones ver_luego tiene Shiriaru.
-- Ejecutar fn_coleccion_ver_luego(2) para Julio.
-- Consultar las colecciones de ambos usuarios.
-- Resultado esperado: Shiriaru recibe nuevamente el ID 2. Shiriaru conserva una sola  coleccion ver_luego.
-- Julio obtiene  su propia coleccion ver_luego.
-- Existen dos colecciones en total, una por usuario. Ambas colecciones pueden utilizar el slug  ver_luego.

select '--- PRUEBA 2: una cola por usuario ---' as test;

select public.fn_coleccion_ver_luego(1) as otra_vez;
-- Esperado: el mismo id de la prueba 1.

select count(*) as colas
from public.colecciones
where dueno_id = 1
    and tipo = 'ver_luego';
-- Esperado: 1. El indice uq_coleccion_ver_luego aguanta.

-- 2 = Julio, usuarios.id.
select public.fn_coleccion_ver_luego(2);

select dueno_id, slug, tipo
from public.colecciones
where tipo = 'ver_luego'
order by dueno_id;
-- Esperado: dos filas. dueno 1 y dueno 2. slug ver-luego en las dos.
-- uq_coleccion_slug_dueno es (dueno_id, slug), no el slug solo.
