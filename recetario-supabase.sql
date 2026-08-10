-- ============================================================
--  RECETARIO NATIVO AÇAÍ · instalación en Supabase
--
--  archivo  : recetario-supabase.sql
--  usado por: recetario.html (lee) y recetario-admin.html (escribe)
--  crea     : tabla "recetario" + bucket "recetario"
--
--  Ejecutar completo en: Supabase → SQL Editor → New query → Run
--  Es idempotente: puedes correrlo de nuevo sin romper nada.
-- ============================================================

-- 0. SI YA CORRISTE UNA VERSIÓN ANTERIOR ----------------------
-- (la que creaba la tabla "recetas"). Si es tu primera vez, no hace nada.
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema = 'public' and table_name = 'recetas')
     and not exists (select 1 from information_schema.tables
                     where table_schema = 'public' and table_name = 'recetario')
  then
    alter table public.recetas rename to recetario;
  end if;
end $$;


-- 1. TABLA ----------------------------------------------------
create table if not exists public.recetario (
  id          uuid primary key default gen_random_uuid(),
  nombre      text not null,
  categoria   text default 'General',
  imagen_url  text,
  video_url   text,
  preparacion text default '',
  orden       int  default 0,
  activo      boolean default true,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

alter table public.recetario add column if not exists preparacion text default '';
alter table public.recetario add column if not exists categoria   text default 'General';
alter table public.recetario add column if not exists imagen_url  text;
alter table public.recetario add column if not exists video_url   text;
alter table public.recetario add column if not exists orden       int default 0;
alter table public.recetario add column if not exists activo      boolean default true;

create index if not exists recetario_orden_idx on public.recetario (orden, nombre);

-- updated_at automático
create or replace function public.recetario_touch()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists recetario_touch on public.recetario;
-- por si venías del nombre antiguo: hay que soltarlo antes de borrar
-- la función touch_updated_at() al final del script, o el script aborta
drop trigger if exists recetas_touch on public.recetario;
create trigger recetario_touch before update on public.recetario
for each row execute function public.recetario_touch();


-- 2. PERMISOS -------------------------------------------------
-- Acceso abierto con la llave anon. Quien edita es solo quien entra
-- al panel con la clave definida en recetario-admin.html.
alter table public.recetario enable row level security;

drop policy if exists recetas_lectura_publica on public.recetario;
drop policy if exists recetas_escritura_admin on public.recetario;
drop policy if exists recetas_todo            on public.recetario;
drop policy if exists recetario_todo          on public.recetario;

create policy recetario_todo on public.recetario
  for all to anon, authenticated
  using (true) with check (true);


-- 3. TABLA DE EXTRAS POR CATEGORÍA ----------------------------
-- Indicaciones que se muestran al final de la receta de todos los
-- productos de una categoría. Ej: "Shot de sabor extra", "Cambio de leche".
-- categoria = 'Todas' → aparece en todos los productos.
create table if not exists public.recetario_extras (
  id           uuid primary key default gen_random_uuid(),
  categoria    text not null,
  titulo       text not null,
  indicaciones text default '',
  orden        int  default 0,
  activo       boolean default true,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

create index if not exists recetario_extras_cat_idx
  on public.recetario_extras (categoria, orden);

drop trigger if exists recetario_extras_touch on public.recetario_extras;
create trigger recetario_extras_touch before update on public.recetario_extras
for each row execute function public.recetario_touch();

alter table public.recetario_extras enable row level security;
drop policy if exists recetario_extras_todo on public.recetario_extras;
create policy recetario_extras_todo on public.recetario_extras
  for all to anon, authenticated
  using (true) with check (true);


-- 4. BUCKET DE IMÁGENES ---------------------------------------
insert into storage.buckets (id, name, public)
values ('recetario', 'recetario', true)
on conflict (id) do update set public = true;

drop policy if exists recetas_img_lectura    on storage.objects;
drop policy if exists recetas_img_subir      on storage.objects;
drop policy if exists recetas_img_borrar     on storage.objects;
drop policy if exists recetas_img_actualizar on storage.objects;
drop policy if exists recetas_img_todo       on storage.objects;
drop policy if exists recetario_img_todo     on storage.objects;

create policy recetario_img_todo on storage.objects
  for all to anon, authenticated
  using (bucket_id = 'recetario') with check (bucket_id = 'recetario');


-- 5. LIMPIEZA de la versión con login (si la corriste) --------
drop function if exists public.es_admin();
drop function if exists public.touch_updated_at();
drop table    if exists public.admins;

-- ============================================================
--  Listo. No hay que crear usuarios ni nada más en Supabase.
--  Sigue en recetario-instalacion.md → paso 2.
-- ============================================================
