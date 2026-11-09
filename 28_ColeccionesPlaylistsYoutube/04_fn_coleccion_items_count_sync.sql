-- fn_coleccion_items_count_sync : Mantiene sincronizado colecciones.items_count
-- Cada vez que agregas un tutorial: items_count + 1
create or replace function public.fn_coleccion_items_count_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Se agrega un tutorial a la coleccion.
    if tg_op = 'INSERT' then
        update public.colecciones
        set items_count = colecciones.items_count + 1,
            updated_at = now()
        where id = new.coleccion_id;
        return new;
    -- Se elimina un tutorial de la coleccion.
    elsif tg_op = 'DELETE' then
        update public.colecciones
        set items_count = greatest(colecciones.items_count -1 , 0),
            updated_at = now()
        where id = old.coleccion_id;
        return old;
    end if;

    return coalesce(new, old);
end;
$$;

drop trigger if exists trg_coleccion_items_count on public.coleccion_items;
create trigger trg_coleccion_items_count
after insert or delete on public.coleccion_items
for each row execute function public.fn_coleccion_items_count_sync();

-- PRUEBA 1: Sincronizar el contador al eliminar el ultimo tutorial.
-- La coleccion contiene un tutorial. items_count = 1.
-- tutorial_id = 4 corresponde a Unreal.
-- Accion: Eliminar tutorial_id = 4 utilizando fn_coleccion_quitar_item().
-- Resultado esperado: Se elimina el ultimo tutorial de la coleccion.
-- El trigger trg_coleccion_items_count se ejecuta automaticamente.
-- TG_OP identifica la operacion como DELETE. items_count disminuye de 1 a 0.
-- la funcion fn_coleccion_quitar_item() devuelve 0.

select items_count
from public.colecciones
where dueno_id = 2
    and tipo = 'ver_luego';
-- Esperado ahora: 1.

-- 2 = Julio. El subquery es su Ver Luego. 4 = Unreal.
select public.fn_coleccion_quitar_item(
    2,
    (select id from public.colecciones where dueno_id = 2 and tipo = 'ver_luego'),
    4
);
-- Esperado: 0

select  items_count
from public.colecciones
where dueno_id = 2
    and tipo = 'ver_luego';
-- Esperado: 0.

select count(*) as items
from public.coleccion_items ci
join public.colecciones c on c.id = ci.coleccion_id
where c.dueno_id = 2
    and c.tipo = 'ver_luego';
-- Esperado: 0.

