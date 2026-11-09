drop function public.fn_dataset_muestras_count_sync();
create or replace function public.fn_dataset_muestras_count_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' then
        update public.dataset_entrenamiento
        set muestras_count = muestras_count + 1,
            updated_at = now()
        where id = new.dataset_id;
        return new;
    elsif tg_op = 'DELETE' then
        update public.dataset_entrenamiento
        set muestras_count = greatest(muestras_count - 1, 0),
            updated_at = now()
        where id = old.dataset_id;
        return old;
    end if;

    return coalesce(new, old);
end;
$$;

drop trigger if exists trg_dataset_muestras_count on public.dataset_muestras;
create trigger trg_dataset_muestras_count
after insert or delete on public.dataset_muestras
for each row execute function public.fn_dataset_muestras_count_sync();

-- PRUEBA 1. Eliminar una muestra y volver a incorporarla.
-- El dataset tiene 4 muestras registradas.
-- Una de las muestras proviene del tutorial con ID 1.
-- Accion: Consultar el contador incial. Eliminar la muestra cuya fuente es 'tutorial' del dataset 1.
-- Consultar nuevamente el contador. Volver a agregar el tutorial 1 mediante fn_dataset_agregar_tutorial().
-- Consultar el contador por ultima vez.
-- Resultado esperado: Contador inicial: 4. Despues del Delete: 3.
-- Despues de volver a insertar el tutorial: 4.

select muestras_count
from public.dataset_entrenamiento
where id = 1;
-- Esperado ahora: 4.

delete from public.dataset_muestras
where dataset_id = 1
    and fuente = 'tutorial';

select muestras_count
from public.dataset_entrenamiento
where id = 1;
-- Esperado: 3.

select public.fn_dataset_agregar_tutorial(1, 1);

select muestras_count
from public.dataset_entrenamiento
where id = 1;
-- Esperado: 4.
