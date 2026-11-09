-- fn_overlay_iniciar -> Es el boton play , Crea la fila en overlay_sesion_ram que dice "Shiriaru esta viendo esto ahora".
-- Registra modo tutorial o modo instalador + en que paso empieza.
-- Funcionamiento: Comprueba que se seleccione un unico objetivo: tutorial o instalador.
-- Verifica los consentimientos(permisos) necesarios segun el modo.
-- Si existe un paso busca su gesto asociado. Si el paso tiene un gesto, compueba el permiso.
-- Registra la sesion temporal en overlay_sesion_ram.
-- Si el usuario ya tiene una sesion, actualiza la existente.
create or replace function public.fn_overlay_iniciar(
    p_yo bigint, -- Id del usuario que da play.
    p_tutorial_id bigint default null, -- Que tutorial va a ver. Puede ser null si es modo instalador.
    p_aplicacion_id bigint default null, -- Id de la app sobre la que pinta si es modo instalador.
    p_ejecucion_id bigint default null, -- Id de la ejecucion cada vez que da play es una ejecucion nueva.
    p_paso_id bigint default null -- En que paso empieza.
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_gesto bigint; -- Guarda el id del gesto que pertenece a es p_paso_id Lo busca en tutorial_gesto
begin

    -- Solo uno puede tener valor. Si ambos tienen valor o ninguno lanza error.
    if num_nonnulls(p_tutorial_id, p_aplicacion_id) <> 1 then
        raise exception 'overlay es tutorial o instalador, no ambos';
    end if;

    -- Modo instalador wizard.
    if p_aplicacion_id is not null then
        -- Si devuelve false -> no tiene permiso -> lanza raise exception.
        if not public.fn_consentimiento_vigente(p_yo , 'instalador_wizard') then
            raise exception 'concede instalador_wizard antes del overlay';
        end if;
    else
    -- Modo tutorial
        -- Si devuelve false -> no tiene permiso -> lanza raise exception
        if not public.fn_consentimiento_vigente(p_yo, 'overlay_neon') then
            raise exception 'concede overlay_neon antes de pintar';
        end if;
        -- Si devuelve false -> no tiene permiso -> lanza raise exception
        if not public.fn_consentimiento_vigente(p_yo, 'ejecucion_tutorial') then
            raise exception 'concede ejecucion_tutorial antes de play';
        end if;
    end if;

    -- p_paso_id no es null , Osea existe un paso.
    if p_paso_id is not null then
        select g.id into v_gesto  -- Guarda en v_gesto el id del gesto.
        from public.tutorial_gestos as g -- De mi tabla tutorial_gestos.
        where g.paso_id = p_paso_id; -- Segun el id del paso.

        -- Si hay gesto
        if v_gesto is not null
            -- Si devuelve false -> no tiene permiso -> lanza raise exception
            and not public.fn_consentimiento_vigente(p_yo, 'cursor_fantasma') then
            raise exception 'concede cursor_fantasma para verl ghost';
        end if;
    end if;

    -- Insert Ram tabla temporal que dice "que boton debo pintar ahora".
    -- Pinta con el neon el paso_id y su gesto_id.
    insert into public.overlay_sesion_ram(
        usuario_id, tutorial_id, aplicacion_id,
        ejecucion_id, paso_id, gesto_id, started_at, last_seen_at
    ) values (
        p_yo, p_tutorial_id, p_aplicacion_id,
        p_ejecucion_id, p_paso_id, v_gesto, now(), now()
    )
    -- Si shiriarua ya tenia una sesion viva viendo el tutorial 1 y paso 2, y ahora quiere ver
    -- tutorial 1 paso 3, no creas 2 filas. Actualizas la existente con los nuevos datos y reseteas.
    on conflict (usuario_id) do update set
        tutorial_id = excluded.tutorial_id,
        aplicacion_id = excluded.aplicacion_id,
        ejecucion_id = excluded.ejecucion_id,
        paso_id = excluded.paso_id,
        gesto_id = excluded.gesto_id,
        started_at = now(),
        last_seen_at = now();

    return true; -- Retorna true para decir "Play iniciado con exito, ya puedes pintar "
end;
$$;

-- PRUEBA 1 Impedir que un usuario sin consentimiento inicie el overlay.
-- Objetivo: Verificar que fn_overlay_iniciar() rechace el inico de un tutorial cuando el usuario
-- no tiene concedido el permiso del overlay..
-- Estado inicial: Julio existe en public.usuario. Su id es 2.
-- El tutorial 1 corresponde a "Create Sheet in Word". Julio no tiene concedio overlay_neon.
-- No existe una sesion previa para Julio.
-- Accion: Julio intenta iniciar el tutorial 1 sin haber aceptado el consentimiento necesario.
-- Resultado: Se lanza la excepcion: 'concede overlay_neon antes de pintar'.
-- No se ejecuta el INSERT INTO. No se crea una sesion para Julio. La consulta final devuelve cero filas.

select '--- PRUEBA 1: sin grant no hay overlay ---' as test;

-- 2 = Julio, usuarios.id.
-- 1 = "Create Sheet in Word", tutoriales.id.
-- Los tres null = sin instalador, sin ejecucion y sin paso.
do $$
begin
    perform public.fn_overlay_iniciar(2,1,null,null,null);
    raise exception 'FALLO: Julio pinto sin grant';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK sin grant: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK sin grant: concede overlay_neon antes de pintar.

select usuario_id
from public.overlay_sesion_ram
where usuario_id = 2;
-- Esperado: cero filas.

-- PRUEBA 2  Impedir que una sesion tenga tutorial e instalador simultaneamente.
-- Objetivo: Verificar que fn_overlay_iniciar() rechace una solicitud cuando se proporcionan
-- simultaneamente tutorial_id y aplicacion_id.
-- Estado inicial: Shiriaru existe en public.usuarios. Su id es 1
-- El tutorial 1 corresponde a "Create Sheet in Word" La aplicacion 1 corresponde a VMware Player.
-- Accion: Intentar iniciar una sesion proporcionando al mismo tiempo un tutorial y una aplicacion.
-- Resultado esperado: Se lanza la excepcion: 'overlay es tutorial o instalador, no ambos'.
-- La funcion rechaza la solicitud antes de comprobar los consentimientos.
-- No se cera ni modifica ninguna sesion.
select '--- PRUEBA 2: un solo objetivo ---' as test;

-- 1 = Shiriaru. tutorial 1 y aplicacion 1 a la vez.
-- 1 de aplicacion = vmware-player, aplicaciones_catalogo.id.
do $$
begin
    perform public.fn_overlay_iniciar(1,1,1,null,null);
    raise exception 'FALLO: acepto tutorial e instalador juntos';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'Ok un objetivo: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK un objetivo: overlay es tutorial o instalador, no ambos.

-- PRUEBA 3 Iniciar una sesion del overlay en un paso de un tutorial.
-- ObjetivoL Verificar que fn_overlay_iniciar() registre correctamente una sesion de tutorial
-- y recupere el gesto asociado al paso seleccionado.
-- Estado inicial: Shiriaru existe en public.usuarios. Su id es 1.
-- Tiene concedido cursor_fantasma.
-- El tutorial 1 corresponde a "Create Sheet in Word".
-- El paso 3 corresponde a Insertar. El paso 3 tiene un gesto registrado en tutorial_gestos.
-- Shiriaru no tiene una sesion previa en overlay_sesion_ram.
-- Accion: Shiriaru inicia el tutorial 1 directamente en el paso 3, sin seleccionar un instalador
-- ni proporcionar una ejecucion.

-- Resultado esperado: La funcion devuelve true.
-- Se crea una fila en overlay_sesion_ram. usuario_id = 1. tutorial_id  1. aplicacion_id = null.
-- paso_id = 3. gesto_id contiene el identificador del gesto asociado al paso 3.

select '--- PRUEBA 3: iniciar overlay del tutorial ---' as test;

select usuario_id
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado ahora: cero filas.

-- 1 = Shiriaru, usuarios.id.
-- 1 = "Create Sheet in Word", tutoriales.id.
-- null = no es instalador. null = sin ejecucion_id.
-- 3 = paso insertar, tutorial_pasos.id Su gesto es el arrastre.
select public.fn_overlay_iniciar(1,1,null,null,3);
-- Esperado: true.

select usuario_id, tutorial_id, aplicacion_id, paso_id, gesto_id
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado: una fila. tutorial_id 1. aplicacion_id null. paso_id 3.
-- gesto_id = el id del gesto de ese paso.

-- PRUEBA 4 Cambiar una sesion existente del tutorial al instalador.
-- Objetivo: Verificar que fn_overlay_iniciar() actualice una sesion existente cuando el usuario
-- cambia del modo tutorial al modo instalador.
-- Estado inicial: Shiriaru ya tiene una sesion en overlay_sesion_ram. La sesion pertenece al
-- tutorial 1. aplicacion_id = null. La sesion fue creada en la PRUEBA 3. Shiriaru tiene
-- concedido instalador_wizard. VMware Player existe en aplicaciones_catalogo  y puede localizarse
-- mendiante su slug.
-- Accion: Shiriaru inicia el instalador de VMware Player utilizando la misma sesion que anteriormente estaba asociada al tutorial.
-- Resultado esperado: La funcion devuelve true. No se crea una segunda fila. Se conserva una unica
-- sesion para Shiriaru. tutorial_id pasa a null. aplicacion_id recibe el id de VMware Player.
-- paso_id pasa a null. gesto_id pasa a null. ejecucion_id permanece null. started_at y last_at se actualizan.

select '--- PRUEBA 4: la sesion cambia a Player ---' as test;
select tutorial_id, aplicacion_id
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado ahora: tutorial_id 1, aplicacion_id null.

-- 1 = Shiriaru
-- null = ya no es tutorial.
-- El subquery es vmware-player, aplicaciones_catalogo.id.
-- Sin ejecucion y sin paso. El instalador pide instalador_wizard, que ya esta concedido.
select public.fn_overlay_iniciar(
    1, null,
    (select id from public.aplicaciones_catalogo where slug = 'vmware-player'),
    null, null
);
-- Esperado: true.

select usuario_id, tutorial_id, aplicacion_id, paso_id, gesto_id
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado: sigue una fila. tutorial_id null.
-- aplciacion_id = el id de vmware-player. paso_id null. gesto_id null.





