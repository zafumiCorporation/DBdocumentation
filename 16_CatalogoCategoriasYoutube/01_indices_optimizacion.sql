-- INDICES TODO LO QUE HACE QUE TU AUTOCOMPLETE SE INSTANTANEO
-- 1 FILTRO PRINCIPAL DEL DASHBOARD
-- COMO SE USA CUANDO PONES  Where categorias.slug = true order by orden asc
create index if not exists idx_categorias_activa_orden ON categorias(orden ASC)
where activa = true;