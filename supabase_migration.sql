-- ==========================================
-- EVIDENCE HUB DATABASE MIGRATION SCRIPT
-- ==========================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Drop existing tables if they exist (for clean setup)
drop table if exists public.search_logs cascade;
drop table if exists public.activity_logs cascade;
drop table if exists public.favorites cascade;
drop table if exists public.evidence_snippets cascade;
drop table if exists public.references cascade;
drop table if exists public.categories cascade;
drop table if exists public.profiles cascade;

-- 1. Profiles Table
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text not null,
  email text not null,
  role text not null check (role in ('admin', 'editor', 'viewer')),
  department text,
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Categories Table
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name_en text not null,
  name_ar text not null,
  icon text, -- Identifier string for icons
  color text, -- Hex color code, e.g., '#009688'
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. References Table
create table public.references (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  title_ar text,
  organization text not null,
  reference_type text not null,
  category_id uuid references public.categories(id) on delete set null,
  publication_year integer not null,
  language text not null default 'en', -- 'en', 'ar'
  summary text,
  source_url text,
  vancouver_reference text,
  file_url text,
  file_name text,
  file_type text,
  file_size bigint,
  added_by uuid references public.profiles(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Evidence Snippets Table
create table public.evidence_snippets (
  id uuid primary key default gen_random_uuid(),
  reference_id uuid references public.references(id) on delete cascade not null,
  title text not null,
  title_ar text,
  evidence_text text not null,
  page_number integer,
  section_name text,
  category_id uuid references public.categories(id) on delete set null,
  keywords text[] default '{}',
  notes text,
  added_by uuid references public.profiles(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. Favorites Table
create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade not null,
  reference_id uuid references public.references(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, reference_id)
);

-- 6. Activity Logs Table
create table public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  description text not null,
  metadata jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. Search Logs Table
create table public.search_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  query text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ==========================================
-- INDEXES & SEARCH VECTORS
-- ==========================================

-- Standard B-Tree Indexes
create index idx_references_category on public.references(category_id);
create index idx_references_added_by on public.references(added_by);
create index idx_snippets_reference on public.evidence_snippets(reference_id);
create index idx_snippets_category on public.evidence_snippets(category_id);
create index idx_favorites_user on public.favorites(user_id);
create index idx_activity_logs_user on public.activity_logs(user_id);

-- Full Text Search Setup for references
alter table public.references add column search_vector tsvector;

create or replace function public.references_search_trigger() 
returns trigger as $$
begin
  new.search_vector :=
    to_tsvector('english', coalesce(new.title, '')) ||
    to_tsvector('arabic', coalesce(new.title_ar, '')) ||
    to_tsvector('english', coalesce(new.organization, '')) ||
    to_tsvector('english', coalesce(new.summary, '')) ||
    to_tsvector('english', coalesce(new.reference_type, ''));
  return new;
end
$$ language plpgsql;

create trigger tsvectorupdate_references 
  before insert or update on public.references 
  for each row execute procedure public.references_search_trigger();

create index references_search_idx on public.references using gin(search_vector);

-- Full Text Search Setup for evidence_snippets
alter table public.evidence_snippets add column search_vector tsvector;

create or replace function public.snippets_search_trigger() 
returns trigger as $$
begin
  new.search_vector :=
    to_tsvector('english', coalesce(new.title, '')) ||
    to_tsvector('arabic', coalesce(new.title_ar, '')) ||
    to_tsvector('english', coalesce(new.evidence_text, '')) ||
    to_tsvector('english', array_to_string(coalesce(new.keywords, '{}'), ' ')) ||
    to_tsvector('english', coalesce(new.section_name, ''));
  return new;
end
$$ language plpgsql;

create trigger tsvectorupdate_snippets 
  before insert or update on public.evidence_snippets 
  for each row execute procedure public.snippets_search_trigger();

create index snippets_search_idx on public.evidence_snippets using gin(search_vector);

-- ==========================================
-- PROFILE TRIGGERS & SECURITY HELPER FUNCTIONS
-- ==========================================

-- Trigger to create profile when auth.user is created
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email, role, department, is_active)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'User_' || substr(new.id::text, 1, 6)),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'role', 'viewer'),
    new.raw_user_meta_data->>'department',
    true
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Trigger to restrict profile updates (prevent self role-elevation and status changes)
create or replace function public.check_profile_update()
returns trigger as $$
declare
  current_user_role text;
