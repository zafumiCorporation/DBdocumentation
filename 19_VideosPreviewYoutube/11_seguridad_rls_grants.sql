-- RLS SOLO DOCUMENTACION POR EL MOMENTO
-- Activa RLS + FORCE: Ni siquiera el owner de la tabla puede bypasearlo
ALTER TABLE public.tutorial_guardados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tutorial_guardados FORCE ROW LEVEL SECURITY;

ALTER TABLE public.tutorial_compartidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tutorial_compartidos FORCE ROW LEVEL SECURITY;

ALTER TABLE public.historial_visualizaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial_visualizaciones FORCE ROW LEVEL SECURITY;

-- Nota: presencia_activa y clipboard_uia_ram son UNLOGGED = no llevan RLS
-- Se protegen solo por fn_set_presencia_rica con SECURITY DEFINER

-- 1. GUARDADOS: Solo puedes ver/tocar tus propios guardados
DROP POLICY IF EXISTS guardados_mios ON public.tutorial_guardados;
CREATE POLICY guardados_mios ON public.tutorial_guardados
FOR ALL
USING (usuario_id = current_setting('app.usuario_actual', true)::BIGINT)
WITH CHECK (usuario_id = current_setting('app.usuario_actual', true)::BIGINT);

-- 2. HISTORIAL: Solo tu historial para entrenar tu IA
DROP POLICY IF EXISTS historial_mio ON public.historial_visualizaciones;
CREATE POLICY historial_mio ON public.historial_visualizaciones
FOR ALL
USING (usuario_id = current_setting('app.usuario_actual', true)::BIGINT)
WITH CHECK (usuario_id = current_setting('app.usuario_actual', true)::BIGINT);

-- 3. COMPARTIDOS: SELECT publico (el codigo es el secreto, como youtu.be)
-- INSERT/UPDATE/DELETE solo el creador
DROP POLICY IF EXISTS compartidos_ver ON public.tutorial_compartidos;
CREATE POLICY compartidos_ver ON public.tutorial_compartidos
FOR SELECT USING (true);

DROP POLICY IF EXISTS compartidos_crear ON public.tutorial_compartidos;
CREATE POLICY compartidos_crear ON public.tutorial_compartidos
FOR INSERT
WITH CHECK (creador_id = current_setting('app.usuario_actual', true)::BIGINT);

DROP POLICY IF EXISTS compartidos_modificar ON public.tutorial_compartidos;
CREATE POLICY compartidos_modificar ON public.tutorial_compartidos
FOR UPDATE USING (creador_id = current_setting('app.usuario_actual', true)::BIGINT)
WITH CHECK (creador_id = current_setting('app.usuario_actual', true)::BIGINT);

DROP POLICY IF EXISTS compartidos_borrar ON public.tutorial_compartidos;
CREATE POLICY compartidos_borrar ON public.tutorial_compartidos
FOR DELETE USING (creador_id = current_setting('app.usuario_actual', true)::BIGINT);

-- 4. GRANTS: app_desktop_role solo puede tocar estas 3 via RLS, nada mas
GRANT SELECT, INSERT, UPDATE, DELETE
ON public.tutorial_guardados,
   public.tutorial_compartidos,
   public.historial_visualizaciones
TO app_desktop_role;

