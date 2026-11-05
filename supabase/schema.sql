-- Pesticide Shop ERP cloud identity + offline sync envelope.
-- Run once in Supabase SQL Editor as the project owner.
create extension if not exists pgcrypto;

create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 120),
  owner_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.shop_members (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','manager','assistant')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(shop_id,user_id)
);

-- One JSON record per local IndexedDB row. The browser uses UUID record IDs;
-- the server owns the canonical updated_at and updated_by values.
create table if not exists public.sync_records (
  shop_id uuid not null references public.shops(id) on delete cascade,
  table_name text not null check (table_name in ('companies','products','customers','sales','payments','purchases','suppliers','expenses','movements','settings','users')),
  record_id text not null,
  payload jsonb,
  is_deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  primary key(shop_id,table_name,record_id)
);
create index if not exists sync_records_shop_updated_idx on public.sync_records(shop_id,updated_at);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  actor_id uuid references auth.users(id),
  event_type text not null,
  table_name text,
  record_id text,
  created_at timestamptz not null default now(),
  details jsonb not null default '{}'::jsonb
);
create index if not exists audit_events_shop_created_idx on public.audit_events(shop_id,created_at desc);

alter table public.shops enable row level security;
alter table public.shop_members enable row level security;
alter table public.sync_records enable row level security;
alter table public.audit_events enable row level security;

-- No direct client table access to the sync payloads. Clients must use the
-- security-definer RPCs below, which apply membership and role checks.
-- No direct client policies are created. All access goes through the checked RPCs.
-- Deliberately no client policies on sync_records or audit_events.

create or replace function public.my_shops()
returns table(shop_id uuid, shop_name text, role text)
language sql security definer set search_path=public,auth
as $$
  select s.id,s.name,m.role from public.shop_members m join public.shops s on s.id=m.shop_id
  where m.user_id=auth.uid() and m.active order by s.created_at;
$$;
revoke all on function public.my_shops() from public;
grant execute on function public.my_shops() to authenticated;

create or replace function public.create_shop_and_owner(p_shop_name text)
returns uuid language plpgsql security definer set search_path=public,auth
as $$
declare v_shop uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if exists(select 1 from public.shop_members where user_id=auth.uid() and role='owner' and active) then
    raise exception 'This account already owns a shop';
  end if;
  if p_shop_name is null or length(trim(p_shop_name))<2 then raise exception 'Shop name is required'; end if;
  insert into public.shops(name,owner_id) values(trim(p_shop_name),auth.uid()) returning id into v_shop;
  insert into public.shop_members(shop_id,user_id,role) values(v_shop,auth.uid(),'owner');
  insert into public.audit_events(shop_id,actor_id,event_type,details) values(v_shop,auth.uid(),'shop.created',jsonb_build_object('name',trim(p_shop_name)));
  return v_shop;
end;
$$;
revoke all on function public.create_shop_and_owner(text) from public;
grant execute on function public.create_shop_and_owner(text) to authenticated;

create or replace function public.invite_shop_member(p_email text,p_role text)
returns uuid language plpgsql security definer set search_path=public,auth
as $$
declare v_shop uuid; v_user uuid; v_role text;
begin
  if p_role not in ('manager','assistant') then raise exception 'Role must be manager or assistant'; end if;
  select m.shop_id into v_shop from public.shop_members m where m.user_id=auth.uid() and m.role='owner' and m.active limit 1;
  if v_shop is null then raise exception 'Only the shop owner can add team members'; end if;
  select id into v_user from auth.users where lower(email)=lower(trim(p_email)) limit 1;
  if v_user is null then raise exception 'This person must create and verify their account before being added'; end if;
  insert into public.shop_members(shop_id,user_id,role,active) values(v_shop,v_user,p_role,true)
  on conflict(shop_id,user_id) do update set role=excluded.role,active=true;
  insert into public.audit_events(shop_id,actor_id,event_type,details) values(v_shop,auth.uid(),'member.added',jsonb_build_object('email',lower(trim(p_email)),'role',p_role));
  return v_user;
end;
$$;
revoke all on function public.invite_shop_member(text,text) from public;
grant execute on function public.invite_shop_member(text,text) to authenticated;

