create or replace function public.fn_dataset_touch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists trg_dataset_touch on public.dataset_entrenamiento;
create trigger trg_dataset_touch
before update on public.dataset_entrenamiento
for each row execute function public.fn_dataset_touch();