-- 02 Muro Publico (Youtube Comments)
DO $$
begin
    create type public.comentario_clase as enum ('normal', 'comunidad');
exception when duplicate_object then null;
end;
$$;

DO $$
begin
    create domain public.url_http as text check (VALUE ~* '^https?://[^\s]+$');
exception when duplicate_object then null;
end;
$$;

create table if not exists public.tutorial_comentarios(
    id bigint generated always as identity primary key,
    tutorial_id bigint not null,
    autor_id bigint not null,
    -- Permite que un comentario sea respuesta a otro comentario.
    -- Si es Null, es un comentario raiz.
    padre_id bigint,
    clase public.comentario_clase not null default 'normal',
    titulo varchar(120),
    codigo citext,
    cuerpo_texto text,
    audio_url public.url_http,
    audio_duracion_ms int check (audio_duracion_ms is null or audio_duracion_ms between 500 and 120000),
    -- Representa el numero de respuestas o participantes asociados al comentario.
    miembros_count int not null default 0 check ( miembros_count >= 0),
    created_at timestamptz not null default now(),

    -- Foreign keys
    constraint fk_tutorial_comentarios_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    constraint fk_tutorial_comentarios_usuarios_autor
        foreign key (autor_id) references public.usuarios(id)
            on delete cascade,

    constraint fk_tutorial_comentarios_tutorial_comentarios_padre
        foreign key (padre_id) references public.tutorial_comentarios(id)
            on delete cascade,

    -- XOR: texto o voz, nunca ambos , nunca vacio
    -- num_nonnulls Cuenta cuantos valores no son NULL.
    constraint ck_comentario_un_medio check ( num_nonnulls(cuerpo_texto, audio_url) = 1),
    -- char_length: numero de caracteres de la cadena. si no es null debe tener un caracter real
    constraint ck_texto_no_vacio check ( cuerpo_texto is null or char_length(btrim(cuerpo_texto)) > 0),

    -- normal = comentario Youtube. comunidad = post con titulo+codigo, solo raiz
    constraint ck_clase_forma check (
        (clase = 'normal' and titulo is null and codigo is null and miembros_count = 0)
            OR
        (clase = 'comunidad' and padre_id is null
         and titulo is not null and char_length(btrim(titulo)) between 3 and 120
         and codigo is not null)
    ),

    -- {5,11} Deben venir entre 5 y 11 caracteres adicionales, pueden ser letras, numeros, guion bajo , guion
    constraint ck_codigo_formato check (codigo is null or codigo::text ~ '^[A-Za-z0-9][A-Za-z0-9_-]{5,11}$')

);

-- Respuestas deben vivir en el mismo tutorial - evita cruzar videos
create or replace function public.fn_comentario_mismo_tutorial()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_padre_tutorial bigint;
    v_padre_clase public.comentario_clase;
begin
    -- Si es null Es un comentario raiz (comunidad).
    -- return new es la fila que se esta insertando o actualizando. permite que se guarde en la tabla.
    if new.padre_id is null then return new; end if;

    -- Significa que este comentario es una respuesta Comentario normal.
    select tutorial_id, clase into v_padre_tutorial, v_padre_clase
    from public.tutorial_comentarios
    where id = new.padre_id;

    -- Comparamos si el tutorial_id del comentario respuesta es igual al tutorial_id del comentario padre
    if v_padre_tutorial is distinct from new.tutorial_id then
        raise exception 'la respuesta debe vivir en el mismo tutorial %', new.tutorial_id;
    end if;

    -- Si mi comentario respuesta trae una clase comunidad
    if new.clase = 'comunidad' then
        raise exception 'solo la raiz puede ser comunidad, no una respuesta';
    end if;

    -- Retorna la fila completa que se esta insertando.
    return new;
end;
$$;

drop trigger if exists trg_comentario_mismo_tutorial on public.tutorial_comentarios;
create trigger trg_comentario_mismo_tutorial
before insert or update of padre_id, tutorial_id, clase
on public.tutorial_comentarios
for each row execute function public.fn_comentario_mismo_tutorial();

comment on table public.tutorial_comentarios is 'Muro publico. normal = comentario Youtube. comunidad = postcon titulo+codigo, lectura publica tipo youtube';

-- Comentarios raiz de Youtube. padre_id null, clase normal, solo texto o solo audio.
-- 1 Shiriaru, tabla usuarios, comenta el turoial 1 "Create Sheet in Word"
insert into public.tutorial_comentarios(tutorial_id, autor_id, padre_id, clase, cuerpo_texto)
values (1, 1, null, 'normal', 'Este es el comentario raiz del tutorial.');

-- 2 Julio comenta el mismo tutorial 1.
insert into public.tutorial_comentarios (tutorial_id, autor_id, padre_id, clase, cuerpo_texto)
values (1,2, null, 'normal', 'Lo probe en Word y funciono.')

-- 4 Angela deja un audio en el tutorial 4 "Create Video Game in Unreal Engine"
-- cuerpo_texto queda null: La regla exige texto o voz, no los dos.
insert into public.tutorial_comentarios (tutorial_id, autor_id, padre_id, clase, audio_url, audio_duracion_ms)
values (
  4, 4, null, 'normal',
  'https://cdn.ejemplo.com/audio/angela-tutorial-4.mp3' , 800
);

-- 3 Sebastian responde al comentario raiz de Shiriaru, en el mismo tutorial 1.
insert into public.tutorial_comentarios (tutorial_id, autor_id, padre_id, clase, cuerpo_texto)
select 1, 3, c.id, 'normal', 'Yo tambien, en el paso 2.'
from public.tutorial_comentarios as c
where c.tutorial_id = 1
  and c.autor_id = 1
  and c.padre_id is null
  and c.clase = 'normal'
order by c.id
limit 1;

