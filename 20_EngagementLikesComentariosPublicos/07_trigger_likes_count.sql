-- Pattern Youtube: Contador denormalizado likes_count = likes_count + 1
create or replace function public.fn_likes_after_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if tg_op = 'INSERT' then
        update public.tutoriales
        set likes_count = likes_count + 1
        where id = new.tutorial_id;
        return new;

    elsif tg_op = 'DELETE' then
        update public.tutoriales
        set likes_count = greatest(likes_count-1, 0)
        where id = old.tutorial_id;
        return old;
    end if;

    return null;
end;
$$;

drop trigger if exists trg_likes_count on public.tutorial_likes;
create trigger trg_likes_count
after insert or delete on public.tutorial_likes
for each row execute function public.fn_likes_after_change();