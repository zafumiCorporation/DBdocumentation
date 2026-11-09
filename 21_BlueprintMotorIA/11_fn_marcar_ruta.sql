-- El usuario eseña a la IA (apaga un cable, enciende otro) + genera muestra SFT.
create or replace function public.fn_marcar_ruta(
    p_yo bigint, -- Id del usuario que esta corrigiendo la ruta que genero la IA.
    p_tutorial_id bigint, -- Id del tutorial que pertenece esa ruta.
    p_ruta_orden int, -- El numero de ruta que se quiere corregir
    p_secuencia_ok text[] -- Es la secuencia correcta de nodos o botones.
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_id bigint; --
    v_ruta_ia_arr text[]; -- Ruta IA en formato arreglo.
    v_ruta_ia text; -- Ruta vieja generada por la IA
    v_uia_ia text; -- Ultimo nodo elegido por la IA. ultimo nodo al que llego la IA.
begin
    -- Obtiene la ruta vieja de la IA en formato arreglo , Resultado: {Insertar, Formas, Rectangulo}
    select array (
        select jsonb_array_elements_text(elem -> 'secuencia')
    )
    into v_ruta_ia_arr
    from public.tutorial_lienzo l
    cross join lateral jsonb_array_elements(l.rutas) e(elem)
    where l.tutorial_id = p_tutorial_id
      and (elem->>'orden')::int = p_ruta_orden;

    -- Valida ciclo antes de marcar , Aqui se valida la secuencia corregida por el usuario.
    if public.fn_hay_ciclo_secuencia(p_secuencia_ok, false) then
        raise exception 'secuencia corregida tiene ciclo interno';
    end if;

    -- 2. Reescribe ruta en borrador RAM: apaga cable viejo, enciende nuevo
    update public.lienzo_borrador_ram
    set rutas = (
        select jsonb_agg( -- Toma todas la rutas y las vuelve a unir en un solo arreglo JSON.
            -- Esta es la ruta que quiero modificar
            case when (elem->>'orden')::int = p_ruta_orden
               -- Si es la ruta correcta la modifica. reemplaza la secuencia.
               then elem || jsonb_build_object('secuencia', to_jsonb(p_secuencia_ok))
               -- Si no la deja exactamente igual.
               else elem
            end
        )
        from jsonb_array_elements(rutas) e(elem)
    ),
    saved_at = now() -- Guarda la fecha de modificacion
    where tutorial_id = p_tutorial_id
    and editor_id = p_yo;

    -- El update encotnro una fila. Si no encontro ninguna fila found = false.
    if not found then
        raise exception 'lienzo borrador no existe - edita primero';
    end if;

    -- Resutlado : Insertar -> Formas -> Rectangulo
    v_ruta_ia :=
        array_to_string(
            v_ruta_ia_arr,
            ' -> '
        );

    -- Obtener ultima eleccion incorrecta de la IA  , Ultimo nodo de la ruta. ejemplo rectangulo.
    if coalesce(array_length(v_ruta_ia_arr, 1), 0) = 0 then
        raise exception 'ruta ia vacia';
    end if;

    -- Guardar correccion para entrenamiento
    insert into public.ia_correciones_ruta(
        tutorial_id, usuario_id, ruta_orden, clave_origen, uia_ia, uia_usuario, ruta_ia, ruta_usuario
    )
    values (
        p_tutorial_id, p_yo, p_ruta_orden, p_secuencia_ok[1],
            v_uia_ia, p_secuencia_ok[array_length(p_secuencia_ok, 1)], v_ruta_ia,
            array_to_string(p_secuencia_ok, ' -> ')
    )
    returning id into v_id;


    -- Notificar worker IA en tiempo real
    perform pg_notify(
        'ia_correccion', -- canal.
        jsonb_build_object('tutorial_id', p_tutorial_id, 'correccion_id', v_id, 'ruta_orden', p_ruta_orden)::text
    );

    return v_id;
end;
$$;

-- PRUEBA 1 Corregir una ruta generada por la IA
-- Objetivo: Verificar que fn_marcar_ruta() permita reemplazar , la secuencia propuesta por la IA
-- utilizando una secuencia corregida por el usuario.
-- Estado inicial: Existe una ruta publicada. La ruta fue utilizada como sugerencia de la IA.
-- El borrador contiene la misma secuencia. No existe correcciones almacenadas.
-- Accion: Shiriaru corrige la secuencia de la ruta.
-- Ruta original: insertar -> pagina-en-blanco , Ruta corregida: pagina-en-blanco -> insertar
-- Resultado esperado: La ruta del borrador se actualiza. La ruta publicada permanece intacta
-- Se registra una correccion en ia_correcciones_ruta , Se genera una notificacion para el worker de IA
-- Nota: Esta operacion no modifica nodos individuales, Lo que se corrige es el recorrido entre nodos
-- La correccion queda almacenada para futuros procesos de aprendizaje del modelo.
select '--- PRUEBA 1: CORREGIR RUTA ---' as test;

-- Antes. Lo que quedo publicado al compilar. De aquie lee la funciona la ruta de la IA
-- 1 = "Create Sheet in Word", tutoriales.id.
select elem->>'orden' as orden, elem->'secuencia' as secuencia
from public.tutorial_lienzo as l
cross join lateral jsonb_array_elements(l.rutas) as elem
where l.tutorial_id = 1;
-- Esperado ahora: orden 1, Secuencia ["insertar", "pagina-en-blanco"].

-- Antes. El borrador tiene la misma secuencia
select elem->'secuencia' as secuencia
from public.lienzo_borrador_ram as r
cross join lateral  jsonb_array_elements(r.rutas) as elem
where r.tutorial_id = 1
    and r.editor_id = 1;
-- Esperado ahora: ["insertar","pagina-en-blanco"].

-- 1 = Shiriaru, usuarios.id. Tiene que ser el editor del borrador.
-- 1 = "Create Sheet in Word", tutoriales.id.
-- 1 = orden de la ruta, el campo orden dentro del JSON de rutas.
-- La secuencia nueva usa las claves ya normalizadas. El primer nodo pasa al final.
select public.fn_marcar_ruta(1,1,1, array['pagina-en-blanco', 'insertar']);
-- Esperado: el id nuevo de ia_correciones_ruta. con la tabla vacia, es 1.
-- pg_notify no sale en un SELECT

-- Despues el borrador RAM ya tiene el cable nuevo
select elem->>'orden' as orden, elem->'secuencia' as secuencia
from public.lienzo_borrador_ram as r
cross join lateral jsonb_array_elements(r.rutas) as elem
where r.tutorial_id = 1;
-- Esperado: orden 1, secuencia ["pagina-en-blanco", "insertar"].

-- El publicado no se toca. Sigue siendo la ruta que vio la IA.
select elem->'secuencia' as secuencia_publicada
from public.tutorial_lienzo as l
cross join lateral jsonb_array_elements(l.rutas) as elem
where l.tutorial_id = 1;
-- Esperado: ["insertar","pagina-en-blanco"].

select id, tutorial_id, usuario_id, ruta_orden, clave_origen, uia_ia, uia_usuario, ruta_ia, ruta_usuario, aplicado_a_modelo
from public.ia_correciones_ruta
where tutorial_id = 1;
-- Esperado: una fila. usuario_id 1 Shiriaru. ruta_orden 1.
-- usuario_id 1 Shiriaru. ruta_orden 1.
-- clave_origen = pagina-en-blanco. Es el primer elementos de la secuencia nueva.
-- uia_usuario = insertar -> pagina-en-blanco.
-- ruta_usuario = pagina-en-blanco.
-- ruta_usuario = pagina-en_blanco -> insertar.
-- aplicado_a_modelo false.
-- uia_ia null, porque v_uia_ia no se asigna en la funcion.

