drop function  if exists fn_tags_before_insert_update();
-- TRIGGER 1 ESTE TRIGGER SE DISPARA ANTES DE GUARDAR UN TAG , ES PARA AUTO-CORREGIR DATOS , FUNCION TIPO TRIGGER
create or replace function public.fn_tags_before_insert_update()
-- DEVUELVE EL REGISTRO MODIFICADO , DEVUELVE LA FILA YA CORREGIDA.
returns trigger
set search_path = ''
as $$
begin
-- tg_op VARIABLE DE Postgres INDICA QUE PASO 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'
-- tg_op QUE OPERACION DISPARO EL TRIGGER.

-- new FILA NUEVA QUE SE VA A GUARDAR , new.nombre = LO QUE EL USUARIO ESCRIBIO eje: Blueprints. new.slug
-- old FILA VIEJA SOLO EXISTE EN UPDATE.
-- is distinct from ES DISTINTO , QUE.
    if tg_op = 'insert' or new.nombre is distinct from old.nombre then
-- LLAMAMOS A LA FUNCION IMMUTABLE
-- new.nombre::citext -> :: es casteo CONVIERTE new.nombre a tipo citext
        new.slug := public.fn_normalizar_slug(new.nombre::public.citext);

-- GUARD SI EL SLUG QUEDA VACIO DESPUES DE LIMPIAR
        if new.slug is null then
-- raise LANZA ERROR Y CANCELA EL GUARDADO , exception ERROR QUE VE EL SUAURIO EN TU AI DESKTOP APP.
-- "%" SE REMPLAZA POR  new.nombre
            raise exception 'El tag "%" no genera un slug valido' , new.nombre
-- errcode = '23514' ES EL CODIGO QUE USA POSTGRES CUANDO FALLA UN check
                using errcode = '23514';
        end if;
    end if;

-- GUARDA FECHA CON ZONA HORARIA.
    new.actualizado_at := now();

-- ENTRENABLE Y PROMOVIDO
    if new.estado = 'activo' then
        -- SI SUPERA 5000 USOS, YA ES ENTRENABLE PARA TU IA
        if new.usos_count >= 5000 then
            new.es_entrenable := true;
        else
            new.es_entrenable := false;
        end if;

        if tg_op = 'insert' or old.estado is distinct from 'activo' then
            new.promovido_at := now();
        end if;
    end if;

-- OBLIGATORIO en BEFORE: DEVUELVE EL REGISTRO YA CORREGIDO PARA QUE SE GUARDE
-- DEVUELVE LAS FILAS YA CORREGIDAS CON slug LIMPIO , actualizado_at nuevo, es_entrenable calculado.
    return new;
end; $$ language plpgsql;

-- 02 EL TRIGGER EN SI DONDE SE ENGANCHA A LA TABLA
drop trigger if exists trg_tags_biu on public.tags;

create trigger trg_tags_biu
-- EL TRIGGER SOLO SE DISPARA SI CAMBIAN ESTA COLUMNAS , SI SOLO SE ACTUALIZA actualizado_at NO SE DISPARA Y AHORAS CPU
    before insert or update of nombre , estado, usos_count on public.tags
-- POR CADA FILA
    for each row
    execute function public.fn_tags_before_insert_update();