--
-- PostgreSQL database dump
--

\restrict ASDb27DakR3NquW40oLqS0Nz63PSdJKPtjcXkCAtiNCgKBzmLe1bClJWx5R1XtD

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: activity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.activity_type AS ENUM (
    'started_reading',
    'finished_reading',
    'added_to_wishlist',
    'rated_book',
    'reviewed_book',
    'status_changed',
    'book_added',
    'favorite_toggled',
    'friend_added'
);


--
-- Name: delete_empty_conversation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_empty_conversation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM conversation_members
    WHERE conversation_id = OLD.conversation_id
  ) THEN
    DELETE FROM conversations
    WHERE id = OLD.conversation_id;
  END IF;

  RETURN NULL;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid NOT NULL,
    type text NOT NULL,
    external_book_id text,
    external_source text,
    created_at timestamp with time zone DEFAULT now(),
    object_type text,
    object_id text,
    target_type text,
    target_id text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT activities_external_source_check CHECK ((external_source = ANY (ARRAY['google_books'::text, 'open_library'::text]))),
    CONSTRAINT activities_type_check CHECK ((type = ANY (ARRAY['book_added'::text, 'started_reading'::text, 'finished_reading'::text, 'rated_book'::text, 'review_posted'::text, 'favorite_toggled'::text, 'dropped_book'::text])))
);


--
-- Name: books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.books (
    id text NOT NULL,
    title text NOT NULL,
    author text,
    description text,
    cover_url text,
    author_id text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: conversation_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation_members (
    conversation_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT now(),
    last_read_at timestamp with time zone,
    deleted_at timestamp with time zone
);


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text,
    created_at timestamp with time zone DEFAULT now(),
    is_ai boolean DEFAULT false,
    book_title text,
    book_author text,
    book_description text
);


--
-- Name: friend_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friend_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sender_id uuid NOT NULL,
    receiver_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT friend_requests_no_self CHECK ((sender_id <> receiver_id)),
    CONSTRAINT friend_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'rejected'::text, 'cancelled'::text])))
);


--
-- Name: friendships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    friend_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT friendships_no_self CHECK ((user_id <> friend_id))
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    sender_id uuid,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    user_id uuid NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    birthdate date,
    bio text,
    profile_image text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_books (
    id text NOT NULL,
    user_id uuid NOT NULL,
    book_id text NOT NULL,
    external_source text NOT NULL,
    status text NOT NULL,
    date_started date,
    date_finished date,
    rating numeric(3,2),
    review text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    favorite boolean DEFAULT false NOT NULL,
    CONSTRAINT user_books_external_source_check CHECK ((external_source = ANY (ARRAY['google_books'::text, 'open_library'::text]))),
    CONSTRAINT user_books_rating_check CHECK (((rating IS NULL) OR ((rating >= 0.25) AND (rating <= (5)::numeric) AND ((rating * (4)::numeric) = floor((rating * (4)::numeric)))))),
    CONSTRAINT user_books_status_check CHECK ((status = ANY (ARRAY['want_to_read'::text, 'reading'::text, 'completed'::text, 'dropped'::text])))
);


--
-- Name: user_books_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_books_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_books_id_seq OWNED BY public.user_books.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_books id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_books ALTER COLUMN id SET DEFAULT nextval('public.user_books_id_seq'::regclass);


--
-- Data for Name: activities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.activities (id, actor_id, type, external_book_id, external_source, created_at, object_type, object_id, target_type, target_id, metadata) FROM stdin;
86c7330f-ad72-42d8-8178-e882b1f61003	4c1ee880-50fb-4be8-8fd4-72c82c41c453	book_added	\N	\N	2026-02-26 15:05:38.88378-08	user_book	97	book	OL39316W	{"status": "want_to_read"}
72d930fc-e4fc-4631-890a-6e0a9fe12ab1	4c1ee880-50fb-4be8-8fd4-72c82c41c453	finished_reading	\N	\N	2026-02-26 15:55:51.810865-08	user_book	97	book	OL39316W	{}
27f3892f-336c-4da2-b1c2-ced27e541fd0	4c1ee880-50fb-4be8-8fd4-72c82c41c453	started_reading	\N	\N	2026-02-26 15:56:07.462328-08	user_book	97	book	OL39316W	{}
59e89a2c-e6e7-49a8-ac9a-e39753affed3	4c1ee880-50fb-4be8-8fd4-72c82c41c453	dropped_book	\N	\N	2026-02-26 15:59:15.401414-08	user_book	97	book	OL39316W	{}
c5ada656-98f1-44f6-a59b-2a6f3ef10e55	67dc1e40-f984-4fbb-8e85-789419d38348	started_reading	\N	\N	2026-02-26 16:19:51.09456-08	user_book	75	book	OL23166W	{}
62c5dcfb-9073-4793-939f-f0873202d312	67dc1e40-f984-4fbb-8e85-789419d38348	finished_reading	\N	\N	2026-02-26 16:20:22.726639-08	user_book	75	book	OL23166W	{}
7a995b5a-d65a-4228-a42a-e80fd29e4c7b	67dc1e40-f984-4fbb-8e85-789419d38348	rated_book	\N	\N	2026-02-26 16:20:48.175448-08	user_book	75	book	OL23166W	{"rating": 5}
4845d0bd-bcd3-4193-b22b-e21735bac6ad	67dc1e40-f984-4fbb-8e85-789419d38348	review_posted	\N	\N	2026-02-26 16:20:48.175448-08	user_book	75	book	OL23166W	{}
fcfce36c-8d4f-4838-b4b3-5dd9376c1ec0	4c1ee880-50fb-4be8-8fd4-72c82c41c453	book_added	\N	\N	2026-02-27 12:22:40.28151-08	user_book	110	book	OL498463W	{"status": "want_to_read"}
bfd1ec4c-a3b3-4da4-b8a9-6df99cab4895	4c1ee880-50fb-4be8-8fd4-72c82c41c453	book_added	\N	\N	2026-02-27 12:23:27.93563-08	user_book	111	book	OL52267W	{"status": "completed"}
b60a4400-6e37-451a-8e51-65f1161d6e28	4c1ee880-50fb-4be8-8fd4-72c82c41c453	book_added	\N	\N	2026-02-27 12:23:41.91573-08	user_book	112	book	OL258902W	{"status": "want_to_read"}
9e29645f-197b-4e98-824a-c45b6bd1e57a	67dc1e40-f984-4fbb-8e85-789419d38348	book_added	\N	\N	2026-02-27 14:25:14.539743-08	user_book	113	book	OL39316W	{"status": "want_to_read"}
3d2ef585-f3af-44f6-b459-31d856de27f6	67dc1e40-f984-4fbb-8e85-789419d38348	book_added	\N	\N	2026-02-27 14:25:34.63596-08	user_book	114	book	OL39316W	{"status": "completed"}
01561bc9-df8c-4fe6-aece-956ecbcb83f3	67dc1e40-f984-4fbb-8e85-789419d38348	dropped_book	\N	\N	2026-02-27 14:38:27.015508-08	user_book	114	book	OL39316W	{}
554560fb-ea86-4659-9559-2009a95e783a	67dc1e40-f984-4fbb-8e85-789419d38348	finished_reading	\N	\N	2026-02-27 14:38:28.635333-08	user_book	114	book	OL39316W	{}
f7672fc2-7fe3-432c-a451-538df3b68ba4	67dc1e40-f984-4fbb-8e85-789419d38348	started_reading	\N	\N	2026-02-27 14:38:29.824704-08	user_book	114	book	OL39316W	{}
4c1f3fcd-05a9-46ec-80b5-0bc58e15f4f4	4c1ee880-50fb-4be8-8fd4-72c82c41c453	finished_reading	\N	\N	2026-02-27 14:46:13.432012-08	user_book	85	book	OL85892W	{}
16cf01f3-1d4d-47f2-b44f-05b493e0b223	4c1ee880-50fb-4be8-8fd4-72c82c41c453	started_reading	\N	\N	2026-02-27 14:46:26.152404-08	user_book	112	book	OL258902W	{}
061c4cff-6982-47de-b503-50ae1b9b6be7	67dc1e40-f984-4fbb-8e85-789419d38348	book_added	\N	\N	2026-03-02 15:22:45.333244-08	user_book	122	book	OL85892W	{"status": "reading"}
6025636d-b8b3-48a8-986c-0ec5a5262dcd	67dc1e40-f984-4fbb-8e85-789419d38348	dropped_book	\N	\N	2026-03-02 15:22:49.531604-08	user_book	122	book	OL85892W	{}
838ce915-3080-40f2-bd74-11d5a472ebf8	67dc1e40-f984-4fbb-8e85-789419d38348	started_reading	\N	\N	2026-03-02 15:22:51.288932-08	user_book	122	book	OL85892W	{}
c8547f36-fbbc-4203-abb8-30e41857915f	b96e7980-dd22-4208-a29e-0279251fb944	book_added	\N	\N	2026-03-03 11:55:51.564695-08	user_book	126	book	OL258902W	{"status": "want_to_read"}
7d91ef0c-b75e-4d1c-9e91-1d6cc8076e48	b96e7980-dd22-4208-a29e-0279251fb944	book_added	\N	\N	2026-03-03 11:55:59.635656-08	user_book	127	book	OL7967812W	{"status": "reading"}
39679af2-1c96-4f77-b196-469c8a970bef	b96e7980-dd22-4208-a29e-0279251fb944	book_added	\N	\N	2026-03-03 11:56:12.400195-08	user_book	128	book	OL1168083W	{"status": "want_to_read"}
9f4568f5-d87e-4e3e-a61a-a1f75a0f4100	b96e7980-dd22-4208-a29e-0279251fb944	started_reading	\N	\N	2026-03-03 11:56:13.813745-08	user_book	128	book	OL1168083W	{}
1df90b99-928e-40b1-9142-cf57d37135bb	b96e7980-dd22-4208-a29e-0279251fb944	book_added	\N	\N	2026-03-03 11:56:26.521051-08	user_book	130	book	OL18173428W	{"status": "want_to_read"}
18499fd2-9f4f-40b8-9a5f-2c1d0afd9a09	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	book_added	\N	\N	2026-03-03 12:42:53.217595-08	user_book	131	book	OL848436W	{"status": "want_to_read"}
19c73d56-442a-42bd-a8fa-4833c5b7c1f4	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	book_added	\N	\N	2026-03-03 12:43:03.991011-08	user_book	132	book	OL1846076W	{"status": "reading"}
\.


