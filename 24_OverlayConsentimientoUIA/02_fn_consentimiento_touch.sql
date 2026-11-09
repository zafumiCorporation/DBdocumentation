-- Cada vez que alguien haga un UPDATE en consentimiento_uia, antes de guardar, ejecuta fn_consentimiento_touch().
create or replace function public.fn_consentimiento_touch()
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

drop trigger if exists trg_consentimiento_touch on public.consentimiento_uia;
create trigger trg_consentimiento_touch
before update on public.consentimiento_uia
for each row execute function public.fn_consentimiento_touch();

-- PRUEBA 1 Actualizacion automatica de updated_at mediante trigger. en consetimiento_uia
-- Objetivo: Verificar que cualquier UPDATE realizado sobre consentimiento_uia
-- actualice automaticamente el campo updated_at.
-- Estado inicial: Existe un consentimiento overlay_neon. politica_version = 2.
-- updated_at contiene una fecha previa.
-- Accion: Ejecutar un UPDATE que no modifica ningun dato funcional de la fila.
-- Resultado esperado: politica_version permanece en 2. El trigger trg_consentimiento_touch
-- Se ejecuta automaticamente. updated recibe una nueva fecha. La nueva fecha es posterior a la anterior.

select '--- PRUEBA 1: tocar updated_at ---' as test;

-- 1 = Shiriaru, usuarios.id. alcance overlay_neon.
select updated_at, politica_version
from public.consentimiento_uia
where usuario_id = 1
    and alcance = 'overlay_neon';
-- Esperado ahora: politica_version 2. Anota updated_at = 2026-10-30 13:00:52.523408 +00:00.

update public.consentimiento_uia
set politica_version = politica_version
where usuario_id = 1
    and alcance = 'overlay_neon';
-- Esperado: politica_version sigue 2. updated_at es posterior al que anotaste 2026-10-30 14:40:13.342112 +00:00

