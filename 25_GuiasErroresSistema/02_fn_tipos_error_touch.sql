-- fn_tipos_error_tocuh actualiza el campo updated_at de mi tabla tipos_error.
create or replace function public.fn_tipos_error_touch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    new.updated_at := now();
    return new; -- Retorna la fila completa.
end;
$$;

drop trigger if exists trg_tipos_error_touch on public.tipos_error;
create trigger trg_tipos_error_touch
before update on public.tipos_error
for each row
execute function public.fn_tipos_error_touch();