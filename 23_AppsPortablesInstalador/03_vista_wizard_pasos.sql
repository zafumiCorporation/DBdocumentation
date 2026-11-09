-- View Cook : pasos_wizard JSONB -> filas para runner.
-- View -> consulta guardada
create or replace view public.vista_wizard_pasos as
select
    a.id as aplicacion_id , -- El numero ID de la app. Ej: 1, 2, 3
    a.slug, -- Identificador unico corto sin espacios. Ej:chrome , vscode.
    a.nombre, -- Nombre bonito que ve el usuario Ej: Google Chrome
    a.tipo, -- Que tipo de app es. Ej: portable, instalable , zip.
    (elem->>'orden')::int as orden, -- El numero del paso. 1, 2, 3. Es para saber en que orden hacer click.
    elem->>'fase' as fase, -- En que ventana o pantalla estamos? Ej: bienvenida , licencia, instalando.
    elem->>'etiqueta' as etiqueta, -- El texto que ve el usuario en el boton. Ej: Siguiente, Aceptar, Instalar
    elem->>'uia_clave' as uia_clave, -- El nombre interno que le pones tu a ese boton para identificarlo.
    elem->>'selector_uia' as selector_uia, -- Direccion exacta para encontrar ese boton en Windows.
    elem->>'por_que' as por_que, -- La explicacion de por que hay que hacer click ahi. Para tu logica, no para el usuario.
    coalesce(elem->>'action', 'click') as action -- Que tiene que hacer el runner , Si en tu JSON no escribiste nada, por defecto hace click. Si escribiste doble_click, hace eso.
from public.aplicaciones_catalogo as a
cross join lateral jsonb_array_elements(a.pasos_wizard) as elem;

-- La vista te lo muestra asi para el runner:
-- aplicacion_id ..........slug......orden.........fase.........etiqueta
-- 1.......................chrome....1.............Bienvenidad..Siguiente
-- 1.......................chrome....2.............final........Instalar