begin
  -- Retrieve current user role from profiles
  select role into current_user_role from public.profiles where id = auth.uid();
  
  if current_user_role != 'admin' then
    if new.role != old.role or new.is_active != old.is_active then
      raise exception 'Only administrators can modify roles or active status.';
    end if;
  end if;
  
  new.updated_at := timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql security definer;

create trigger on_profile_update
  before update on public.profiles
  for each row execute procedure public.check_profile_update();

-- Helper security functions
create or replace function public.get_current_user_role()
returns text as $$
  select role from public.profiles where id = auth.uid();
$$ language sql security definer;

create or replace function public.is_current_user_active()
returns boolean as $$
  select is_active from public.profiles where id = auth.uid();
$$ language sql security definer;

-- ==========================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.references enable row level security;
alter table public.evidence_snippets enable row level security;
alter table public.favorites enable row level security;
alter table public.activity_logs enable row level security;
alter table public.search_logs enable row level security;

-- 1. Profiles Policies
create policy "Allow active profiles reading by active authenticated users"
  on public.profiles for select
  using (auth.uid() is not null and (select is_active from public.profiles where id = auth.uid()));

create policy "Allow profile updates by user themselves or admin"
  on public.profiles for update
  using (auth.uid() = id or (select role from public.profiles where id = auth.uid()) = 'admin');

create policy "Allow profile insert by admin only"
  on public.profiles for insert
  with check ((select role from public.profiles where id = auth.uid()) = 'admin');

-- 2. Categories Policies
create policy "Allow active categories reading by active authenticated users"
  on public.categories for select
  using (auth.uid() is not null and (select is_active from public.profiles where id = auth.uid()));

create policy "Allow full categories management by admin"
  on public.categories for all
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

-- 3. References Policies
create policy "Allow active references reading by active authenticated users"
  on public.references for select
  using (auth.uid() is not null and (select is_active from public.profiles where id = auth.uid()) and is_active = true);

create policy "Allow inactive references reading by admin/editors"
  on public.references for select
  using (auth.uid() is not null and (select role from public.profiles where id = auth.uid()) in ('admin', 'editor'));

create policy "Allow reference insert by editor or admin"
  on public.references for insert
  with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'editor') and added_by = auth.uid());

create policy "Allow reference update by owner editor or admin"
  on public.references for update
  using (
    (select role from public.profiles where id = auth.uid()) = 'admin' or 
    ((select role from public.profiles where id = auth.uid()) = 'editor' and added_by = auth.uid())
  );

create policy "Allow reference delete by admin only"
  on public.references for delete
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

-- 4. Evidence Snippets Policies
create policy "Allow active snippets reading by active authenticated users"
  on public.evidence_snippets for select
  using (auth.uid() is not null and (select is_active from public.profiles where id = auth.uid()));

create policy "Allow snippet insert by editor or admin"
  on public.evidence_snippets for insert
  with check ((select role from public.profiles where id = auth.uid()) in ('admin', 'editor') and added_by = auth.uid());

create policy "Allow snippet update by owner editor or admin"
  on public.evidence_snippets for update
  using (
    (select role from public.profiles where id = auth.uid()) = 'admin' or 
    ((select role from public.profiles where id = auth.uid()) = 'editor' and added_by = auth.uid())
  );

create policy "Allow snippet delete by admin only"
  on public.evidence_snippets for delete
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

-- 5. Favorites Policies
create policy "Allow users to view own favorites"
  on public.favorites for select
  using (auth.uid() = user_id);

create policy "Allow users to insert own favorites"
  on public.favorites for insert
  with check (auth.uid() = user_id);

