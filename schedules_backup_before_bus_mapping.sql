--
-- PostgreSQL database dump
--

\restrict 7Mx9GnUjoKN0Lawe41hh20c80TCa9CGactBecyxboezf6Ki8XW85PefbHRUgTr2

-- Dumped from database version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: schedules; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.schedules (
    schedule_id integer NOT NULL,
    route_id integer NOT NULL,
    bus_id integer,
    departure_time time without time zone NOT NULL,
    arrival_time time without time zone,
    day_of_week character varying(20) NOT NULL,
    direction character varying(20)
);


ALTER TABLE public.schedules OWNER TO bus_admin;

--
-- Name: schedules_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.schedules_schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.schedules_schedule_id_seq OWNER TO bus_admin;

--
-- Name: schedules_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.schedules_schedule_id_seq OWNED BY public.schedules.schedule_id;


--
-- Name: schedules schedule_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.schedules ALTER COLUMN schedule_id SET DEFAULT nextval('public.schedules_schedule_id_seq'::regclass);


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.schedules (schedule_id, route_id, bus_id, departure_time, arrival_time, day_of_week, direction) FROM stdin;
1	11	9	07:30:00	\N	WORKING_DAYS	OUTBOUND
2	11	9	07:55:00	\N	WORKING_DAYS	OUTBOUND
3	11	9	08:25:00	\N	WORKING_DAYS	OUTBOUND
4	11	9	08:45:00	\N	WORKING_DAYS	OUTBOUND
5	11	9	14:00:00	\N	WORKING_DAYS	OUTBOUND
6	11	9	16:40:00	\N	WORKING_DAYS	OUTBOUND
7	11	9	17:20:00	\N	WORKING_DAYS	OUTBOUND
8	11	9	18:00:00	\N	WORKING_DAYS	OUTBOUND
9	11	9	07:45:00	\N	WORKING_DAYS	RETURN
10	11	9	08:10:00	\N	WORKING_DAYS	RETURN
11	11	9	08:35:00	\N	WORKING_DAYS	RETURN
12	11	9	08:55:00	\N	WORKING_DAYS	RETURN
13	11	9	14:30:00	\N	WORKING_DAYS	RETURN
14	11	9	17:00:00	\N	WORKING_DAYS	RETURN
15	11	9	17:40:00	\N	WORKING_DAYS	RETURN
16	11	9	18:30:00	\N	WORKING_DAYS	RETURN
17	12	10	07:30:00	\N	WORKING_DAYS	OUTBOUND
18	12	10	07:50:00	\N	WORKING_DAYS	OUTBOUND
19	12	10	08:15:00	\N	WORKING_DAYS	OUTBOUND
20	12	10	08:40:00	\N	WORKING_DAYS	OUTBOUND
21	12	10	14:00:00	\N	WORKING_DAYS	OUTBOUND
22	12	10	16:40:00	\N	WORKING_DAYS	OUTBOUND
23	12	10	07:40:00	\N	WORKING_DAYS	RETURN
24	12	10	08:05:00	\N	WORKING_DAYS	RETURN
25	12	10	08:30:00	\N	WORKING_DAYS	RETURN
26	12	10	08:55:00	\N	WORKING_DAYS	RETURN
27	12	10	14:30:00	\N	WORKING_DAYS	RETURN
28	12	10	17:00:00	\N	WORKING_DAYS	RETURN
\.


--
-- Name: schedules_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.schedules_schedule_id_seq', 28, true);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (schedule_id);


--
-- Name: schedules fk_schedule_bus; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT fk_schedule_bus FOREIGN KEY (bus_id) REFERENCES public.buses(bus_id) ON DELETE SET NULL;


--
-- Name: schedules fk_schedule_route; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT fk_schedule_route FOREIGN KEY (route_id) REFERENCES public.routes(route_id) ON DELETE CASCADE;


--
-- Name: TABLE schedules; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.schedules TO asus;


--
-- Name: SEQUENCE schedules_schedule_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.schedules_schedule_id_seq TO asus;


--
-- PostgreSQL database dump complete
--

\unrestrict 7Mx9GnUjoKN0Lawe41hh20c80TCa9CGactBecyxboezf6Ki8XW85PefbHRUgTr2

