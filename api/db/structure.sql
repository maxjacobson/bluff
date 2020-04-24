SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: game_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.game_status AS ENUM (
    'pending',
    'playing',
    'complete'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: game_attendances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.game_attendances (
    id bigint NOT NULL,
    human_id bigint NOT NULL,
    game_id bigint NOT NULL,
    heartbeat_at timestamp without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: game_attendances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.game_attendances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: game_attendances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.game_attendances_id_seq OWNED BY public.game_attendances.id;


--
-- Name: games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.games (
    id bigint NOT NULL,
    identifier character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    last_action_at timestamp without time zone NOT NULL,
    status public.game_status DEFAULT 'pending'::public.game_status NOT NULL
);


--
-- Name: games_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.games_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: games_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.games_id_seq OWNED BY public.games.id;


--
-- Name: humans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.humans (
    id bigint NOT NULL,
    nickname character varying NOT NULL,
    uuid character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: humans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.humans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: humans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.humans_id_seq OWNED BY public.humans.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: game_attendances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_attendances ALTER COLUMN id SET DEFAULT nextval('public.game_attendances_id_seq'::regclass);


--
-- Name: games id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games ALTER COLUMN id SET DEFAULT nextval('public.games_id_seq'::regclass);


--
-- Name: humans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.humans ALTER COLUMN id SET DEFAULT nextval('public.humans_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: game_attendances game_attendances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_attendances
    ADD CONSTRAINT game_attendances_pkey PRIMARY KEY (id);


--
-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (id);


--
-- Name: humans humans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.humans
    ADD CONSTRAINT humans_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_game_attendances_on_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_game_attendances_on_game_id ON public.game_attendances USING btree (game_id);


--
-- Name: index_game_attendances_on_human_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_game_attendances_on_human_id ON public.game_attendances USING btree (human_id);


--
-- Name: index_game_attendances_on_human_id_and_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_game_attendances_on_human_id_and_game_id ON public.game_attendances USING btree (human_id, game_id);


--
-- Name: index_games_on_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_games_on_identifier ON public.games USING btree (identifier);


--
-- Name: index_humans_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_humans_on_uuid ON public.humans USING btree (uuid);


--
-- Name: game_attendances fk_rails_6f1ca5105c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_attendances
    ADD CONSTRAINT fk_rails_6f1ca5105c FOREIGN KEY (game_id) REFERENCES public.games(id);


--
-- Name: game_attendances fk_rails_ec41558046; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.game_attendances
    ADD CONSTRAINT fk_rails_ec41558046 FOREIGN KEY (human_id) REFERENCES public.humans(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20200423034056'),
('20200424025346'),
('20200424043535'),
('20200424052330'),
('20200424080215');


