-- Prepara un dataset para exportarlo y devuelve todas sus muestras en formato SFT (prompt + completion)
-- Funcion: Tomar las muestras ya existentes -> Marcar el dataset como exportando ->
-- Extraer prompt y completion -> Devolverlos para generar el archivo de entrenamiento.
create or replace function public.fn_dataset_exportar_sft(
    p_dataset_id bigint -- Id del dataset del cual se exportaran las muestras.
)
-- setof -> Devuelve varias filas.
returns setof public.stf_par
language plpgsql
security definer
set search_path = ''
as $$
begin
    update public.dataset_entrenamiento
    set estado = 'exportando', -- Indica que el dataset esta siendo preparado para generar los datos que usara el entrenamiento.
        exportado_en = now(),
        updated_at = now()
    where id = p_dataset_id -- Modifica solamente el dataset recibido.
        and estado in ('abierto', 'exportando'); -- Solo datasets abiertos o exportando.

    return query -- Devuelve todas las filas de una consulta.
    select
        (m.par_sft->>'prompt')::text as prompt,
        (m.par_sft->>'completion')::text as completion
    from public.dataset_muestras as m
    where m.dataset_id = p_dataset_id -- Solo obtener las muestras de este dataset.
    order by m.id; -- Ordena los resultado por id de muestra.
end;
$$;

-- PRUEBA 1 Exportar las muestras del dataset en formato SFT.
-- Objetivo: Comprobar que la funcion cambia el estado del dataset a 'exportando',
-- registra la fecha de exportacion y devuelve todas las muestras utiilizando los campos prompt y completion
-- Estado inicial: Existe el dataset con ID 1: sft-word-noviembre.
-- El dataset tiene estado 'abierto'. exportado_en es NULL. Existen 4 muestras registradas:
-- 1. Una correcion de ruta. 2. Dos guias de solucion de errores. 3. Un tutorial.
-- Resultado esperado: Inicialmente estado = 'abierto'. Inicialmente exportado_en = NULL.
-- La funcion devuelve 4 filas con prompt y completion. Las muestras se devuelven ordenadas por ID.
-- El estado cambia a 'exportando'. exportando_en deja de ser null.
-- El intento de agregar el tutorial 4 genera una excepcion: "dataset 1 no esta abierto (estado=exportando)".

select '--- PRUEBA 1: exporta sft ---' as test;

select estado, exportado_en
from public.dataset_entrenamiento
where id = 1;
-- Esperado ahora: abierto. exportado_en null.

-- 1 = sft-word-noviembre.
select prompt, left(completion, 40) as completion
from public.fn_dataset_exportar_sft(1)
order by prompt;
-- Esperado: 4 filas.
-- Create Sheet in Word / Create Sheet in Word.
-- Hypervisor bloqueado / el json de los dos pasos, en texto.
-- Missing files / el json del paso de Notepad.
-- insertar -> pagina-en-blanco / pagina-en-blanco -> insertar.

select estado, exportado_en is not null as exportado
from public.dataset_entrenamiento
where id = 1;
-- Esperado: estado exportando. exportado true.

do $$
begin
    perform public.fn_dataset_agregar_tutorial(1, 4);
    raise exception 'FALLO: agrego con el lote exportando';
exception
    when others then
        if sqlerrm like 'FALLO:%' then
            raise;
        end if;
        raise notice 'OK cerrado: %', sqlerrm;
end;
$$;
-- Esperado en Messages: OK cerrado: dataset 1 no esta abierto (estado=exportando).
-- 4 = "Create Video Game in Unreal Engine". No debe entrar.

