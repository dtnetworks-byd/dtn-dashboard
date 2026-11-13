-- DT Networks 서비스 대시보드 스키마
-- Supabase > SQL Editor 에 전체를 붙여넣고 실행하세요.
-- 여러 번 실행해도 안전합니다(이전 버전으로 만든 DB 는 부족한 칸만 추가됨).

-- 1) 계정 권한: admin(관리자) / editor(입력 가능) / viewer(조회만)
create table if not exists members (
  user_id uuid primary key references auth.users on delete cascade,
  memo text
);
alter table members add column if not exists email text;
alter table members add column if not exists role text not null default 'viewer';
alter table members drop constraint if exists members_role_check;
alter table members add constraint members_role_check check (role in ('admin', 'editor', 'viewer'));

-- 2) 열람 신청: 로그인은 했지만 아직 승인되지 않은 계정이 자동으로 남기는 기록
create table if not exists access_requests (
  user_id uuid primary key references auth.users on delete cascade,
  email text not null,
  created_at timestamptz not null default now()
);

-- 3) 브랜드 · 지점
create table if not exists shops (
  id bigint generated always as identity primary key,
  brand text not null default 'BYD',
  name text not null,
  created_at timestamptz not null default now()
);
alter table shops add column if not exists active boolean not null default true;   -- false: 브랜드 비활성화(화면에서 숨김)

-- 4) 항목
--    grp: 'intake'(입고 유형) | 'sales'(매출) | 'call_in'(콜 인입) | 'call_ok'(콜 수락) | 'etc'(기타 지표)
--         'promo'(프로모션) | 'recall'(리콜)  ← 관리자 페이지에서 수시로 추가
--    이름 끝의 괄호가 같으면(예: 입고대수(보증) ↔ 매출(보증)) 대당 매출이 자동 계산됨
create table if not exists metrics (
  id bigint generated always as identity primary key,
  name text not null unique,
  unit text not null default '대',
  grp text not null default 'intake'
);
alter table metrics add column if not exists brand text;                             -- 프로모션·리콜: 특정 브랜드 전용이면 브랜드명, 전체면 null
alter table metrics add column if not exists start_day date;                         -- 프로모션·리콜: 시작일
alter table metrics add column if not exists end_day date;                           -- 프로모션·리콜: 종료일(없으면 계속)
alter table metrics add column if not exists active boolean not null default true;   -- false: 입력 화면에서 숨김

-- 5) 일별 실적
create table if not exists entries (
  id bigint generated always as identity primary key,
  shop_id bigint not null references shops on delete cascade,
  metric_id bigint not null references metrics on delete cascade,
  day date not null,
  value numeric not null,
  unique (shop_id, metric_id, day)
);
create index if not exists entries_day_idx on entries (day);

-- 6) 일시정지 방지용 테이블 (GitHub Actions 가 하루 한 번 조회, 실적 데이터와 무관)
create table if not exists keepalive (id int primary key, note text);
insert into keepalive (id, note) values (1, 'ping') on conflict (id) do nothing;

-- 7) 보안(RLS)
create or replace function my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from members where user_id = auth.uid();
$$;
create or replace function is_member() returns boolean language sql stable as $$ select my_role() is not null; $$;
create or replace function can_edit()  returns boolean language sql stable as $$ select coalesce(my_role() in ('admin', 'editor'), false); $$;
create or replace function is_admin()  returns boolean language sql stable as $$ select coalesce(my_role() = 'admin', false); $$;

alter table members         enable row level security;
alter table access_requests enable row level security;
alter table shops           enable row level security;
alter table metrics         enable row level security;
alter table entries         enable row level security;
alter table keepalive       enable row level security;

-- 예전 버전 정책 정리
drop policy if exists members_self on members;
drop policy if exists shops_all on shops;
drop policy if exists metrics_all on metrics;
drop policy if exists entries_all on entries;

-- 계정: 본인 것은 조회 가능, 나머지는 관리자만
drop policy if exists members_read on members;
create policy members_read on members for select to authenticated using (user_id = auth.uid() or is_admin());
drop policy if exists members_admin on members;
create policy members_admin on members for all to authenticated using (is_admin()) with check (is_admin());

-- 열람 신청: 본인 이름으로만 신청 가능, 처리(삭제)는 관리자만
drop policy if exists requests_insert on access_requests;
create policy requests_insert on access_requests for insert to authenticated
  with check (user_id = auth.uid() and email = (auth.jwt() ->> 'email'));
drop policy if exists requests_read on access_requests;
create policy requests_read on access_requests for select to authenticated using (user_id = auth.uid() or is_admin());
drop policy if exists requests_delete on access_requests;
create policy requests_delete on access_requests for delete to authenticated using (is_admin());

-- 지점 · 항목: 조회는 승인된 계정, 변경은 관리자만
drop policy if exists shops_read on shops;
create policy shops_read on shops for select to authenticated using (is_member());
drop policy if exists shops_admin on shops;
create policy shops_admin on shops for all to authenticated using (is_admin()) with check (is_admin());
drop policy if exists metrics_read on metrics;
create policy metrics_read on metrics for select to authenticated using (is_member());
drop policy if exists metrics_admin on metrics;
create policy metrics_admin on metrics for all to authenticated using (is_admin()) with check (is_admin());

-- 실적: 조회는 승인된 계정, 입력·수정·삭제는 admin / editor
drop policy if exists entries_read on entries;
create policy entries_read on entries for select to authenticated using (is_member());
drop policy if exists entries_insert on entries;
create policy entries_insert on entries for insert to authenticated with check (can_edit());
drop policy if exists entries_update on entries;
create policy entries_update on entries for update to authenticated using (can_edit()) with check (can_edit());
drop policy if exists entries_delete on entries;
create policy entries_delete on entries for delete to authenticated using (can_edit());

drop policy if exists keepalive_read on keepalive;
create policy keepalive_read on keepalive for select to anon, authenticated using (true);

-- 8) 초기 데이터 (비어 있을 때만)
insert into shops (brand, name) select 'BYD', 'BYD 서비스센터' where not exists (select 1 from shops);
insert into metrics (name, unit, grp) values
  ('입고대수(일반)',     '대', 'intake'),
  ('입고대수(보증)',     '대', 'intake'),
  ('입고대수(사고수리)', '대', 'intake'),
  ('매출(일반)',     '만원', 'sales'),
  ('매출(보증)',     '만원', 'sales'),
  ('매출(사고수리)', '만원', 'sales'),
  ('콜 인입', '건', 'call_in'),
  ('콜 수락', '건', 'call_ok')
on conflict (name) do nothing;

-- 9) 첫 관리자 등록 (Authentication > Users 에서 본인 계정을 만든 뒤, 이메일을 바꿔서 실행)
--    이후 계정은 사이트의 관리자 페이지에서 승인·권한 변경을 합니다.
-- insert into members (user_id, email, role)
-- select id, email, 'admin' from auth.users where email = 'you@example.com'
-- on conflict (user_id) do update set role = 'admin', email = excluded.email;
