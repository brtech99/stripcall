-- Sync local schema with production (generated via supabase db diff --linked)
-- This migration ensures RLS policies and other schema elements match production exactly.
-- Generated: 2026-02-09
--
-- Key changes:
-- - Updates RLS policies to match production (notably problem_create_policy allows any authenticated user)
-- - Adds keep_alive_log table and function
-- - Updates various policy definitions for crews, events, users, responders, etc.

create sequence "public"."keep_alive_log_id_seq";

drop policy "crewmembers_update_policy" on "public"."crewmembers";

drop policy "crews_create_policy" on "public"."crews";

drop policy "crews_delete_policy" on "public"."crews";

drop policy "crews_update_policy" on "public"."crews";

drop policy "events_create_policy" on "public"."events";

drop policy "events_delete_policy" on "public"."events";

drop policy "events_update_policy" on "public"."events";

drop policy "notification_preferences_policy" on "public"."notification_preferences";

drop policy "oldproblemsymptom_delete_policy" on "public"."oldproblemsymptom";

drop policy "oldproblemsymptom_read_policy" on "public"."oldproblemsymptom";

drop policy "oldproblemsymptom_update_policy" on "public"."oldproblemsymptom";

drop policy "PendingUsersDeletePolicy" on "public"."pending_users";

drop policy "PendingUsersReadPolicy" on "public"."pending_users";

drop policy "problem_create_policy" on "public"."problem";

drop policy "problem_delete_policy" on "public"."problem";

drop policy "problem_read_policy" on "public"."problem";

drop policy "responders_create_policy" on "public"."responders";

drop policy "responders_delete_policy" on "public"."responders";

drop policy "responders_read_policy" on "public"."responders";

drop policy "responders_update_policy" on "public"."responders";

drop policy "users_create_policy" on "public"."users";

drop policy "users_delete_policy" on "public"."users";

drop policy "users_read_policy" on "public"."users";

drop policy "users_update_policy" on "public"."users";

alter table "public"."crew_messages" drop constraint "crew_messages_crew_fkey";

drop function if exists "public"."get_new_problems"(event_id text, since_time timestamp with time zone, crew_filter text);

create table "public"."keep_alive_log" (
    "id" bigint not null default nextval('keep_alive_log_id_seq'::regclass),
    "timestamp" timestamp with time zone default now()
);


alter table "public"."sms_reply_slots" drop column "message_id";

alter sequence "public"."keep_alive_log_id_seq" owned by "public"."keep_alive_log"."id";

CREATE UNIQUE INDEX keep_alive_log_pkey ON public.keep_alive_log USING btree (id);

alter table "public"."keep_alive_log" add constraint "keep_alive_log_pkey" PRIMARY KEY using index "keep_alive_log_pkey";

alter table "public"."crew_messages" add constraint "crew_messages_crew_fkey" FOREIGN KEY (crew) REFERENCES crews(id) ON DELETE CASCADE not valid;

alter table "public"."crew_messages" validate constraint "crew_messages_crew_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.keep_database_active()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Simple query to keep database active
  PERFORM count(*) FROM users LIMIT 1;

  -- Log the activity
  INSERT INTO public.keep_alive_log (timestamp)
  VALUES (now())
  ON CONFLICT DO NOTHING;

  RAISE NOTICE 'Database keep-alive executed at %', now();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_new_problems(event_id integer, since_time timestamp with time zone, crew_filter text)
 RETURNS SETOF problem
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  EXECUTE format('
    SELECT p.*,
           s.symptomstring,
           a.actionstring,
           m.*
    FROM problem p
    LEFT JOIN symptom s ON p.symptom = s.id
    LEFT JOIN action a ON p.action = a.id
    LEFT JOIN LATERAL (
      SELECT json_agg(m.*) as messages
      FROM messages m
      WHERE m.problem = p.id
    ) m ON true
    WHERE p.event = %L
      AND p.startdatetime > %L
      %s
    ORDER BY p.startdatetime DESC',
    event_id, since_time, crew_filter);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_new_problems(event_id text, since_time timestamp with time zone, crew_filter text)
 RETURNS SETOF problem
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  EXECUTE format('
    SELECT p.*,
           s.symptomstring,
           a.actionstring,
           m.*
    FROM problem p
    LEFT JOIN symptom s ON p.symptom = s.id
    LEFT JOIN action a ON p.action = a.id
    LEFT JOIN LATERAL (
      SELECT json_agg(m.*) as messages
      FROM messages m
      WHERE m.problem = p.id
    ) m ON true
    WHERE p.event = %L
      AND p.startdatetime > %L
      %s
    ORDER BY p.startdatetime DESC',
    event_id::int, since_time, crew_filter);
END;
$function$
;

grant delete on table "public"."keep_alive_log" to "anon";

grant insert on table "public"."keep_alive_log" to "anon";

grant references on table "public"."keep_alive_log" to "anon";

grant select on table "public"."keep_alive_log" to "anon";

grant trigger on table "public"."keep_alive_log" to "anon";

