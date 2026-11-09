-- TRIGGER 2: EL CORAZON DEL SISTEMA TikTok , HACE QUE UN TAG PASE DE pendiente a activo
-- ACTUALIZA CONTADOR DE FORMA CONCURRENTE Y SEGURA
-- CADA VEZ QUE INSERTAS UN REGISTRO EN tutorial_tags ESTE TRIGGES SE EJECUTA
drop function public.fn_tutorial_tags_after_change();
create or replace function public.fn_tutorial_tags_after_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
-- VARIABLE CONSTANTE LE ASIGNAS 100 ,SI UN TAG LLEGA A 100 usos tutorial_tags PASA A activo
    v_umbral_activo constant int := 100;
-- VARIABLE CONSTANTE SI LLEGA A 5000 usos, es_entrenable = true
    v_umbral_ia     constant int := 500;
    v_filas_afectadas int;
begin
    if tg_op = 'insert' then
-- PON UN CADADO SOBRE LA TABLA tags PERO ESPECIFICAMENTE SOBRE ESTE TAG EN PARTICULAR tag_id
-- pg_advisory_xact_lock CANDADO , EVITA QUE DOS PROCESOS AL MISMO TIEMPO INTENTEN MODIFICAR EL MISMO RECURSO(campo , columna)
-- public.tags SIGNIFICA LA TBLA tags QUE ESTA EN EL schema public.
-- ::regclass convierte ese nombre  EN UN PUNTERO INTERNO QUE REPRESENTA LA REFERENCIA A LA TABLA
        perform pg_advisory_xact_lock('public.tags'::regclass::oid::int, new.tag_id);

        update  public.tags
        set usos_count = usos_count + 1,
-- SI EL estado ACTUAL ES pendiente Y usos_count (CON EL NUEVO USO) LLEGA AL UMBRA (100) CAMBIA A 'activo' , SI NO DEJA EL ESTADO COMO ESTA.
            estado = case when estado = 'pendiente' and usos_count + 1 >= v_umbral_activo then 'activo' else estado end,
            promovido_at = case when estado = 'pendiente' and usos_count + 1 >= v_umbral_activo then now() else promovido_at end,
            es_entrenable = case when usos_count +1 > v_umbral_ia then true else es_entrenable end
        where id = new.tag_id;

--  get diagnostics PERMITE LEER INFORMACION ESPECIAL , DESPUES DE EJECUTAR UNA SENTENCIA
--  row_count TE DICE CUANTAS FILAS FUERON AFECTADAS POR LA ULTIMA SENTENCIA SQL (UPDATE, INSERT, DELETE)
        get diagnostics v_filas_afectadas =  row_count;

-- new NUEVE FILA QUE SE ESTA INSERTANDO O ACTUALIZANDO.
        return  new;

    elsif tg_op = 'delete' then
        -- NO downgrade: UNA VEZ ACTIVO, SIEMPRE ACTIVO
        update public.tags
-- greatest() DEVUELVE EL VALOR MAS GRANDE.
        set usos_count = greatest(usos_count - 1, 0)
        where id = old.tag_id;
-- return old TABLA ELIMINADA
        return old;

-- Tag Platform (id=1) tiene usos_count = 100
-- Tag Blueprints (id=1) tiene usos_count = 50
-- Un tutorial cambia de Platform a Blueprints
-- Platform -> 100 -1 = 99  , Blueprints -> 50 + 1 = 51
    elsif tg_op = 'update' then
        if new.tag_id is distinct from old.tag_id then
            update public.tags set usos_count =  greatest(usos_count -1, 0) where id = old.tag_id;
            update public.tags set usos_count = usos_count + 1 where id = new.tag_id;
        end if;
        return new;
    end if;

    return null;
end;
$$;


-- EL TRIGGER
drop trigger if exists trg_tutorial_tags_usos on public.tutorial_tags;
create trigger trg_tutorial_tags_usos
after insert or delete or update of tag_id on public.tutorial_tags
for each row execute function public.fn_tutorial_tags_after_change();