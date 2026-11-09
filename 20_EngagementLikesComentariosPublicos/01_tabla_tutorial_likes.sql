create table if not exists public.tutorial_likes(
    usuario_id bigint not null,
    tutorial_id bigint not null,
    created_at timestamptz not null default now(),

    -- Foreing key
    constraint tutorial_likes_usuarios_usario
        foreign key (usuario_id) references public.usuarios(id)
            on delete cascade,

    constraint tutorial_likes_tutoriales_tutorial
        foreign key (tutorial_id) references public.tutoriales(id)
            on delete cascade,

    -- Un mismo usuario no puede dar "like" dos veces al mismo tutorial.
    primary key (usuario_id, tutorial_id)
);

comment on table public.tutorial_likes is 'Like publico Youtube. No abre hilo ni mencion.';

-- Ejecutar despues de 07_trigger_likes_count.sql una sola vez.
-- 2 Julio y 3 Sebastian dan like al tutorial 1 "Create Sheet in Word" (creador Shiriaru). Likes_count pasa de 150 a 152
-- 1 Shiriaru da like al tutorial 4 "Create Video Game in Unreal Engine" (creador Julio). Likes_count pasa de 500 a 501
-- 4 Angela y 1 Shiriaru dan like al tutorial 9 "Edit Music & Audio Mixes" (creador Angela). Likes_count pasa de 60 a 62
insert into public.tutorial_likes(usuario_id, tutorial_id)  values
    (2,1),
    (3,1),
    (1,4),
    (4,9),
    (1,9);