create or replace function public.sync_upsert_record(
  p_shop_id uuid,p_table_name text,p_record_id text,p_payload jsonb,p_is_deleted boolean default false
) returns void language plpgsql security definer set search_path=public,auth
as $$
declare v_role text; v_existing jsonb; v_payload jsonb;
begin
  select role into v_role from public.shop_members where shop_id=p_shop_id and user_id=auth.uid() and active;
  if v_role is null then raise exception 'You are not an active member of this shop'; end if;
  if p_table_name not in ('companies','products','customers','sales','payments','purchases','suppliers','expenses','movements','settings','users') then raise exception 'Unsupported record type'; end if;
  if p_record_id is null or length(p_record_id)>160 then raise exception 'Invalid record ID'; end if;
  if v_role='assistant' and p_table_name not in ('sales','payments','customers','products','movements') then raise exception 'Assistant role cannot modify this record type'; end if;
  if v_role='assistant' and p_is_deleted then raise exception 'Assistant role cannot delete records'; end if;
  if v_role='manager' and p_table_name in ('users','settings') then raise exception 'Manager role cannot modify this record type'; end if;
  v_payload:=p_payload;
  if v_role='assistant' and not p_is_deleted then
    if p_table_name='products' then
      select payload into v_existing from public.sync_records where shop_id=p_shop_id and table_name='products' and record_id=p_record_id and not is_deleted;
      if v_existing is null then raise exception 'Assistants cannot create products'; end if;
      -- Assistants can only alter the stock count; prices, costs, pack and identity remain owner-controlled.
      v_payload:=v_existing || jsonb_build_object('stock',coalesce(p_payload->'stock',v_existing->'stock'));
    elsif p_table_name='sales' then
      v_payload:=p_payload-'cost';
      if jsonb_typeof(v_payload->'items')='array' then
        select jsonb_set(v_payload,'{items}',coalesce(jsonb_agg(value-'cost'),'[]'::jsonb)) into v_payload from jsonb_array_elements(v_payload->'items');
      end if;
    elsif p_table_name='customers' then
      select payload into v_existing from public.sync_records where shop_id=p_shop_id and table_name='customers' and record_id=p_record_id and not is_deleted;
      if v_existing is not null then
        v_payload:=v_existing || jsonb_build_object('balance',coalesce(p_payload->'balance',v_existing->'balance'),'totalPurchases',coalesce(p_payload->'totalPurchases',v_existing->'totalPurchases'),'lastPurchaseDate',coalesce(p_payload->'lastPurchaseDate',v_existing->'lastPurchaseDate'));
      end if;
    end if;
  end if;
  insert into public.sync_records(shop_id,table_name,record_id,payload,is_deleted,updated_at,updated_by)
  values(p_shop_id,p_table_name,p_record_id,case when p_is_deleted then null else v_payload end,p_is_deleted,now(),auth.uid())
  on conflict(shop_id,table_name,record_id) do update set payload=excluded.payload,is_deleted=excluded.is_deleted,updated_at=now(),updated_by=auth.uid();
  insert into public.audit_events(shop_id,actor_id,event_type,table_name,record_id,details)
  values(p_shop_id,auth.uid(),case when p_is_deleted then 'record.deleted' else 'record.upserted' end,p_table_name,p_record_id,jsonb_build_object('role',v_role));
end;
$$;
revoke all on function public.sync_upsert_record(uuid,text,text,jsonb,boolean) from public;
grant execute on function public.sync_upsert_record(uuid,text,text,jsonb,boolean) to authenticated;

create or replace function public.sync_pull_records(p_shop_id uuid)
returns setof jsonb language plpgsql security definer set search_path=public,auth
as $$
declare v_role text;
begin
  select role into v_role from public.shop_members where shop_id=p_shop_id and user_id=auth.uid() and active;
  if v_role is null then raise exception 'You are not an active member of this shop'; end if;
  return query
  select jsonb_build_object(
    'table_name',r.table_name,'record_id',r.record_id,'payload',
    case when v_role='assistant' and r.table_name='products' then r.payload-'purchasePrice'-'wholesalePrice'-'minPrice'
         when v_role='assistant' and r.table_name='sales' then
           case when jsonb_typeof(r.payload->'items')='array' then jsonb_set(r.payload-'cost','{items}',coalesce((select jsonb_agg(i-'cost') from jsonb_array_elements(r.payload->'items') i),'[]'::jsonb)) else r.payload-'cost' end
         else r.payload end,
    'deleted_at',case when r.is_deleted then r.updated_at else null end,
    'updated_at',r.updated_at
  )
  from public.sync_records r
  where r.shop_id=p_shop_id
    and (v_role<>'assistant' or r.table_name not in ('purchases','suppliers','expenses','users'))
  order by r.updated_at;
end;
$$;
revoke all on function public.sync_pull_records(uuid) from public;
grant execute on function public.sync_pull_records(uuid) to authenticated;

-- Owner-only audit feed. The app's current UI does not yet expose this feed.
create or replace function public.get_audit_events(p_shop_id uuid,p_limit integer default 200)
returns setof public.audit_events language plpgsql security definer set search_path=public,auth
as $$
begin
  if not exists(select 1 from public.shop_members where shop_id=p_shop_id and user_id=auth.uid() and role='owner' and active) then raise exception 'Owner access required'; end if;
  return query select * from public.audit_events where shop_id=p_shop_id order by created_at desc limit least(greatest(p_limit,1),1000);
end;
$$;
revoke all on function public.get_audit_events(uuid,integer) from public;
grant execute on function public.get_audit_events(uuid,integer) to authenticated;
