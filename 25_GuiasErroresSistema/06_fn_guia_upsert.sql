-- fn_guia_upsert -> Crea una guia nueva o Actualizar una guia existente.
-- Una guia representa una solucion documentada para un error registrado previamente en public.tipos_error.
create or replace function public.fn_guia_upsert(
    p_tipo_error_id bigint, -- Id del error que esta guia soluciona.
    p_titulo text, -- Titulo de la guia.
    p_tutorial_id bigint default null, -- Id del tutorial que resuelve el error. puede ser null.
    p_pasos jsonb default '[]'::jsonb, -- Lista de pasos para resolver el error.
    p_ia boolean default false -- Indica quien creo la guia. true = La IA la creo , fasle = La creo un humano o viene de un tutorial.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; -- Id final de la guia.
    v_pasos jsonb := coalesce(p_pasos, '[]'::jsonb);
begin

    if jsonb_typeof(v_pasos) is distinct from 'array' then
        raise exception 'pasos debe ser array JSON, no %', jsonb_typeof(v_pasos);
    end if;

    if btrim(coalesce(p_titulo, '')) = '' then
        raise exception 'titulo no puede ser vacio para tipo_error_id=%', p_tipo_error_id;
    end if;

    -- Crea la guia.
    insert into public.guias(
        tipo_error_id, tutorial_id, titulo, pasos, ia_generada, updated_at
    ) values (
        p_tipo_error_id, p_tutorial_id, btrim(p_titulo), v_pasos, p_ia, now()
    )
    on conflict (tipo_error_id) do update set
        tutorial_id = coalesce(excluded.tutorial_id, public.guias.tutorial_id),
        titulo = excluded.titulo,
        pasos = excluded.pasos,
        ia_generada = excluded.ia_generada,
        updated_at = now()
    returning id into v_id;

    return v_id;
end
$$;

-- PRUEBA 1: Se crea(registra) la guia para el error hyperv-hypervisor-bloqueado.
select 'PRUEBA 1: alta de guia' as test;

select id from public.guias;
-- Esperado ahora cero filas.

-- Se crea la guia para el error hyperv-hyppervisor-bloqueado.
-- tipo_error_id: Busca el ID del error en public.tipos_error mediante su slug.
-- titulo: Nombre descriptivo de la solucion. tutorial_id = 1: Relaciona la guia con "Create Sheet in Word".
-- pasos = [] : No se definen instrucciones propias porque la solucion utiliza el tutorial como referencia.
-- ia_generada = false: La guia no fue generada por inteligencia artificial.
select public.fn_guia_upsert(
    (select id from public.tipos_error where slug = 'hyperv-hypervisor-bloqueado'),
    'El hypervisor no arranca',
    1,
    '[]'::jsonb,
    false
);
-- Esperado devuevle el ID de la nueva guia.

-- Se consulta la guia relacionandola con su error mendiante join.
-- pasos_count: Cantidad de pasos almacenados en la guia.
-- Esperado: titulo: "El hypervisor no arranca". tutorial_id = 1. pasos_count = 0. ia_generada = false
-- activa = true.

select g.titulo, g.tutorial_id, g.pasos_count, g.ia_generada, g.activa
from public.guias g
join public.tipos_error t on t.id = g.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';
-- Esperado: titulo "El hypervisor no arranca". tutorial_id 1.
-- pasos_count 0. ia_generada false. activa true.

-- PRUEBA 2: Actualizacion de una guia existente.
select '--- PRUEBA 2: actualizar la guia ---' as test;

-- Se comprueba que ya exista una guia para el error Hyper-V, Esperado una fila.
select count(*)  as filas
from public.guias g
join public.tipos_error t
    on t.id = g.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';

-- Se vuelve a ejecuta fn_guia_upsert() para el mismo tipo_error_id.
-- Como ya existe una guia, on conflict(tipo_error_id) ejecuta update en lugar de crear una segunda fila.
-- El titulo cambia de "El hypervisor no arranca" a "Activar Hyper-V".
select public.fn_guia_upsert(
    (select id from public.tipos_error where slug = 'hyperv-hypervisor-bloqueado'),
    'Activar Hyper-V',
    1,
    '[]'::jsonb,
    false
);

select count(*) as filas, max(g.titulo) as titulo
from public.guias g
join public.tipos_error t on t.id = g.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';
-- Esperado: filas 1. titulo "Activar Hyper-V".


-- PRUEBA 3: Rechazar titulos vacios.
select '--- PRUEBA 3: titulo vacio ---' as test;

do $$
begin
    perform public.fn_guia_upsert(
        (select id from public.tipos_error where slug = 'hyperv-hypervisor-bloqueado'),
        ' ',
        1
    );
    raise exception 'FALLO: acepto titulo vacio';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK titulo: %', sqlerrm;
end;
$$;
-- Esperado en Messages: Ok titulono puede ser vacio para tipo_error_id=1.

-- Se comprueba que el intento fallido no haya modificado la guia.
select titulo
from public.guias g
join public.tipos_error t on t.id = g.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';
-- Esperado: "Activar Hyper-V";

-- PRUEBA 4: Catalogo de guias con diferentes modalidades de solucion.
-- Se consulta el total de guias antes de insertar las nuevas.
select '--- PRUEBA 4: catalogo de guias ---' as test;

select count(*) as guias from public.guias;
-- Esperado ahora: 1.

-- Guia de NOTEPAD++  con pasos JSONB.
-- Se crea una guia para notepad-missing-files.
-- tutorial_id = null: No existe un tutorial asociado a esta solucion.
-- pasos: Contiene una instruccion propia de repacion que podra interpretar posteriormente el agente de escritorio.
-- ia_generada = false:  La guia fue definida por una persona.
-- Esperado: devuelve el ID de la nueva guia.
select public.fn_guia_upsert(
    (select id from public.tipos_error where slug = 'notepad-missing-files'),
    'Reinstalar Notepad++ portable',
    null,
    '[{"orden":1,"fase":"Reparacion","etiqueta":"Reinstalar Notepad++","uia_clave":"Notepad.Reinstall","selector_uia":null,"por_que":"Faltan los dll del portable","action":"click"}]'::jsonb,
    false
);

-- Guia del reloj de windows relacionada con un tutorial
-- Se crea una guia para reloj-sistema.
-- tutorial_id = 4: Relaciona la solucion con "create Video Game in Unreal Engine".
-- pasos = [] No se almacenan instrucciones propias; se utiliza el tutorial como referencia de solucion.
-- ia_generada = false: la guia fue creada por una persona.
-- Esperado: devuelve el ID de la nueva guia.
select public.fn_guia_upsert(
    (select id from public.tipos_error where slug = 'reloj-sistema'),
    'Ajustar el reloj de Windows',
    '4',
    '[]'::jsonb,
    false
);

select t.slug, g.titulo, g.tutorial_id, g.pasos_count, g.ia_generada
from public.guias g
join public.tipos_error t on t.id = g.tipo_error_id
order by t.slug;
-- Esperado: tres filas.
-- hyperv-hypervisor-bloqueado, "Activar Hyper-V", tutorial 1, pasos 0, ia false.
-- notepad-missing-files, "Reinstalar Notepad++ portable", tutorial null, pasos 1, ia false.
-- reloj-sistema, "Ajustar el reloj de Windows", tutorial 4, pasos 0, ia false.
-- overlay-boton-ausente no aparece.