create policy "Allow users to delete own favorites"
  on public.favorites for delete
  using (auth.uid() = user_id);

-- 6. Activity Logs Policies
create policy "Allow authenticated users to insert logs"
  on public.activity_logs for insert
  with check (auth.uid() is not null);

create policy "Allow admins to read activity logs"
  on public.activity_logs for select
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

-- 7. Search Logs Policies
create policy "Allow authenticated users to insert search logs"
  on public.search_logs for insert
  with check (auth.uid() is not null);

create policy "Allow admins to read search logs"
  on public.search_logs for select
  using ((select role from public.profiles where id = auth.uid()) = 'admin');

-- ==========================================
-- SEED DATA
-- ==========================================

-- Seed Categories
insert into public.categories (id, name_en, name_ar, icon, color) values
  ('c1000000-0000-0000-0000-000000000001', 'Hepatitis B', 'التهاب الكبد ب', 'coronavirus', '#00796B'),
  ('c1000000-0000-0000-0000-000000000002', 'Hepatitis C', 'التهاب الكبد ج', 'coronavirus', '#009688'),
  ('c1000000-0000-0000-0000-000000000003', 'HIV', 'فيروس نقص المناعة البشرية', 'medical_services', '#D32F2F'),
  ('c1000000-0000-0000-0000-000000000004', 'Syphilis', 'الزهري', 'healing', '#E91E63'),
  ('c1000000-0000-0000-0000-000000000005', 'Epidemiological Definitions', 'التعريفات الوبائية', 'menu_book', '#3F51B5'),
  ('c1000000-0000-0000-0000-000000000006', 'Surveillance', 'الترصد الوبائي', 'query_stats', '#673AB7'),
  ('c1000000-0000-0000-0000-000000000007', 'Laboratory', 'المختبر', 'science', '#00BCD4'),
  ('c1000000-0000-0000-0000-000000000008', 'Screening', 'الفحص والتقصي', 'person_search', '#4CAF50'),
  ('c1000000-0000-0000-0000-000000000009', 'Treatment', 'العلاج والمتابعة', 'medication', '#8BC34A'),
  ('c1000000-0000-0000-0000-000000000010', 'Contact Tracing', 'تقصي المخالطين', 'people', '#FF9800'),
  ('c1000000-0000-0000-0000-000000000011', 'High-Risk Populations', 'الفئات الأكثر عرضة', 'groups', '#795548'),
  ('c1000000-0000-0000-0000-000000000012', 'WHO Indicators', 'مؤشرات منظمة الصحة العالمية', 'analytics', '#2196F3'),
  ('c1000000-0000-0000-0000-000000000013', 'Ministry Circulars', 'التعاميم الوزارية', 'description', '#607D8B'),
  ('c1000000-0000-0000-0000-000000000014', 'Policies and Procedures', 'السياسات والإجراءات', 'rule', '#455A64'),
  ('c1000000-0000-0000-0000-000000000015', 'Statistical Reports', 'التقارير الإحصائية', 'poll', '#E65100');

-- Since we don't have user IDs in profiles yet (they are created via Supabase Auth),
-- we will use a dummy admin profile ID for references, but wait!
-- If we attempt to insert into public.references referencing public.profiles(id), we need the profiles to exist.
-- Let's create a system/dummy profile for seeding if needed, or allow added_by to be null.
-- Let's insert a dummy admin profile directly so that seed data works even before registration.
-- We can insert an auth.users record first, or just insert directly into profiles without checking auth.users.
-- Wait, profiles has a foreign key to auth.users. Let's make the references.added_by reference profiles(id),
-- which in turn references auth.users.
-- To avoid foreign key violations on auth.users when testing, we can insert dummy data with added_by set to NULL.
-- This is clean and safe.

