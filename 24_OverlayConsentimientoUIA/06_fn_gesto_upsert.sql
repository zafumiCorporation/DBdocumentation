-- Un gesto por paso: Solo puedes tener 1 fila en tutorial_gestos. No puedes tener un click y
-- arrastre en el mismo paso. Por eso existe unique(paso_id).
-- Solo el creador_id de tutoriales puede crear/editar el gesto.
-- Remix no copia gestos = Cuando alguien hace fork/remix de tutorial, copia los pasos pero No copia
-- los gestos del fantasma. Por que los gestos tienen origen_x en pixeles que dependen de la resolucion del creador original. quedan desfasados. El nuevo creado debe regrabar sus propios gestos.

-- fn_gesto_upsert -> Si no existe gesto para ese paso_id , lo crea. Si ya existe, lo reemplaza.
create or replace function public.fn_gesto_upsert(
    p_yo bigint, -- Id del usuario que intenta crear el gesto.
    p_paso_id bigint, -- Id del paso al que pertenece el gesto. donde se crea.
    p_kind public.gesto_kind, -- Tipo del gesto , Ej: click , arrastre, redimension, tecla.
    p_origen_x int, -- Siempre son obligatorios para saber donde hacer click.
    p_origen_y int,
    p_destino_x int default null, -- Solo sirve cuando es arrastre o redimension. Si es click , van null.
    p_destino_y int default null,
    p_trayectoria jsonb default '[]'::jsonb, -- Puede tener trayectoria curva.
    p_duracion_ms public.ms_positivo default 800, -- Cuanto dura la animacion del gesto.
    p_volver boolean default true, -- Regresa al origine despues de ensenar.
    p_frame public.url_http default null, -- Foto del resultado.
    p_uia_clave text default null -- Clave del objeto que tocas. Ej: si arrastras imagen, uia_clave='Picture'.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_tutorial bigint; -- Id del tutorial que sacas del join.
    v_dueno bigint; -- El dueno real del tutorial.
    v_id bigint; -- Id de la fila que se creo o actualizo en tutorial_gestos.
begin
    -- Si p_trayectoria no es array JSON, error.
    if jsonb_typeof(p_trayectoria) is distinct from 'array' then
        raise exception 'trayectoria debe ser array JSON, no %', jsonb_typeof(p_trayectoria);
    end if;


    select tp.tutorial_id, t.creador_id
    into v_tutorial, v_dueno
    from public.tutorial_pasos as tp -- Tabla de pasos.
    join public.tutoriales as t --
        on t.id = tp.tutorial_id
    where tp.id = p_paso_id; -- Filtra solo el paso como parametro.

    if v_tutorial is null then
        raise exception 'paso % no existe', p_paso_id;
    end if;

    if v_dueno is distinct from p_yo then
        raise exception 'solo el creador edita el gesto';
    end if;

    -- Si, creas o actualizas.
    insert into public.tutorial_gestos(
        tutorial_id, paso_id, kind,
        origen_x, origen_y, destino_x, destino_y,
        trayectoria, duracion_ms, volver_origen,
        frame_resultado, uia_clave, updated_at
    ) values (
        v_tutorial, p_paso_id, p_kind,
        p_origen_x, p_origen_y, p_destino_x, p_destino_y,
        p_trayectoria, p_duracion_ms, p_volver,
        p_frame, p_uia_clave, now()
    )
    on conflict (paso_id) do update set
        kind = excluded.kind, -- Tipo gesto
        origen_x = excluded.origen_x, -- X inicio
        origen_y = excluded.origen_y, -- Y inicio
        destino_x = excluded.destino_x, -- X fin
        destino_y = excluded.destino_y, -- Y fin
        trayectoria = excluded.trayectoria, -- path curvo.
        duracion_ms = excluded.duracion_ms, -- tiempo anim
        volver_origen = excluded.volver_origen, -- vuelve origen.
        frame_resultado = excluded.frame_resultado, -- foto resultado.
        uia_clave = excluded.uia_clave, -- clave uia
        updated_at = now() -- fecha actual.
    returning id into v_id;

    return v_id; -- Retorna el id de la fila creada o actualizada en tutorial_gestos.
end;
$$;

-- PRUEBA 1
-- Crear el gesto inicial de un paso.
-- Objetivo: Verificar que fn_gesto_upsert() , cree correctamente un nuevo gesto , cuando
-- El paso aun no tiene animacion.
-- Estado inicial: El paso  3 existe. No existe fila en tutorial_gestos.
-- Accion: Registrar un gesto  tipo click.
-- Resultado esperado: Se crea una fila en tutorial_gestos. Kind = click. origen_x = 40.
-- origen_y = 80. puntos_count = 2.  duracion_ms = 800. volver origen = true.

select '--- PRUEBA 1: alta del gesto ---' as test;
-- Valida select tp.tutorial_id, t.creador_id
-- if v_dueno is distinct from p_yo
-- insert into public.tutorial_gestos

-- 3 = paso insertar, tabla public.tutorial_pasos.
-- tutorial_id 1 = "Create Sheet in Word". Creador:  Shiriaru.
select id
from public.tutorial_gestos
where paso_id = 3;
-- Esperado ahora: cero filas

-- 1 = Shiriaru, usuarios.id. Tiene que ser el creador.
-- 3 = paso insertar, tutorial_pasos.id.
-- click no pide destino. 40 y 80 son el pixel de origen.
-- La url tiene que empezar con http:// o https://. Insert = uia_clave del paso.
select public.fn_gesto_upsert(
    1, 3, 'click', 40, 80,
    null, null,
    '[{"x":40, "y":80},{"x":120, "y":80}]'::jsonb,
    800, true,
    'https://cdn.ejemplo.com/frames/insertar.png',
    'Insert'
);
-- Esperado: el id nuevo. Con la tabla vacia, es 1.

select id, tutorial_id, paso_id, kind, origen_x, origen_y, destino_x, destino_y,
       trayectoria, puntos_count, duracion_ms, volver_origen, frame_resultado, uia_clave
from public.tutorial_gestos
where paso_id = 3;
-- Esperado: una fila. tutorial_id 1. kind click. origen 40, 80.
-- destino null. puntos_count 2. duracion_ms 800. volver_origen true.
-- frame_resultado = https://cdn.ejemplo.com/

-- PRUEBA 2 Reemplazar un gesto existente.
-- Objetivo: Verificar que fn_gesto_upsert() , actualice un gesto del paso cuando ya existe.
-- Estado inicial: El paso posee un gesto tipo click.
-- Accion: Registrar nuevamente el paso usando un gesto tipo arrastre.
-- Resultado esperado : No se crea una segunda fila. Se conserva el mismo id.
-- kind cambia a arrastre. destino_x = 240. destino_y = 80. duracion_ms = 1200.

select '--- PRUEBA 2: actualizar el gesto ---' as test;
-- Valida on conflict (paso_id) do update set

select id, kind
from public.tutorial_gestos
where paso_id = 3;
-- esperado ahora: una fila, kind click. Anota el id.

-- 1 = Shiriaru. 3 = paso insertar.
-- arrastre exige destino_x y destino_y. 240, 80 es el pixel final.
select public.fn_gesto_upsert(
    1, 3, 'arrastre', 40, 80,
    240, 80,
    '[{"x":40,"y":80},{"x":240,"y":80}]'::jsonb,
    1200, true,
    'https://cdn.ejemplo.com/frames/insertar-resultado.png',
    'Insert'
);
-- Esperado: el mismo id de arriba.

select id, kind, destino_x, destino_y, puntos_count, duracion_ms, frame_resultado
from public.tutorial_gestos
where paso_id = 3;
-- Esperado: sigue una fila. kind arrastre. destino 240, 80.
-- puntos_count 2. duracion_ms 1200.
-- frame = https://cdn.ejemplo.com/frames/insertar-resultado.png.

-- PRUEBA 3 Impedir edicion de gestos por usuarios no propietarios.
-- Objetivo: Verificar que unicamente el creador del tutorial pueda crear o modificar gestos
-- asociados a sus pasos.
-- Estado inicial: El tutorial pertenece a Shiriaru. El paso ya tiene un gesto registrado.
-- Accion: Julio intenta modificar el gesto.
-- Resultado esperado: Se lanza la excepcion: 'Solo el creador edita el gesto'
-- No se actualiza ninguna fila. El gesto original permanece intacto.

select '--- PRUEBA 3: otro usuario no edita el gesto ---' as test;
-- Valida if v_dueno is distinct from p_yo then

select kind
from public.tutorial_gestos
where paso_id = 3;
-- Esperado ahora arrastre.

-- 2 = Julio, usuarios.id
-- 3 = paso insertar del tutorial 1. El creador es Shiriaru, no Julio.
do $$
begin
    perform public.fn_gesto_upsert(2, 3, 'click',1,1);
    raise exception 'FALLO: Julio edito el gesto';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK solo el creador: %', sqlerrm;
end
$$;
-- Esperado en Messages: OK solo el creador: solo el creador edita el gesto.

select kind, destino_x
from public.tutorial_gestos
where paso_id = 3;
-- Esperado: sigue arrastre, destino 240