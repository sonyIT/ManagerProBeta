-- PARTIE 1 : tables et sécurité (à exécuter une seule fois dans SQL Editor)
create table organisations(id uuid primary key default gen_random_uuid(), name text not null, created_at timestamptz default now());
create table membres(organisation_id uuid references organisations on delete cascade, user_id uuid references auth.users on delete cascade, role text not null default 'admin', primary key(organisation_id,user_id));
create table app_state(organisation_id uuid primary key references organisations on delete cascade, data jsonb not null default '{}', updated_at timestamptz default now());
alter table organisations enable row level security;
alter table membres enable row level security;
alter table app_state enable row level security;
create policy "ses appartenances" on membres for select using (user_id = auth.uid());
create policy "ses organisations" on organisations for select using (id in (select organisation_id from membres where user_id = auth.uid()));
create policy "lire ses données" on app_state for select using (organisation_id in (select organisation_id from membres where user_id = auth.uid()));
create policy "modifier ses données" on app_state for update using (organisation_id in (select organisation_id from membres where user_id = auth.uid())) with check (organisation_id in (select organisation_id from membres where user_id = auth.uid()));

-- PARTIE 2 : offres (si vous avez déjà exécuté mon ancien script, exécutez seulement cette partie)
create table if not exists abonnements(organisation_id uuid primary key references organisations on delete cascade, plan text not null default 'gratuit', expire date);
alter table abonnements enable row level security;
create policy "voir son offre" on abonnements for select using (organisation_id in (select organisation_id from membres where user_id = auth.uid()));
create or replace function creer_organisation(nom text) returns uuid language plpgsql security definer set search_path = public as $$
declare o uuid;
begin
  insert into organisations(name) values (nom) returning id into o;
  insert into membres(organisation_id,user_id,role) values (o,auth.uid(),'admin');
  insert into app_state(organisation_id) values (o);
  insert into abonnements(organisation_id) values (o);
  return o;
end $$;

-- ACTIVER L'OFFRE PRO D'UN CLIENT APRÈS PAIEMENT (à la main au début) :
-- update abonnements set plan='pro', expire=current_date+31 where organisation_id=(select organisation_id from membres where user_id=(select id from auth.users where email='client@exemple.com'));