-- Seed References (5 total)
insert into public.references (id, title, title_ar, organization, reference_type, category_id, publication_year, language, summary, source_url, vancouver_reference, is_active) values
  (
    'r1000000-0000-0000-0000-000000000001',
    'National Hepatitis B Contact Tracing Guideline',
    'الدليل الوطني لتقصي مخالطي التهاب الكبد ب',
    'Ministry of Health',
    'Guideline',
    'c1000000-0000-0000-0000-000000000010',
    2024,
    'en',
    'This is a comprehensive national guideline for tracing and managing contacts of Hepatitis B patients. (Dummy Data for clinical presentation purposes).',
    'https://www.moh.gov.sa',
    'Ministry of Health. National Hepatitis B Contact Tracing Guideline. Riyadh: MOH; 2024.',
    true
  ),
  (
    'r1000000-0000-0000-0000-000000000002',
    'Hepatitis C Screening Guideline',
    'الدليل الإرشادي لفحص التهاب الكبد ج',
    'Ministry of Health',
    'Guideline',
    'c1000000-0000-0000-0000-000000000008',
    2025,
    'en',
    'National protocols for Hepatitis C screening in high-risk populations. (Dummy Data for clinical presentation purposes).',
    'https://www.moh.gov.sa',
    'Ministry of Health. Hepatitis C Screening Guideline. Riyadh: MOH; 2025.',
    true
  ),
  (
    'r1000000-0000-0000-0000-000000000003',
    'Congenital Syphilis Epidemiological Definition',
    'التعريف الوبائي للزهري الخلقي',
    'Saudi CDC',
    'Epidemiological Definition',
    'c1000000-0000-0000-0000-000000000005',
    2023,
    'ar',
    'التعريف الوطني المعتمد لحالات الزهري الخلقي لأغراض الترصد الوبائي. (بيانات تجريبية لأغراض العرض فقط).',
    'https://www.cdc.gov.sa',
    'Saudi CDC. Congenital Syphilis Epidemiological Definition. Riyadh: SCDC; 2023.',
    true
  ),
  (
    'r1000000-0000-0000-0000-000000000004',
    'WHO Viral Hepatitis Indicators',
    'مؤشرات منظمة الصحة العالمية لالتهاب الكبد الفيروسي',
    'WHO',
    'WHO Document',
    'c1000000-0000-0000-0000-000000000012',
    2022,
    'en',
    'Global reporting templates and indicators for monitoring viral hepatitis elimination programs. (Dummy Data for clinical presentation purposes).',
    'https://www.who.int',
    'World Health Organization. WHO Viral Hepatitis Indicators. Geneva: WHO; 2022.',
    true
  ),
  (
    'r1000000-0000-0000-0000-000000000005',
    'Laboratory Turnaround Time Policy',
    'سياسة وقت الاستجابة للفحوصات المخبرية',
    'National Public Health Laboratory',
    'Policy',
    'c1000000-0000-0000-0000-000000000007',
    2024,
    'en',
    'Standard operating procedures defining acceptable time limits for reporting disease notification results. (Dummy Data for clinical presentation purposes).',
    'https://www.nphl.gov.sa',
    'National Public Health Laboratory. Laboratory Turnaround Time Policy. Riyadh: NPHL; 2024.',
    true
  );

