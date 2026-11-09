-- 1. Recibir una familia de aplicaciones , 2. Revisar que aplicacion ya tiene instalada el usuario.
-- 3. Crear una lista de recomendaciones, 4. Ordenarlas , 5. Marcar cual recomienda el sistema
-- 6. Devolver la lista completa . Ejemplo :  Familia: Virtualizacion
-- Aplicaciones disponibles: 1 VMWare Player , 2 VirtualBox , 3 Hyper-V , 4  VMWare ESXi.
-- La funcion devuelve todas Pero una queda marcada como:
create or replace function public.fn_recomendar_instalacion(
    p_yo bigint, -- Id del usuario al que se le generaran las recomendaciones. Ej: Usuario 10
    p_familia text, -- Familia de apps. ej: virtualizacion, empaquetado-java, editores
    p_tutorial_id bigint default null, -- De que tutorial nacio la recomendacion. Ej: Tutorial "Crear Maquina Virtual" , Puede ser: 25 o Null si no viene de ningun tutorial.
    p_paso_ia jsonb default null -- JSON con pasos de instalacion personalizados generados por la IA. [{"orden":1, "accion":"descargar"}, {"orden":2, "accion":instalar}]
)
returns table( -- Devuelve una tabla, no un solo valor. Cada fila es una opcion de la familia con:
    aplicacion_id bigint, -- Id de la aplicacion , Ej: 1
    slug varchar, -- Identificador unico , Ej: vmware-workstation-player
    nombre varchar, -- Nombre visible , Ejemplo VMWare Player.
    tipo public.app_tipo_paquete, -- Tipo de aplicacion, Ejemplo: portable, instalada , runtime
    rango int, -- Posicion de la recomendacion, Ej: 1 , 2, 3
    motivo text,-- Texto explicando por que aprece la recomendacion , Ej: ya estas usando VMware.  u Opcion recomendada de virtualizacion
    es_sugerida boolean, -- Esta es la recomendacion ganadora , Ej: VMWare = true , VirtualBox = false , Hyper-V = false.
    pasos_overlay jsonb -- Pasos especiales generados por la IA para la aplicacion ganadora.
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_fam text := public.fn_normalizar_slug(p_familia::public.citext);
    v_ya bigint; -- Guarda aplicacion instalada mas reciente de esa familia.
begin
    -- 1. Que ya tiene instalado/detectado en esta familia
    -- Busca que aplicacion ya tiene instalada el usuario en esta familia?.
    -- Ej: Familia: virtualizacion , Aplicacion instalada : VMWare. Resultado v_ya = VMware
    select au.aplicacion_id into v_ya
    from public.aplicaciones_usuario as au
    -- Junta aplicaciones_usuario con aplicaciones_catalogo para saber la familia
    join public.aplicaciones_catalogo as c
        on c.id = au.aplicacion_id
    where au.usuario_id = p_yo
      and c.familia_slug = v_fam
      and au.estado = 'instalada'
    order by au.updated_at desc -- Si tiene varias, agarra la mas reciente. Guarda solo el ID.
    limit 1;

    -- 2. Limpia lista completa de recomendaciones
    -- Ej: Antes existian: VMWare , VirtualBox , Hyper-V , Se elimina
    -- Despues se crean nuevamente , Por que las recomendaciones pueden cambiar.
    delete from public.recomendaciones_instalacion
    where usuario_id = p_yo
        and familia_slug = v_fam;

    -- Insertar lote nuevo con ranking: instalada primero, luego peso
    insert into public.recomendaciones_instalacion( -- Inserta una fila por cada app activa de esa familia.
        usuario_id, familia_slug, aplicacion_id, tutorial_id, rango, motivo, es_sugerida, pasos_overlay
    )
    select
        p_yo,
        v_fam,
        c.id,
        p_tutorial_id,
        -- row_number() -> Numera filas 1,2,3 segun el ORDER BY que le des.
        -- over -> Numera las filas usando este orden.
        row_number() over (
                order by -- Orden a utilizar
                    -- Reglas 1 Primero pone la que tiene instalada
                    (c.id = v_ya) desc,
                    -- Regla 2 Si ninguna esta instalada. Entonces gana el menor peso.
                    c.peso_recomendacion asc,
                    c.id -- Si empatan. Ordena por id.
            )::int, -- Ese numero es el rango.
        case -- Ese CASE construye el texto del campo. Puede cambiarse Incluso podrias tener : motivos_json en otra tabla y construir los mensajes dinamicamete.
            when c.id = v_ya then -- Si , entonces.
                format('Esta es la que debes de elegir, porque ya estas usando %s para tu proyecto.', c.nombre)
            when c.slug = 'vmware-esxi' then
                'Solo aplica si tuvieras un servidor ESXi (infraestructura empresarial).'
            when c.slug = 'virtualbox' then
                'Si usaras VirtualBox en lugar de VMware'
            when c.slug = 'hyper-v' then
                'Si usaras la virtualizacion nativa de Windows.'
            else
                format('Opcion de %s. Peso %s.', c.familia_slug, c.peso_recomendacion)
        end,
        -- Marca como ganadora si: Devuelve True o False
        -- Caso 1 (c.id = v_ya) Usuario ya tiene VMware , VMWare = TRUE , VirtualBox = FALSE , Hyper-V = FALSE
        -- Caso 2 No tiene nada instalado : v_ya is null and , Entonces gana: min(c2.peso_recomendacion)
        (c.id is not distinct from v_ya) or (v_ya is null and c.peso_recomendacion = ( -- Resultado 10
                        select min(c2.peso_recomendacion) -- Busca el peso mas pequeno. Ej: VMWare = 10 , VirtualBox = 40 , Hyper-V = 80
                        from public.aplicaciones_catalogo as c2
                        where c2.familia_slug = v_fam and c2.activa
                    )),
        case -- Llena pasos overlay when p_paso_ia is not null
            -- Si la IA envio pasos especiales y esta aplicacion fue la ganadora entonces guardalos.
            when p_paso_ia is not null and (
                (c.id = v_ya) or (v_ya is null and c.peso_recomendacion = (
                    select min(c2.peso_recomendacion)
                    from public.aplicaciones_catalogo as c2
                    where c2.familia_slug = v_fam and c2.activa
                ))
            ) then p_paso_ia
            else null
        end
    from public.aplicaciones_catalogo as c
    where c.familia_slug = v_fam and c.activa;

    -- Devuelve lo que acabas de guardar, ordenado por rango. Si, devuelve todas las apps de esa
    -- familia, no solo una.
    return query
    select r.aplicacion_id, c.slug, c.nombre, c.tipo,
        r.rango, r.motivo, r.es_sugerida, r.pasos_overlay
    from public.recomendaciones_instalacion as r
    join public.aplicaciones_catalogo as c on c.id = r.aplicacion_id
    where r.usuario_id = p_yo and r.familia_slug = v_fam
    order by r.rango;
end;
$$;

-- PRUEBA 1 Sin nada instalado
-- Objetivo: Verificar que cuando el usuario no tiene nada instalado de la familia virtualizacion
-- gane la de menor peso y solo esa reciba el guion de la IA.
-- aplicaciones_usuario = vacio para esa famila , Por eso v_ya = null
-- Accion: LLamar fn_recomendar_instalacion(1, 'Virtualizacion', 4, JSON)
-- Resultado esperado: 4 filas:
-- rango 1: vmware_player, es_sugerida = true, tiene_overlay = true , motivo = Opcion de virtualizacion. Peso 10.

select '--- PRUEBA 1: radios en frio ---' as test;

select id
from public.recomendaciones_instalacion
where usuario_id = 1
  and familia_slug = 'virtualizacion';
-- Esperado ahora: cero filas.

-- 1 = Shiriaru, usuarios.id , familia 'Virtualizacion' se normaliza a virtualizacion
-- 4 = "Create Video Game in Unreal Engine", tutoriales.id. Creador: Julio
-- p_paso_ia = [{"orden":1,"etiqueta":"Launch4j"}] Es el guion de esta sesion, no el wizard del catalogo.
select rango, slug, nombre, es_sugerida, motivo, pasos_overlay is not null as tiene_overlay
from public.fn_recomendar_instalacion(
    1, 'Virtualizacion', 4,
     '[{"orden":1,"etiqueta":"Launch4j"}]'::jsonb
)
order by rango;

-- Esperado: cuatro filas.
-- Esperado: cuatro filas.
-- rango 1, vmware-player, es_sugerida true, tiene_overlay true.
--   motivo = Opcion de virtualizacion. Peso 10.
-- rango 2, virtualbox, es_sugerida false, tiene_overlay false.
--   motivo = Si usaras VirtualBox en lugar de VMware
-- rango 3, hyper-v, es_sugerida false.
--   motivo = Si usaras la virtualizacion nativa de Windows.
-- rango 4, vmware-esxi, es_sugerida false.
--   motivo = Solo aplica si tuvieras un servidor ESXi (infraestructura empresarial).

-- PRUEBA 2 Recomendacion cuando el usuario YA tiene VMware Player instalado.
-- Objetivo: Verificar que si el usuario ya tiene una app de la familia instalada, esa app siga siendo la sugerida aun que hayan otras con peso menor
-- y el motivo cambie a personalizado.
-- Estado inicial: usuario_id = 1 , aplicacion_id = VMware Player, estado = instalada
-- Por lo tanto v_ya = id de VMware Player.
-- Accion: Llamar fn_recomendar_instalacion(2, 'Virtualizacion', 4, JSON)
-- Resultado esperado: 4 filas, igual que antes pero con motivo distinto.

select '--- PRUEBA 2: ya estas usando Player ---' as test; -- Corre despues de 13_fn_marcar_detectada.sql

select rango, slug, es_sugerida, motivo, pasos_overlay is not null as tiene_overlay
from public.fn_recomendar_instalacion(
    1, 'Virtualizacion', 4,
     '[{"orden":1,"etiqueta":"Launch4j"}]'::jsonb
)
order by rango;
