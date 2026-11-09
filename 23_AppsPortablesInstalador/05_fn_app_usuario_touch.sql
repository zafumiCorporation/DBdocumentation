-- Trigger touch - updated_at
-- Cuando se actualiza una fila de aplicaciones_usuario el trigger ejecuta new.updated_at := now();
-- Eso significa , Alguien modifico algo , Actualizar fecha y hora automaticamente.
create or replace function public.fn_app_usuario_touch()
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

drop trigger if exists trg_app_user_touch on public.aplicaciones_usuario;
create trigger trg_app_user_touch
before update on public.aplicaciones_usuario
for each row execute function public.fn_app_usuario_touch();

-- PRUEBA 1 Actualizacion automatica de updated_at.
-- Objetivo: verificar que el trigger fn_app_usuario_touch(), actualice automaticamente la fecha de modificacion
-- cuando una fila cambia.
-- Estado inicial: Existe una fila para Notepad++ Portable, updated_at contiene una fecha previa.
-- error_texto es Null.
-- Accion: Actualizar unicamente la columna error_texto
-- Resultado esperado: error_texto cambia a 'toque'. updated_at se actualiza automaticamente.
-- updated_at contiene una fecha posteriro a la anterior.

select '--- PRUEBA 1: tocar updated_at ---' as test;

-- Antes. Fila de Notepad de Shiriaru , 1 = Shiriaru, usuarios.id.
select updated_at, error_texto
from public.aplicaciones_usuario
where usuario_id = 1
  and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable');
-- Esperado ahora: error_texto null. anota updated_at.

update public.aplicaciones_usuario
set error_texto = 'toque'
where usuario_id = 1
    and aplicacion_id = (select id from public.aplicaciones_catalogo where slug = 'notepadpp-portable');

-- Linea 33
-- Esperado: error_texto = toque. updated_at es posterior al que anotaste.

