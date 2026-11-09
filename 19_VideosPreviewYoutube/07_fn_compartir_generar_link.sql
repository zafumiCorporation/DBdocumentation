-- Pattern youtube: Generar shortlink + Resolver con click atomico
create or replace function public.fn_compartir_generar_link(p_yo bigint,
    p_tutorial_id bigint , p_expira_horas int default null
)
returns table (codigo citext, url_completa text)
language plpgsql
security definer
as $$
declare
    v_codigo citext;
    v_intentos int := 0;
begin
    -- Repite este bloque hasta que yo diga que salgas , Se rompe con exit
    loop
        -- gen_random_bytes(6) Genera 6 bytes aleatorios
        -- encode(..., 'base64') Convierte esos bytes binarios en una base64 Ejemplo: dQw4w9WgXcQ
        -- translate(..., '+/=', '-_') remplaza + -> - , / -> _ , = Asi obtienes un formato URL-safe(seguro para usar en links)
        -- substr(..., 1, 8) Toma solo los primeros 8 caracteres de la cadena generada Ejemplo: cadena(dQw4w9WgXcQ) el substr(1,8) devuelve dQw4w9Wg
        v_codigo := substr(
            translate(encode(gen_random_bytes(6), 'base64'), '+/=', '-_'),
            1,8
        )::citext;

        begin
            insert into public.tutorial_compartidos(tutorial_id, creador_id, codigo, expira_at)
            values (p_tutorial_id, p_yo, v_codigo,
                             -- Si p_expira_horas tiene un valor "fecha actual + X horas"
                             case when p_expira_horas is not null
                                  then now() + (p_expira_horas::text || 'hours')::interval
                                  else null end
                   );
            exit; -- Si el insert se ejecuta correctamente, rompe loop
        --Exception Plan b , unique_violation Error que lanza PostgreSQL cuando intentas insertar un valor
        exception when unique_violation then
            v_intentos := v_intentos + 1;
            if v_intentos > 5 then raise exception 'No se pudo generar codigo unico'; end if;
        end;
    end loop;

    -- return query Devuelve el resultado de la funcion como si fuera una tabla.
    -- 'https://tuapp.com/t/' texto fijo (la base de tu URL)
    return query select v_codigo, ('https://tuapp.com/t/' || v_codigo::text):: text;
end;
$$;

-- Cada vez que alguien abre un enlace compartido esta funcion incrementa el contador de clics y devuelve la informacion del tutorial y su creador.
create or replace function public.fn_resolver_compartido(p_codigo citext)
returns table (tutorial_id bigint, creador_id bigint)
language plpgsql
security definer
set search_path = ''
as $$
begin
    return query
    update public.tutorial_compartidos as tc
    set clicks = tc.clicks + 1
    where tc.codigo = p_codigo
        and (tc.expira_at is null or tc.expira_at > now())
    returning tc.tutorial_id, tc.creador_id;
end;
$$;

-- PRUEBA 1 Abrir un shorlink que ya existe , Patron youtube: Cada apertura suma un click
select '--- PRUEBA 1: resolver shortlink ---' as test;

-- Antes. Tabla public.tutorial_compartidos, codigo Sheet720
-- Sheet720 pertenece al tutorial 1 "Create Sheet in Word" y al creador 1 Shiriaru
select id, tutorial_id, creador_id, codigo, clicks, expira_at
from public.tutorial_compartidos
where codigo = 'Sheet720';
-- Esperado ahora: una fila, clicks = 3, expira_at null (el link no caduca)

-- fn_resolver_compartido(p_codigo)
-- 'Sheet720' = columna codigo de public.tutorial_compartidos
select * from public.fn_resolver_compartido('Sheet720');
-- 1 de tutorial_id = "Create Sheet in Word", tabla public.tutoriales.
-- 1 de creador_id = Shiriaru, tabla public.usuarios

-- Despues el click queda guardado linea 68
-- Esperado: la misma fila, clicks = 4

-- PRUEBA 2. Generar un link nuevo, con caducidad de 24 horas
select  '--- PRUEBA 2: generar shortlink ---' as test;

-- Antes. Links que Julio ya creo para el tutorial 5
-- 2 = Julio , tabla public.usuarios, columna id.
-- 5 = "Build Level in Unreal Engine" , tabla public.tutoriales, columna id. Creador: Julio
select id, tutorial_id, creador_id, codigo, clicks, expira_at, created_at
from public.tutorial_compartidos
where creador_id = 2
  and tutorial_id = 5;
-- Esperado ahora: cero filas.

-- fn_compartir_generar_link(p_yo, p_tutorial_id, p_expira_horas)
-- 2 = Julio, tabla public.usuarios
-- 5 = "Build level in Unreal Engine", tabla public.tutoriales.
-- 24 = el link caduca dentro de 24 horas. Si fuera null, no caduca
select * from public.fn_compartir_generar_link(2, 5, 24);
-- Esperado:  una fila con un codigo de 8 caracteres y url_completa https://tuapp.com/t/ + ese codigo.
-- El codigo cambia en cada ejecucion.

-- Despues. la fila quedo en la tabla linea 88
-- Esperado: una fila, clicks = 0, expira_at aproximadamente dentro de 24 horas.
-- creador_id = Julio. tutorial_id 5 = "Build Level in Unreal Engine".

-- PRUEBA 3. Abrir un codigo que no existe. No suma clicks en los links reales
select '--- PRUEBA 3: codigo inexistente ---' as test;

-- Antes. Click actual de Sheet720, para compararlo despues.
select codigo, clicks
from public.tutorial_compartidos
where codigo = 'Sheet720';
-- Esperado ahora: clicks = 4

-- 'NoExiste' no esta en public.tutorial_compartidos.codigo.
select * from public.fn_resolver_compartido('NoExiste');
-- EsperadoL cero filas. La funcion no devuelve tutorial ni creador.
