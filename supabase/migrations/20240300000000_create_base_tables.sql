-- Create base tables in the correct order

-- Create users table
CREATE TABLE IF NOT EXISTS public.users (
  supabase_id text NOT NULL DEFAULT ''::text,
  firstname text,
  lastname text,
  phonenbr text,
  superuser boolean DEFAULT false,
  organizer boolean DEFAULT false,
  CONSTRAINT users_pkey PRIMARY KEY (supabase_id)
);

-- Create crewtypes table
CREATE TABLE IF NOT EXISTS public.crewtypes (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  crewtype text,
  CONSTRAINT crewtypes_pkey PRIMARY KEY (id)
);

-- Create events table
CREATE TABLE IF NOT EXISTS public.events (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  organizer text,
  city text,
  state text,
  startdatetime timestamp with time zone,
  enddatetime timestamp with time zone,
  stripnumbering text, -- Changed from USER-DEFINED to text
  count integer,
  name text,
  CONSTRAINT events_pkey PRIMARY KEY (id),
  CONSTRAINT events_organizer_fkey FOREIGN KEY (organizer) REFERENCES public.users(supabase_id)
);

-- Create crews table
CREATE TABLE IF NOT EXISTS public.crews (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  event bigint,
  crew_chief text,
  crew_type bigint,
  display_style text, -- Changed from USER-DEFINED to text
  CONSTRAINT crews_pkey PRIMARY KEY (id),
  CONSTRAINT crew_event_fkey FOREIGN KEY (event) REFERENCES public.events(id),
  CONSTRAINT crew_crewtype_fkey FOREIGN KEY (crew_type) REFERENCES public.crewtypes(id),
  CONSTRAINT crews_crew_chief_fkey FOREIGN KEY (crew_chief) REFERENCES public.users(supabase_id)
);

-- Create crewmembers table
CREATE TABLE IF NOT EXISTS public.crewmembers (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  crew bigint,
  crewmember text,
  CONSTRAINT crewmembers_pkey PRIMARY KEY (id),
  CONSTRAINT crewmembers_crew_fkey FOREIGN KEY (crew) REFERENCES public.crews(id),
  CONSTRAINT crewmembers_crewmember_fkey FOREIGN KEY (crewmember) REFERENCES public.users(supabase_id)
);

-- Create symptomclass table
CREATE TABLE IF NOT EXISTS public.symptomclass (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  symptomclassstring text,
  crewType bigint,
  CONSTRAINT symptomclass_pkey PRIMARY KEY (id),
  CONSTRAINT symptomclass_crewType_fkey FOREIGN KEY (crewType) REFERENCES public.crewtypes(id)
);

-- Create symptom table
CREATE TABLE IF NOT EXISTS public.symptom (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  symptomclass bigint,
  symptomstring text,
  CONSTRAINT symptom_pkey PRIMARY KEY (id),
  CONSTRAINT symptom_symptomclass_fkey FOREIGN KEY (symptomclass) REFERENCES public.symptomclass(id)
);

-- Create action table
CREATE TABLE IF NOT EXISTS public.action (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  symptomclass bigint,
  actionstring text,
  CONSTRAINT action_pkey PRIMARY KEY (id),
  CONSTRAINT action_symptomclass_fkey FOREIGN KEY (symptomclass) REFERENCES public.symptomclass(id)
);

-- Create problem table
CREATE TABLE IF NOT EXISTS public.problem (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  event bigint,
  crew bigint,
  originator text,
  strip text,
  symptom bigint,
  startdatetime timestamp with time zone,
  action bigint,
  actionby text,
  enddatetime timestamp with time zone,
  CONSTRAINT problem_pkey PRIMARY KEY (id),
  CONSTRAINT problem_crew_fkey FOREIGN KEY (crew) REFERENCES public.crews(id),
  CONSTRAINT problem_symptom_fkey FOREIGN KEY (symptom) REFERENCES public.symptom(id),
  CONSTRAINT problem_originator_fkey FOREIGN KEY (originator) REFERENCES public.users(supabase_id),
  CONSTRAINT problem_action_fkey FOREIGN KEY (action) REFERENCES public.action(id),
  CONSTRAINT problem_actionby_fkey FOREIGN KEY (actionby) REFERENCES public.users(supabase_id),
  CONSTRAINT problem_event_fkey FOREIGN KEY (event) REFERENCES public.events(id)
);

-- Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  crew bigint,
  author text,
  message text,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_crew_fkey FOREIGN KEY (crew) REFERENCES public.crews(id),
  CONSTRAINT messages_author_fkey FOREIGN KEY (author) REFERENCES public.users(supabase_id)
);

-- Create oldproblemsymptom table
CREATE TABLE IF NOT EXISTS public.oldproblemsymptom (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  problem bigint,
  oldsymptom bigint,
  changedby text,
  changedat timestamp with time zone,
  CONSTRAINT oldproblemsymptom_pkey PRIMARY KEY (id),
  CONSTRAINT oldproblemsymptom_oldsymptom_fkey FOREIGN KEY (oldsymptom) REFERENCES public.symptom(id),
  CONSTRAINT oldproblemsymptom_problem_fkey FOREIGN KEY (problem) REFERENCES public.problem(id),
  CONSTRAINT oldproblemsymptom_changedby_fkey FOREIGN KEY (changedby) REFERENCES public.users(supabase_id)
);

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crewtypes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crewmembers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.symptomclass ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.symptom ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.action ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.problem ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oldproblemsymptom ENABLE ROW LEVEL SECURITY; 