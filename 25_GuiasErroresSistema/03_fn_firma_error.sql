-- digest proviene de la extension pgcrypto.
-- fn_firma_error -> Crea un identificador unico del error.
create or replace function public.fn_firma_error(
    p_titulo text, -- Titulo del error.
    p_cuerpo text default null, -- mensaje interno del error.
    p_uia text default null -- Clave unica del error..
)
returns text
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
begin
    return encode(
        public.digest( -- Convierte Bytes a caracteres exadecimales > 2cf24dba5fb0...
            convert_to( -- Convierte texto  a bytes ej: hola > 68 6f 6c 61
                lower(public.immutable_unaccent(
                    -- Forma un texto unico.
                    coalesce(p_uia, '') || '|' ||
                    coalesce(p_titulo, '') || '|' ||
                    coalesce(p_cuerpo, '')
                    )
                ),
                'UTF8'
            ),
            'sha256' -- Produce 64 caracteres hexadecimales.
        ),
        'hex'
    );
end;
$$;

-- PRUEBA 1: Misma informacion, misma huella.
-- Se comparan dos resultados:
-- 1. La firma generada por fn_firma_error().  2. La firma alamcenada para hyperv-hypervisor-bloqueado.
-- Se utilizan titulo_patron , cuerpo_patron , uia_clave del catalogo.
-- Esperado: misma_huella = true.
select '--- PRUEBA 1: huella del dialogo ---' as test;

select public.fn_firma_error(
    'Hypervisor bloqueado',
    'No se pudo iniciar Hyper-V',
    'HyperV.ErrorDialog'
) = (
    select firma_hash
    from public.tipos_error
    where slug = 'hyperv-hypervisor-bloqueado'
) as misma_huella;
-- Esperado true.

-- PRUEBA 3: longitud y diferenciacion de huellas.
-- Se genera la firma de un error diferente: Windows.BSOD
-- Length() comprueba que la firma hexadecimal tenga 64 caracters.
-- Is distict from: comprueba que la firma de Windows.BSOD sea diferente de la firma correspondiente al error Hyper-V.
-- Esperado largo = 64 , otra_huella = true.
select length(public.fn_firma_error('Pantalla azul de la muerte', 'El equipo se reinicio', 'Windows.BSOD')) as largo,
       public.fn_firma_error('Pantalla azul de la muerte', 'El equipo se reinicio', 'Windows.BSOD')
            is distinct from public.fn_firma_error(
                'Hypervisor bloqueado',
                'No se pudo iniciar Hyper-V',
                'HyperV.ErrorDialog'
            )as otra_huella;


