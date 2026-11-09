-- Contador total de vistas unicas del tutorial.
alter table public.tutoriales
    add column if not exists vistas_count int not null default 0
        check (vistas_count >= 0);