--
-- Data for Name: books; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.books (id, title, author, description, cover_url, author_id, created_at, updated_at) FROM stdin;
OL1168083W	Nineteen Eighty-Four	George Orwell	Nineteen Eighty-Four: A Novel, often referred to as 1984, is a dystopian social science fiction novel by the English novelist George Orwell (the pen name of Eric Arthur Blair). It was published on 8 June 1949 by Secker & Warburg as Orwell's ninth and final book completed in his lifetime. Thematically, Nineteen Eighty-Four centres on the consequences of totalitarianism, mass surveillance, and repressive regimentation of persons and behaviours within society. Orwell, himself a democratic socialist, modelled the authoritarian government in the novel after Stalinist Russia. More broadly, the novel examines the role of truth and facts within politics and the ways in which they are manipulated.\r\n\r\n----------\t\t\r\nAlso contained in:\t\t\r\n[Novels (Animal Farm / Burmese Days / Clergyman's Daughter / Coming Up for Air / Keep the Aspidistra Flying / Nineteen Eighty-Four)](https://openlibrary.org/works/OL1168045W)\t\t\r\n[Novels (Animal Farm / Nineteen Eighty-Four)](https://openlibrary.org/works/OL1167981W)\r\n[Orwell's Nineteen Eighty-Four: Text, Sources, Criticism](https://openlibrary.org/works/OL1168095W)	https://covers.openlibrary.org/b/id/9267242-L.jpg	/authors/OL118077A	2026-02-11 18:35:16.617398	2026-02-11 18:35:16.617398
OL1168007W	Animal Farm	George Orwell	Animal Farm is a brilliant political satire and a powerful and affecting story of revolutions and idealism, power and corruption. 'All animals are equal. But some animals are more equal than others.' Mr Jones of Manor Farm is so lazy and drunken that one day he forgets to feed his livestock. The ensuing rebellion under the leadership of the pigs Napoleon and Snowball leads to the animals taking over the farm. Vowing to eliminate the terrible inequities of the farmyard, the renamed Animal Farm is organised to benefit all who walk on four legs. But as time passes, the ideals of the rebellion are corrupted, then forgotten. And something new and unexpected emerges..	https://covers.openlibrary.org/b/id/11261770-L.jpg	/authors/OL118077A	2026-02-12 10:09:07.260911	2026-02-12 10:09:07.260911
OL24633409W	Credence	Penelope Douglas	From New York Times bestselling author, Penelope Douglas, comes a new standalone!\r\n\r\nThree of them, one of her, and a remote cabin in the woods. Let the hot, winter nights ensue...\r\n\r\nTiernan de Haas doesn't care about anything anymore. The only child of a film producer and his starlet wife, she's grown up with wealth and privilege but not love or guidance. Shipped off to boarding schools from an early age, it was still impossible to escape the loneliness and carve out a life of her own. The shadow of her parents' fame followed her everywhere.\r\n\r\nAnd when they suddenly pass away, she knows she should be devastated. But has anything really changed? She's always been alone, hasn't she?\r\n\r\nJake Van der Berg, her father's stepbrother and her only living relative, assumes guardianship of Tiernan who is still two months shy of eighteen. Sent to live with him and his two sons, Noah and Kaleb, in the mountains of Colorado, Tiernan soon learns that these men now have a say in what she chooses to care and not care about anymore.\r\n\r\nAs the three of them take her under their wing, teach her to work and survive in the remote woods far away from the rest of the world, she slowly finds her place among them. And as a part of them.\r\n\r\nShe also realizes that lines blur and rules become easy to break when no one else is watching.\r\n\r\nOne of them has her. The other one wants her. But he...\r\n\r\nHe's going to keep her.	https://covers.openlibrary.org/b/id/11311896-L.jpg	/authors/OL7680979A	2026-02-12 10:22:55.71495	2026-02-12 10:22:55.71495
OL34774028W	Powerless	Lauren Roberts	Only the extraordinary belong in the kingdom of Ilya—the exceptional, the empowered, the Elites.\r\n\r\nThe powers these Elites have possessed for decades were graciously gifted to them by the Plague, though not all were fortunate enough to both survive the sickness and reap the reward. Those born Ordinary are just that—ordinary. And when the king decreed that all Ordinaries be banished in order to preserve his Elite society, lacking an ability suddenly became a crime—making Paedyn Gray a felon by fate and a thief by necessity.\r\n\r\nSurviving in the slums as an Ordinary is no simple task, and Paedyn knows this better than most. Having been trained by her father to be overly observant since she was a child, Paedyn poses as a Psychic in the crowded city, blending in with the Elites as best she can in order to stay alive and out of trouble. Easier said than done.\r\n\r\nWhen Paeydn unsuspectingly saves one of Ilyas princes, she finds herself thrown into the Purging Trials. The brutal competition exists to showcase the Elites’ powers—the very thing Paedyn lacks. If the Trials and the opponents within them don’t kill her, the prince she’s fighting feelings for certainly will if he discovers what she is—completely Ordinary.	https://covers.openlibrary.org/b/id/14567864-L.jpg	/authors/OL11086929A	2026-02-12 10:42:16.864128	2026-02-12 10:42:16.864128
OL2172524W	Valis	Philip K. Dick	\N	https://covers.openlibrary.org/b/id/9251944-L.jpg	/authors/OL274606A	2026-02-13 11:01:54.780134	2026-02-13 11:01:54.780134
OL28429W	Schachnovelle	Stefan Zweig	Auf einem Passagierdampfer, der von New York nach Buenos Aires unterwegs ist, fordert ein Millionär gegen Honorar den mit einer Art mechanischer Präzision spielenden Schachweltmeister Mirko Czentovic zu einer Partie heraus. Der mitreisende Dr. B., ein österreichischer Emigrant, greift beratend ein und erreicht so ein Remis für den Herausforderer. Er hat sich, von der Gestapo, die ihn verhaftete, in ein Hotelzimmer gesperrt und von der Außenwelt hermetisch abgeschlossen, monatelang mit dem blinden Spiel von 150 Partien beschäftigt, um sich so seine intellektuelle Widerstandskraft zu erhalten. Durch diese einseitige geistige Anstrengung ergriff ihn ein Nervenfieber, dessentwegen man ihn entließ. Jetzt spielt Dr. B. zum ersten Mal wieder gegen einen tatsächlichen, freilich roboterhaft reagierenden Gegner. Es geht ihm bei dieser Partie lediglich darum, festzustellen, ob sein Tun damals während seiner Haft noch Spiel oder bereits Wahnsinn gewesen ist. Er schlägt den Weltmeister in der ersten Partie souverän, läßt sich aber, eigentlich gegen seinen Willen, auf eine Revanche ein. Während dieser zweiten Partie ergreift ihn wieder das Nervenfieber: er bricht die Partie ab und wird nie wieder ein Schachbrett berühren.	https://covers.openlibrary.org/b/id/5548285-L.jpg	/authors/OL26439A	2026-02-13 11:02:27.296224	2026-02-13 11:02:27.296224
OL17860744W	A Court of Mist and Fury	Sarah J. Maas	Feyre has undergone more trials than one human woman can carry in her heart. Though she's now been granted the powers and lifespan of the High Fae, she is haunted by her time Under the Mountain and the terrible deeds she performed to save the lives of Tamlin and his people.\r\n\r\nAs her marriage to Tamlin approaches, Feyre's hollowness and nightmares consume her. She finds herself split into two different people: one who upholds her bargain with Rhysand, High Lord of the feared Night Court, and one who lives out her life in the Spring Court with Tamlin. While Feyre navigates a dark web of politics, passion, and dazzling power, a greater evil looms. She might just be the key to stopping it, but only if she can harness her harrowing gifts, heal her fractured soul, and decide how she wishes to shape her future-and the future of a world in turmoil.\r\n\r\nBestselling author Sarah J. Maas's masterful storytelling brings this second book in her dazzling, sexy, action-packed series to new heights.	https://covers.openlibrary.org/b/id/14315081-L.jpg	/authors/OL7115219A	2026-02-17 10:37:18.551771	2026-02-17 10:37:18.551771
OL498556W	Die Verwandlung	Franz Kafka	Metamorphosis (German: Die Verwandlung) is a novella written by Franz Kafka which was first published in 1915. One of Kafka's best-known works, Metamorphosis tells the story of salesman Gregor Samsa, who wakes one morning to find himself inexplicably transformed into a huge insect (German: ungeheueres Ungeziefer, lit. "monstrous vermin") and subsequently struggles to adjust to this new condition. The novella has been widely discussed among literary critics, with differing interpretations being offered. In popular culture and adaptations of the novella, the insect is commonly depicted as a cockroach.\r\n\r\nWith a length of about 70 printed pages over three chapters, it is the longest of the stories Kafka considered complete and published during his lifetime. The text was first published in 1915 in the October issue of the journal Die weißen Blätter under the editorship of René Schickele. The first edition in book form appeared in December 1915 in the series Der jüngste Tag, edited by Kurt Wolff.	https://covers.openlibrary.org/b/id/12820198-L.jpg	/authors/OL33146A	2026-02-17 10:38:20.799992	2026-02-17 10:38:20.799992
OL498463W	Der Proceß	Franz Kafka	Byzantine and claustrophobic novel of a man arrested by the secret police and charged with an unspecified crime. Unable to defend himself and disorientated by the legal process at work around him the man soon becomes apathetic and acquiescent, accepting his eventual sentence as inevitable.	https://covers.openlibrary.org/b/id/997423-L.jpg	/authors/OL33146A	2026-02-17 10:38:35.473394	2026-02-17 10:38:35.473394
OL2172403W	The Man in the High Castle	Philip K. Dick	The Man in the High Castle is an alternate history novel by American writer Philip K. Dick. Published and set in 1962, the novel takes place fifteen years after an alternative ending to World War II, and concerns intrigues between the victorious Axis Powers—primarily, Imperial Japan and Nazi Germany—as they rule over the former United States, as well as daily life under the resulting totalitarian rule. The Man in the High Castle won the Hugo Award for Best Novel in 1963. Beginning in 2015, the book was adapted as a multi-season TV series, with Dick's daughter, Isa Dick Hackett, serving as one of the show's producers.\r\n\r\nReported inspirations include Ward Moore's alternate Civil War history, Bring the Jubilee (1953), various classic World War II histories, and the I Ching (referred to in the novel). The novel features a "novel within the novel" comprising an alternate history within this alternate history wherein the Allies defeat the Axis (though in a manner distinct from the actual historical outcome).	https://covers.openlibrary.org/b/id/420452-L.jpg	/authors/OL274606A	2026-02-17 10:39:40.713305	2026-02-17 10:39:40.713305
OL46125W	Foundation	Isaac Asimov	One of the great masterworks of science fiction, the Foundation novels of Isaac Asimov are unsurpassed for their unique blend of nonstop action, daring ideas, and extensive world-building. \r\n\r\nThe story of our future begins with the history of Foundation and its greatest psychohistorian: Hari Seldon.  For twelve thousand years the Galactic Empire has ruled supreme. Now it is dying.  Only Hari Seldon, creator of the revolutionary science of psychohistory, can see into the future--a dark age of ignorance, barbarism, and warfare that will last thirty thousand years. To preserve knowledge and save mankind, Seldon gathers the best minds in the Empire--both scientists and scholars--and brings them to a bleak planet at the edge of the Galaxy to serve as a beacon of hope for future generations. He calls his sanctuary the Foundation.\r\n\r\nBut soon the fledgling Foundation finds itself at the mercy of corrupt warlords rising in the wake of the receding Empire. And mankind's last best hope is faced with an agonizing choice: submit to the barbarians and live as slaves--or take a stand for freedom and risk total destruction.	https://covers.openlibrary.org/b/id/14612610-L.jpg	/authors/OL34221A	2026-02-17 10:40:07.147485	2026-02-17 10:40:07.147485
OL46241W	Les Robots	Isaac Asimov	I, Robot is a fixup novel of science fiction short stories or essays by American writer Isaac Asimov. The stories originally appeared in the American magazines Super Science Stories and Astounding Science Fiction between 1940 and 1950 and were then compiled into a book for stand-alone publication by Gnome Press in 1950, in an initial edition of 5,000 copies. The stories are woven together by a framing narrative in which the fictional Dr. Susan Calvin tells each story to a reporter (who serves as the narrator) in the 21st century. Although the stories can be read separately, they share a theme of the interaction of humans, robots, and morality, and when combined they tell a larger story of Asimov's fictional history of robotics.\r\n\r\n\r\n----------\r\n\r\nContains:\r\n"Introduction" \r\n"Robbie" (1940, 1950)\r\n"Runaround" (1942)\r\n"Reason" (1941)\r\n"Catch That Rabbit" (1944)\r\n"Liar!" (1941)\r\n"Little Lost Robot" (1947)\r\n"Escape!" (1945)\r\n"Evidence" (1946)\r\n"The Evitable Conflict" (1950)	https://covers.openlibrary.org/b/id/12385229-L.jpg	/authors/OL34221A	2026-02-17 10:40:23.05663	2026-02-17 10:40:23.05663
OL103123W	Fahrenheit 451	Ray Bradbury	Fahrenheit 451 is a 1953 dystopian novel by American writer Ray Bradbury. Often regarded as one of his best works, the novel presents a future American society where books are outlawed and "firemen" burn any that are found. The book's tagline explains the title as "'the temperature at which book paper catches fire, and burns": the autoignition temperature of paper. The lead character, Guy Montag, is a fireman who becomes disillusioned with his role of censoring literature and destroying knowledge, eventually quitting his job and committing himself to the preservation of literary and cultural writings.\r\n\r\nThe novel has been the subject of interpretations focusing on the historical role of book burning in suppressing dissenting ideas for change. In a 1956 radio interview, Bradbury said that he wrote Fahrenheit 451 because of his concerns at the time (during the McCarthy era) about the threat of book burning in the United States. In later years, he described the book as a commentary on how mass media reduces interest in reading literature.\r\n\r\nIn 1954, Fahrenheit 451 won the American Academy of Arts and Letters Award in Literature and the Commonwealth Club of California Gold Medal. It later won the Prometheus "Hall of Fame" Award in 1984 and a "Retro" Hugo Award, one of a limited number of Best Novel Retro Hugos ever given, in 2004. Bradbury was honored with a Spoken Word Grammy nomination for his 1976 audiobook version.\r\n\r\n\r\n----------\r\nAlso contained in:\r\n\r\n - [451° по Фаренгейту: Рассказы](https://openlibrary.org/works/OL17811384W/Fahrenheit_451_stories)\r\n - [451° по Фаренгейту: повести и рассказы](https://openlibrary.org/works/OL27741633W)\r\n - [Works](https://openlibrary.org/works/OL28185143W)	https://covers.openlibrary.org/b/id/12993656-L.jpg	/authors/OL24137A	2026-02-17 10:40:38.335473	2026-02-17 10:40:38.335473
OL23204W	Of Mice and Men	John Steinbeck	The second book in John Steinbeck’s labor trilogy, Of Mice and Men is a touching tale of two migrant laborers in search of work and eventual liberation from their social circumstances. Fiercely devoted to one another, George and Lennie plan to save up to finance their dream of someday owning a small piece of land. The pair seems unstoppable until tragedy strikes and their hopes come crashing down, forcing George to make a difficult decision regarding the welfare of his best friend.\r\n\r\nThe novel is set on a ranch in Soledad, CA. Author Frank Bergon recalls reading Of Mice and Men for the first time as a teenager living in the San Joaquin Valley and remembers how he saw “as if in a jolt of light the ordinary surroundings of [his] life become worthy of literature.” Steinbeck works to propagate the notion that meaningful stories emerge from the marginalized; that even those on the fringes of society can make deserving contributions to the literary canon.\r\n\r\nSource: http://www.steinbeck.org/about-john/his-works/\r\n\r\n\r\n----------\r\nAlso contained in:\r\n - [Cannery Row / Of Mice and Men](https://openlibrary.org/works/OL23172W/Cannery_Row_Of_Mice_and_Men)\r\n - [Grapes of Wrath / The Moon is Down / Cannery Row / East of Eden / Of Mice and Men][1]\r\n - [Novels and Stories 1932-1937](https://openlibrary.org/works/OL23167W)\r\n - [Short Novels of John Steinbeck](https://openlibrary.org/works/OL23185W/The_Short_Novels_of_John_Steinbeck)\r\n - [Steinbeck](https://openlibrary.org/works/OL23183W/Steinbeck)\r\n - [Steinbeck Pocket Book](https://openlibrary.org/works/OL16051131W/The_Steinbeck_Pocket_Book)\r\n\r\n  [1]: https://openlibrary.org/works/OL23165W/The_Grapes_of_Wrath_The_Moon_is_Down_Cannery_Row_East_of_Eden_Of_Mice_and_Men	https://covers.openlibrary.org/b/id/14319003-L.jpg	/authors/OL25788A	2026-02-17 12:42:21.450339	2026-02-17 12:42:21.450339
OL26446888W	The Odyssey	Όμηρος	A new translation of the epic poem retells the story of Odysseus's ten-year voyage home to Ithaca after the Trojan War.	https://covers.openlibrary.org/b/id/12474938-L.jpg	/authors/OL18404A	2026-02-17 12:43:03.181963	2026-02-17 12:43:03.181963
OL17116910W	The Nightingale	Kristin Hannah	Despite their differences, sisters Vianne and Isabelle have always been close. Younger, bolder Isabelle lives in Paris while Vianne is content with life in the French countryside with her husband Antoine and their daughter. But when the Second World War strikes, Antoine is sent off to fight and Vianne finds herself isolated so Isabelle is sent by their father to help her. \r\n\r\nAs the war progresses, the sisters' relationship and strength are tested. With life changing in unbelievably horrific ways, Vianne and Isabelle will find themselves facing frightening situations and responding in ways they never thought possible as bravery and resistance take different forms in each of their actions.	https://covers.openlibrary.org/b/id/8314147-L.jpg	/authors/OL30522A	2026-02-17 12:43:24.059041	2026-02-17 12:43:24.059041
OL28952677W	Icebreaker	Hannah Grace	**A TikTok sensation! Sparks fly when a competitive figure skater and hockey team captain are forced to share a rink.**\r\n\r\nAnastasia Allen has worked her entire life for a shot at Team USA. It looks like everything is going according to plan when she gets a full scholarship to the University of California, Maple Hills and lands a place on their competitive figure skating team.\r\n\r\nNothing will stand in her way, not even the captain of the hockey team, Nate Hawkins.\r\n\r\nNate is focus as team captain is on keeping his team on the ice. Which is tricky when a facilities mishap means they are forced to share a rink with the figure skating team including Anastasia, who clearly can't stand him.\r\n\r\nBut when Anastasia's skating partner faces an uncertain future, she may have to look to Nate to take her shot.\r\n\r\nSparks fly, but Anastasia isn't worried because she could never like a hockey player, right?	https://covers.openlibrary.org/b/id/13180728-L.jpg	/authors/OL2992103A	2026-02-17 12:43:40.686863	2026-02-17 12:43:40.686863
OL46337W	Robot Visions	Isaac Asimov	Collection of science fiction short stories and factual essays\r\n\r\n**Short stories:**\r\nRobot visions\r\nToo bad!\r\n[Robbie](https://openlibrary.org/works/OL46260W)\r\nLiar!\r\nRunaround\r\nEvidence\r\nLittle lost robot\r\nThe Evitable conflict\r\nFeminine intuition\r\nThe Bicentennial man\r\nSomeday\r\nThink!\r\nSegregationist\r\nMirror image\r\nLenny\r\nGalley slave\r\nChristmas without Rodney \r\n\r\n**Essays:** \r\nRobots I have known\r\nThe New teachers\r\nWhatever you wish\r\nThe Friends we make\r\nOur intelligent tools\r\nThe Laws of robotics\r\nFuture fantastic\r\nThe gachine and the robot\r\nThe Robot as enemy?\r\nIntelligences together\r\nMy robots\r\nThe Laws of humanics\r\nCybernetic organism\r\nThe Sense of humor\r\nRobots in combination	https://covers.openlibrary.org/b/id/12003851-L.jpg	/authors/OL34221A	2026-02-17 12:44:30.466174	2026-02-17 12:44:30.466174
OL35085373W	Titus Andronicus	William Shakespeare	\N	https://covers.openlibrary.org/b/id/14065290-L.jpg	/authors/OL9388A	2026-02-17 12:44:54.146193	2026-02-17 12:44:54.146193
OL675783W	The Handmaid's Tale	Margaret Atwood	The Handmaid's Tale is a dystopian novel by Canadian author Margaret Atwood, published in 1985. It is set in a near-future New England, in a strongly patriarchal, totalitarian theonomic state, known as the Republic of Gilead, which has overthrown the United States government. The central character and narrator is a woman named Offred, one of the group known as "handmaids", who are forcibly assigned to produce children for the "commanders" — the ruling class of men in Gilead.\r\n\r\nThe novel explores themes of subjugated women in a patriarchal society, loss of female agency and individuality, and the various means by which they resist and attempt to gain individuality and independence.\r\n\r\nThe Handmaid's Tale won the 1985 Governor General's Award and the first Arthur C. Clarke Award in 1987; it was also nominated for the 1986 Nebula Award, the 1986 Booker Prize, and the 1987 Prometheus Award.\r\n\r\n\r\n----------\r\nAlso contained in:\r\n[Novels](https://openlibrary.org/works/OL24301311W)	https://covers.openlibrary.org/b/id/8231851-L.jpg	/authors/OL52922A	2026-02-17 12:45:35.53921	2026-02-17 12:45:35.53921
OL810991W	Paradise Lost	John Milton	John Milton's Paradise Lost is one of the greatest epic poems in the English language. It tells the story of the Fall of Man, a tale of immense drama and excitement, of rebellion and treachery, of innocence pitted against corruption, in which God and Satan fight a bitter battle for control of mankind's destiny. The struggle rages across three worlds - heaven, hell, and earth - as Satan and his band of rebel angels plot their revenge against God. At the center of the conflict are Adam and Eve, who are motivated by all too human temptations but whose ultimate downfall is unyielding love.\r\n\r\nMarked by Milton's characteristic erudition, Paradise Lost is a work epic both in scale and, notoriously, in ambition. For nearly 350 years, it has held generation upon generation of audiences in rapt attention, and its profound influence can be seen in almost every corner of Western culture.	https://covers.openlibrary.org/b/id/5992814-L.jpg	/authors/OL68333A	2026-02-17 12:47:31.326584	2026-02-17 12:47:31.326584
OL23166W	East of Eden	John Steinbeck	Steinbeck considered East of Eden to be his masterpiece. In his journal, Journal of a Novel (often read as a companion to the novel) he notes that “this is the book I have always wanted and have worked and prayed to be able to write Set primarily in the Salinas Valley in the early twentieth century, the novel traces three generations of two families – the Trasks and the Hamiltons – as they grapple with the ever-present forces of good and evil. From this plot emerged some of Steinbeck’s most fascinating characters – many of whom are modeled after people in his own life.\r\n\r\nPart allegory, part autobiography, and part epic, East of Eden was an ambitious project from the start – a gift to Steinbeck’s sons that was meant to teach them about identity, grief, and what it means to be human. Tinged with biblical echoes of the fall of Adam and Eve and the rivalry of Cain and Abel, this sprawling saga has captivated audiences everywhere for generations. It is through the popularization of East of Eden that the Salinas Valley was truly transformed into “the valley of the world”; a place where everyone is able to find a piece of themselves in the golden, rolling hills.\r\n([source][1])\r\n\r\n\r\n----------\r\nContains:\r\n\r\n - [East of Eden 1/2][2]\r\n - [East of Eden 2/2][3]\r\n\r\n----------\r\nAlso contained in:\r\n\r\n - [East of Eden / The Wayward Bus][4]\r\n - [The Grapes of Wrath / The Moon is Down / Cannery Row / East of Eden / Of Mice and Men][5]\r\n - [Novels 1942-1952](https://openlibrary.org/works/OL15334093W/Novels_1942-1952)\r\n - [Reader's Digest Condensed Books: Spring 1953 Selections](https://openlibrary.org/works/OL15158232W)\r\n\r\n\r\n  [1]: http://www.steinbeck.org/about-john/his-works/\r\n  [2]: https://openlibrary.org/works/OL17811975W/East_of_Eden_1_2\r\n  [3]: https://openlibrary.org/works/OL18023025W/East_of_Eden_2_2\r\n  [4]: https://openlibrary.org/works/OL15138391W/East_of_Eden_The_Wayward_Bus\r\n  [5]: https://openlibrary.org/works/OL23165W/The_Grapes_of_Wrath_The_Moon_is_Down_Cannery_Row_East_of_Eden_Of_Mice_and_Men	https://covers.openlibrary.org/b/id/11386937-L.jpg	/authors/OL25788A	2026-02-17 12:48:03.991604	2026-02-17 12:48:03.991604
OL19655889W	A Court of Frost and Starlight	Sarah J. Maas	A new, original novella in the A Court of Thorns and Roses series that picks up several months after the events of A Court of Wings and Ruin. Months after the explosive events in A Court of Wings and Ruin, Feyre, Rhys, and their companions are still busy rebuilding the Night Court and the vastly-changed world beyond. But Winter Solstice is finally near, and with it, a hard-earned reprieve. Yet even the festive atmosphere can't keep the shadows of the past from looming. As Feyre navigates her first Winter Solstice as High Lady, she finds that those dearest to her have more wounds than she anticipated-scars that will have far-reaching impact on the future of their Court.	https://covers.openlibrary.org/b/id/8569939-L.jpg	/authors/OL7115219A	2026-02-18 16:31:18.125336	2026-02-18 16:31:18.125336
OL69630W	A Little Princess	Frances Hodgson Burnett	This is a story about a different kind of princess than one might imagine; a princess that is an orphan - lonely, cold, hungry and abused. Sara Crewe begins life as the beloved, pampered daughter of a rich man. When he dies a pauper, she is thrown on the non-existent mercy of her small-minded, mercenary boarding school mistress. Stripped of all her belongings but for one set of clothes and a doll, Sara becomes a servant of the household. Hated by the schoolmistress for her independent spirit, Sara becomes a pariah in the household, with only a few secretly loyal friends. But through her inner integrity and strength of will, Sara Crewe maintains the deportment, inner nobility and generous spirit of a "real" princess.	https://covers.openlibrary.org/b/id/2328315-L.jpg	/authors/OL23767A	2026-02-23 13:04:52.132524	2026-02-23 13:04:52.132524
OL1898308W	Green Eggs and Ham	Dr. Seuss	Sam-I-am tries to persuade the character in the top hat to try green eggs and ham.\r\n “Do you like green eggs and ham?” asks Sam-I-am in this Beginner Book by Dr. Seuss. In a house or with a mouse? In a boat or with a goat? On a train or in a tree? Sam keeps asking persistently. With unmistakable characters and signature rhymes, Dr. Seuss’s beloved favorite has cemented its place as a children’s classic. In this most famous of cumulative tales, the list of places to enjoy green eggs and ham, and friends to enjoy them with, gets longer and longer. Follow Sam-I-am as he insists that this unusual treat is indeed a delectable snack to be savored everywhere and in every way.	https://covers.openlibrary.org/b/id/231746-L.jpg	/authors/OL2622837A	2026-02-23 13:05:00.33249	2026-02-23 13:05:00.33249
OL85892W	Dracula	Bram Stoker	Na história, um casal e seus amigos são atormentados por Conde Drácula, uma entidade sobrenatural e hematófoga que, presa em uma maldição contagiosa, pretende se mudar de seu recluso castelo na Transilvânia para a efervescente Londres do século XIX. Com a ajuda do professor Van Helsing, o grupo de amigos pretende enfrentar o morto-vivo, mesmo com todos os perigos que a ofensiva trará.	https://covers.openlibrary.org/b/id/12216503-L.jpg	/authors/OL31727A	2026-02-23 13:05:56.172115	2026-02-23 13:05:56.172115
OL36287W	El Conde de Montecristo	Alexandre Dumas	Thrown in prison for a crime he has not committed, Edmond Dantes is confined to the grim fortress of If. There he learns of a great hoard of treasure hidden on the Isle of Monte Cristo and becomes determined not only to escape but to unearth the treasure and use it to plot the destruction of the three men responsible for his incarceration. A huge popular success when it was first serialized in the 1840s, Dumas was inspired by a real-life case of wrongful imprisonment when writing his epic tale of suffering and retribution.	https://covers.openlibrary.org/b/id/14566393-L.jpg	/authors/OL18236A	2026-02-23 13:09:17.676682	2026-02-23 13:09:17.676682
OL10432709W	Братья Карамазовы	Фёдор Михайлович Достоевский	The Brothers Karamazov, Dostoevsky’s crowning achievement, is a tale of patricide and family rivalry that embodies the moral and spiritual dissolution of an entire society (Russia in the 1870s). It created a national furor comparable only to the excitement stirred by the publication, in 1866, of Crime and Punishment. To Dostoevsky, The Brothers Karamazov captured the quintessence of Russian character in all its exaltation, compassion, and profligacy. Significantly, the book was on Tolstoy’s bedside table when he died. Readers in every language have since accepted Dostoevsky’s own evaluation of this work and have gone further by proclaiming it one of the few great novels of all ages and countries.\r\n([source][1])	https://covers.openlibrary.org/b/id/8272336-L.jpg	/authors/OL22242A	2026-02-23 13:09:31.299984	2026-02-23 13:09:31.299984
OL23197W	The Red Pony	John Steinbeck	Tells story of a young boy and his life on his father's ranch. Ownership of a red pony teaches ten-year-old Jody about life and death.	https://covers.openlibrary.org/b/id/9278181-L.jpg	/authors/OL25788A	2026-02-26 14:16:51.331948	2026-02-26 14:16:51.331948
OL39316W	The Waves	Virginia Woolf	Tracing the lives of a group of friends, this novel follows their development from childhood to middle age. Social events, individual achievements and disappointments form the outer structure of the book, but the focus is the inner life of the characters which is conveyed in rich poetic language.	https://covers.openlibrary.org/b/id/119517-L.jpg	/authors/OL19450A	2026-02-26 15:05:38.88378	2026-02-26 15:05:38.88378
OL52267W	The Time Machine	H. G. Wells	The Time Traveller, a dreamer obsessed with traveling through time, builds himself a time machine and, much to his surprise, travels over 800,000 years into the future. He lands in the year 802701: the world has been transformed by a society living in apparent harmony and bliss, but as the Traveler stays in the future he discovers a hidden barbaric and depraved subterranean class. Wells's transparent commentary on the capitalist society was an instant bestseller and launched the time-travel genre.	https://covers.openlibrary.org/b/id/9009316-L.jpg	/authors/OL13066A	2026-02-27 12:23:27.93563	2026-02-27 12:23:27.93563
OL258902W	Macbeth	William Shakespeare	The play concerns a trusted general who secretly lusts for power. Encouraged by the prophecies of three witches and urged on by his ambitious wife Macbeth commits regicide. Left fearful and superstitious by this desperate act he is driven to a spiralling course of murder and outrage, almost inevitably culminating in his own death. One of Shakespeare’s most popular tragedies, Macbeth is ostensibly based on the Scottish king although the story represented in the play bears no relation to historical fact as the true King Macbeth was well respected by his contemporaries. This book includes the hero Macbeth becoming more and more evil after he gets told his "destiny" by the witches and becomes greedy with power.	https://covers.openlibrary.org/b/id/872432-L.jpg	/authors/OL9388A	2026-02-27 12:23:41.91573	2026-02-27 12:23:41.91573
OL7967812W	Roadside Picnic	Аркадий Натанович Стругацкий	[Comment by Hari Kunru in The Guardian][1]:\r\n\r\n> Soviet-era Russian science fiction deserves a wider audience in English. The Strugatsky brothers collaborated on numerous novels and stories, the best known of which is this, partly because it was filmed by Andrei Tarkovsky as Stalker, in 1977. The novel takes place 10 years after a mysterious alien visitation, which seems to have no rational explanation. No one saw the visitors. Their presence caused disease and blindness in the areas where they landed. Now, in the six "Zones", the laws of physics (and, seemingly, of reality) are disturbed by anomalies, and littered with inexplicable, deadly wreckage. Only a few brave "stalkers" risk their lives to enter the zones to gather alien artefacts for sale. Some of these artefacts offer the promise of extraordinary powers. Unlike Tarkovsky's film, which concentrates on the hallucinatory, vacated landscape of the zones, the novels portray a society adapting to an inexplicable, terrifying event, an eruption of the unknown. Though written in 1971 and published in English in 1977, the novel was heavily bowdlerised by Soviet censors, and an authoritative text wasn't available in Russian until 2000. It's a book with an extraordinary atmosphere – and a demonstration of how science fiction, by using a single bold central metaphor, can open up the possibilities of the novel.\r\n\r\nOriginal Title: Пикник на обочине\r\n\r\n\r\n  [1]: http://www.guardian.co.uk/books/2011/may/14/science-fiction-authors-choice	https://covers.openlibrary.org/b/id/6752719-L.jpg	/authors/OL182660A	2026-03-03 11:55:59.635656	2026-03-03 11:55:59.635656
OL18173428W	The monkey's paw	W. W. Jacobs	\N	https://covers.openlibrary.org/b/id/8335044-L.jpg	/authors/OL160918A	2026-03-03 11:56:26.521051	2026-03-03 11:56:26.521051
OL848436W	Memoirs of Fanny Hill	John Cleland	Memoirs of Fanny Hill was written in debtor's prison in 1784 and was the first modern erotic novel in English. A young woman, Fanny Hill, is forced by poverty to go into service, but is tricked into becoming a prostitute instead. She is then saved by her love, only to have his jealous father send him from the country some months later. She moves from one lover to the next, gaining maturity with each encounter, and nearing her...happy ending.	https://covers.openlibrary.org/b/id/12947584-L.jpg	/authors/OL73278A	2026-03-03 12:42:53.217595	2026-03-03 12:42:53.217595
OL1846076W	The Giver	Lois Lowry	At the age of twelve, Jonas, a young boy from a seemingly utopian, futuristic world, is singled out to receive special training from The Giver, who alone holds the memories of the true joys and pain of life.	https://covers.openlibrary.org/b/id/8352502-L.jpg	/authors/OL221009A	2026-03-03 12:43:03.991011	2026-03-03 12:43:03.991011
\.


--
-- Data for Name: conversation_members; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.conversation_members (conversation_id, user_id, joined_at, last_read_at, deleted_at) FROM stdin;
4968eb4a-73e9-45ba-be24-fd8138c663ec	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-03 14:23:00.870394-08	2026-03-05 11:59:46.93582-08	2026-03-05 15:25:33.389133-08
d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	2026-02-24 14:04:36.40192-08	2026-03-09 12:12:38.405241-07	\N
4968eb4a-73e9-45ba-be24-fd8138c663ec	d9614312-04a4-4428-aebd-58e60bedbcd4	2026-03-03 14:23:00.870394-08	\N	\N
199fda90-0291-41a2-a3e8-517dd312c342	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-05 13:25:48.229157-08	2026-03-05 16:03:30.814291-08	2026-03-05 16:03:40.572767-08
199fda90-0291-41a2-a3e8-517dd312c342	b96e7980-dd22-4208-a29e-0279251fb944	2026-03-05 13:25:48.229157-08	\N	\N
433fc7d7-6bee-41bc-bb9c-a72192d43882	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-05 13:27:03.148442-08	2026-03-05 15:25:51.044882-08	2026-03-05 15:27:21.535153-08
f725ea49-7494-42e0-8662-ba0c53d61ea8	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-05 13:13:29.715528-08	\N	2026-03-05 15:40:00.546578-08
5299af96-1d71-4cc9-8de4-4dcd2ad31b7f	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-05 13:25:59.414147-08	2026-03-05 15:20:46.025015-08	2026-03-05 15:21:45.596041-08
d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	2026-02-24 14:04:36.40192-08	2026-03-05 16:09:09.707005-08	\N
\.


--
-- Data for Name: conversations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.conversations (id, name, created_at, is_ai, book_title, book_author, book_description) FROM stdin;
d835e65e-ca6d-439d-8a8d-fc8de92b820d	\N	2026-02-24 14:04:36.40192-08	f	\N	\N	\N
4968eb4a-73e9-45ba-be24-fd8138c663ec	\N	2026-03-03 14:23:00.870394-08	f	\N	\N	\N
f725ea49-7494-42e0-8662-ba0c53d61ea8	\N	2026-03-05 13:13:29.715528-08	t	The Waves	Virginia Woolf	\N
199fda90-0291-41a2-a3e8-517dd312c342	\N	2026-03-05 13:25:48.229157-08	f	\N	\N	\N
5299af96-1d71-4cc9-8de4-4dcd2ad31b7f	\N	2026-03-05 13:25:59.414147-08	t	Dracula	Bram Stoker	\N
433fc7d7-6bee-41bc-bb9c-a72192d43882	\N	2026-03-05 13:27:03.148442-08	t	Icebreaker	Hannah Grace	\N
\.


--
-- Data for Name: friend_requests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.friend_requests (id, sender_id, receiver_id, status, created_at, updated_at) FROM stdin;
8f9c6fce-0d76-479c-83f7-cf19de3f23f1	67dc1e40-f984-4fbb-8e85-789419d38348	b96e7980-dd22-4208-a29e-0279251fb944	accepted	2026-03-03 12:14:02.10939-08	2026-03-03 12:14:02.10939-08
a9297384-5d7e-453c-b9bc-15b683ab025a	67dc1e40-f984-4fbb-8e85-789419d38348	4c1ee880-50fb-4be8-8fd4-72c82c41c453	accepted	2026-03-03 12:13:56.349891-08	2026-03-03 12:13:56.349891-08
7dc53976-ea9a-4a9b-8049-f26309e75bc6	4c1ee880-50fb-4be8-8fd4-72c82c41c453	b96e7980-dd22-4208-a29e-0279251fb944	pending	2026-03-03 12:14:40.787925-08	2026-03-03 12:14:40.787925-08
3b0aee6c-8e95-49b6-9b1b-a688e216a485	67dc1e40-f984-4fbb-8e85-789419d38348	d9614312-04a4-4428-aebd-58e60bedbcd4	accepted	2026-03-03 12:14:57.252989-08	2026-03-03 12:14:57.252989-08
c4688f6a-4982-483d-82c0-2848fa85af16	67dc1e40-f984-4fbb-8e85-789419d38348	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	accepted	2026-03-03 12:14:51.756515-08	2026-03-03 12:14:51.756515-08
cfbdf1cc-f88d-4ad6-a524-6f58b1d7579e	4c1ee880-50fb-4be8-8fd4-72c82c41c453	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	accepted	2026-03-03 12:14:45.421566-08	2026-03-03 12:14:45.421566-08
2b2bf92b-ccb5-4124-9589-bcf80c94fc8c	67dc1e40-f984-4fbb-8e85-789419d38348	3ba83aed-0c70-4836-aebf-7792ce68be5c	accepted	2026-03-03 12:14:54.551593-08	2026-03-03 12:14:54.551593-08
777987fc-d02c-4340-a670-09250c0df060	4c1ee880-50fb-4be8-8fd4-72c82c41c453	3ba83aed-0c70-4836-aebf-7792ce68be5c	accepted	2026-03-03 12:14:48.503619-08	2026-03-03 12:14:48.503619-08
\.


--
-- Data for Name: friendships; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.friendships (id, user_id, friend_id, created_at) FROM stdin;
3616350b-dafb-48e3-8748-709ff4210d9d	b96e7980-dd22-4208-a29e-0279251fb944	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-03 12:14:09.017993-08
266b9106-b33c-4e98-bf21-81117d767ac9	67dc1e40-f984-4fbb-8e85-789419d38348	b96e7980-dd22-4208-a29e-0279251fb944	2026-03-03 12:14:09.017993-08
3a326183-dbaa-43e6-9b61-8ac7604e9323	4c1ee880-50fb-4be8-8fd4-72c82c41c453	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-03 12:14:30.105195-08
593d2e14-3ab2-43de-840f-6f048a1772b4	67dc1e40-f984-4fbb-8e85-789419d38348	4c1ee880-50fb-4be8-8fd4-72c82c41c453	2026-03-03 12:14:30.105195-08
045bc19f-6656-4fe4-88b6-21fec5a0adcd	d9614312-04a4-4428-aebd-58e60bedbcd4	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-03 12:15:09.407072-08
58cf3b82-a638-4122-81fe-38704bcdaeba	67dc1e40-f984-4fbb-8e85-789419d38348	d9614312-04a4-4428-aebd-58e60bedbcd4	2026-03-03 12:15:09.407072-08
d5ae6a42-bde8-4205-8f01-f0d61719c221	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-03 12:43:07.652693-08
b3230ec3-ca3d-4245-9f87-debd1e1fa691	67dc1e40-f984-4fbb-8e85-789419d38348	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	2026-03-03 12:43:07.652693-08
33c910ab-b97b-4e5d-8991-9bdbd558b720	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	4c1ee880-50fb-4be8-8fd4-72c82c41c453	2026-03-03 12:43:08.118696-08
8d15306c-22e4-42cf-ae82-46986e0db1a6	4c1ee880-50fb-4be8-8fd4-72c82c41c453	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	2026-03-03 12:43:08.118696-08
b2c26eff-0649-48bb-a3f3-66af8241d3b8	3ba83aed-0c70-4836-aebf-7792ce68be5c	67dc1e40-f984-4fbb-8e85-789419d38348	2026-03-03 12:43:25.91122-08
7bc30547-aead-4d57-8f65-70a690b775ea	67dc1e40-f984-4fbb-8e85-789419d38348	3ba83aed-0c70-4836-aebf-7792ce68be5c	2026-03-03 12:43:25.91122-08
19b2817d-e72b-469e-a3e8-1e74d29d5e6a	3ba83aed-0c70-4836-aebf-7792ce68be5c	4c1ee880-50fb-4be8-8fd4-72c82c41c453	2026-03-03 12:43:26.172376-08
47245578-bf8b-41a9-adbe-a1532807c556	4c1ee880-50fb-4be8-8fd4-72c82c41c453	3ba83aed-0c70-4836-aebf-7792ce68be5c	2026-03-03 12:43:26.172376-08
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.messages (id, conversation_id, sender_id, body, created_at) FROM stdin;
cb9f2e27-38d5-4baf-9b20-368454edd839	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	Hello	2026-02-25 11:25:36.050582-08
afd94b23-75a8-4912-ac26-2e66f28b2c2b	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	hope you're doing well	2026-02-25 11:25:54.781976-08
7c80c8ba-8888-4eec-9ad9-11bbda302768	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	hey bro hows it going	2026-02-25 11:26:13.081681-08
70c055f9-6b63-4021-918e-4047ebca8b40	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	good and you	2026-02-25 12:20:38.185728-08
868b7f90-7b67-48c2-aa19-d026c108a681	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	im good whats new with you?	2026-02-25 12:20:49.540595-08
a935fa9a-1bc7-4acf-af2f-440843aaa074	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	just been busy with work and everything hbu?	2026-02-25 12:21:06.190104-08
2d6ac5e2-47b2-4cb9-aa56-39e54e4adca0	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	yeah ive been busy working on the car	2026-02-25 14:18:46.026309-08
ea2f8308-6cd1-4ace-9aec-45fac83ed8bb	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	on nice	2026-02-25 14:18:51.276821-08
94bf446c-553b-4d10-b87d-56be878cdcd8	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	test	2026-02-25 14:21:48.630397-08
b4f0b5ab-4c27-4ace-ad83-3b309d8450a4	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	test again	2026-02-25 14:32:34.610555-08
45b060dd-8775-453b-a85a-ed04a058f604	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	this is a test	2026-02-25 14:37:10.606261-08
409ae60b-27a5-4179-b2ba-1afe3c21eb8b	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	this can be another test	2026-02-25 14:37:20.113419-08
4d192286-0246-4b30-9016-44eabc50fa1b	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	test	2026-02-25 16:24:31.385248-08
ad27cf1b-4729-45f2-b32a-14032a84ff20	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	test	2026-02-25 16:24:35.392002-08
7b2c0621-1e37-4b08-90d8-d34483699207	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	test	2026-02-25 16:24:52.612916-08
12d3c566-5090-4a1e-a860-405c95b4b7d8	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	lets run a unread test	2026-02-25 16:46:17.377167-08
102dad55-81c1-4459-96db-875f43582e91	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	this is anothe rmessage	2026-02-25 16:46:35.148139-08
caa38fc8-347e-41c8-8934-ecd02ec7fe1b	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	hello	2026-02-25 16:46:54.806938-08
566ac32f-c02a-4c09-a1f1-1ba671c5a8d5	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	are you there	2026-02-25 16:47:01.183564-08
6273f881-507e-4cd6-a958-28ab72c6e60a	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	yes	2026-02-25 16:47:12.820059-08
cb80f7e1-0fb1-408d-8a1e-aed8cd35207a	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	hello	2026-02-25 17:05:44.74243-08
c01ead53-23da-49b1-8d7b-4751fea4eea8	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	test	2026-02-25 17:05:59.928191-08
2815c4ec-d879-4460-9608-640d3481d08c	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	test	2026-02-25 17:06:22.34197-08
bfd07216-fd21-42ce-8592-2a5fcc14ccb7	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	hello	2026-02-25 17:20:48.772933-08
eb80b610-37d4-44d7-8f5d-72bb82aae5d5	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	wats up	2026-02-25 17:20:58.121674-08
4bfe2072-bfd6-4260-91a0-aa319477d6ff	4968eb4a-73e9-45ba-be24-fd8138c663ec	67dc1e40-f984-4fbb-8e85-789419d38348	hey bro	2026-03-03 14:23:04.137956-08
d3b49214-4f98-4148-9f69-515a4a0376e7	4968eb4a-73e9-45ba-be24-fd8138c663ec	67dc1e40-f984-4fbb-8e85-789419d38348	test	2026-03-05 11:59:46.927188-08
612502c2-2e2a-4cc7-b426-726a434b3274	199fda90-0291-41a2-a3e8-517dd312c342	67dc1e40-f984-4fbb-8e85-789419d38348	yo	2026-03-05 13:25:51.149255-08
0768f8f7-df21-49e2-b039-addb43542091	5299af96-1d71-4cc9-8de4-4dcd2ad31b7f	67dc1e40-f984-4fbb-8e85-789419d38348	test	2026-03-05 13:26:02.275595-08
510ca934-6166-4544-bbe1-8879c999d2bc	433fc7d7-6bee-41bc-bb9c-a72192d43882	67dc1e40-f984-4fbb-8e85-789419d38348	test	2026-03-05 13:29:04.15914-08
d7aa1da8-1f06-46da-a98b-b5fd2c7b3891	5299af96-1d71-4cc9-8de4-4dcd2ad31b7f	67dc1e40-f984-4fbb-8e85-789419d38348	test	2026-03-05 13:30:32.578252-08
fa927bb1-04bf-43d1-84e9-830a07927ea9	433fc7d7-6bee-41bc-bb9c-a72192d43882	67dc1e40-f984-4fbb-8e85-789419d38348	hello	2026-03-05 13:34:59.938185-08
b5f6758f-2567-4571-a967-65feb3e60af5	433fc7d7-6bee-41bc-bb9c-a72192d43882	\N	Hello, I'm excited to dive into "Icebreaker" by Hannah Grace with you. What drew you to this book, and what are you hoping to get out of the story?	2026-03-05 13:35:00.39846-08
19537917-96f4-4c53-8d10-322f2fac8be3	433fc7d7-6bee-41bc-bb9c-a72192d43882	67dc1e40-f984-4fbb-8e85-789419d38348	I want to learn who the main characters are in this book	2026-03-05 13:35:24.075692-08
24b480f7-57a0-49b4-a68a-0cacfb13d46b	433fc7d7-6bee-41bc-bb9c-a72192d43882	\N	The main character in "Icebreaker" is Anastasia Allen, a 17-year-old figure skater who's trying to make a comeback after a serious injury. What do you think about athletes having to balance their competitive careers with personal struggles, and how do you think Anastasia will handle this challenge?	2026-03-05 13:35:24.627918-08
0b7e1108-9bcd-4315-82fa-bd8caeab096b	199fda90-0291-41a2-a3e8-517dd312c342	67dc1e40-f984-4fbb-8e85-789419d38348	yo	2026-03-05 15:40:11.984698-08
58bcb180-eb89-4c13-afee-626ea06f110d	199fda90-0291-41a2-a3e8-517dd312c342	67dc1e40-f984-4fbb-8e85-789419d38348	test	2026-03-05 15:41:15.249798-08
f864abc6-4192-4de9-8e9b-c3789f1ab8fd	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	whats up	2026-03-05 15:54:53.325299-08
d76379bb-4938-4cf4-baa0-f408fa48aab7	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	so whats up	2026-03-05 15:55:03.341508-08
f2d88867-401a-47f1-9375-cced7e3ad7f3	199fda90-0291-41a2-a3e8-517dd312c342	67dc1e40-f984-4fbb-8e85-789419d38348	test	2026-03-05 16:03:22.446226-08
93f5d996-4731-40a6-9519-9e96604eaaac	d835e65e-ca6d-439d-8a8d-fc8de92b820d	67dc1e40-f984-4fbb-8e85-789419d38348	yyooo	2026-03-05 16:03:37.218071-08
2ddde34e-7c8d-435c-98d7-e6d2d788015e	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	hey	2026-03-05 16:03:48.841068-08
d1eae1fb-6a46-4a0c-8b98-4503eea6a74e	d835e65e-ca6d-439d-8a8d-fc8de92b820d	4c1ee880-50fb-4be8-8fd4-72c82c41c453	wasda	2026-03-05 16:04:09.278458-08
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.profiles (user_id, first_name, last_name, birthdate, bio, profile_image, created_at, updated_at) FROM stdin;
b96e7980-dd22-4208-a29e-0279251fb944	Aldo	Quintero	\N	\N	\N	2026-01-21 14:22:52.441331-08	2026-01-21 14:22:52.441331-08
3ba83aed-0c70-4836-aebf-7792ce68be5c	Frank	Gutierrez 	\N	\N	\N	2026-01-21 14:23:35.809704-08	2026-01-21 14:23:35.809704-08
74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	Carlos	De la Rosa	\N	\N	\N	2026-01-21 14:23:51.555851-08	2026-01-21 14:23:51.555851-08
4c1ee880-50fb-4be8-8fd4-72c82c41c453	Sergio	Carbajal	\N	\N	https://shelfie-profile-images.s3.us-west-1.amazonaws.com/users/4c1ee880-50fb-4be8-8fd4-72c82c41c453/profile-1771889255624.png	2026-01-21 14:23:16.821673-08	2026-01-21 14:23:16.821673-08
67dc1e40-f984-4fbb-8e85-789419d38348	Hector	Carbajal	1997-01-27	I like reading Classics, Sci-fi, and romance novels 	https://shelfie-profile-images.s3.us-west-1.amazonaws.com/users/67dc1e40-f984-4fbb-8e85-789419d38348/profile-1770400300546.png	2026-01-23 18:18:43.636442-08	2026-01-23 18:18:43.636442-08
d9614312-04a4-4428-aebd-58e60bedbcd4	Jason	Guzman	1996-12-04	Love Sci-fi and Fiction and Personal Growth	https://shelfie-profile-images.s3.us-west-1.amazonaws.com/users/d9614312-04a4-4428-aebd-58e60bedbcd4/profile-1772568931027.png	2026-01-21 14:23:05.799894-08	2026-01-21 14:23:05.799894-08
b4e04da7-fd04-4d6b-a3c2-45da5211037c	Briana	Rodriguez	\N	\N	\N	2026-02-03 14:33:35.797416-08	2026-02-03 14:33:35.797416-08
\.


--
-- Data for Name: user_books; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_books (id, user_id, book_id, external_source, status, date_started, date_finished, rating, review, created_at, updated_at, favorite) FROM stdin;
43	67dc1e40-f984-4fbb-8e85-789419d38348	OL1168007W	open_library	reading	\N	\N	\N	\N	2026-02-12 10:22:33.963231-08	2026-02-12 10:22:33.963231-08	f
44	67dc1e40-f984-4fbb-8e85-789419d38348	OL24633409W	open_library	completed	\N	\N	\N	\N	2026-02-12 10:22:55.717637-08	2026-02-12 10:22:55.717637-08	f
45	67dc1e40-f984-4fbb-8e85-789419d38348	OL34774028W	open_library	reading	\N	\N	\N	\N	2026-02-12 10:42:16.867033-08	2026-02-12 10:42:16.867033-08	f
46	67dc1e40-f984-4fbb-8e85-789419d38348	OL2172524W	open_library	want_to_read	\N	\N	\N	\N	2026-02-13 11:01:54.784171-08	2026-02-13 11:01:54.784171-08	f
110	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL498463W	open_library	want_to_read	\N	\N	\N	\N	2026-02-27 12:22:40.28151-08	2026-02-27 12:22:40.28151-08	f
77	67dc1e40-f984-4fbb-8e85-789419d38348	OL19655889W	open_library	dropped	\N	\N	\N	\N	2026-02-18 16:31:18.135031-08	2026-02-19 10:20:27.202554-08	f
111	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL52267W	open_library	completed	\N	\N	\N	\N	2026-02-27 12:23:27.93563-08	2026-02-27 12:23:27.93563-08	f
57	67dc1e40-f984-4fbb-8e85-789419d38348	OL28429W	open_library	want_to_read	\N	\N	\N	\N	2026-02-13 11:08:27.934603-08	2026-02-13 11:08:29.256965-08	f
59	67dc1e40-f984-4fbb-8e85-789419d38348	OL17860744W	open_library	completed	\N	\N	\N	\N	2026-02-17 10:37:18.553875-08	2026-02-17 10:37:18.553875-08	f
60	67dc1e40-f984-4fbb-8e85-789419d38348	OL498556W	open_library	completed	\N	\N	\N	\N	2026-02-17 10:38:20.803632-08	2026-02-17 10:38:20.803632-08	f
61	67dc1e40-f984-4fbb-8e85-789419d38348	OL498463W	open_library	completed	\N	\N	\N	\N	2026-02-17 10:38:35.483133-08	2026-02-17 10:38:35.483133-08	f
62	67dc1e40-f984-4fbb-8e85-789419d38348	OL2172403W	open_library	want_to_read	\N	\N	\N	\N	2026-02-17 10:39:40.714485-08	2026-02-17 10:39:40.714485-08	f
63	67dc1e40-f984-4fbb-8e85-789419d38348	OL46125W	open_library	want_to_read	\N	\N	\N	\N	2026-02-17 10:40:07.154934-08	2026-02-17 10:40:07.154934-08	f
64	67dc1e40-f984-4fbb-8e85-789419d38348	OL46241W	open_library	want_to_read	\N	\N	\N	\N	2026-02-17 10:40:23.057493-08	2026-02-17 10:40:23.057493-08	f
65	67dc1e40-f984-4fbb-8e85-789419d38348	OL103123W	open_library	want_to_read	\N	\N	\N	\N	2026-02-17 10:40:38.338327-08	2026-02-17 10:40:38.338327-08	f
66	67dc1e40-f984-4fbb-8e85-789419d38348	OL23204W	open_library	completed	\N	\N	\N	\N	2026-02-17 12:42:21.458703-08	2026-02-17 12:42:23.449206-08	f
68	67dc1e40-f984-4fbb-8e85-789419d38348	OL26446888W	open_library	completed	\N	\N	\N	\N	2026-02-17 12:43:03.184726-08	2026-02-17 12:43:03.184726-08	f
70	67dc1e40-f984-4fbb-8e85-789419d38348	OL28952677W	open_library	reading	\N	\N	\N	\N	2026-02-17 12:43:40.689274-08	2026-02-17 12:43:40.689274-08	f
71	67dc1e40-f984-4fbb-8e85-789419d38348	OL46337W	open_library	want_to_read	\N	\N	\N	\N	2026-02-17 12:44:30.468871-08	2026-02-17 12:44:30.468871-08	f
72	67dc1e40-f984-4fbb-8e85-789419d38348	OL35085373W	open_library	want_to_read	\N	\N	\N	\N	2026-02-17 12:44:54.148907-08	2026-02-17 12:44:54.148907-08	f
73	67dc1e40-f984-4fbb-8e85-789419d38348	OL675783W	open_library	want_to_read	\N	\N	\N	\N	2026-02-17 12:45:35.548782-08	2026-02-17 12:45:35.548782-08	f
74	67dc1e40-f984-4fbb-8e85-789419d38348	OL810991W	open_library	want_to_read	\N	\N	\N	\N	2026-02-17 12:47:31.327249-08	2026-02-17 12:47:31.327249-08	f
82	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL1168083W	open_library	want_to_read	\N	\N	\N	\N	2026-02-23 13:04:40.287032-08	2026-02-23 13:04:40.287032-08	f
83	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL69630W	open_library	want_to_read	\N	\N	\N	\N	2026-02-23 13:04:52.142595-08	2026-02-23 13:04:52.142595-08	f
84	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL1898308W	open_library	want_to_read	\N	\N	\N	\N	2026-02-23 13:05:00.332923-08	2026-02-23 13:05:00.332923-08	f
86	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL36287W	open_library	want_to_read	\N	\N	\N	\N	2026-02-23 13:09:17.679458-08	2026-02-23 13:09:17.679458-08	f
87	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL10432709W	open_library	completed	\N	\N	\N	\N	2026-02-23 13:09:31.302543-08	2026-02-23 13:09:31.302543-08	f
69	67dc1e40-f984-4fbb-8e85-789419d38348	OL17116910W	open_library	completed	2026-01-01	2026-01-20	4.50	Lorem ipsum dolor sit amet consectetur adipisicing elit. Sunt id sit consectetur illo, obcaecati atque. Ullam ad exercitationem cum, laboriosam delectus molestiae quam, eos dolore, harum in maxime quisquam eligendi?\n	2026-02-17 12:43:24.062182-08	2026-02-18 13:47:46.495792-08	t
92	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL23197W	open_library	want_to_read	\N	\N	\N	\N	2026-02-26 14:16:51.332823-08	2026-02-26 14:16:51.332823-08	f
76	67dc1e40-f984-4fbb-8e85-789419d38348	OL1168083W	open_library	completed	2025-02-05	2025-10-07	5.00	Aldo hasn't read it so there's that	2026-02-18 13:48:35.827774-08	2026-02-18 16:02:03.141191-08	t
85	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL85892W	open_library	completed	\N	\N	\N	\N	2026-02-23 13:05:56.175876-08	2026-02-27 14:46:13.432012-08	f
112	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL258902W	open_library	reading	2026-02-27	\N	\N	\N	2026-02-27 12:23:41.91573-08	2026-02-27 14:46:26.152404-08	f
97	4c1ee880-50fb-4be8-8fd4-72c82c41c453	OL39316W	open_library	dropped	\N	\N	\N	\N	2026-02-26 15:05:38.88378-08	2026-02-26 15:59:15.401414-08	f
122	67dc1e40-f984-4fbb-8e85-789419d38348	OL85892W	open_library	reading	\N	\N	\N	\N	2026-03-02 15:22:45.333244-08	2026-03-02 15:22:51.288932-08	f
114	67dc1e40-f984-4fbb-8e85-789419d38348	OL39316W	open_library	want_to_read	\N	\N	\N	\N	2026-02-27 14:25:34.63596-08	2026-03-02 15:25:42.489872-08	f
126	b96e7980-dd22-4208-a29e-0279251fb944	OL258902W	open_library	want_to_read	\N	\N	\N	\N	2026-03-03 11:55:51.564695-08	2026-03-03 11:55:51.564695-08	f
127	b96e7980-dd22-4208-a29e-0279251fb944	OL7967812W	open_library	reading	\N	\N	\N	\N	2026-03-03 11:55:59.635656-08	2026-03-03 11:55:59.635656-08	f
128	b96e7980-dd22-4208-a29e-0279251fb944	OL1168083W	open_library	reading	\N	\N	\N	\N	2026-03-03 11:56:12.400195-08	2026-03-03 11:56:13.813745-08	f
130	b96e7980-dd22-4208-a29e-0279251fb944	OL18173428W	open_library	want_to_read	\N	\N	\N	\N	2026-03-03 11:56:26.521051-08	2026-03-03 11:56:26.521051-08	f
131	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	OL848436W	open_library	want_to_read	\N	\N	\N	\N	2026-03-03 12:42:53.217595-08	2026-03-03 12:42:53.217595-08	f
132	74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	OL1846076W	open_library	reading	\N	\N	\N	\N	2026-03-03 12:43:03.991011-08	2026-03-03 12:43:03.991011-08	f
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, email, password_hash, created_at) FROM stdin;
b96e7980-dd22-4208-a29e-0279251fb944	aldo@mail.com	$2b$10$TqnAnZuw6fgmj0cx7fiWEuNFP1VGGh1vLMiVpHgXwo18.53YuOdbu	2026-01-21 14:22:52.441331-08
67dc1e40-f984-4fbb-8e85-789419d38348	hector@mail.com	$2b$10$ZoH3SaHmUMht7cwkzzCpnu1z2Lz4rjJc3Houe/7jcdcxw.eIl/KTS	2026-01-23 18:18:43.636442-08
d9614312-04a4-4428-aebd-58e60bedbcd4	jason@mail.com	$2b$10$ONy85OEojQ7uyMRhWQbzQeD0CaQFfu7pCRtpmGBjuXowyCCYBo8AW	2026-01-21 14:23:05.799894-08
4c1ee880-50fb-4be8-8fd4-72c82c41c453	sergio@mail.com	$2b$10$MuphjzkpMAAQMCYOH/2MB.hrrg5WiKWdVx6Oz2rBMmUAF1OhCxFVO	2026-01-21 14:23:16.821673-08
3ba83aed-0c70-4836-aebf-7792ce68be5c	frank@mail.com	$2b$10$ospFngq.i7FDABSm4ZfTiOp4pzXTsjVvyXxvDwPDOJ1q4.K.sdBb6	2026-01-21 14:23:35.809704-08
74b69a1b-0e94-41f8-a9ef-fdf87e78a0ca	carlos@mail.com	$2b$10$5ui75sZhLP1Eb8RlrhkmVukEdL4UCffRY.O87Vq7vxjf1QvAzSJEe	2026-01-21 14:23:51.555851-08
b4e04da7-fd04-4d6b-a3c2-45da5211037c	briana@mail.com	$2b$10$FR28UP8zLg/jgZUC8vgkG.2Ez/A00WjQpedisJ7wUcdkBdiWCa9xC	2026-02-03 14:33:35.797416-08
\.


--
-- Name: user_books_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_books_id_seq', 132, true);


--
-- Name: activities activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: books books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT books_pkey PRIMARY KEY (id);


--
-- Name: conversation_members conversation_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_members
    ADD CONSTRAINT conversation_members_pkey PRIMARY KEY (conversation_id, user_id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: friend_requests friend_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_pkey PRIMARY KEY (id);


--
-- Name: friend_requests friend_requests_unique_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_unique_pair UNIQUE (sender_id, receiver_id);


--
-- Name: friendships friendships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_pkey PRIMARY KEY (id);


--
-- Name: friendships friendships_unique_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_unique_pair UNIQUE (user_id, friend_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (user_id);


--
-- Name: user_books user_books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_books
    ADD CONSTRAINT user_books_pkey PRIMARY KEY (id);


--
-- Name: user_books user_books_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_books
    ADD CONSTRAINT user_books_unique UNIQUE (user_id, book_id, external_source);


--
-- Name: user_books user_books_unique_per_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_books
    ADD CONSTRAINT user_books_unique_per_user UNIQUE (user_id, book_id, external_source);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: user_books_user_external_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_books_user_external_unique ON public.user_books USING btree (user_id, book_id);


--
-- Name: conversation_members trg_delete_empty_conversation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_delete_empty_conversation AFTER DELETE ON public.conversation_members FOR EACH ROW EXECUTE FUNCTION public.delete_empty_conversation();


--
-- Name: activities fk_activities_actor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT fk_activities_actor FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: conversation_members fk_conversation_members_conversation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_members
    ADD CONSTRAINT fk_conversation_members_conversation FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: conversation_members fk_conversation_members_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_members
    ADD CONSTRAINT fk_conversation_members_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: friend_requests fk_friend_requests_receiver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT fk_friend_requests_receiver FOREIGN KEY (receiver_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: friend_requests fk_friend_requests_sender; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT fk_friend_requests_sender FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: friendships fk_friendships_friend; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT fk_friendships_friend FOREIGN KEY (friend_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: friendships fk_friendships_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT fk_friendships_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages fk_messages_conversation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_messages_conversation FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: messages fk_messages_sender; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: profiles fk_profiles_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_books fk_user_books_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_books
    ADD CONSTRAINT fk_user_books_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict ASDb27DakR3NquW40oLqS0Nz63PSdJKPtjcXkCAtiNCgKBzmLe1bClJWx5R1XtD