-- Seed Evidence Snippets (2-3 per reference)
insert into public.evidence_snippets (reference_id, title, title_ar, evidence_text, page_number, section_name, category_id, keywords, notes) values
  -- Reference 1 Snippets
  (
    'r1000000-0000-0000-0000-000000000001',
    'Household Contact Screening',
    'فحص المخالطين المنزليين',
    'All household contacts of a newly diagnosed Hepatitis B case must be screened for HBsAg, anti-HBs, and anti-HBc. Non-immune contacts should receive the HBV vaccine series. (Dummy Data).',
    12,
    'Chapter 3: Tracing Protocols',
    'c1000000-0000-0000-0000-000000000010',
    array['hepatitis b', 'screening', 'contacts', 'vaccine'],
    'Highly recommended to verify vaccine availability before referral.'
  ),
  (
    'r1000000-0000-0000-0000-000000000001',
    'Infant Post-Exposure Prophylaxis',
    'الوقاية بعد التعرض للرضع',
    'Infants born to HBsAg-positive mothers must receive HBV vaccine and 0.5 mL of HBIG within 12 hours of birth. Dose 2 and 3 should follow standard schedules. (Dummy Data).',
    25,
    'Chapter 5: Perinatal Transmission',
    'c1000000-0000-0000-0000-000000000010',
    array['infant', 'hbig', 'perinatal', 'vaccination'],
    'Coordinate with delivery rooms directly.'
  ),
  -- Reference 2 Snippets
  (
    'r1000000-0000-0000-0000-000000000002',
    'High-Risk Group Screening Frequency',
    'تكرار الفحص للفئات الأكثر عرضة للخطورة',
    'Routine screening for Hepatitis C is recommended annually for individuals with history of intravenous drug use, hemodialysis, or occupational exposure. (Dummy Data).',
    5,
    'Section 2: High-Risk Groups',
    'c1000000-0000-0000-0000-000000000008',
    array['hepatitis c', 'screening', 'high-risk', 'hemodialysis'],
    'Confirm screening kits are WHO approved.'
  ),
  (
    'r1000000-0000-0000-0000-000000000002',
    'Confirmatory PCR Testing',
    'فحص تأكيد الحالات بالـ PCR',
    'Any specimen reactive to anti-HCV must be followed up with an HCV RNA PCR test to confirm active infection before initiating therapy. (Dummy Data).',
    9,
    'Section 4: Diagnostic Algorithm',
    'c1000000-0000-0000-0000-000000000008',
    array['pcr', 'hcv rna', 'confirmatory', 'diagnostics'],
    'Send samples to the regional laboratory.'
  ),
  -- Reference 3 Snippets
  (
    'r1000000-0000-0000-0000-000000000003',
    'Confirmed Case Definition',
    'تعريف الحالة المؤكدة',
    'A case is confirmed congenital syphilis when Treponema pallidum is identified by darkfield microscopy, PCR, or special stains in specimens from the placenta, umbilical cord, or autopsy material. (Dummy Data).',
    2,
    'القسم الأول: تصنيف الحالات',
    'c1000000-0000-0000-0000-000000000005',
    array['syphilis', 'congenital', 'pcr', 'case definition'],
    'أهمية الإبلاغ الفوري خلال 24 ساعة من التشخيص.'
  ),
  (
    'r1000000-0000-0000-0000-000000000003',
    'Probable Case Definition',
    'تعريف الحالة المحتملة',
    'A case is probable if the infant is born to a mother with untreated or inadequately treated syphilis at delivery, regardless of infant laboratory findings. (Dummy Data).',
    3,
    'القسم الأول: تصنيف الحالات',
    'c1000000-0000-0000-0000-000000000005',
    array['syphilis', 'probable case', 'clinical criteria'],
    'يتطلب المتابعة السريرية لمدة عام كامل.'
  ),
  -- Reference 4 Snippets
  (
    'r1000000-0000-0000-0000-000000000004',
    'Hepatitis B Third Dose Coverage Rate',
    'نسبة تغطية الجرعة الثالثة للقاح الكبد ب',
    'Indicator definition: Percentage of infants surviving to 1 year who received 3 doses of HepB vaccine. Target goal is >= 90% coverage globally. (Dummy Data).',
    44,
    'Annex A: Global Core Indicators',
    'c1000000-0000-0000-0000-000000000012',
    array['who', 'indicators', 'coverage', 'hepatitis b'],
    'Computed annually from national coverage statistics.'
  ),
  -- Reference 5 Snippets
  (
    'r1000000-0000-0000-0000-000000000005',
    'Standard Turnaround Times',
    'أوقات الاستجابة القياسية للعينات',
    'Epidemiological priority samples (e.g., suspected Measles, MERS, or Meningitis) must be processed and results reported within 24 hours of sample receipt. (Dummy Data).',
    7,
    'Policy Statement 1: Timeframes',
    'c1000000-0000-0000-0000-000000000007',
    array['tat', 'turnaround time', 'laboratory', 'priority'],
    'Logs must record exact receipt and dispatch times.'
  );
