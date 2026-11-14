-- CAN: 커뮤니티·프로필 영속 저장소 (Supabase / PostgreSQL)
-- 적용: Supabase SQL Editor에 그대로 실행하거나 `supabase db push`를 사용한다.
-- 모든 테이블은 RLS가 켜져 있으며, 클라이언트는 아래 정책 범위만 접근할 수 있다.

-- ── 프로필 ────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 20),
  avatar_emoji text not null default '🐣' check (char_length(avatar_emoji) between 1 and 16),
  avatar_image_data_url text check (
    avatar_image_data_url is null
    or (char_length(avatar_image_data_url) <= 100000 and avatar_image_data_url ~ '^data:image/(png|jpeg|gif|webp);base64,[A-Za-z0-9+/=]+$')
  ),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles readable by signed-in users" on public.profiles;
create policy "profiles readable by signed-in users"
  on public.profiles for select to authenticated using (true);

drop policy if exists "users insert own profile" on public.profiles;
create policy "users insert own profile"
  on public.profiles for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- ── 게시글 ────────────────────────────────────────────────────────────────
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles (user_id) on delete cascade,
  quote_id text check (quote_id is null or char_length(quote_id) <= 64),
  title text not null check (char_length(btrim(title)) between 1 and 60),
  content text not null check (char_length(btrim(content)) between 2 and 300),
  like_count integer not null default 0 check (like_count >= 0),
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists community_posts_feed_idx
  on public.community_posts (created_at desc) where not hidden;
create index if not exists community_posts_top_idx
  on public.community_posts (like_count desc, created_at desc) where not hidden;
create index if not exists community_posts_user_idx
  on public.community_posts (user_id, created_at desc);

alter table public.community_posts enable row level security;

drop policy if exists "visible posts readable by signed-in users" on public.community_posts;
create policy "visible posts readable by signed-in users"
  on public.community_posts for select to authenticated
  using (not hidden or (select auth.uid()) = user_id);

-- 게스트(익명) 계정은 읽기·좋아요만 가능하고, 글 작성은 가입한 계정만 가능하다.
drop policy if exists "registered users create own posts" on public.community_posts;
create policy "registered users create own posts"
  on public.community_posts for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    and like_count = 0
    and hidden = false
  );

drop policy if exists "users delete own posts" on public.community_posts;
create policy "users delete own posts"
  on public.community_posts for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 하루 작성량 제한(스팸 방지)
create or replace function public.enforce_post_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.community_posts
      where user_id = new.user_id and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'post_rate_limit' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists community_posts_rate_limit on public.community_posts;
create trigger community_posts_rate_limit
  before insert on public.community_posts
  for each row execute function public.enforce_post_rate_limit();

-- ── 좋아요 ────────────────────────────────────────────────────────────────
create table if not exists public.community_post_likes (
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.community_post_likes enable row level security;

drop policy if exists "users read own likes" on public.community_post_likes;
create policy "users read own likes"
  on public.community_post_likes for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "users like as themselves" on public.community_post_likes;
create policy "users like as themselves"
  on public.community_post_likes for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "users remove own likes" on public.community_post_likes;
create policy "users remove own likes"
  on public.community_post_likes for delete to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.sync_post_like_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.community_posts set like_count = like_count + 1 where id = new.post_id;
  else
    update public.community_posts set like_count = greatest(like_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$;

drop trigger if exists community_post_likes_count on public.community_post_likes;
create trigger community_post_likes_count
  after insert or delete on public.community_post_likes
  for each row execute function public.sync_post_like_count();

-- ── 신고 ──────────────────────────────────────────────────────────────────
create table if not exists public.post_reports (
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.post_reports enable row level security;

drop policy if exists "users report as themselves" on public.post_reports;
create policy "users report as themselves"
  on public.post_reports for insert to authenticated
  with check ((select auth.uid()) = user_id);

-- 서로 다른 사용자 3명이 신고하면 게시글을 자동으로 숨긴다. 검토 후 운영자가 hidden을 직접 해제할 수 있다.
create or replace function public.hide_reported_post()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.community_posts
     set hidden = true
   where id = new.post_id
     and (select count(*) from public.post_reports where post_id = new.post_id) >= 3;
  return null;
end;
$$;

drop trigger if exists post_reports_autohide on public.post_reports;
create trigger post_reports_autohide
  after insert on public.post_reports
  for each row execute function public.hide_reported_post();

-- ── 계정 삭제 (스토어 정책 필수) ──────────────────────────────────────────
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
