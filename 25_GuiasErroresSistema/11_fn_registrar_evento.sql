-- fn_registrar_evento -> wrapper una funcion que llama a otra.
create or replace function public.fn_registrar_evento(
    p_yo bigint,
    p_origen public.error_origen,
    p_titulo text,
    p_cuerpo text default null,
    p_uia text default null,
    p_aplicacion_id bigint default null,
    p_tutorial_id bigint default null,
    p_ejecucion_id bigint default null,
    p_payload jsonb default '{}'::jsonb
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
    r record; -- Una variable capaz de guardar: una fila completa.
begin
    select * into r from public.fn_reportar_evento(
        p_yo, p_origen, p_titulo, p_cuerpo, p_uia,
        p_aplicacion_id, p_tutorial_id, p_ejecucion_id, p_payload, 'error'
    ) limit 1;
    return r.evento_id; -- Devuelve unicamente el id del evento.
end;
$$;

-- PRUEBA 1: Registrar una segunda aparicion de HYPER-V.
-- Escenario: El tipo de error hyper-hypervisor-bloqueado ya existe en el catalogo.
-- Anteriormente se registro una ocurrencia mendiante fn_reportar_evento().
-- Objetivo: Comprobar que el wrapper pueda reutilizar el tipo de error existente,
-- registrar una nueva ocurrencia y devolver solamente el ID del evento.

-- Precondiciones: 1. Existe el usuario con ID 1. , 2. Existe la aplicacion hyper-v.
-- 3. Existe el tipo de error hyperv-hypervisor-bloqueado. 4. Ya se registro una primera ocurrencia del error.
-- 5. El tutorial con ID 1 existe.

-- Resultado General esperado:
-- 1. El tipo de error existente se reutiliza. 2. Se registra una seguna ocurrencia.
-- 3. El wrapper devuelve un bigint. 4. El contador veces_visto pasa de 1 a 2, si la funcion principal implementa explicitamente su incremento.
-- El total de eventos de Hyper-V pasa a ser 2.
 select '--- PRUEBA 1: segunda aparicion ---' as test;


-- Consultar el contador inicial.
-- Consulta: Busca el tipo de error hyperv-hypervisor-bloqueado y obtiene su contador veces-visto.
select veces_visto
from public.tipos_error
where slug = 'hyperv-hypervisor-bloqueado';
-- Esperado ahora: 1.

-- Ejecutar el Wrapper. Consulta: llama a fn_registrar_evento() con los datos de un segundo reporte
-- del error Hyper-V.
-- Parametros: 1. Usuario 1. 2. Origen sistema. 3. Titulo Hypervisor bloqueado.
-- Descripcion No se pudo iniciar Hyper-V. 5. Identificador uIA HyperV.ErrorDialog.
-- 6. ID de la aplicacion hyper-v. 7. Tutorial relacionado con ID 1.
-- 8. Sin ejecucion especifica. 9. Payload JSONB vacio.
select public.fn_registrar_evento(
    1,
    'sistema',
    'Hypervisor bloqueado',
    'No se puedo iniciar Hyper-V',
    'Hypervisor.ErrorDialog',
    (select id from public.aplicaciones_catalogo where slug = 'hyper-v'),
    1,
    null,
    '{}'::jsonb
);
-- Esperado: un bigint. Es el id del evento nuevo.

-- Comprobar el contador despues del reporte.
select veces_visto
from public.tipos_error
where slug = 'hyperv-hypervisor-bloqueado';
-- esperado 2.

-- Contar las apariciones del error HYPER-V.
select count(*) as apariciones
from public.eventos_sistema e
join public.tipos_error t on t.id = e.tipo_error_id
where t.slug = 'hyperv-hypervisor-bloqueado';
-- Esperado: 2.

select * from public.tipos_error;
select * from public.eventos_sistema;

-- Arreglar Cuando diferentes usuarios reportan el mismo error veces visto. .
-- Se crearo dos registros en tipos_error.


