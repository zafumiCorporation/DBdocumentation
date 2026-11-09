-- Funcion que se ejecuta automaticamente cuando ocurre un evento sobre la tabla -> Su trabajo es mantener actualizado forks_count
create or replace function public.fn_forks_count_sync()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'INSERT' and new.tutorial_original_id is not null then
        update public.tutoriales
        set forks_count = forks_count + 1
        where id = new.tutorial_original_id;
        return new; -- new -> La nueva fila que se esta insertando.
    elsif tg_op = 'DELETE' and OLD.tutorial_original_id is not null then
        update public.tutoriales
        set forks_count = greatest(forks_count - 1, 0)
        where id = old.tutorial_original_id;
        return old; -- old -> representa la fila antigua que existia antes de eliminarse.
    end if;
    return coalesce(new, old);
end;
$$;

drop trigger if exists trg_forks_count on public.tutorial_forks;
create trigger trg_forks_count
after insert or delete on public.tutorial_forks
for each row execute function public.fn_forks_count_sync();

-- PRUEBA 1. Borrar el registro del fork resta el contador.
-- La copia del tutorial no se borra.
-- Objetivo: Verificar que el trigger trg_forks_count actualice correctamente forks_count
-- cuando se elimina una fila de tutorial_forks.
-- Estado inicial: El tutorial de Julio tiene forks_count = 1. Existe un registro de fork
-- creado por Sebastian. El tutorial de Sebastian sigue existiendo
-- Accion: Eliminar la fila correspondiente al fork de Sebastian en la tabla tutorial_forks.
-- Resultado esperado: forks_count disminuye de 1 a 0. El registro desaparece de tutorial_forks.
-- El tutorial de Sebastian No se elimina , Solamente desaparece la relacion registrada entre ambos tutoriales
-- Nota: Esta operacion elimina el evento o vinculo del fork, no la copia fisica del tutorial.

select '--- PRUEBA 1: trigger resta al borrar ---' as test;

-- Antes. El remix de Julio tiene un fork: el de Sebastian.
select id, titulo, forks_count
from public.tutoriales
where creador_id = 2
  and tutorial_padre_id = 1;
-- Esperado ahora: forks_count = 2

select f.id, f.tutorial_original_id, f.tutorial_copia_id, f.usuario_fork_id
from public.tutorial_forks as f
where f.usuario_fork_id = 3;
-- Esperado ahora: una fila. usuario 3 = Sebastian
-- tutorial_original_id = el remix de Julio.
-- tutorial_copia_id = el remix de Sebastian.

-- Se borra el evento, no el tutorial
-- 3 = Sebastian, tabla public.usuarios, columna id.
delete from public.tutorial_forks
where usuario_fork_id = 3;

-- Despues. El remix de Julio vuelve a 0
select id, titulo, forks_count
from public.tutoriales
where creador_id = 2
  and tutorial_padre_id = 1;
-- Esperado: forks_count = 0.

-- Despues. El tutorial de Sebastian sigue existiendo. Solo se fue la fila del evento
select id, creador_id, titulo, tutorial_padre_id
from public.tutoriales
where creador_id = 3
  and titulo like 'Remix: Remix:%';
--Esperado: la fila sigue. creador_id 3 Sebastian. padre = el remix de Julio.

select id
from public.tutorial_forks
where usuario_fork_id = 3;
-- Esperado: cero filas.

-- El fork de Julio sobre el original no se toco
select forks_count
from public.tutoriales
where id = 1;
-- Esperado: sigue en 1.