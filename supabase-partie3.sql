-- PARTIE 3 : droits d'accès, profils, moyens de paiement, déclarations de paiement
grant usage on schema public to anon, authenticated;
grant select, update on app_state to authenticated;
grant select on organisations, membres, abonnements to authenticated;
grant execute on function creer_organisation(text) to authenticated;

create table profils(user_id uuid primary key references auth.users on delete cascade, nom text, entreprise text, telephone text, photo text, updated_at timestamptz default now());
alter table profils enable row level security;
create policy "voir son profil" on profils for select using (user_id = auth.uid());
create policy "créer son profil" on profils for insert with check (user_id = auth.uid());
create policy "modifier son profil" on profils for update using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update on profils to authenticated;

create table admins(user_id uuid primary key references auth.users on delete cascade);
alter table admins enable row level security;
create policy "voir si admin" on admins for select using (user_id = auth.uid());
grant select on admins to authenticated;

create table config_paiement(id int primary key default 1 check (id = 1), data jsonb not null default '{}', updated_at timestamptz default now());
alter table config_paiement enable row level security;
create policy "lire la config" on config_paiement for select using (true);
create policy "créer la config" on config_paiement for insert with check (exists (select 1 from admins where user_id = auth.uid()));
create policy "modifier la config" on config_paiement for update using (exists (select 1 from admins where user_id = auth.uid())) with check (exists (select 1 from admins where user_id = auth.uid()));
grant select on config_paiement to anon, authenticated;
grant insert, update on config_paiement to authenticated;
insert into config_paiement(id, data) values (1, '{}') on conflict do nothing;

create table paiements(id bigint generated always as identity primary key, user_id uuid not null default auth.uid() references auth.users on delete cascade, email text, methode text not null, montant text, telephone text, reference text, statut text not null default 'en_attente', created_at timestamptz default now(), traite_le timestamptz);
alter table paiements enable row level security;
create policy "voir ses paiements" on paiements for select using (user_id = auth.uid() or exists (select 1 from admins where user_id = auth.uid()));
create policy "déclarer un paiement" on paiements for insert with check (user_id = auth.uid() and statut = 'en_attente');
create policy "admin modifie" on paiements for update using (exists (select 1 from admins where user_id = auth.uid()));
grant select, insert, update on paiements to authenticated;

create or replace function valider_paiement(pid bigint, jours int default 31) returns void language plpgsql security definer set search_path = public as $$
declare u uuid; o uuid;
begin
  if not exists (select 1 from admins where user_id = auth.uid()) then raise exception 'non autorisé'; end if;
  select user_id into u from paiements where id = pid;
  if u is null then raise exception 'paiement introuvable'; end if;
  select organisation_id into o from membres where user_id = u limit 1;
  if o is null then raise exception 'aucun espace pour cet utilisateur'; end if;
  insert into abonnements(organisation_id, plan, expire) values (o, 'pro', current_date + jours)
    on conflict (organisation_id) do update set plan = 'pro', expire = greatest(coalesce(abonnements.expire, current_date), current_date) + jours;
  update paiements set statut = 'valide', traite_le = now() where id = pid;
end $$;
grant execute on function valider_paiement(bigint, int) to authenticated;

-- DEVENIR ADMINISTRATEUR (à faire une seule fois, avec VOTRE e-mail) :
-- insert into admins(user_id) select id from auth.users where email = 'VOTRE_EMAIL';
