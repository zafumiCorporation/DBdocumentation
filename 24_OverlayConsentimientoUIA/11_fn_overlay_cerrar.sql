-- Cierra neon + mata RAM + notifica tray para Hide();
-- Es el boton x , el stop manual. El usuario termino el tutorial o dio clic en cerra.
-- Borra el estado y manda overlay_off  para que el tray haga Hide().
create or replace function public.fn_overlay_cerrar(p_yo bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    -- Borra la sesion de ese usuario.
    delete from public.overlay_sesion_ram
    where usuario_id = p_yo;

    perform pg_notify(
        'canal_overlay_' || p_yo::text,
        jsonb_build_object('tipo', 'overlay_off')::text
    );
end;
$$;

-- PRUEBA 1: Cerrar la sesion del overlay
-- Objetivo: Comprobar que fn_overlay_cerrar elimina la sesion temporal del usuario.
-- y que el consentimiento overlay_neon permanece concedido.
-- Estado inicial: usuario: 1 (Shiriaru). Debe existir una sesion en overlay_sesion_ram.
-- La sesion corresponde a VMware Player. La sesion fue creada por la prueba 4 de 09_fn_overlay_iniciar.sql
-- El heartbeat de 10_fn_overlay_heartbeat.sql pudo renovar su actividad.

select '--- PRUEBA 1: Cerrar overlay ---' as test;

select usuario_id, aplicacion_id
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado ahora: una fila. 1 = Shiriaru. aplicacion_id = vmware-player.
-- Es la sesion que dejo la prueba 4 del archvio 09 y que el hearbeat acaba de renovar.

--1 = Shiriaru, usuarios.id.
select public.fn_overlay_cerrar(1);
-- No devuelve fila. pg_notify no sale en un select

select usuario_id
from public.overlay_sesion_ram
where usuario_id = 1;
-- Esperado: cero filas.

select concedido
from public.consentimiento_uia
where usuario_id = 1
    and alcance = 'overlay_neon';
-- Esperado: true. Cerrar no revoca el grant.