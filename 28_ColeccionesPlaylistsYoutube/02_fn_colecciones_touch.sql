create or replace function public.fn_colecciones_touch()
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

drop trigger if exists trg_colecciones_touch on public.colecciones;
create trigger trg_colecciones_touch
before update on public.colecciones
for each row execute function public.fn_colecciones_touch();