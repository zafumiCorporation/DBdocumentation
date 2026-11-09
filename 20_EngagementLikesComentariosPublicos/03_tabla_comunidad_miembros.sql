-- Tabla comunidad miembros
create table if not exists public.comentario_miembros(
    comentario_id bigint not null,
    usuario_id bigint not null,
    joined_at timestamptz not null default now(),
    primary key (comentario_id, usuario_id),

    -- Foreign
    constraint fk_comentario_miembros_tutorial_comentarios_comentario
        foreign key (comentario_id) references public.tutorial_comentarios(id)
            on delete cascade,

    constraint fk_comentario_miembros_usuarios_usuario
        foreign key (usuario_id) references public.usuarios(id) on delete cascade
);

-- Conteos de los miembros dentro del comentario
create or replace function public.fn_miembros_after_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' then
        update public.tutorial_comentarios
        set miembros_count = miembros_count + 1
        where id = new.comentario_id
          and clase = 'comunidad';
        return new;

    elsif tg_op = 'DELETE' then
        update public.tutorial_comentarios
        set miembros_count = greatest(miembros_count - 1, 0)
        where id = old.comentario_id
          and clase = 'comunidad';
        return old;
    end if;

    return null;
end;
$$;

drop trigger if exists trg_miembros_count on public.comentario_miembros;
create trigger trg_miembros_count
after insert or delete on public.comentario_miembros
for each row execute function public.fn_miembros_after_change();

-- El autor de una comunidad entra solo (como admin del canal de whatsApp)
create or replace function public.fn_comunidad_autor_miembro()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.clase = 'comunidad' and new.padre_id is null then
        insert into public.comentario_miembros (comentario_id, usuario_id)
        values (new.id, new.autor_id)
        on conflict do nothing;
    end if;
    return new;
end;
$$;

drop trigger if exists trg_comunidad_autor on public.tutorial_comentarios;
create trigger trg_comunidad_autor
after insert on public.tutorial_comentarios
for each row execute function public.fn_comunidad_autor_miembro();

-- Comunidad de Julio en el tutorial 4 "Create Video Game in Unreal Engine"
-- 4 = tutorial, tabla public.tutoriales. 2 = Julio, tabla public.usuarios, autor y primer miembro.
-- El trigger mete a Julio solo. miembros_count pasa de 0 a 1.
-- Codigo UnrealHQ: 8 caracteres, entra en la regla de 6 a 12.
insert into public.tutorial_comentarios(
    tutorial_id, autor_id, padre_id, clase, titulo, codigo, cuerpo_texto
) values (
    4, 2, null, 'comunidad', 'Comunidad Unreal',
    'UnrealHQ', 'Canal para dudas del nivel.'
);

-- Comunidad de Shiriaru en el tutorial 1 "Create Sheet in Word".
-- 1 = tutorial. 1 = Shiriaru, autor y primer miembro. miembros_count pasa de 0 a 1.
insert into public.tutorial_comentarios(
    tutorial_id, autor_id, padre_id, clase, titulo, codigo, cuerpo_texto
) values (
  1, 1, null, 'comunidad', 'Dudas de Word', 'WordDudas',
  'Pregunta aqui antes de ejecutar.'
);

-- 3 = Sebastian, tabla public.usuarios. Se une a UnrealHQ. miembros_count pasa de 1 a 2.
insert into public.comentario_miembros (comentario_id, usuario_id)
select c.id, 3
from public.tutorial_comentarios as c
where c.codigo = 'UnrealHQ';

-- Sebastian ya es miembro y opina dentro de UnrealHQ. La respuesta es clase normal, en el tutorial 4
insert into public.tutorial_comentarios (tutorial_id, autor_id,padre_id,clase, cuerpo_texto)
select c.tutorial_id, 3, c.id, 'normal', 'Me uno para el nivel 2.'
from public.tutorial_comentarios as c
where c.codigo = 'UnrealHQ';

-- 4 = Angela, tabla public.usuarios. Se une a WordDudas. miembros_count pasa de 1 a 2.
insert into public.comentario_miembros (comentario_id, usuario_id)
select c.id, 4
from public.tutorial_comentarios as c
where c.codigo = 'WordDudas';

-- Angela ya es miembro y opina dentro de WordDudas. La respuesta es clase normal, en el tutorial 1.
insert into public.tutorial_comentarios (tutorial_id, autor_id, padre_id, clase, cuerpo_texto)
select c.tutorial_id, 4, c.id, 'normal', 'Lo voy a probar en el paso 1.'
from public.tutorial_comentarios as c
where c.codigo = 'WordDudas';



