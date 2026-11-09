-- Intenta validar que no existan dos pasos que tengan la misma uia_clave.
create or replace function public.fn_wizard_uia_unicas()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if exists(
        select 1
        from jsonb_array_elements(new.pasos_wizard) as e(elem)
        group by elem->>'uia_clave'
        having count(*) > 1
    ) then
        raise exception 'uia_clave duplicada en wizard %', new.slug;
    end if;
    new.updated_at := now();
    return new; -- La fila completa que esta siendo insertada o actualizada.
end;
$$;

drop trigger if exists trg_wizard_uia on public.aplicaciones_catalogo;
create trigger trg_wizard_uia
before insert or update OF pasos_wizard on public.aplicaciones_catalogo
for each row execute function public.fn_wizard_uia_unicas();

-- PRUEBA 1 Impedir botones duplicados dentro del wizard.
-- Objetivo: Verificar que un wizard no pueda almacenar dos pasos que tengan la misma uia_clave.
-- Accion: Intentar agregar otro paso con: uia_clave = Next.
-- Resultado esperado: El trigger bloquea la operacion , Se genera una excepcion.
-- El JSON permanece sin cambios. pasos_count sigue siendo 1.

select '--- PRUEBA 1: uia duplicada ---' as test;

select pasos_count
from public.aplicaciones_catalogo
where slug = 'vmware-player';
-- Esperado ahora: 1

do $$
begin
    update public.aplicaciones_catalogo
    set pasos_wizard = pasos_wizard || jsonb_build_array(
        jsonb_build_object('orden', 2, 'etiqueta', 'Otra vez', 'uia_clave', 'Next')
    )
    where slug = 'vmware-player';
    raise exception 'FALLO: el wizard acepto dos Next';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise ;
        end if;
        raise notice 'OK uia unica: %', sqlerrm;
end;
$$;