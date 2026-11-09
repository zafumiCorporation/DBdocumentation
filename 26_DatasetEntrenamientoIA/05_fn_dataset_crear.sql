-- Crea un nuevo dataset de entrenamiento. Crea el contenedor donde despues guardaras las muestras.
create or replace function public.fn_dataset_crear(
    p_yo bigint, -- Id del usuario que esta creando el dataset.
    p_slug text, -- Nombre tecnico unico del dataset. office-word , windows-11, hyper-v-training.
    p_titulo text, -- Nombre visible para personas.
    p_notas text default null -- Comentarios internos del dataset.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Guarda el id generado por el insert.
    v_slug text := public.fn_normalizar_slug(p_slug::public.citext); -- slug limpio y normalizado.
begin

    if v_slug is null or btrim(v_slug) = '' then
        raise exception 'slug vacio despues de normalizar: %', p_slug;
    end if;

    if btrim(coalesce(p_titulo, '')) = '' then
        raise exception 'titulo vacio para slug=%', v_slug;
    end if;

    insert into public.dataset_entrenamiento( -- Crea una nueva fila.
        slug, titulo, estado, creador_id, notas
    ) values (
        v_slug, btrim(p_titulo), 'abierto', p_yo, p_notas
    )
    returning id into v_id;

    return v_id;
end;
$$;

-- PRUEBA 1 Crear el primer dataset de entrenamiento.
-- Objetivo: Verificar que fn_dataset_crear() cree correctamente un nuevo lote de entrenamiento.
-- Accion: Crear un dataset llamado SFT Word Noviembre. Normalizar el slug a partir del nombre proporcionado.
-- Resultado esperado: Se crea una nueva fila en dataset_entrenamiento.
-- Se genera un id automaticamente. slug = sft-word-noviembre. estado = abierto. creador_id = 1
-- muestras_count = 0. entrenado_en = null.
select '--- PRUEBA 1: crear dataset ---' as test;

select id
from public.dataset_entrenamiento;
-- Esperado ahora: cero filas.

-- 1 = Shiriaru, usuarios.id.
-- 'SFT Word Noviembre' pasa por fn_normalizar_slug -> sft-word-noviembre.
select public.fn_dataset_crear(
    1,
    'SFT Word Noviembre',
    'SFT Word Noviembre',
    'correcciones de ruta, guias de Hyper-V y Notepad, tutorial 1'
);
-- Esperado: 1. Con la tabla vacia, es el primer identity.

select slug, titulo, estado, creador_id, muestras_count, entrenado_en
from public.dataset_entrenamiento
where id = 1;
-- Esperado: slug sft-word-noviembre. estado abierto.
-- creador_id 1. muestras_count 0. entrenado_en null.

-- PRUEBA 2 Estado inicial: Ya existe el dataset sft-word-noviembre.
-- La funcion recibe nuevas solicitudes de creacion.
-- Un slug que se va a vacio no entra. Un titulo en blanco tampoco.
select '--- PRUEBA 2: slug y titulo vacios ---' as test;

do $$
begin
    perform public.fn_dataset_crear(1, '!!!', 'Lote');
    raise exception 'FALLO: acepto slug vacio';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK slug: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK slug: slug vacio despues de normalizar: !!!

do $$
begin
    perform public.fn_dataset_crear(1, 'lote-excel', '  ');
    raise exception 'FALLO: acepto titulo vacio';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK titulo: %', sqlerrm;
end
$$;
-- Esperado en Messages: OK titulo: titulo vacio para slug=Lote-excel.

select count(*) as filas
from public.dataset_entrenamiento;
-- Esperado: 1.

-- PRUEBA 3: Verificar que fn_dataset_crear no permita registrar dos datasets con el mismo slug.
-- Estado inicial: Ya existe un dataset con slug = sft-word-noviembre.
-- La restriccion uq_dataset_slug garantiza su unicidad.
-- Accion: Intentar crear otro dataset utilizando el mismo slug, aun que se proporcione titulo diferente.
select '---PRUEBA 3: slug unico ---' as test;

do $$
begin
    perform public.fn_dataset_crear(1, 'sft-word-noviembre', 'otro titulo');
    raise exception 'FALLO: duplico el slug';
exception
    when unique_violation then
        raise notice 'OK unique: %', sqlerrm;
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK uniqeu: %', sqlerrm;
end;
$$;
-- Esperado en Messages: Ok unique, constraint uq_dataset_slug.

