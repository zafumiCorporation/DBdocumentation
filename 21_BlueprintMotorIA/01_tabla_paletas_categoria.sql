-- 1 Fila por categoria
create table if not exists public.paletas_categoria(
    categoria_id bigint primary key, -- Cada categoria tiene una sola fila en esta tabla.
    botones jsonb not null default '[]'::jsonb, -- Json con todos los botones de esa aplicacion, Ejemplo: Archivo, Inicio , Insertar , Vista..
    -- Campo calculado automaticamente.
    -- json_array_length(botones) -> cuenta cuantos botones hay en el JSON
    -- stored -> El valor se guarda en la tabla (no se calcula cada vez).
    botones_count int generated always as (jsonb_array_length(botones)) stored,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    -- restrict -> No puedes borrar una categoria si todavia tiene una paleta asociada.
    constraint fk_paletas_categoria_categorias_categoria
        foreign key (categoria_id) references public.categorias(id)
            on update cascade
            on delete restrict,

    -- Asegura que el campo botones siempre sera un array JSON.
    constraint ck_botones_array check ( jsonb_typeof(botones) = 'array' )
);

comment on table public.paletas_categoria is
    'Paleta Unreal: una fila word, JSON con miles de botones UIA. Entrenamiento IA via vista, no via 1 fila/boton.';

-- uia_clave unica Dentro del Json de esa categoria.
-- Esta funcion y trigger sirven para asegurarse de que no haya claves duplicadas dentron del JSON
create or replace function public.fn_paleta_uia_unicas()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if exists(
        select 1
        -- jsonb_array_element() -> Toma el campo botones , Lo convierte en filas, cada fila es un boton
        -- Si tienes 12 botones en el JSON, aqui se generan 12 filas temporales.
        -- as e(elem) -> Da un apodo: cada fila se llama elem. Asi puedes acceder a lso campos de cada boton.
        from jsonb_array_elements(new.botones) as e(elem)
        -- Agrupa todos los botones con "uia_clave":"File" se agrupan juntos.
        group by elem ->>'uia_clave'
        -- Revisa si algun grupo tiene mas de un boton con la misma clave.
        having count(*) > 1
    )then
        raise exception 'uia_clave duplicada en la paleta';
    end if;
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists trg_paleta_uia on public.paletas_categoria;
create trigger trg_paleta_uia
before insert or update of botones on public.paletas_categoria
for each row execute function public.fn_paleta_uia_unicas();

-- La IA lee botones como si fueran filas
-- Una vista -> Tabla virtual puedes consultarla con SELECT como si fuera una tabla
-- pero en realida esta ejecutando la consulta que definiste
create or replace view public.vista_botones_catalogo as
select
    p.categoria_id,
    c.slug as app_objetivo,
    c.nombre as app_nombre,
    elem->>'nombre'     as nombre,
    elem->>'etiqueta'   as etiqueta,
    elem->>'uia_clave'  as uia_clave,
    elem->>'icono'      as icono,
    -- Convierte el valor de es_accion_uia a booleano (true/false)
    -- Si el boton no tiene ese campo (es null), devuelve true por defecto.
    -- Asegura que todos los botones tengan un valor y si falta se asume que es una accion.
    coalesce((elem->>'es_accion_uia')::boolean, true) as es_accion_uia
-- Une la tabla paletas_categoria con categorias .
-- Relacion: c.id = p.categoria_id
from public.paletas_categoria as p
join public.categorias as c on c.id = p.categoria_id
-- jsonb_array_elements(p.botones) -> Aqui se generan n numero de filas.
-- cross join combina la fila de la categoria con cada boton que salio del JSON.
cross join lateral jsonb_array_elements(p.botones) as elem;
-- lateral -> Permite que cada fila de la tabla paletas_categoria pase su propio JSON a la funcion.

-- Seed: Word (1) = Insertar -> Pagina en Blanco.
-- Seed: Unreal (2) = File -> New Project -> First Person -> Create.
insert into public.paletas_categoria( categoria_id, botones) values
(1, '[
    {"nombre":"Archivo","etiqueta":"File","uia_clave":"File","icono":"icon_file","es_accion_uia":true},
	{"nombre":"Insertar","etiqueta":"Insertar","uia_clave":"Insert","icono":"icon_insert","es_accion_uia":true},
	{"nombre":"Pagina en Blanco","etiqueta":"Pagina en Blanco","uia_clave":"BlankPage","icono":"icon_page","es_accion_uia":true}
]'::jsonb),
(2, '[
    {"nombre":"File","etiqueta":"File","uia_clave":"File","icono":"icon_file","es_accion_uia":true},
	{"nombre":"New Project","etiqueta":"New Project","uia_clave":"NewProject","icono":"icon_new","es_accion_uia":true},
	{"nombre":"First Person","etiqueta":"First Person","uia_clave":"FirstPerson","icono":"icon_fp","es_accion_uia":true},
	{"nombre":"Create","etiqueta":"Create","uia_clave":"Create","icono":"icon_ok","es_accion_uia":true}
]'::jsonb)
on conflict (categoria_id) do nothing;