grant truncate on table "public"."keep_alive_log" to "anon";

grant update on table "public"."keep_alive_log" to "anon";

grant delete on table "public"."keep_alive_log" to "authenticated";

grant insert on table "public"."keep_alive_log" to "authenticated";

grant references on table "public"."keep_alive_log" to "authenticated";

grant select on table "public"."keep_alive_log" to "authenticated";

grant trigger on table "public"."keep_alive_log" to "authenticated";

grant truncate on table "public"."keep_alive_log" to "authenticated";

grant update on table "public"."keep_alive_log" to "authenticated";

grant delete on table "public"."keep_alive_log" to "service_role";

grant insert on table "public"."keep_alive_log" to "service_role";

grant references on table "public"."keep_alive_log" to "service_role";

grant select on table "public"."keep_alive_log" to "service_role";

grant trigger on table "public"."keep_alive_log" to "service_role";

grant truncate on table "public"."keep_alive_log" to "service_role";

grant update on table "public"."keep_alive_log" to "service_role";

create policy "crewmembers_update_policy"
on "public"."crewmembers"
as permissive
for update
to public
using ((is_superuser(auth.uid()) OR is_crew_chief(auth.uid(), crew)))
with check ((is_superuser(auth.uid()) OR is_crew_chief(auth.uid(), crew)));


create policy "crews_create_policy"
on "public"."crews"
as permissive
for insert
to public
with check (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR is_organizer(auth.uid()))));


create policy "crews_delete_policy"
on "public"."crews"
as permissive
for delete
to public
using (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = crews.event) AND (e.organizer = (auth.uid())::text)))) OR (crew_chief = (auth.uid())::text))));


create policy "crews_update_policy"
on "public"."crews"
as permissive
for update
to public
using (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = crews.event) AND (e.organizer = (auth.uid())::text)))) OR (crew_chief = (auth.uid())::text))))
with check (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = crews.event) AND (e.organizer = (auth.uid())::text)))) OR (crew_chief = (auth.uid())::text))));


create policy "events_create_policy"
on "public"."events"
as permissive
for insert
to public
with check (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR is_organizer(auth.uid()))));


create policy "events_delete_policy"
on "public"."events"
as permissive
for delete
to public
using (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (organizer = (auth.uid())::text))));


create policy "events_update_policy"
on "public"."events"
as permissive
for update
to public
using (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (organizer = (auth.uid())::text))))
with check (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (organizer = (auth.uid())::text))));


create policy "notification_preferences_policy"
on "public"."notification_preferences"
as permissive
for all
to public
using ((auth.role() = 'authenticated'::text));


create policy "oldproblemsymptom_delete_policy"
on "public"."oldproblemsymptom"
as permissive
for delete
to public
using (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())));


create policy "oldproblemsymptom_read_policy"
on "public"."oldproblemsymptom"
as permissive
for select
to public
using ((auth.role() = 'authenticated'::text));


create policy "oldproblemsymptom_update_policy"
on "public"."oldproblemsymptom"
as permissive
for update
to public
using (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())))
with check (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())));


create policy "PendingUsersDeletePolicy"
on "public"."pending_users"
as permissive
for delete
to public
using ((auth.role() = 'authenticated'::text));


create policy "PendingUsersReadPolicy"
on "public"."pending_users"
as permissive
for select
to public
using ((auth.role() = 'authenticated'::text));


create policy "problem_create_policy"
on "public"."problem"
as permissive
for insert
to public
with check ((auth.role() = 'authenticated'::text));


create policy "problem_delete_policy"
on "public"."problem"
as permissive
for delete
to public
using ((auth.role() = 'authenticated'::text));


create policy "problem_read_policy"
on "public"."problem"
as permissive
for select
to public
using ((auth.role() = 'authenticated'::text));


create policy "responders_create_policy"
on "public"."responders"
as permissive
for insert
to public
with check ((auth.role() = 'authenticated'::text));


create policy "responders_delete_policy"
on "public"."responders"
as permissive
for delete
to public
using ((auth.role() = 'authenticated'::text));


create policy "responders_read_policy"
on "public"."responders"
as permissive
for select
to public
using ((auth.role() = 'authenticated'::text));


create policy "responders_update_policy"
on "public"."responders"
as permissive
for update
to public
using (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())))
with check (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())));


create policy "users_create_policy"
on "public"."users"
as permissive
for insert
to public
with check ((auth.role() = 'authenticated'::text));


create policy "users_delete_policy"
on "public"."users"
as permissive
for delete
to public
using ((auth.role() = 'authenticated'::text));


create policy "users_read_policy"
on "public"."users"
as permissive
for select
to public
using ((auth.role() = 'authenticated'::text));


create policy "users_update_policy"
on "public"."users"
as permissive
for update
to public
using ((auth.role() = 'authenticated'::text))
with check ((auth.role() = 'authenticated'::text));


CREATE TRIGGER update_device_tokens_updated_at BEFORE UPDATE ON public.device_tokens FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
