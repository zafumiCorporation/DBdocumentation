-- materialized view: Una fotografia precalculada para lectura rapida.
-- Contiene los errores conocidos mas frecuentes. Resumen de errores.
create materialized view if not exists public.mv_errores_frecuentes as
select
    t.id, -- Id del tipo de error.
    t.slug, -- Nombre amigable unico.
    t.origen, -- Origen del error.
    t.gravedad, -- Que tan grave es el error.
    t.veces_visto, -- Cuantas veces ocurrio.
    g.id as guia_id, -- Id de la guia para resolverlo.
    g.tutorial_id -- Id del tutorial de resolucion.
from public.tipos_error as t
left join public.guias as g on g.tipo_error_id = t.id and g.activa = true
where t.activa = true -- Solo errores activos.
with no data; -- Crea la materialized view per No la llenes todavia.
-- Despues: refresh materialized view la crea.

-- Sirve para buscar rapido por id. Devuelve las filas que coiciden.
create unique index if not exists uq_mv_errores_frecuentes_id
    on public.mv_errores_frecuentes (id);

create unique index if not exists idx_mv_errores_veces_desc
    on public.mv_errores_frecuentes (veces_visto desc);

create index if not exists idx_mv_errores_origen
    on public.mv_errores_frecuentes(origen);

-- refresh -> Reconstruye la fotografia , Antes: foto vieja , Despues: foto nueva.
refresh materialized view public.mv_errores_frecuentes;

-- Almacena errores ocurridos en los ultimos 7 dias.
create materialized view if not exists public.mv_errores_frecuentes_7d as
select
    e.tipo_error_id, -- Id del tipo de error ocurrido.
    t.slug, -- Nombre unico del error.
    t.origen, -- Origen del error.
    count(*)::int as eventos_7d, -- cuenta eventos ocurridos.
    max(e.ocurrio_en) as ultimo_en -- Obtiene la fecha mas reciente de eventos.
from public.eventos_sistema as e
join public.tipos_error as t on t.id = e.tipo_error_id
where e.ocurrio_en >= now() - interval '7 days' -- Deste hace 7 dias hasta ahora.
  and e.tipo_error_id is not null
group by e.tipo_error_id, t.slug, t.origen -- Agrupa eventos.
with  no data ;

create unique index if not exists uq_mv_errores_7d_tipo
    on public.mv_errores_frecuentes_7d (tipo_error_id);
