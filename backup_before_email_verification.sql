--
-- PostgreSQL database dump
--

\restrict 3U9hZDwy8FTLytCJZZ7W1eRafh0ZACiiKBPWfqUEUlw2zB8q7LXhUcIQhKQU4zK

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

--
-- Name: validate_new_trip_assignment(); Type: FUNCTION; Schema: public; Owner: bus_admin
--

CREATE FUNCTION public.validate_new_trip_assignment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    assigned_driver INTEGER;
    assigned_route INTEGER;
BEGIN
    SELECT driver_id, route_id
    INTO assigned_driver, assigned_route
    FROM buses
    WHERE bus_id = NEW.bus_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Assigned bus does not exist';
    END IF;

    IF assigned_driver IS NULL THEN
        RAISE EXCEPTION 'Assign a driver to this bus before creating a trip';
    END IF;

    IF assigned_route IS NULL THEN
        RAISE EXCEPTION 'Assign a route to this bus before creating a trip';
    END IF;

    IF NEW.driver_id IS DISTINCT FROM assigned_driver THEN
        RAISE EXCEPTION 'Trip driver does not match assigned bus driver';
    END IF;

    IF NEW.route_id IS DISTINCT FROM assigned_route THEN
        RAISE EXCEPTION 'Trip route does not match assigned bus route';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_new_trip_assignment() OWNER TO bus_admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bus_geofence_simulator_state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bus_geofence_simulator_state (
    bus_id integer NOT NULL,
    is_inside boolean NOT NULL,
    last_latitude numeric(10,7) NOT NULL,
    last_longitude numeric(10,7) NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.bus_geofence_simulator_state OWNER TO postgres;

--
-- Name: bus_geofence_state; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.bus_geofence_state (
    bus_id integer NOT NULL,
    is_inside boolean NOT NULL,
    last_latitude numeric(10,7) NOT NULL,
    last_longitude numeric(10,7) NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.bus_geofence_state OWNER TO bus_admin;

--
-- Name: bus_geofence_validation_state; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.bus_geofence_validation_state (
    bus_id integer NOT NULL,
    source character varying(10) NOT NULL,
    candidate_inside boolean,
    candidate_started_at timestamp with time zone,
    candidate_last_at timestamp with time zone,
    candidate_count integer DEFAULT 0 NOT NULL,
    last_recorded_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT bus_geofence_validation_state_candidate_count_check CHECK ((candidate_count >= 0)),
    CONSTRAINT bus_geofence_validation_state_source_check CHECK (((source)::text = ANY ((ARRAY['REAL'::character varying, 'SIMULATED'::character varying])::text[])))
);


ALTER TABLE public.bus_geofence_validation_state OWNER TO bus_admin;

--
-- Name: bus_locations; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.bus_locations (
    location_id bigint NOT NULL,
    trip_id integer NOT NULL,
    bus_id integer NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    speed numeric(6,2),
    recorded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bus_locations OWNER TO bus_admin;

--
-- Name: bus_locations_location_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.bus_locations_location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bus_locations_location_id_seq OWNER TO bus_admin;

--
-- Name: bus_locations_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.bus_locations_location_id_seq OWNED BY public.bus_locations.location_id;


--
-- Name: bus_locations_timezone_backup_20261124; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bus_locations_timezone_backup_20261124 (
    location_id bigint,
    trip_id integer,
    bus_id integer,
    latitude numeric(10,7),
    longitude numeric(10,7),
    speed numeric(6,2),
    recorded_at timestamp without time zone
);


ALTER TABLE public.bus_locations_timezone_backup_20261124 OWNER TO postgres;

--
-- Name: buses; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.buses (
    bus_id integer NOT NULL,
    bus_number character varying(50) NOT NULL,
    bus_type character varying(20) NOT NULL,
    capacity integer,
    registration_number character varying(50),
    driver_id integer,
    front_photo character varying(255),
    side_photo character varying(255),
    route_id integer,
    CONSTRAINT buses_bus_type_check CHECK (((bus_type)::text = ANY ((ARRAY['ROUTE_BUS'::character varying, 'SHUTTLE_BUS'::character varying])::text[])))
);


ALTER TABLE public.buses OWNER TO bus_admin;

--
-- Name: buses_bus_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.buses_bus_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.buses_bus_id_seq OWNER TO bus_admin;

--
-- Name: buses_bus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.buses_bus_id_seq OWNED BY public.buses.bus_id;


--
-- Name: driver_registration_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.driver_registration_requests (
    request_id integer NOT NULL,
    user_id integer NOT NULL,
    license_number character varying(50) NOT NULL,
    phone character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    reviewed_by integer,
    reviewed_at timestamp without time zone,
    rejection_reason text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT driver_registration_requests_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[])))
);


ALTER TABLE public.driver_registration_requests OWNER TO postgres;

--
-- Name: driver_registration_requests_request_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.driver_registration_requests_request_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.driver_registration_requests_request_id_seq OWNER TO postgres;

--
-- Name: driver_registration_requests_request_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.driver_registration_requests_request_id_seq OWNED BY public.driver_registration_requests.request_id;


--
-- Name: drivers; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.drivers (
    driver_id integer NOT NULL,
    user_id integer NOT NULL,
    license_number character varying(50) NOT NULL,
    phone character varying(20)
);


ALTER TABLE public.drivers OWNER TO bus_admin;

--
-- Name: drivers_driver_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.drivers_driver_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.drivers_driver_id_seq OWNER TO bus_admin;

--
-- Name: drivers_driver_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.drivers_driver_id_seq OWNED BY public.drivers.driver_id;


--
-- Name: faculty; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.faculty (
    faculty_id integer NOT NULL,
    user_id integer NOT NULL,
    employee_id character varying(50) NOT NULL,
    department character varying(100)
);


ALTER TABLE public.faculty OWNER TO bus_admin;

--
-- Name: faculty_faculty_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.faculty_faculty_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.faculty_faculty_id_seq OWNER TO bus_admin;

--
-- Name: faculty_faculty_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.faculty_faculty_id_seq OWNED BY public.faculty.faculty_id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.notifications (
    notification_id integer NOT NULL,
    user_id integer NOT NULL,
    title character varying(150) NOT NULL,
    message text NOT NULL,
    notification_type character varying(50),
    is_read boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.notifications OWNER TO bus_admin;

--
-- Name: notifications_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.notifications_notification_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_notification_id_seq OWNER TO bus_admin;

--
-- Name: notifications_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.notifications_notification_id_seq OWNED BY public.notifications.notification_id;


--
-- Name: routes; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.routes (
    route_id integer NOT NULL,
    route_name character varying(100) NOT NULL,
    route_code character varying(50) NOT NULL,
    description text,
    start_point character varying(150),
    end_point character varying(150),
    is_active boolean DEFAULT true
);


ALTER TABLE public.routes OWNER TO bus_admin;

--
-- Name: routes_route_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.routes_route_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.routes_route_id_seq OWNER TO bus_admin;

--
-- Name: routes_route_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.routes_route_id_seq OWNED BY public.routes.route_id;


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
-- Name: stops; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.stops (
    stop_id integer NOT NULL,
    route_id integer NOT NULL,
    stop_name character varying(150) NOT NULL,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    stop_order integer NOT NULL,
    pickup_time time without time zone,
    drop_time time without time zone
);


ALTER TABLE public.stops OWNER TO bus_admin;

--
-- Name: stops_stop_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.stops_stop_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stops_stop_id_seq OWNER TO bus_admin;

--
-- Name: stops_stop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.stops_stop_id_seq OWNED BY public.stops.stop_id;


--
-- Name: students; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.students (
    student_id integer NOT NULL,
    user_id integer NOT NULL,
    enrollment_no character varying(50) NOT NULL,
    department character varying(100),
    semester integer
);


ALTER TABLE public.students OWNER TO bus_admin;

--
-- Name: students_student_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.students_student_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.students_student_id_seq OWNER TO bus_admin;

--
-- Name: students_student_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.students_student_id_seq OWNED BY public.students.student_id;


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.subscriptions (
    subscription_id integer NOT NULL,
    student_id integer NOT NULL,
    route_id integer NOT NULL,
    subscribed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_active boolean DEFAULT true
);


ALTER TABLE public.subscriptions OWNER TO bus_admin;

--
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.subscriptions_subscription_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.subscriptions_subscription_id_seq OWNER TO bus_admin;

--
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.subscriptions_subscription_id_seq OWNED BY public.subscriptions.subscription_id;


--
-- Name: trip_stop_events; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.trip_stop_events (
    event_id bigint NOT NULL,
    trip_id integer NOT NULL,
    stop_id integer NOT NULL,
    arrival_time timestamp without time zone,
    departure_time timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT valid_stop_event_times CHECK (((departure_time IS NULL) OR ((arrival_time IS NOT NULL) AND (departure_time >= arrival_time))))
);


ALTER TABLE public.trip_stop_events OWNER TO bus_admin;

--
-- Name: trip_stop_events_event_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.trip_stop_events_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trip_stop_events_event_id_seq OWNER TO bus_admin;

--
-- Name: trip_stop_events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.trip_stop_events_event_id_seq OWNED BY public.trip_stop_events.event_id;


--
-- Name: trips; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.trips (
    trip_id integer NOT NULL,
    bus_id integer NOT NULL,
    route_id integer NOT NULL,
    driver_id integer,
    trip_date date DEFAULT CURRENT_DATE,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    status character varying(20) DEFAULT 'SCHEDULED'::character varying,
    source character varying(20) DEFAULT 'REAL'::character varying NOT NULL,
    CONSTRAINT trips_status_check CHECK (((status)::text = ANY ((ARRAY['SCHEDULED'::character varying, 'ACTIVE'::character varying, 'COMPLETED'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE public.trips OWNER TO bus_admin;

--
-- Name: trips_trip_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.trips_trip_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trips_trip_id_seq OWNER TO bus_admin;

--
-- Name: trips_trip_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.trips_trip_id_seq OWNED BY public.trips.trip_id;


--
-- Name: user_notification_preferences; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_notification_preferences (
    user_id integer NOT NULL,
    preferences jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_notification_preferences OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: bus_admin
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(150) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(20) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_active boolean DEFAULT true,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['STUDENT'::character varying, 'DRIVER'::character varying, 'FACULTY'::character varying, 'ADMIN'::character varying])::text[])))
);


ALTER TABLE public.users OWNER TO bus_admin;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: bus_admin
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_user_id_seq OWNER TO bus_admin;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: bus_admin
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: bus_locations location_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.bus_locations ALTER COLUMN location_id SET DEFAULT nextval('public.bus_locations_location_id_seq'::regclass);


--
-- Name: buses bus_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.buses ALTER COLUMN bus_id SET DEFAULT nextval('public.buses_bus_id_seq'::regclass);


--
-- Name: driver_registration_requests request_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_registration_requests ALTER COLUMN request_id SET DEFAULT nextval('public.driver_registration_requests_request_id_seq'::regclass);


--
-- Name: drivers driver_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.drivers ALTER COLUMN driver_id SET DEFAULT nextval('public.drivers_driver_id_seq'::regclass);


--
-- Name: faculty faculty_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.faculty ALTER COLUMN faculty_id SET DEFAULT nextval('public.faculty_faculty_id_seq'::regclass);


--
-- Name: notifications notification_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.notifications ALTER COLUMN notification_id SET DEFAULT nextval('public.notifications_notification_id_seq'::regclass);


--
-- Name: routes route_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.routes ALTER COLUMN route_id SET DEFAULT nextval('public.routes_route_id_seq'::regclass);


--
-- Name: schedules schedule_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.schedules ALTER COLUMN schedule_id SET DEFAULT nextval('public.schedules_schedule_id_seq'::regclass);


--
-- Name: stops stop_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.stops ALTER COLUMN stop_id SET DEFAULT nextval('public.stops_stop_id_seq'::regclass);


--
-- Name: students student_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.students ALTER COLUMN student_id SET DEFAULT nextval('public.students_student_id_seq'::regclass);


--
-- Name: subscriptions subscription_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.subscriptions ALTER COLUMN subscription_id SET DEFAULT nextval('public.subscriptions_subscription_id_seq'::regclass);


--
-- Name: trip_stop_events event_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trip_stop_events ALTER COLUMN event_id SET DEFAULT nextval('public.trip_stop_events_event_id_seq'::regclass);


--
-- Name: trips trip_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trips ALTER COLUMN trip_id SET DEFAULT nextval('public.trips_trip_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Data for Name: bus_geofence_simulator_state; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus_geofence_simulator_state (bus_id, is_inside, last_latitude, last_longitude, updated_at) FROM stdin;
1	f	13.2250000	77.7539430	2026-11-18 11:49:17.974014
\.


--
-- Data for Name: bus_geofence_state; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.bus_geofence_state (bus_id, is_inside, last_latitude, last_longitude, updated_at) FROM stdin;
1	f	13.2406908	77.7178163	2026-11-27 09:41:03.033904
2	f	13.2405318	77.7182197	2026-11-27 13:35:07.918864
\.


--
-- Data for Name: bus_geofence_validation_state; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.bus_geofence_validation_state (bus_id, source, candidate_inside, candidate_started_at, candidate_last_at, candidate_count, last_recorded_at, updated_at) FROM stdin;
1	REAL	\N	\N	\N	0	2026-11-27 04:11:02.464+00	2026-11-27 04:11:03.033904+00
2	REAL	\N	\N	\N	0	2026-11-27 08:05:07.763+00	2026-11-27 08:05:07.918864+00
\.


--
-- Data for Name: bus_locations; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.bus_locations (location_id, trip_id, bus_id, latitude, longitude, speed, recorded_at) FROM stdin;
1	2	1	16.8302000	75.7150000	30.00	2026-10-08 17:56:41.395921
2	2	1	16.8302000	75.7150000	30.00	2026-10-08 17:56:57.293476
3	2	1	13.2408447	77.7171378	\N	2026-10-08 18:33:22.418866
4	2	1	13.2408217	77.7173535	\N	2026-10-08 18:36:39.036159
5	2	1	13.2410772	77.7166275	\N	2026-10-09 18:16:04.315016
6	2	1	13.2408702	77.7175544	\N	2026-10-09 18:16:23.532542
7	2	1	13.2407359	77.7180365	\N	2026-10-09 18:16:49.16818
8	2	1	13.2407359	77.7180365	\N	2026-10-09 18:17:07.697575
9	2	1	13.2408760	77.7175671	\N	2026-10-09 18:17:18.274579
10	2	1	13.2411161	77.7162537	\N	2026-10-09 18:19:19.378811
11	2	1	13.2408399	77.7168326	\N	2026-10-09 18:19:39.767335
12	2	1	13.2408319	77.7168251	\N	2026-10-09 18:19:57.355366
13	2	1	13.2408185	77.7169101	\N	2026-10-09 18:20:16.693548
14	2	1	16.8302000	75.7150000	30.00	2026-10-10 11:27:39.65171
15	2	1	13.2405920	77.7192190	\N	2026-10-10 11:47:59.397702
16	2	1	13.2405641	77.7169327	\N	2026-10-10 11:50:23.142121
17	2	1	12.9786000	77.3640000	\N	2026-10-10 11:50:52.349971
18	2	1	13.2407018	77.7173106	\N	2026-10-10 11:52:13.622523
19	3	1	13.2407673	77.7174502	\N	2026-10-18 10:52:35.780004
20	3	1	13.2407933	77.7173010	\N	2026-10-18 10:52:47.685592
21	3	1	13.2411481	77.7165524	\N	2026-10-18 10:59:12.965605
22	3	1	13.2407511	77.7173974	\N	2026-10-18 10:59:24.947171
23	3	1	13.2407511	77.7173974	\N	2026-10-18 10:59:43.445796
24	3	1	13.2407300	77.7173412	\N	2026-10-18 10:59:54.865268
25	3	1	13.2407616	77.7173210	\N	2026-10-18 11:00:35.179149
26	3	1	13.2406991	77.7171149	\N	2026-10-18 11:01:46.866039
27	3	1	13.2406898	77.7170811	\N	2026-10-18 11:02:02.639377
28	4	1	13.2407016	77.7171017	\N	2026-10-18 12:06:58.611468
29	4	1	13.2406933	77.7171836	\N	2026-10-18 12:07:11.033008
30	4	1	13.2407457	77.7170849	\N	2026-10-18 12:07:25.659177
31	4	1	13.2408111	77.7171104	\N	2026-10-18 12:07:38.185222
32	4	1	13.2408097	77.7171108	\N	2026-10-18 12:08:51.039738
33	4	1	13.2408310	77.7171537	\N	2026-10-18 12:09:11.274964
34	4	1	13.2408415	77.7167814	\N	2026-10-18 12:09:25.27485
35	5	1	12.9786000	77.3640000	\N	2026-10-18 12:41:03.277955
36	5	1	13.2406722	77.7174984	\N	2026-10-18 12:41:18.490129
37	5	1	13.2407267	77.7174605	\N	2026-10-18 12:41:38.164265
38	5	1	13.2407989	77.7174540	\N	2026-10-18 12:42:01.458757
39	5	1	13.2407989	77.7174540	\N	2026-10-18 12:42:17.838579
40	5	1	13.2407685	77.7174273	\N	2026-10-18 12:42:31.110847
41	5	1	13.2406017	77.7172475	\N	2026-10-25 09:27:34.212459
42	5	1	13.2406375	77.7171764	\N	2026-10-25 09:27:34.261755
43	5	1	13.2407877	77.7172786	\N	2026-10-25 09:27:34.264489
44	5	1	13.2407664	77.7174588	\N	2026-10-25 09:27:34.267009
45	5	1	13.2407664	77.7174588	\N	2026-10-25 09:27:34.271063
46	5	1	13.2406613	77.7172438	\N	2026-10-25 09:27:34.275625
47	5	1	13.2406142	77.7171521	\N	2026-10-25 09:27:34.280499
48	5	1	13.2408277	77.7172895	\N	2026-10-25 09:28:01.21013
49	5	1	13.2407849	77.7168226	\N	2026-10-25 09:28:13.311334
50	6	1	13.2408952	77.7168983	\N	2026-11-07 11:37:24.788362
51	6	1	13.2409629	77.7168614	\N	2026-11-07 11:38:22.673528
52	6	1	13.2409612	77.7169391	\N	2026-11-07 11:38:43.100669
53	6	1	13.2409345	77.7168279	\N	2026-11-07 11:41:05.210047
54	6	1	13.2401380	77.7171330	\N	2026-11-07 11:48:34.274462
55	6	1	13.2407987	77.7171226	\N	2026-11-08 10:08:13.728112
56	6	1	13.2407938	77.7177695	\N	2026-11-08 10:08:25.883564
57	6	1	13.2407887	77.7177518	\N	2026-11-08 10:08:46.07903
58	7	2	13.2405006	77.7174027	\N	2026-11-10 18:02:30.161496
59	7	2	13.2408333	77.7170520	\N	2026-11-10 18:02:48.517482
60	7	2	13.2407516	77.7175152	\N	2026-11-10 18:03:00.189633
61	7	2	13.2407961	77.7175371	\N	2026-11-10 18:03:36.969025
62	8	2	13.2445610	77.7136520	25.00	2026-11-16 19:01:47.426235
63	8	2	13.2445610	77.7136520	25.00	2026-11-16 19:02:01.966528
64	9	2	13.2403743	77.7185256	\N	2026-11-16 20:17:00.792507
65	9	2	12.9786000	77.3640000	\N	2026-11-16 20:17:18.989797
66	9	2	13.2407650	77.7175698	\N	2026-11-16 20:17:44.543466
67	9	2	13.2404418	77.7178306	\N	2026-11-16 20:19:44.763993
68	9	2	13.2404744	77.7179530	\N	2026-11-16 20:19:55.570678
69	9	2	13.2404887	77.7179435	\N	2026-11-16 20:20:16.436055
70	9	2	13.2404117	77.7182036	\N	2026-11-16 20:27:05.990563
71	9	2	13.0721000	77.7922000	\N	2026-11-16 21:04:20.044304
72	9	2	13.2404336	77.7187786	\N	2026-11-16 21:10:12.522388
73	9	2	13.2407304	77.7177320	\N	2026-11-16 21:37:18.487875
74	9	2	13.0721000	77.7922000	\N	2026-11-16 21:37:50.319518
75	9	2	13.2407269	77.7175334	\N	2026-11-16 21:38:06.873511
76	9	2	13.0721000	77.7922000	\N	2026-11-16 21:38:24.761594
77	9	2	13.2407269	77.7175334	\N	2026-11-16 21:38:34.04103
78	9	2	13.0721000	77.7922000	\N	2026-11-16 21:40:09.377484
79	9	2	13.2409087	77.7168824	\N	2026-11-16 21:49:08.631635
80	9	2	13.2409087	77.7168824	\N	2026-11-16 21:49:29.865766
81	9	2	13.2408923	77.7168771	\N	2026-11-16 21:49:40.222897
82	9	2	13.2408923	77.7168771	\N	2026-11-16 21:49:46.496863
83	9	2	13.2408923	77.7168771	\N	2026-11-16 21:49:48.566124
84	9	2	13.2401912	77.7186650	\N	2026-11-16 21:54:00.762867
85	9	2	13.2406970	77.7178837	\N	2026-11-16 22:05:18.133626
86	9	2	13.2406970	77.7178837	\N	2026-11-16 22:05:19.227768
87	9	2	13.0721000	77.7922000	\N	2026-11-16 22:05:38.522587
88	9	2	13.2408776	77.7176744	\N	2026-11-16 22:05:43.296434
89	9	2	13.2408722	77.7176533	\N	2026-11-16 22:06:57.847128
90	9	2	13.2408722	77.7176533	\N	2026-11-16 22:07:00.381196
91	9	2	13.2408604	77.7176197	\N	2026-11-16 22:12:57.063753
92	9	2	13.2408752	77.7176956	\N	2026-11-16 22:13:57.624029
93	9	2	13.2408752	77.7176956	\N	2026-11-16 22:13:59.185867
94	9	2	13.2408752	77.7176956	\N	2026-11-16 22:14:01.521533
95	9	2	12.9786000	77.3640000	\N	2026-11-17 19:22:17.658118
96	9	2	13.2405169	77.7178375	\N	2026-11-17 19:22:20.502342
97	9	2	13.2405169	77.7178375	\N	2026-11-17 19:22:22.328061
98	9	2	13.2407078	77.7179837	\N	2026-11-17 19:22:40.453036
99	9	2	13.2407078	77.7179837	\N	2026-11-17 19:22:42.205858
100	10	1	13.2250000	77.7539430	20.00	2026-11-17 20:17:52.963953
101	11	1	13.2250000	77.7539430	20.00	2026-11-18 06:19:18.501372
102	9	2	13.2229593	77.7564961	\N	2026-11-18 06:45:52.764636
103	9	2	13.2229593	77.7564961	\N	2026-11-18 06:45:56.484138
104	9	2	13.2229471	77.7564998	\N	2026-11-18 06:49:09.302334
105	9	2	13.2229471	77.7564998	\N	2026-11-18 06:49:10.647851
106	9	2	13.2229734	77.7564729	\N	2026-11-18 06:49:23.302571
107	9	2	13.2229602	77.7564797	\N	2026-11-18 06:49:41.437314
108	9	2	13.2229584	77.7564789	\N	2026-11-18 06:49:54.692921
109	9	2	13.2230060	77.7564643	\N	2026-11-18 06:55:47.392459
110	9	2	13.2229848	77.7564556	\N	2026-11-18 06:56:10.49022
111	9	2	13.2229848	77.7564556	\N	2026-11-18 06:56:20.285428
112	9	2	13.2229902	77.7564517	\N	2026-11-18 07:08:01.60728
113	9	2	13.2229902	77.7564517	\N	2026-11-18 07:08:08.209791
114	9	2	13.2229867	77.7564620	\N	2026-11-18 07:08:14.161204
115	9	2	13.2201800	77.7555100	\N	2026-11-18 07:08:32.927489
116	9	2	13.2229721	77.7564640	\N	2026-11-18 07:08:47.294904
117	9	2	13.2229720	77.7564641	\N	2026-11-18 07:09:08.42023
118	9	2	13.2229660	77.7564695	\N	2026-11-18 07:09:26.01384
119	9	2	13.2229657	77.7564640	\N	2026-11-18 07:09:43.312589
120	9	2	13.2229574	77.7565032	\N	2026-11-18 07:22:56.794242
774	13	1	13.2401170	77.7166930	0.05	2026-11-23 20:10:21.577
775	13	1	13.2401158	77.7166929	0.06	2026-11-23 20:10:27.586
776	13	1	13.2401165	77.7166932	0.05	2026-11-23 20:10:33.603
777	13	1	13.2401178	77.7166931	0.06	2026-11-23 20:10:38.578
778	13	1	13.2401188	77.7166930	0.06	2026-11-23 20:10:43.669
779	13	1	13.2401197	77.7166920	0.06	2026-11-23 20:10:49.576
780	13	1	13.2401208	77.7166911	0.08	2026-11-23 20:10:54.661
781	13	1	13.2401228	77.7166902	0.06	2026-11-23 20:11:00.677
782	13	1	13.2401229	77.7166906	0.07	2026-11-23 20:11:06.578
783	13	1	13.2401228	77.7166908	0.07	2026-11-23 20:11:11.668
784	13	1	13.2401239	77.7166915	0.06	2026-11-23 20:11:17.575
785	13	1	13.2401244	77.7166920	0.06	2026-11-23 20:11:22.661
786	13	1	13.2401234	77.7166923	0.06	2026-11-23 20:11:27.636
787	13	1	13.2401219	77.7166923	0.06	2026-11-23 20:11:33.652
788	13	1	13.2401207	77.7166914	0.07	2026-11-23 20:11:39.669
789	13	1	13.2401203	77.7166919	0.06	2026-11-23 20:11:44.644
790	13	1	13.2401201	77.7166917	0.06	2026-11-23 20:11:50.661
791	13	1	13.2401201	77.7166911	0.06	2026-11-23 20:11:56.676
792	13	1	13.2401194	77.7166909	0.07	2026-11-23 20:12:02.578
793	13	1	13.2401181	77.7166907	0.06	2026-11-23 20:12:08.593
794	13	1	13.2401176	77.7166908	0.07	2026-11-23 20:12:13.685
795	13	1	13.2401171	77.7166894	0.06	2026-11-23 20:12:19.586
796	13	1	13.2401174	77.7166908	0.05	2026-11-23 20:12:25.603
797	13	1	13.2401231	77.7166970	0.06	2026-11-23 20:12:30.577
798	13	1	13.2401291	77.7167062	0.06	2026-11-23 20:12:35.669
799	13	1	13.2401326	77.7167114	0.06	2026-11-23 20:12:40.643
800	13	1	13.2401372	77.7167167	0.06	2026-11-23 20:12:46.661
801	13	1	13.2401482	77.7167373	0.06	2026-11-23 20:12:52.676
802	13	1	13.2401557	77.7167526	0.07	2026-11-23 20:12:58.577
803	13	1	13.2401594	77.7167582	0.07	2026-11-23 20:13:04.595
804	13	1	13.2401609	77.7167605	0.06	2026-11-23 20:13:09.578
805	13	1	13.2401629	77.7167625	0.07	2026-11-23 20:13:15.586
806	13	1	13.2401649	77.7167637	0.07	2026-11-23 20:13:20.676
807	13	1	13.2401672	77.7167653	0.06	2026-11-23 20:13:26.582
808	13	1	13.2401694	77.7167668	0.07	2026-11-23 20:13:32.594
809	13	1	13.2401734	77.7167683	0.06	2026-11-23 20:13:38.61
810	13	1	13.2401746	77.7167695	0.06	2026-11-23 20:13:43.585
811	13	1	13.2401750	77.7167702	0.07	2026-11-23 20:13:48.676
812	13	1	13.2401749	77.7167700	0.06	2026-11-23 20:13:54.577
813	13	1	13.2401746	77.7167706	0.06	2026-11-23 20:14:00.593
814	13	1	13.2401746	77.7167706	0.06	2026-11-23 20:14:06.61
815	13	1	13.2401748	77.7167708	0.05	2026-11-23 20:14:12.627
816	13	1	13.2401749	77.7167703	0.06	2026-11-23 20:14:17.601
817	13	1	13.2401756	77.7167700	0.06	2026-11-23 20:14:23.618
818	13	1	13.2401761	77.7167707	0.06	2026-11-23 20:14:29.634
819	13	1	13.2401759	77.7167701	0.07	2026-11-23 20:14:34.61
820	13	1	13.2401767	77.7167699	0.06	2026-11-23 20:14:40.626
821	13	1	13.2401764	77.7167698	0.06	2026-11-23 20:14:46.643
822	13	1	13.2401752	77.7167696	0.07	2026-11-23 20:14:52.659
823	13	1	13.2401748	77.7167681	0.06	2026-11-23 20:14:58.676
824	13	1	13.2401733	77.7167677	0.06	2026-11-23 20:15:04.576
825	13	1	13.2401732	77.7167677	0.07	2026-11-23 20:15:09.667
826	13	1	13.2401731	77.7167685	0.07	2026-11-23 20:15:14.642
827	13	1	13.2401742	77.7167687	0.07	2026-11-23 20:15:20.659
828	13	1	13.2401745	77.7167690	0.07	2026-11-23 20:15:26.674
829	13	1	13.2401756	77.7167697	0.06	2026-11-23 20:15:32.575
830	13	1	13.2401759	77.7167697	0.06	2026-11-23 20:15:37.667
831	13	1	13.2401760	77.7167701	0.08	2026-11-23 20:15:43.682
832	13	1	13.2401758	77.7167706	0.06	2026-11-23 20:15:49.584
833	13	1	13.2401757	77.7167707	0.07	2026-11-23 20:15:54.675
834	13	1	13.2401755	77.7167715	0.06	2026-11-23 20:16:00.46
835	13	1	13.2401755	77.7167711	0.06	2026-11-23 20:16:05.667
836	13	1	13.2401755	77.7167710	0.06	2026-11-23 20:16:10.642
837	13	1	13.2401750	77.7167710	0.06	2026-11-23 20:16:15.617
838	13	1	13.2401752	77.7167699	0.07	2026-11-23 20:16:21.633
839	13	1	13.2401747	77.7167698	0.07	2026-11-23 20:16:27.65
840	13	1	13.2401746	77.7167711	0.06	2026-11-23 20:16:32.625
841	13	1	13.2401746	77.7167712	0.06	2026-11-23 20:16:38.641
842	13	1	13.2401733	77.7167705	0.03	2026-11-23 20:16:43.617
843	13	1	13.2401587	77.7167576	0.07	2026-11-23 20:16:48.592
844	13	1	13.2401546	77.7167515	0.06	2026-11-23 20:16:53.571
845	13	1	13.2401520	77.7167485	0.03	2026-11-23 20:16:58.659
846	13	1	13.2401497	77.7167460	0.04	2026-11-23 20:17:03.633
847	13	1	13.2401542	77.7167405	0.04	2026-11-23 20:17:09.651
848	13	1	13.2401602	77.7167270	0.03	2026-11-23 20:17:15.667
849	13	1	13.2401665	77.7167185	0.03	2026-11-23 20:17:21.574
850	13	1	13.2401693	77.7167156	0.04	2026-11-23 20:17:26.658
851	13	1	13.2401725	77.7167128	0.04	2026-11-23 20:17:31.633
852	13	1	13.2401761	77.7167079	0.04	2026-11-23 20:17:37.651
853	13	1	13.2401773	77.7167049	0.04	2026-11-23 20:17:43.666
854	13	1	13.2401777	77.7167032	0.04	2026-11-23 20:17:48.643
855	13	1	13.2401781	77.7167029	0.04	2026-11-23 20:17:54.659
856	13	1	13.2401789	77.7167026	0.04	2026-11-23 20:17:59.634
857	13	1	13.2401792	77.7167017	0.05	2026-11-23 20:18:05.651
858	13	1	13.2401803	77.7167014	0.05	2026-11-23 20:18:10.626
859	13	1	13.2401801	77.7167013	0.06	2026-11-23 20:18:16.642
860	13	1	13.2401801	77.7167009	0.05	2026-11-23 20:18:22.659
861	13	1	13.2401797	77.7167001	0.06	2026-11-23 20:18:27.634
862	13	1	13.2401792	77.7166996	0.06	2026-11-23 20:18:33.649
863	13	1	13.2401795	77.7166993	0.06	2026-11-23 20:18:38.625
864	13	1	13.2401799	77.7166989	0.07	2026-11-23 20:18:43.601
865	13	1	13.2401796	77.7166983	0.07	2026-11-23 20:18:49.616
866	13	1	13.2401787	77.7166981	0.07	2026-11-23 20:18:54.592
867	13	1	13.2401801	77.7166990	0.05	2026-11-23 20:19:00.609
868	13	1	13.2401809	77.7166985	0.05	2026-11-23 20:19:05.583
869	13	1	13.2401812	77.7166988	0.05	2026-11-23 20:19:10.79
870	13	1	13.2401816	77.7166992	0.07	2026-11-23 20:19:16.576
871	13	1	13.2401821	77.7167009	0.04	2026-11-23 20:19:22.591
872	13	1	13.2401791	77.7167042	0.05	2026-11-23 20:19:27.573
873	13	1	13.2401788	77.7167044	0.06	2026-11-23 20:19:32.658
874	13	1	13.2401781	77.7167052	0.05	2026-11-23 20:19:38.578
875	13	1	13.2401771	77.7167055	0.06	2026-11-23 20:19:44.577
876	13	1	13.2401564	77.7167290	0.07	2026-11-23 20:19:50.594
877	13	1	13.2401436	77.7167413	0.06	2026-11-23 20:19:56.609
878	13	1	13.2401365	77.7167501	0.07	2026-11-23 20:20:02.627
879	13	1	13.2401311	77.7167592	0.06	2026-11-23 20:20:08.643
880	13	1	13.2401255	77.7167636	0.05	2026-11-23 20:20:13.619
881	13	1	13.2401232	77.7167668	0.07	2026-11-23 20:20:18.594
882	13	1	13.2401214	77.7167694	0.06	2026-11-23 20:20:24.609
883	13	1	13.2401203	77.7167719	0.06	2026-11-23 20:20:30.627
884	13	1	13.2401204	77.7167730	0.05	2026-11-23 20:20:35.601
885	13	1	13.2401197	77.7167736	0.06	2026-11-23 20:20:40.65
886	13	1	13.2401194	77.7167751	0.06	2026-11-23 20:20:45.668
887	13	1	13.2401197	77.7167758	0.06	2026-11-23 20:20:51.577
888	13	1	13.2401200	77.7167767	0.06	2026-11-23 20:20:56.66
889	13	1	13.2401212	77.7167755	0.06	2026-11-23 20:21:01.635
890	13	1	13.2401210	77.7167758	0.06	2026-11-23 20:21:07.651
891	13	1	13.2401205	77.7167762	0.06	2026-11-23 20:21:13.668
892	13	1	13.2401195	77.7167768	0.06	2026-11-23 20:21:18.643
893	13	1	13.2401188	77.7167757	0.06	2026-11-23 20:21:24.659
894	13	1	13.2401188	77.7167762	0.07	2026-11-23 20:21:30.342
895	13	1	13.2401196	77.7167760	0.06	2026-11-23 20:21:35.651
896	13	1	13.2401196	77.7167751	0.07	2026-11-23 20:21:40.672
897	13	1	13.2401206	77.7167743	0.06	2026-11-23 20:21:46.642
898	13	1	13.2401214	77.7167735	0.07	2026-11-23 20:21:52.659
899	13	1	13.2401234	77.7167742	0.06	2026-11-23 20:21:57.633
900	13	1	13.2401248	77.7167732	0.07	2026-11-23 20:22:03.65
901	13	1	13.2401242	77.7167733	0.06	2026-11-23 20:22:09.667
902	13	1	13.2401231	77.7167725	0.07	2026-11-23 20:22:15.684
903	13	1	13.2401223	77.7167715	0.06	2026-11-23 20:22:20.774
904	13	1	13.2401216	77.7167716	0.06	2026-11-23 20:22:26.676
1318	13	1	13.2401903	77.7168478	0.06	2026-11-23 21:09:22.587
1319	13	1	13.2401900	77.7168475	0.06	2026-11-23 21:09:27.679
1320	13	1	13.2401895	77.7168473	0.06	2026-11-23 21:09:33.579
1321	13	1	13.2401892	77.7168473	0.07	2026-11-23 21:09:38.669
1322	13	1	13.2401890	77.7168486	0.06	2026-11-23 21:09:44.339
1323	13	1	13.2401890	77.7168486	0.06	2026-11-23 21:09:49.66
1324	13	1	13.2401887	77.7168483	0.06	2026-11-23 21:09:55.573
1325	13	1	13.2401890	77.7168480	0.07	2026-11-23 21:10:00.651
1326	13	1	13.2401894	77.7168487	0.06	2026-11-23 21:10:05.626
1327	13	1	13.2401895	77.7168479	0.06	2026-11-23 21:10:10.602
1328	13	1	13.2401898	77.7168485	0.06	2026-11-23 21:10:16.618
1329	13	1	13.2401901	77.7168488	0.07	2026-11-23 21:10:21.593
1330	13	1	13.2401904	77.7168488	0.06	2026-11-23 21:10:26.577
1331	13	1	13.2401909	77.7168489	0.08	2026-11-23 21:10:32.584
1332	13	1	13.2401903	77.7168488	0.05	2026-11-23 21:10:38.6
1333	13	1	13.2401906	77.7168491	0.06	2026-11-23 21:10:43.575
1334	13	1	13.2401904	77.7168494	0.06	2026-11-23 21:10:49.591
1335	13	1	13.2401891	77.7168477	0.06	2026-11-23 21:10:55.607
1336	13	1	13.2401884	77.7168473	0.07	2026-11-23 21:11:00.582
1337	13	1	13.2401880	77.7168458	0.06	2026-11-23 21:11:05.672
1338	13	1	13.2401872	77.7168449	0.06	2026-11-23 21:11:11.577
1339	13	1	13.2401869	77.7168452	0.05	2026-11-23 21:11:16.663
1340	13	1	13.2401867	77.7168467	0.06	2026-11-23 21:11:22.577
1341	13	1	13.2401870	77.7168468	0.05	2026-11-23 21:11:27.655
1342	13	1	13.2401872	77.7168468	0.06	2026-11-23 21:11:33.44
1343	13	1	13.2401866	77.7168466	0.06	2026-11-23 21:11:38.646
1344	13	1	13.2401865	77.7168472	0.07	2026-11-23 21:11:43.62
1345	13	1	13.2401865	77.7168471	0.06	2026-11-23 21:11:48.595
1346	13	1	13.2401871	77.7168480	0.06	2026-11-23 21:11:54.611
1347	13	1	13.2401879	77.7168486	0.07	2026-11-23 21:12:00.629
1348	13	1	13.2401877	77.7168491	0.06	2026-11-23 21:12:05.604
1349	13	1	13.2401877	77.7168491	0.06	2026-11-23 21:12:10.579
1350	13	1	13.2401876	77.7168496	0.07	2026-11-23 21:12:16.595
1351	13	1	13.2401882	77.7168505	0.07	2026-11-23 21:12:22.61
1352	13	1	13.2401886	77.7168506	0.07	2026-11-23 21:12:28.627
1353	13	1	13.2401887	77.7168500	0.06	2026-11-23 21:12:33.601
1354	13	1	13.2401883	77.7168491	0.06	2026-11-23 21:12:39.618
1355	13	1	13.2401883	77.7168490	0.03	2026-11-23 21:12:44.593
1356	13	1	13.2401882	77.7168482	0.04	2026-11-23 21:12:50.608
1357	13	1	13.2401879	77.7168479	0.03	2026-11-23 21:12:56.625
1358	13	1	13.2401884	77.7168476	0.05	2026-11-23 21:13:01.6
1359	13	1	13.2401885	77.7168474	0.03	2026-11-23 21:13:07.616
1360	13	1	13.2401882	77.7168477	0.04	2026-11-23 21:13:12.591
1361	13	1	13.2401877	77.7168477	0.04	2026-11-23 21:13:18.608
1362	13	1	13.2401876	77.7168477	0.04	2026-11-23 21:13:23.581
1363	13	1	13.2401870	77.7168476	0.04	2026-11-23 21:13:29.599
1364	13	1	13.2401870	77.7168477	0.04	2026-11-23 21:13:35.615
1365	13	1	13.2401880	77.7168477	0.03	2026-11-23 21:13:41.631
1366	13	1	13.2401882	77.7168476	0.04	2026-11-23 21:13:46.606
1367	13	1	13.2401883	77.7168481	0.05	2026-11-23 21:13:52.391
1368	13	1	13.2401879	77.7168487	0.04	2026-11-23 21:13:57.596
1369	13	1	13.2401881	77.7168486	0.04	2026-11-23 21:14:03.612
1370	13	1	13.2401880	77.7168485	0.03	2026-11-23 21:14:08.588
1371	13	1	13.2401882	77.7168489	0.04	2026-11-23 21:14:13.679
1372	13	1	13.2401881	77.7168492	0.04	2026-11-23 21:14:19.578
1373	13	1	13.2401884	77.7168490	0.04	2026-11-23 21:14:25.595
1374	13	1	13.2401878	77.7168486	0.03	2026-11-23 21:14:30.574
1375	13	1	13.2401874	77.7168487	0.04	2026-11-23 21:14:36.587
1376	13	1	13.2401877	77.7168487	0.04	2026-11-23 21:14:42.024
1377	13	1	13.2401877	77.7168495	0.04	2026-11-23 21:14:47.578
1378	13	1	13.2401194	77.7167903	0.03	2026-11-23 21:14:52.668
1379	13	1	13.2401192	77.7167905	0.04	2026-11-23 21:14:57.642
1380	13	1	13.2401188	77.7167906	0.03	2026-11-23 21:15:02.618
1381	13	1	13.2401192	77.7167908	0.04	2026-11-23 21:15:08.634
1382	13	1	13.2401195	77.7167909	0.03	2026-11-23 21:15:13.609
1383	13	1	13.2401197	77.7167909	0.03	2026-11-23 21:15:18.584
1384	13	1	13.2401201	77.7167907	0.03	2026-11-23 21:15:23.674
1385	13	1	13.2401200	77.7167894	0.04	2026-11-23 21:15:29.579
1386	13	1	13.2401204	77.7167893	0.03	2026-11-23 21:15:35.591
1387	13	1	13.2401207	77.7167897	0.04	2026-11-23 21:15:41.608
1499	13	1	13.2401205	77.7168825	0.03	2026-11-23 21:28:54.666
905	13	1	13.2401212	77.7167718	0.07	2026-11-23 20:22:31.652
906	13	1	13.2401208	77.7167715	0.06	2026-11-23 20:22:37.668
907	13	1	13.2401202	77.7167710	0.06	2026-11-23 20:22:42.643
908	13	1	13.2401195	77.7167703	0.06	2026-11-23 20:22:47.618
909	13	1	13.2401195	77.7167697	0.07	2026-11-23 20:22:52.594
910	13	1	13.2401191	77.7167700	0.06	2026-11-23 20:22:58.61
911	13	1	13.2401193	77.7167704	0.06	2026-11-23 20:23:03.585
912	13	1	13.2401192	77.7167700	0.06	2026-11-23 20:23:08.676
913	13	1	13.2401180	77.7167711	0.06	2026-11-23 20:23:14.578
914	13	1	13.2401217	77.7167717	\N	2026-11-23 20:25:53.732
915	13	1	13.2401422	77.7166945	0.69	2026-11-23 20:26:05.006
916	13	1	13.2401239	77.7166787	0.17	2026-11-23 20:26:10.58
917	13	1	13.2401142	77.7166705	0.17	2026-11-23 20:26:16.482
918	13	1	13.2401106	77.7166679	0.15	2026-11-23 20:26:21.576
919	13	1	13.2401108	77.7166674	0.12	2026-11-23 20:26:26.664
920	13	1	13.2401103	77.7166652	0.10	2026-11-23 20:26:32.578
921	13	1	13.2401415	77.7167908	0.07	2026-11-23 20:26:37.657
922	13	1	13.2401416	77.7167902	0.06	2026-11-23 20:26:43.571
923	13	1	13.2401415	77.7167906	0.05	2026-11-23 20:26:49.575
924	13	1	13.2401412	77.7167912	0.06	2026-11-23 20:26:55.592
925	13	1	13.2401408	77.7167912	0.06	2026-11-23 20:27:00.574
926	13	1	13.2401409	77.7167916	0.06	2026-11-23 20:27:05.658
927	13	1	13.2401409	77.7167926	0.07	2026-11-23 20:27:10.633
928	13	1	13.2401412	77.7167928	0.06	2026-11-23 20:27:16.651
929	13	1	13.2401406	77.7167935	0.06	2026-11-23 20:27:21.625
930	13	1	13.2401401	77.7167935	0.08	2026-11-23 20:27:27.41
931	13	1	13.2401404	77.7167932	0.07	2026-11-23 20:27:32.618
932	13	1	13.2401407	77.7167933	0.06	2026-11-23 20:27:38.635
933	13	1	13.2401415	77.7167920	0.06	2026-11-23 20:27:43.609
934	13	1	13.2401418	77.7167909	0.07	2026-11-23 20:27:48.585
935	13	1	13.2401415	77.7167902	0.06	2026-11-23 20:27:54.602
936	13	1	13.2401409	77.7167895	0.06	2026-11-23 20:28:00.618
937	13	1	13.2401399	77.7167887	0.08	2026-11-23 20:28:06.635
938	13	1	13.2401393	77.7167882	0.07	2026-11-23 20:28:12.65
939	13	1	13.2401403	77.7167887	0.06	2026-11-23 20:28:17.625
940	13	1	13.2401405	77.7167900	0.06	2026-11-23 20:28:22.601
941	13	1	13.2401405	77.7167903	0.06	2026-11-23 20:28:28.618
942	13	1	13.2401405	77.7167895	0.06	2026-11-23 20:28:34.634
943	13	1	13.2401403	77.7167897	0.06	2026-11-23 20:28:39.61
944	13	1	13.2401399	77.7167909	0.06	2026-11-23 20:28:45.625
945	13	1	13.2401404	77.7167917	0.07	2026-11-23 20:28:50.601
946	13	1	13.2401413	77.7167913	0.05	2026-11-23 20:28:55.577
947	13	1	13.2401411	77.7167915	0.07	2026-11-23 20:29:00.667
948	13	1	13.2401400	77.7167928	0.06	2026-11-23 20:29:06.683
949	13	1	13.2401402	77.7167939	0.05	2026-11-23 20:29:12.584
950	13	1	13.2401405	77.7167940	0.05	2026-11-23 20:29:18.601
951	13	1	13.2401413	77.7167936	0.08	2026-11-23 20:29:24.617
952	13	1	13.2401409	77.7167935	0.06	2026-11-23 20:29:29.591
953	13	1	13.2401407	77.7167926	0.06	2026-11-23 20:29:35.608
954	13	1	13.2401412	77.7167916	0.07	2026-11-23 20:29:40.583
955	13	1	13.2401421	77.7167907	0.07	2026-11-23 20:29:46.599
956	13	1	13.2401421	77.7167907	0.07	2026-11-23 20:29:52.616
957	13	1	13.2401415	77.7167902	0.05	2026-11-23 20:29:57.591
958	13	1	13.2401416	77.7167908	0.06	2026-11-23 20:30:02.574
959	13	1	13.2401415	77.7167913	0.06	2026-11-23 20:30:07.658
960	13	1	13.2401411	77.7167912	0.06	2026-11-23 20:30:12.633
961	13	1	13.2401411	77.7167912	0.06	2026-11-23 20:30:18.65
962	13	1	13.2401409	77.7167917	0.07	2026-11-23 20:30:24.667
963	13	1	13.2401409	77.7167912	0.06	2026-11-23 20:30:29.642
964	13	1	13.2401405	77.7167909	0.07	2026-11-23 20:30:35.657
965	13	1	13.2401407	77.7167913	0.06	2026-11-23 20:30:40.633
966	13	1	13.2401408	77.7167907	0.06	2026-11-23 20:30:46.57
967	13	1	13.2401400	77.7167905	0.06	2026-11-23 20:30:51.625
968	13	1	13.2401402	77.7167900	0.06	2026-11-23 20:30:57.179
969	13	1	13.2401399	77.7167906	0.06	2026-11-23 20:31:02.617
970	13	1	13.2401401	77.7167920	0.07	2026-11-23 20:31:07.591
971	13	1	13.2401403	77.7167912	0.06	2026-11-23 20:31:12.576
972	13	1	13.2401413	77.7167903	0.06	2026-11-23 20:31:18.583
973	13	1	13.2401410	77.7167904	0.07	2026-11-23 20:31:24.6
974	13	1	13.2401418	77.7167901	0.06	2026-11-23 20:31:29.578
975	13	1	13.2401422	77.7167902	0.07	2026-11-23 20:31:35.591
976	13	1	13.2401427	77.7167905	0.06	2026-11-23 20:31:40.575
977	13	1	13.2401432	77.7167909	0.06	2026-11-23 20:31:46.582
978	13	1	13.2401434	77.7167907	0.06	2026-11-23 20:31:52.598
979	13	1	13.2401440	77.7167906	0.06	2026-11-23 20:31:57.576
980	13	1	13.2401445	77.7167899	0.07	2026-11-23 20:32:02.665
981	13	1	13.2401450	77.7167912	0.07	2026-11-23 20:32:08.681
982	13	1	13.2401453	77.7167925	0.07	2026-11-23 20:32:14.582
983	13	1	13.2401451	77.7167936	0.07	2026-11-23 20:32:20.598
984	13	1	13.2401438	77.7167924	0.06	2026-11-23 20:32:26.615
985	13	1	13.2401432	77.7167924	0.05	2026-11-23 20:32:31.59
986	13	1	13.2401424	77.7167930	0.07	2026-11-23 20:32:36.576
987	13	1	13.2401425	77.7167934	0.06	2026-11-23 20:32:41.656
988	13	1	13.2401420	77.7167935	0.06	2026-11-23 20:32:47.167
989	13	1	13.2401412	77.7167945	0.06	2026-11-23 20:32:52.647
990	13	1	13.2401408	77.7167942	0.07	2026-11-23 20:32:57.621
991	13	1	13.2401412	77.7167936	0.06	2026-11-23 20:33:03.639
992	13	1	13.2401411	77.7167924	0.07	2026-11-23 20:33:08.613
993	13	1	13.2401417	77.7167928	0.07	2026-11-23 20:33:14.63
994	13	1	13.2401399	77.7167942	0.07	2026-11-23 20:33:20.647
995	13	1	13.2401397	77.7167948	0.05	2026-11-23 20:33:26.663
996	13	1	13.2401403	77.7167938	0.07	2026-11-23 20:33:32.679
997	13	1	13.2401396	77.7167918	0.06	2026-11-23 20:33:38.579
998	13	1	13.2401388	77.7167907	0.06	2026-11-23 20:33:44.595
999	13	1	13.2401385	77.7167892	0.07	2026-11-23 20:33:50.612
1000	13	1	13.2401386	77.7167891	0.06	2026-11-23 20:33:56.628
1001	13	1	13.2401401	77.7167894	0.07	2026-11-23 20:34:01.604
1002	13	1	13.2401402	77.7167901	0.06	2026-11-23 20:34:07.389
1003	13	1	13.2401397	77.7167898	0.07	2026-11-23 20:34:12.595
1004	13	1	13.2401398	77.7167896	0.05	2026-11-23 20:34:17.686
1005	13	1	13.2401407	77.7167904	0.06	2026-11-23 20:34:23.587
1006	13	1	13.2401409	77.7167905	0.04	2026-11-23 20:34:29.604
1007	13	1	13.2401468	77.7167885	0.05	2026-11-23 20:34:34.579
1008	13	1	13.2401512	77.7167855	0.07	2026-11-23 20:34:40.596
1009	13	1	13.2401520	77.7167845	0.04	2026-11-23 20:34:46.613
1010	13	1	13.2401460	77.7167875	0.04	2026-11-23 20:34:51.589
1011	13	1	13.2401402	77.7167893	0.05	2026-11-23 20:34:56.679
1012	13	1	13.2401370	77.7167920	0.06	2026-11-23 20:35:01.654
1013	13	1	13.2401345	77.7167955	0.06	2026-11-23 20:35:06.631
1014	13	1	13.2401324	77.7167966	0.07	2026-11-23 20:35:11.606
1015	13	1	13.2401303	77.7167968	0.07	2026-11-23 20:35:17.622
1016	13	1	13.2401293	77.7167986	0.06	2026-11-23 20:35:23.638
1017	13	1	13.2401288	77.7167995	0.06	2026-11-23 20:35:28.613
1018	13	1	13.2401277	77.7167992	0.06	2026-11-23 20:35:34.63
1019	13	1	13.2401275	77.7167989	0.06	2026-11-23 20:35:39.606
1020	13	1	13.2401271	77.7167996	0.06	2026-11-23 20:35:45.622
1021	13	1	13.2401267	77.7167987	0.06	2026-11-23 20:35:50.596
1022	13	1	13.2401278	77.7167998	0.06	2026-11-23 20:35:56.614
1023	13	1	13.2401279	77.7167997	0.06	2026-11-23 20:36:01.589
1024	13	1	13.2401288	77.7167992	0.06	2026-11-23 20:36:07.605
1025	13	1	13.2401290	77.7167986	0.06	2026-11-23 20:36:12.579
1026	13	1	13.2401301	77.7167972	0.06	2026-11-23 20:36:18.248
1027	13	1	13.2401303	77.7167971	0.06	2026-11-23 20:36:23.577
1028	13	1	13.2401311	77.7167970	0.06	2026-11-23 20:36:28.663
1029	13	1	13.2401320	77.7167968	0.06	2026-11-23 20:36:33.637
1030	13	1	13.2401326	77.7167966	0.06	2026-11-23 20:36:38.613
1031	13	1	13.2401319	77.7167960	0.06	2026-11-23 20:36:44.629
1032	13	1	13.2401321	77.7167961	0.07	2026-11-23 20:36:50.646
1033	13	1	13.2401308	77.7167970	0.04	2026-11-23 20:36:56.571
1034	13	1	13.2401303	77.7167969	0.04	2026-11-23 20:37:01.638
1035	13	1	13.2401298	77.7167965	0.04	2026-11-23 20:37:07.572
1036	13	1	13.2401293	77.7167960	0.04	2026-11-23 20:37:12.629
1037	13	1	13.2401294	77.7167958	0.04	2026-11-23 20:37:17.604
1038	13	1	13.2401283	77.7167966	0.05	2026-11-23 20:37:23.621
1039	13	1	13.2401284	77.7167956	0.04	2026-11-23 20:37:28.595
1040	13	1	13.2401290	77.7167953	0.03	2026-11-23 20:37:34.613
1041	13	1	13.2401298	77.7167968	0.03	2026-11-23 20:37:39.588
1042	13	1	13.2401304	77.7167979	0.04	2026-11-23 20:37:45.603
1043	13	1	13.2401301	77.7167988	0.04	2026-11-23 20:37:50.578
1044	13	1	13.2401301	77.7167988	0.04	2026-11-23 20:37:56.596
1045	13	1	13.2401302	77.7167991	0.04	2026-11-23 20:38:02.611
1046	13	1	13.2401299	77.7167997	0.04	2026-11-23 20:38:08.628
1047	13	1	13.2401295	77.7167992	0.04	2026-11-23 20:38:14.645
1048	13	1	13.2401302	77.7167985	0.03	2026-11-23 20:38:20.661
1049	13	1	13.2401299	77.7167979	0.04	2026-11-23 20:38:26.576
1050	13	1	13.2401304	77.7167983	0.04	2026-11-23 20:38:31.653
1051	13	1	13.2401300	77.7167986	0.04	2026-11-23 20:38:37.378
1388	13	1	13.2401209	77.7167900	0.05	2026-11-23 21:15:46.583
1389	13	1	13.2401210	77.7167897	0.04	2026-11-23 21:15:52.599
1390	13	1	13.2401204	77.7167888	0.03	2026-11-23 21:15:57.577
1391	13	1	13.2401204	77.7167893	0.04	2026-11-23 21:16:03.59
1392	13	1	13.2401210	77.7167904	0.03	2026-11-23 21:16:08.573
1393	13	1	13.2401210	77.7167905	0.04	2026-11-23 21:16:13.655
1394	13	1	13.2401210	77.7167908	0.04	2026-11-23 21:16:19.67
1395	13	1	13.2401214	77.7167908	0.04	2026-11-23 21:16:24.646
1396	13	1	13.2401213	77.7167911	0.03	2026-11-23 21:16:30.662
1397	13	1	13.2401205	77.7167908	0.04	2026-11-23 21:16:36.679
1398	13	1	13.2401198	77.7167909	0.03	2026-11-23 21:16:41.652
1399	13	1	13.2401258	77.7167954	0.04	2026-11-23 21:16:46.628
1400	13	1	13.2401374	77.7167994	0.04	2026-11-23 21:16:52.645
1401	13	1	13.2401444	77.7168015	0.03	2026-11-23 21:16:57.62
1402	13	1	13.2401499	77.7168049	0.04	2026-11-23 21:17:03.636
1403	13	1	13.2401532	77.7168070	0.03	2026-11-23 21:17:08.611
1404	13	1	13.2401570	77.7168085	0.04	2026-11-23 21:17:14.627
1405	13	1	13.2401533	77.7168154	0.04	2026-11-23 21:17:19.601
1406	13	1	13.2401514	77.7168281	0.03	2026-11-23 21:17:25.617
1407	13	1	13.2401486	77.7168336	0.05	2026-11-23 21:17:30.592
1408	13	1	13.2401470	77.7168349	0.04	2026-11-23 21:17:35.574
1409	13	1	13.2401461	77.7168345	0.04	2026-11-23 21:17:40.658
1410	13	1	13.2401442	77.7168335	0.03	2026-11-23 21:17:46.675
1411	13	1	13.2401409	77.7168190	0.04	2026-11-23 21:17:51.651
1412	13	1	13.2401427	77.7168095	0.04	2026-11-23 21:17:57.667
1413	13	1	13.2401425	77.7168073	0.05	2026-11-23 21:18:02.642
1414	13	1	13.2401416	77.7168057	0.05	2026-11-23 21:18:08.657
1415	13	1	13.2401408	77.7168056	0.03	2026-11-23 21:18:13.633
1416	13	1	13.2401401	77.7168046	0.04	2026-11-23 21:18:19.648
1417	13	1	13.2401398	77.7168028	0.04	2026-11-23 21:18:25.57
1418	13	1	13.2401385	77.7168031	0.04	2026-11-23 21:18:30.639
1419	13	1	13.2401374	77.7168029	0.05	2026-11-23 21:18:36.656
1420	13	1	13.2401370	77.7168034	0.03	2026-11-23 21:18:41.631
1421	13	1	13.2401368	77.7168038	0.04	2026-11-23 21:18:47.648
1422	13	1	13.2401366	77.7168041	0.03	2026-11-23 21:18:53.664
1423	14	2	13.2401367	77.7168050	\N	2026-11-23 21:19:31.06
1424	14	2	13.2401221	77.7168909	0.05	2026-11-23 21:19:36.157
1425	14	2	13.2400727	77.7168918	0.09	2026-11-23 21:19:41.61
1426	14	2	13.2400780	77.7168876	0.14	2026-11-23 21:19:47.627
1427	14	2	13.2400816	77.7168859	0.12	2026-11-23 21:19:53.18
1428	14	2	13.2400852	77.7168844	0.11	2026-11-23 21:19:58.618
1429	14	2	13.2401026	77.7168773	0.06	2026-11-23 21:20:04.634
1430	14	2	13.2401158	77.7168730	0.11	2026-11-23 21:20:10.651
1431	14	2	13.2401230	77.7168709	0.05	2026-11-23 21:20:16.668
1432	14	2	13.2401263	77.7168695	0.07	2026-11-23 21:20:21.642
1433	14	2	13.2401281	77.7168684	0.06	2026-11-23 21:20:27.659
1434	14	2	13.2401286	77.7168675	0.05	2026-11-23 21:20:32.634
1435	14	2	13.2401286	77.7168672	0.06	2026-11-23 21:20:38.651
1436	14	2	13.2401285	77.7168663	0.07	2026-11-23 21:20:44.573
1437	14	2	13.2401279	77.7168662	0.07	2026-11-23 21:20:49.642
1438	14	2	13.2401275	77.7168664	0.06	2026-11-23 21:20:54.617
1439	14	2	13.2401277	77.7168672	0.05	2026-11-23 21:21:00.632
1440	14	2	13.2401276	77.7168674	0.04	2026-11-23 21:21:06.649
1441	14	2	13.2401274	77.7168675	0.04	2026-11-23 21:21:12.575
1442	14	2	13.2401271	77.7168693	0.03	2026-11-23 21:21:17.641
1443	14	2	13.2401268	77.7168791	0.04	2026-11-23 21:21:22.616
1444	14	2	13.2401273	77.7168835	0.04	2026-11-23 21:21:27.591
1445	14	2	13.2401278	77.7168856	0.03	2026-11-23 21:21:32.798
1446	14	2	13.2401281	77.7168877	0.03	2026-11-23 21:21:38.583
1447	14	2	13.2401302	77.7168937	0.05	2026-11-23 21:21:43.674
1448	14	2	13.2401313	77.7168967	0.04	2026-11-23 21:21:49.578
1449	14	2	13.2401314	77.7168975	0.04	2026-11-23 21:21:54.665
1450	14	2	13.2401314	77.7168979	0.03	2026-11-23 21:22:00.575
1451	14	2	13.2401309	77.7168982	0.05	2026-11-23 21:22:05.656
1452	14	2	13.2401307	77.7168985	0.04	2026-11-23 21:22:11.673
1453	14	2	13.2401302	77.7168984	0.04	2026-11-23 21:22:16.648
1454	14	2	13.2401299	77.7168988	0.03	2026-11-23 21:22:22.433
1052	13	1	13.2401300	77.7167990	0.04	2026-11-23 20:38:42.644
1053	13	1	13.2401300	77.7167989	0.04	2026-11-23 20:38:47.619
1054	13	1	13.2401299	77.7167991	0.03	2026-11-23 20:38:52.594
1055	13	1	13.2401303	77.7167990	0.04	2026-11-23 20:38:58.609
1056	13	1	13.2401296	77.7167986	0.03	2026-11-23 20:39:03.586
1057	13	1	13.2401293	77.7167986	0.03	2026-11-23 20:39:08.675
1058	13	1	13.2401299	77.7167989	0.04	2026-11-23 20:39:14.577
1059	13	1	13.2401300	77.7167994	0.04	2026-11-23 20:39:19.667
1060	13	1	13.2401301	77.7167991	0.03	2026-11-23 20:39:24.643
1061	13	1	13.2401295	77.7167993	0.03	2026-11-23 20:39:29.618
1062	13	1	13.2401291	77.7167992	0.03	2026-11-23 20:39:34.593
1063	13	1	13.2401394	77.7167952	0.03	2026-11-23 20:39:40.609
1064	13	1	13.2401539	77.7167942	0.05	2026-11-23 20:39:45.584
1065	13	1	13.2401577	77.7167920	0.03	2026-11-23 20:39:51.599
1066	13	1	13.2401606	77.7167906	0.03	2026-11-23 20:39:56.575
1067	13	1	13.2401683	77.7167777	0.04	2026-11-23 20:40:02.592
1068	13	1	13.2401767	77.7167726	0.04	2026-11-23 20:40:07.575
1069	13	1	13.2401832	77.7167709	0.04	2026-11-23 20:40:13.582
1070	13	1	13.2401874	77.7167710	0.03	2026-11-23 20:40:18.673
1071	13	1	13.2401913	77.7167692	0.03	2026-11-23 20:40:24.576
1072	13	1	13.2401929	77.7167680	0.04	2026-11-23 20:40:29.664
1073	13	1	13.2401937	77.7167666	0.04	2026-11-23 20:40:35.565
1074	13	1	13.2401938	77.7167660	0.05	2026-11-23 20:40:40.656
1075	13	1	13.2401944	77.7167660	0.04	2026-11-23 20:40:46.672
1076	13	1	13.2401946	77.7167662	0.03	2026-11-23 20:40:52.574
1077	13	1	13.2401947	77.7167680	0.06	2026-11-23 20:40:57.664
1078	13	1	13.2401938	77.7167882	0.03	2026-11-23 20:41:03.576
1079	13	1	13.2401938	77.7167931	0.05	2026-11-23 20:41:08.654
1080	13	1	13.2401917	77.7167951	0.04	2026-11-23 20:41:14.67
1081	13	1	13.2401898	77.7167977	0.04	2026-11-23 20:41:19.647
1082	13	1	13.2401785	77.7168090	0.04	2026-11-23 20:41:25.128
1083	13	1	13.2401759	77.7168109	0.04	2026-11-23 20:41:30.638
1084	13	1	13.2401748	77.7168116	0.04	2026-11-23 20:41:36.654
1085	13	1	13.2401748	77.7168108	0.04	2026-11-23 20:41:42.67
1086	13	1	13.2401739	77.7168094	0.03	2026-11-23 20:41:47.645
1087	13	1	13.2401746	77.7168076	0.04	2026-11-23 20:41:53.661
1088	13	1	13.2401747	77.7168074	0.03	2026-11-23 20:41:58.637
1089	13	1	13.2401784	77.7168028	0.04	2026-11-23 20:42:03.611
1090	13	1	13.2401808	77.7168007	0.03	2026-11-23 20:42:08.587
1091	13	1	13.2401823	77.7167987	0.04	2026-11-23 20:42:14.603
1092	13	1	13.2401827	77.7167973	0.04	2026-11-23 20:42:19.578
1093	13	1	13.2401827	77.7167961	0.04	2026-11-23 20:42:25.594
1094	13	1	13.2401824	77.7167958	0.04	2026-11-23 20:42:31.61
1095	13	1	13.2401836	77.7167973	0.06	2026-11-23 20:42:36.584
1096	13	1	13.2401838	77.7167980	0.04	2026-11-23 20:42:42.601
1097	13	1	13.2401837	77.7167999	0.04	2026-11-23 20:42:47.575
1098	13	1	13.2401860	77.7168073	0.06	2026-11-23 20:42:53.593
1099	13	1	13.2401865	77.7168125	0.04	2026-11-23 20:42:59.609
1100	13	1	13.2401867	77.7168144	0.04	2026-11-23 20:43:04.583
1101	13	1	13.2401862	77.7168166	0.04	2026-11-23 20:43:10.6
1102	13	1	13.2401830	77.7168194	0.05	2026-11-23 20:43:16.616
1103	13	1	13.2401824	77.7168203	0.04	2026-11-23 20:43:21.59
1104	13	1	13.2401823	77.7168214	0.05	2026-11-23 20:43:26.681
1105	13	1	13.2401824	77.7168229	0.04	2026-11-23 20:43:32.583
1106	13	1	13.2401817	77.7168236	0.05	2026-11-23 20:43:37.672
1107	13	1	13.2401822	77.7168236	0.05	2026-11-23 20:43:43.577
1108	13	1	13.2401824	77.7168242	0.07	2026-11-23 20:43:48.664
1109	13	1	13.2401825	77.7168247	0.06	2026-11-23 20:43:54.333
1110	13	1	13.2401832	77.7168251	0.07	2026-11-23 20:43:59.655
1111	13	1	13.2401834	77.7168245	0.06	2026-11-23 20:44:05.672
1112	13	1	13.2401830	77.7168247	0.06	2026-11-23 20:44:11.576
1113	13	1	13.2401829	77.7168243	0.07	2026-11-23 20:44:16.663
1114	13	1	13.2401836	77.7168233	0.06	2026-11-23 20:44:22.574
1115	13	1	13.2401833	77.7168231	0.06	2026-11-23 20:44:27.654
1116	13	1	13.2401831	77.7168223	0.06	2026-11-23 20:44:32.629
1117	13	1	13.2401823	77.7168225	0.06	2026-11-23 20:44:37.604
1118	13	1	13.2401820	77.7168227	0.06	2026-11-23 20:44:43.619
1119	13	1	13.2401822	77.7168216	0.06	2026-11-23 20:44:48.594
1120	13	1	13.2401825	77.7168222	0.07	2026-11-23 20:44:53.583
1121	13	1	13.2401834	77.7168228	0.06	2026-11-23 20:44:59.586
1122	13	1	13.2401833	77.7168227	0.07	2026-11-23 20:45:04.676
1123	13	1	13.2401838	77.7168227	0.06	2026-11-23 20:45:09.652
1124	13	1	13.2401837	77.7168228	0.07	2026-11-23 20:45:14.625
1125	13	1	13.2401830	77.7168233	0.06	2026-11-23 20:45:20.643
1126	13	1	13.2401839	77.7168234	0.07	2026-11-23 20:45:25.617
1127	13	1	13.2401846	77.7168233	0.07	2026-11-23 20:45:31.634
1128	13	1	13.2401850	77.7168239	0.06	2026-11-23 20:45:36.609
1129	13	1	13.2401847	77.7168246	0.07	2026-11-23 20:45:41.583
1130	13	1	13.2401849	77.7168250	0.07	2026-11-23 20:45:47.599
1131	13	1	13.2401840	77.7168245	0.06	2026-11-23 20:45:53.499
1132	13	1	13.2399656	77.7168257	\N	2026-11-23 20:49:42.996
1133	13	1	13.2402070	77.7167819	0.03	2026-11-23 20:49:48.234
1134	13	1	13.2401786	77.7167338	0.14	2026-11-23 20:49:54.261
1135	13	1	13.2401766	77.7167283	0.10	2026-11-23 20:49:59.583
1136	13	1	13.2401766	77.7167277	0.10	2026-11-23 20:50:04.57
1137	13	1	13.2401772	77.7167280	0.10	2026-11-23 20:50:09.651
1138	13	1	13.2401796	77.7167292	0.09	2026-11-23 20:50:15.573
1139	13	1	13.2401748	77.7167281	0.04	2026-11-23 20:50:20.643
1140	13	1	13.2401673	77.7167256	0.03	2026-11-23 20:50:26.66
1141	13	1	13.2401645	77.7167244	0.04	2026-11-23 20:50:32.561
1142	13	1	13.2401631	77.7167240	0.05	2026-11-23 20:50:37.652
1143	13	1	13.2401622	77.7167234	0.03	2026-11-23 20:50:43.668
1144	13	1	13.2401626	77.7167232	0.06	2026-11-23 20:50:49.575
1145	13	1	13.2401622	77.7167222	0.06	2026-11-23 20:50:55.584
1146	13	1	13.2401614	77.7167221	0.06	2026-11-23 20:51:00.675
1147	13	1	13.2401611	77.7167213	0.07	2026-11-23 20:51:05.651
1148	13	1	13.2401608	77.7167212	0.07	2026-11-23 20:51:11.667
1149	13	1	13.2401605	77.7167224	0.07	2026-11-23 20:51:16.641
1150	13	1	13.2401610	77.7167229	0.06	2026-11-23 20:51:22.08
1151	13	1	13.2401618	77.7167226	0.06	2026-11-23 20:51:27.633
1152	13	1	13.2401626	77.7167227	0.06	2026-11-23 20:51:32.608
638	14	2	13.2399619	77.7168250	\N	2026-11-23 19:57:13.275
639	14	2	13.2401063	77.7166473	0.24	2026-11-23 19:57:22.496
640	14	2	13.2402817	77.7165652	9.79	2026-11-23 19:57:35.58
641	14	2	13.2404466	77.7168022	8.28	2026-11-23 19:57:41.654
642	14	2	13.2404603	77.7163680	0.13	2026-11-23 19:57:46.671
643	14	2	13.2404261	77.7163213	0.11	2026-11-23 19:57:52.686
644	14	2	13.2404247	77.7163228	0.04	2026-11-23 19:57:57.662
645	14	2	13.2401701	77.7167363	0.05	2026-11-23 19:58:03.679
646	14	2	13.2401350	77.7167971	0.04	2026-11-23 19:58:09.654
647	14	2	13.2401346	77.7167969	0.04	2026-11-23 19:58:14.67
648	14	2	13.2401343	77.7167961	0.04	2026-11-23 19:58:19.654
649	14	2	13.2401342	77.7167955	0.04	2026-11-23 19:58:24.654
650	14	2	13.2401349	77.7167953	0.04	2026-11-23 19:58:29.654
651	14	2	13.2401345	77.7167958	0.04	2026-11-23 19:58:35.654
652	14	2	13.2401348	77.7167966	0.04	2026-11-23 19:58:41.653
653	14	2	13.2401354	77.7167967	0.04	2026-11-23 19:58:47.654
654	14	2	13.2401350	77.7167961	0.04	2026-11-23 19:58:53.66
655	14	2	13.2401351	77.7167948	0.01	2026-11-23 19:58:58.654
656	14	2	13.2401353	77.7167957	0.04	2026-11-23 19:59:04.654
657	14	2	13.2401338	77.7167964	0.05	2026-11-23 19:59:09.653
658	14	2	13.2401349	77.7167967	0.04	2026-11-23 19:59:15.654
659	14	2	13.2401332	77.7167972	0.04	2026-11-23 19:59:20.653
660	14	2	13.2401333	77.7167982	0.06	2026-11-23 19:59:25.654
661	14	2	13.2401349	77.7167979	0.05	2026-11-23 19:59:31.607
662	14	2	13.2401455	77.7168208	0.05	2026-11-23 19:59:37.654
663	14	2	13.2401507	77.7168229	0.03	2026-11-23 19:59:43.653
664	14	2	13.2401522	77.7168230	0.04	2026-11-23 19:59:49.656
665	14	2	13.2401528	77.7168235	0.04	2026-11-23 19:59:54.654
666	14	2	13.2401529	77.7168233	0.04	2026-11-23 20:00:00.647
667	14	2	13.2401523	77.7168229	0.03	2026-11-23 20:00:05.654
668	14	2	13.2401518	77.7168225	0.03	2026-11-23 20:00:10.653
669	14	2	13.2401524	77.7168224	0.03	2026-11-23 20:00:15.654
670	14	2	13.2401529	77.7168223	0.05	2026-11-23 20:00:21.654
671	14	2	13.2401523	77.7168220	0.04	2026-11-23 20:00:26.653
672	14	2	13.2401517	77.7168216	0.04	2026-11-23 20:00:32.653
673	14	2	13.2401524	77.7168215	0.05	2026-11-23 20:00:37.671
674	14	2	13.2401528	77.7168212	0.03	2026-11-23 20:00:43.572
675	14	2	13.2401527	77.7168205	0.04	2026-11-23 20:00:48.662
676	14	2	13.2401533	77.7168211	0.05	2026-11-23 20:00:54.68
677	14	2	13.2401530	77.7168214	0.04	2026-11-23 20:00:59.654
678	14	2	13.2401531	77.7168217	0.04	2026-11-23 20:01:04.654
679	14	2	13.2401532	77.7168220	0.04	2026-11-23 20:01:10.654
680	14	2	13.2401526	77.7168225	0.05	2026-11-23 20:01:16.662
681	14	2	13.2401525	77.7168222	0.05	2026-11-23 20:01:22.653
682	14	2	13.2401523	77.7168217	0.04	2026-11-23 20:01:27.654
683	14	2	13.2401522	77.7168213	0.05	2026-11-23 20:01:33.572
684	14	2	13.2401521	77.7168212	0.07	2026-11-23 20:01:38.654
685	14	2	13.2401511	77.7168170	0.03	2026-11-23 20:01:44.66
686	14	2	13.2401487	77.7168105	0.05	2026-11-23 20:01:50.677
687	14	2	13.2401399	77.7167995	0.04	2026-11-23 20:01:55.654
688	14	2	13.2401342	77.7167916	0.05	2026-11-23 20:02:01.669
689	14	2	13.2401348	77.7167876	0.05	2026-11-23 20:02:06.654
690	14	2	13.2401352	77.7167826	0.05	2026-11-23 20:02:12.659
691	14	2	13.2401353	77.7167790	0.04	2026-11-23 20:02:17.654
692	14	2	13.2401353	77.7167773	0.05	2026-11-23 20:02:23.653
693	14	2	13.2401344	77.7167762	0.04	2026-11-23 20:02:28.654
694	14	2	13.2401349	77.7167751	0.04	2026-11-23 20:02:34.653
695	14	2	13.2401345	77.7167753	0.05	2026-11-23 20:02:39.654
696	14	2	13.2401350	77.7167747	0.04	2026-11-23 20:02:45.653
697	14	2	13.2401351	77.7167738	0.04	2026-11-23 20:02:51.654
698	14	2	13.2401345	77.7167729	0.05	2026-11-23 20:02:57.667
699	14	2	13.2401355	77.7167725	0.04	2026-11-23 20:03:03.653
700	14	2	13.2401360	77.7167731	0.05	2026-11-23 20:03:09.653
701	14	2	13.2401370	77.7167735	0.06	2026-11-23 20:03:15.653
702	14	2	13.2401375	77.7167738	0.04	2026-11-23 20:03:20.654
703	14	2	13.2401372	77.7167738	0.04	2026-11-23 20:03:26.653
704	14	2	13.2401364	77.7167745	0.05	2026-11-23 20:03:32.654
705	14	2	13.2401355	77.7167747	0.04	2026-11-23 20:03:38.276
706	14	2	13.2401356	77.7167752	0.04	2026-11-23 20:03:43.653
707	14	2	13.2401353	77.7167750	0.04	2026-11-23 20:03:49.654
708	14	2	13.2401353	77.7167745	0.05	2026-11-23 20:03:55.654
709	14	2	13.2401358	77.7167740	0.04	2026-11-23 20:04:01.653
710	14	2	13.2401356	77.7167734	0.05	2026-11-23 20:04:07.663
711	14	2	13.2401363	77.7167736	0.05	2026-11-23 20:04:13.654
712	14	2	13.2401363	77.7167739	0.04	2026-11-23 20:04:18.654
713	14	2	13.2401358	77.7167747	0.04	2026-11-23 20:04:23.654
714	14	2	13.2401350	77.7167833	0.06	2026-11-23 20:04:29.653
715	14	2	13.2401353	77.7167801	0.05	2026-11-23 20:04:35.664
716	14	2	13.2401366	77.7167776	0.04	2026-11-23 20:04:40.653
717	14	2	13.2401387	77.7167747	0.04	2026-11-23 20:04:45.654
718	14	2	13.2401377	77.7167717	0.04	2026-11-23 20:04:51.654
719	14	2	13.2401384	77.7167701	0.04	2026-11-23 20:04:57.653
720	14	2	13.2401402	77.7167691	0.04	2026-11-23 20:05:02.654
721	14	2	13.2401412	77.7167687	0.05	2026-11-23 20:05:07.945
722	14	2	13.2401421	77.7167688	0.05	2026-11-23 20:05:13.614
723	13	1	13.2400385	77.7168287	\N	2026-11-23 20:05:42.44
724	13	1	13.2401422	77.7167845	0.09	2026-11-23 20:05:47.572
725	13	1	13.2401518	77.7167836	0.09	2026-11-23 20:05:52.661
726	13	1	13.2401548	77.7167864	0.10	2026-11-23 20:05:58.678
727	13	1	13.2401539	77.7167848	0.09	2026-11-23 20:06:04.579
728	13	1	13.2401527	77.7167875	0.08	2026-11-23 20:06:09.574
729	13	1	13.2401517	77.7167894	0.06	2026-11-23 20:06:15.574
730	13	1	13.2401500	77.7167892	0.05	2026-11-23 20:06:21.587
731	13	1	13.2401487	77.7167889	0.06	2026-11-23 20:06:26.574
732	13	1	13.2401427	77.7167874	0.07	2026-11-23 20:06:31.654
733	13	1	13.2401415	77.7167877	0.03	2026-11-23 20:06:36.631
734	13	1	13.2401413	77.7167872	0.04	2026-11-23 20:06:42.57
735	13	1	13.2401410	77.7167874	0.05	2026-11-23 20:06:48.571
736	13	1	13.2401413	77.7167877	0.05	2026-11-23 20:06:54.575
737	13	1	13.2401405	77.7167875	0.06	2026-11-23 20:06:59.661
738	13	1	13.2401402	77.7167875	0.07	2026-11-23 20:07:05.572
739	13	1	13.2401405	77.7167868	0.06	2026-11-23 20:07:11.581
740	13	1	13.2401403	77.7167873	0.07	2026-11-23 20:07:16.573
741	13	1	13.2401412	77.7167879	0.06	2026-11-23 20:07:21.648
742	13	1	13.2401421	77.7167873	0.05	2026-11-23 20:07:27.569
743	13	1	13.2401421	77.7167870	0.07	2026-11-23 20:07:32.642
744	13	1	13.2401430	77.7167870	0.07	2026-11-23 20:07:37.617
745	13	1	13.2401431	77.7167863	0.07	2026-11-23 20:07:42.593
746	13	1	13.2401432	77.7167855	0.06	2026-11-23 20:07:48.61
747	13	1	13.2401418	77.7167849	0.06	2026-11-23 20:07:53.585
748	13	1	13.2401422	77.7167840	0.06	2026-11-23 20:07:59.601
749	13	1	13.2401419	77.7167841	0.07	2026-11-23 20:08:04.576
750	13	1	13.2401424	77.7167838	0.06	2026-11-23 20:08:09.668
751	13	1	13.2401421	77.7167843	0.06	2026-11-23 20:08:14.644
752	13	1	13.2401428	77.7167845	0.06	2026-11-23 20:08:20.659
753	13	1	13.2401423	77.7167851	0.07	2026-11-23 20:08:26.676
754	13	1	13.2401429	77.7167841	0.06	2026-11-23 20:08:32.23
755	13	1	13.2401432	77.7167840	0.06	2026-11-23 20:08:37.667
756	13	1	13.2401380	77.7167691	0.07	2026-11-23 20:08:42.643
757	13	1	13.2401367	77.7167559	0.06	2026-11-23 20:08:48.659
758	13	1	13.2401351	77.7167349	0.06	2026-11-23 20:08:53.635
759	13	1	13.2401309	77.7167199	0.06	2026-11-23 20:08:59.651
760	13	1	13.2401297	77.7167086	0.06	2026-11-23 20:09:04.626
761	13	1	13.2401260	77.7167010	0.06	2026-11-23 20:09:10.643
762	13	1	13.2401238	77.7166965	0.07	2026-11-23 20:09:15.619
763	13	1	13.2401221	77.7166934	0.07	2026-11-23 20:09:21.634
764	13	1	13.2401215	77.7166926	0.05	2026-11-23 20:09:26.611
765	13	1	13.2401208	77.7166916	0.06	2026-11-23 20:09:32.171
766	13	1	13.2401213	77.7166912	0.06	2026-11-23 20:09:37.603
767	13	1	13.2401206	77.7166912	0.06	2026-11-23 20:09:43.619
768	13	1	13.2401201	77.7166911	0.07	2026-11-23 20:09:49.637
769	13	1	13.2401203	77.7166917	0.07	2026-11-23 20:09:54.612
770	13	1	13.2401203	77.7166917	0.07	2026-11-23 20:10:00.628
771	13	1	13.2401196	77.7166931	0.06	2026-11-23 20:10:05.603
772	13	1	13.2401197	77.7166922	0.07	2026-11-23 20:10:10.578
121	12	1	13.2401604	77.7167967	0.07	2026-11-23 18:34:00.602
122	12	1	13.2401589	77.7167994	0.07	2026-11-23 18:34:48.628
123	12	1	13.2401593	77.7167989	0.06	2026-11-23 18:34:54.646
124	12	1	13.2401581	77.7167987	0.06	2026-11-23 18:34:59.622
125	12	1	13.2401584	77.7167984	0.06	2026-11-23 18:35:05.64
126	12	1	13.2401570	77.7167983	0.06	2026-11-23 18:35:10.616
127	12	1	13.2401559	77.7167975	0.06	2026-11-23 18:35:16.632
128	12	1	13.2401559	77.7167955	0.06	2026-11-23 18:35:22.651
129	12	1	13.2401567	77.7167954	0.03	2026-11-23 18:35:28.572
130	12	1	13.2401565	77.7167950	0.06	2026-11-23 18:35:33.644
131	12	1	13.2401567	77.7167954	0.06	2026-11-23 18:35:39.664
132	12	1	13.2401566	77.7167947	0.06	2026-11-23 18:35:44.64
133	12	1	13.2401571	77.7167950	0.06	2026-11-23 18:35:49.615
134	12	1	13.2401579	77.7167947	0.07	2026-11-23 18:35:54.593
135	12	1	13.2401578	77.7167946	0.07	2026-11-23 18:35:59.685
136	12	1	13.2401581	77.7167938	0.06	2026-11-23 18:36:05.586
137	12	1	13.2401579	77.7167935	0.07	2026-11-23 18:36:10.679
138	12	1	13.2401588	77.7167934	0.06	2026-11-23 18:36:16.58
139	12	1	13.2401590	77.7167935	0.06	2026-11-23 18:36:21.672
140	12	1	13.2401590	77.7167929	0.06	2026-11-23 18:36:26.649
141	12	1	13.2401574	77.7167932	0.07	2026-11-23 18:36:32.667
142	12	1	13.2401587	77.7167934	0.07	2026-11-23 18:36:37.642
143	12	1	13.2401591	77.7167938	0.06	2026-11-23 18:36:42.62
144	12	1	13.2401584	77.7167963	0.07	2026-11-23 18:36:48.638
145	12	1	13.2401591	77.7167970	0.06	2026-11-23 18:36:54.655
146	12	1	13.2401580	77.7167976	0.06	2026-11-23 18:37:00.673
147	12	1	13.2401582	77.7167981	0.06	2026-11-23 18:37:06.574
148	12	1	13.2401578	77.7167988	0.07	2026-11-23 18:37:11.667
149	12	1	13.2401566	77.7167991	0.06	2026-11-23 18:37:16.643
150	12	1	13.2401565	77.7167987	0.07	2026-11-23 18:37:22.661
151	12	1	13.2401563	77.7167997	0.07	2026-11-23 18:37:27.637
152	12	1	13.2401562	77.7168000	0.06	2026-11-23 18:37:33.654
153	12	1	13.2401547	77.7167994	0.06	2026-11-23 18:37:38.631
154	12	1	13.2401540	77.7167991	0.06	2026-11-23 18:37:44.649
155	12	1	13.2401544	77.7167994	0.06	2026-11-23 18:37:49.625
156	12	1	13.2401572	77.7167988	0.06	2026-11-23 18:37:55.643
157	12	1	13.2401584	77.7167976	0.06	2026-11-23 18:38:00.618
158	12	1	13.2401584	77.7167969	0.07	2026-11-23 18:38:06.521
159	12	1	13.2401587	77.7167972	0.07	2026-11-23 18:38:11.613
160	12	1	13.2401592	77.7167968	0.06	2026-11-23 18:38:17.629
161	12	1	13.2401600	77.7167969	0.06	2026-11-23 18:38:23.648
162	12	1	13.2401597	77.7167969	0.06	2026-11-23 18:38:28.623
163	12	1	13.2401597	77.7167979	0.06	2026-11-23 18:38:34.642
164	12	1	13.2401586	77.7167977	0.06	2026-11-23 18:38:40.572
165	12	1	13.2401589	77.7167988	0.07	2026-11-23 18:38:45.636
166	12	1	13.2401583	77.7167989	0.06	2026-11-23 18:38:50.612
167	12	1	13.2401577	77.7167989	0.06	2026-11-23 18:38:56.63
168	12	1	13.2401575	77.7168004	0.06	2026-11-23 18:39:01.606
169	12	1	13.2401568	77.7168010	0.07	2026-11-23 18:39:07.623
170	12	1	13.2401555	77.7168013	0.06	2026-11-23 18:39:12.6
171	12	1	13.2401545	77.7168008	0.05	2026-11-23 18:39:18.616
172	12	1	13.2401551	77.7168000	0.07	2026-11-23 18:39:24.635
173	12	1	13.2401548	77.7167993	0.06	2026-11-23 18:39:30.652
174	12	1	13.2401555	77.7167992	0.06	2026-11-23 18:39:35.628
175	12	1	13.2401579	77.7167993	0.06	2026-11-23 18:39:41.646
176	12	1	13.2401589	77.7167985	0.07	2026-11-23 18:39:47.664
177	12	1	13.2401590	77.7167977	0.06	2026-11-23 18:39:52.64
178	12	1	13.2401583	77.7167977	0.06	2026-11-23 18:39:58.658
179	12	1	13.2401585	77.7167970	0.07	2026-11-23 18:40:03.634
180	12	1	13.2401581	77.7167968	0.07	2026-11-23 18:40:09.651
181	12	1	13.2401581	77.7167969	0.07	2026-11-23 18:40:15.669
182	12	1	13.2401587	77.7167965	0.06	2026-11-23 18:40:20.644
183	12	1	13.2401589	77.7167967	0.07	2026-11-23 18:40:26.125
184	12	1	13.2401591	77.7167973	0.06	2026-11-23 18:40:31.638
185	12	1	13.2401573	77.7167979	0.07	2026-11-23 18:40:36.615
186	12	1	13.2401571	77.7167983	0.07	2026-11-23 18:40:42.633
187	12	1	13.2401556	77.7167988	0.07	2026-11-23 18:40:47.608
188	12	1	13.2401571	77.7167991	0.06	2026-11-23 18:40:53.625
189	12	1	13.2401565	77.7168010	0.06	2026-11-23 18:40:59.644
190	12	1	13.2401567	77.7168009	0.07	2026-11-23 18:41:04.62
191	12	1	13.2401557	77.7168010	0.07	2026-11-23 18:41:10.638
192	12	1	13.2401557	77.7168022	0.07	2026-11-23 18:41:16.655
193	12	1	13.2401559	77.7168016	0.06	2026-11-23 18:41:22.673
194	12	1	13.2401558	77.7168017	0.07	2026-11-23 18:41:27.648
195	12	1	13.2401578	77.7168019	0.06	2026-11-23 18:41:33.667
196	12	1	13.2401574	77.7168020	0.06	2026-11-23 18:41:39.579
197	12	1	13.2401576	77.7168031	0.06	2026-11-23 18:41:45.585
198	12	1	13.2401580	77.7168050	0.06	2026-11-23 18:41:51.604
199	12	1	13.2401586	77.7168014	0.06	2026-11-23 18:41:56.927
200	12	1	13.2401570	77.7168015	0.06	2026-11-23 18:42:02.598
201	12	1	13.2401543	77.7168017	0.05	2026-11-23 18:42:08.615
202	12	1	13.2401539	77.7168003	0.06	2026-11-23 18:42:14.632
203	12	1	13.2401534	77.7167987	0.07	2026-11-23 18:42:20.651
204	12	1	13.2401537	77.7167974	0.07	2026-11-23 18:42:26.667
205	12	1	13.2401537	77.7167972	0.06	2026-11-23 18:42:31.644
206	12	1	13.2401552	77.7167954	0.06	2026-11-23 18:42:36.621
207	12	1	13.2401552	77.7167944	0.06	2026-11-23 18:42:42.637
208	12	1	13.2401565	77.7167948	0.07	2026-11-23 18:42:47.613
209	12	1	13.2401575	77.7167957	0.05	2026-11-23 18:42:52.589
210	12	1	13.2401574	77.7167963	0.06	2026-11-23 18:42:57.681
211	12	1	13.2401586	77.7167959	0.06	2026-11-23 18:43:03.583
212	12	1	13.2401590	77.7167965	0.06	2026-11-23 18:43:08.676
213	12	1	13.2401596	77.7167965	0.06	2026-11-23 18:43:13.651
214	12	1	13.2401600	77.7167978	0.07	2026-11-23 18:43:19.67
215	12	1	13.2401607	77.7167984	0.06	2026-11-23 18:43:25.577
216	12	1	13.2401604	77.7167990	0.07	2026-11-23 18:43:31.59
217	12	1	13.2401599	77.7168004	0.06	2026-11-23 18:43:36.574
218	12	1	13.2401576	77.7168000	0.06	2026-11-23 18:43:41.658
219	12	1	13.2401568	77.7167991	0.06	2026-11-23 18:43:46.749
220	12	1	13.2401557	77.7167996	0.06	2026-11-23 18:43:52.652
221	12	1	13.2401555	77.7167995	0.06	2026-11-23 18:43:57.628
222	12	1	13.2401557	77.7167998	0.07	2026-11-23 18:44:02.604
223	12	1	13.2401554	77.7168003	0.06	2026-11-23 18:44:08.622
224	12	1	13.2401552	77.7168008	0.07	2026-11-23 18:44:13.598
225	12	1	13.2401564	77.7168007	0.05	2026-11-23 18:44:19.616
226	12	1	13.2401580	77.7168010	0.06	2026-11-23 18:44:25.633
227	12	1	13.2401572	77.7168004	0.06	2026-11-23 18:44:30.61
228	12	1	13.2401572	77.7168005	0.05	2026-11-23 18:44:35.585
229	12	1	13.2401558	77.7168001	0.06	2026-11-23 18:44:41.604
230	12	1	13.2401574	77.7167995	0.07	2026-11-23 18:44:46.694
231	12	1	13.2401571	77.7167993	0.05	2026-11-23 18:44:52.596
232	12	1	13.2401570	77.7167985	0.06	2026-11-23 18:44:58.614
233	12	1	13.2401577	77.7167979	0.07	2026-11-23 18:45:04.632
234	12	1	13.2401576	77.7167983	0.06	2026-11-23 18:45:09.608
235	12	1	13.2401572	77.7167979	0.06	2026-11-23 18:45:15.626
236	12	1	13.2401570	77.7167987	0.07	2026-11-23 18:45:20.602
237	12	1	13.2401575	77.7167987	0.07	2026-11-23 18:45:26.62
238	12	1	13.2401570	77.7167987	0.06	2026-11-23 18:45:31.596
239	12	1	13.2401567	77.7167984	0.06	2026-11-23 18:45:37.151
240	12	1	13.2401553	77.7167980	0.07	2026-11-23 18:45:42.589
241	12	1	13.2401556	77.7167976	0.06	2026-11-23 18:45:47.682
242	12	1	13.2401561	77.7167819	0.05	2026-11-23 18:45:53.584
243	12	1	13.2401555	77.7167706	0.06	2026-11-23 18:45:58.675
244	12	1	13.2401557	77.7167603	0.06	2026-11-23 18:46:03.883
245	12	1	13.2401557	77.7167541	0.07	2026-11-23 18:46:09.669
246	12	1	13.2401637	77.7167388	0.08	2026-11-23 18:46:15.577
247	12	1	13.2401751	77.7167246	0.07	2026-11-23 18:46:21.589
248	12	1	13.2401748	77.7167196	0.06	2026-11-23 18:46:26.681
249	12	1	13.2401746	77.7167170	0.07	2026-11-23 18:46:32.583
250	12	1	13.2401730	77.7167132	0.06	2026-11-23 18:46:37.675
251	12	1	13.2401691	77.7167082	0.06	2026-11-23 18:46:43.576
252	12	1	13.2401682	77.7167069	0.06	2026-11-23 18:46:48.667
253	12	1	13.2401670	77.7167055	0.06	2026-11-23 18:46:54.455
254	12	1	13.2401655	77.7167048	0.06	2026-11-23 18:46:59.662
255	12	1	13.2401650	77.7167046	0.07	2026-11-23 18:47:05.575
256	12	1	13.2401650	77.7167045	0.06	2026-11-23 18:47:10.656
257	12	1	13.2401651	77.7167052	0.06	2026-11-23 18:47:15.631
258	12	1	13.2401650	77.7167058	0.05	2026-11-23 18:47:20.607
259	12	1	13.2401650	77.7167060	0.06	2026-11-23 18:47:25.584
260	12	1	13.2401650	77.7167062	0.06	2026-11-23 18:47:30.675
261	12	1	13.2401644	77.7167067	0.06	2026-11-23 18:47:36.577
262	12	1	13.2401646	77.7167071	0.06	2026-11-23 18:47:42.595
263	12	1	13.2401648	77.7167086	0.06	2026-11-23 18:47:47.686
264	12	1	13.2401643	77.7167094	0.07	2026-11-23 18:47:53.589
265	12	1	13.2401653	77.7167105	0.06	2026-11-23 18:47:59.607
266	12	1	13.2401667	77.7167093	0.07	2026-11-23 18:48:04.583
267	12	1	13.2401677	77.7167084	0.06	2026-11-23 18:48:10.601
268	12	1	13.2401683	77.7167084	0.07	2026-11-23 18:48:15.691
269	12	1	13.2401684	77.7167078	0.07	2026-11-23 18:48:21.594
270	12	1	13.2401673	77.7167085	0.07	2026-11-23 18:48:26.686
271	12	1	13.2401669	77.7167078	0.07	2026-11-23 18:48:32.588
272	12	1	13.2401671	77.7167083	0.06	2026-11-23 18:48:37.68
273	12	1	13.2401679	77.7167072	0.05	2026-11-23 18:48:42.655
274	12	1	13.2401660	77.7167068	0.07	2026-11-23 18:48:48.674
275	12	1	13.2401655	77.7167053	0.07	2026-11-23 18:48:54.579
276	12	1	13.2401641	77.7167055	0.05	2026-11-23 18:49:00.593
277	12	1	13.2401646	77.7167063	0.07	2026-11-23 18:49:05.578
278	12	1	13.2401638	77.7167077	0.06	2026-11-23 18:49:11.586
279	12	1	13.2401640	77.7167092	0.06	2026-11-23 18:49:16.678
280	12	1	13.2401654	77.7167089	0.06	2026-11-23 18:49:22.58
281	12	1	13.2401666	77.7167086	0.06	2026-11-23 18:49:27.673
282	12	1	13.2401668	77.7167087	0.07	2026-11-23 18:49:33.575
283	12	1	13.2401668	77.7167087	0.06	2026-11-23 18:49:38.666
284	12	1	13.2401682	77.7167079	0.06	2026-11-23 18:49:44.575
285	12	1	13.2401689	77.7167076	0.06	2026-11-23 18:49:49.66
286	12	1	13.2401705	77.7167074	0.07	2026-11-23 18:49:55.678
287	12	1	13.2401703	77.7167074	0.07	2026-11-23 18:50:00.655
288	12	1	13.2401705	77.7167067	0.06	2026-11-23 18:50:05.901
289	12	1	13.2401702	77.7167061	0.07	2026-11-23 18:50:11.648
290	12	1	13.2401697	77.7167056	0.06	2026-11-23 18:50:16.624
291	12	1	13.2401691	77.7167059	0.08	2026-11-23 18:50:22.642
292	12	1	13.2401681	77.7167059	0.05	2026-11-23 18:50:28.659
293	12	1	13.2401676	77.7167045	0.06	2026-11-23 18:50:34.678
294	12	1	13.2401679	77.7167042	0.07	2026-11-23 18:50:40.58
295	12	1	13.2401667	77.7167043	0.07	2026-11-23 18:50:45.671
296	12	1	13.2401651	77.7167051	0.07	2026-11-23 18:50:51.576
297	12	1	13.2401637	77.7167055	0.07	2026-11-23 18:50:56.664
298	12	1	13.2401633	77.7167054	0.06	2026-11-23 18:51:02.572
299	12	1	13.2401623	77.7167064	0.06	2026-11-23 18:51:07.659
300	12	1	13.2401626	77.7167074	0.06	2026-11-23 18:51:13.675
301	12	1	13.2401630	77.7167077	0.07	2026-11-23 18:51:19.577
302	12	1	13.2401635	77.7167083	0.07	2026-11-23 18:51:24.67
303	12	1	13.2401626	77.7167095	0.06	2026-11-23 18:51:30.58
304	12	1	13.2401638	77.7167102	0.06	2026-11-23 18:51:35.663
305	12	1	13.2401646	77.7167094	0.06	2026-11-23 18:51:41.682
306	12	1	13.2401641	77.7167078	0.06	2026-11-23 18:51:47.582
307	12	1	13.2401635	77.7167072	0.06	2026-11-23 18:51:53.601
308	12	1	13.2401631	77.7167079	0.05	2026-11-23 18:51:58.577
309	12	1	13.2401624	77.7167072	0.07	2026-11-23 18:52:03.669
310	12	1	13.2401623	77.7167077	0.06	2026-11-23 18:52:08.645
311	12	1	13.2401632	77.7167068	0.07	2026-11-23 18:52:14.662
312	13	1	13.2401646	77.7167120	\N	2026-11-23 18:53:12.089
313	13	1	13.2400221	77.7168420	0.26	2026-11-23 18:53:18.213
314	13	1	13.2400833	77.7168317	0.20	2026-11-23 18:53:23.609
315	13	1	13.2400886	77.7168338	0.11	2026-11-23 18:53:28.585
316	13	1	13.2400943	77.7168347	0.09	2026-11-23 18:53:34.603
317	13	1	13.2400951	77.7168369	0.09	2026-11-23 18:53:39.579
318	13	1	13.2400975	77.7168378	0.09	2026-11-23 18:53:44.671
319	13	1	13.2401106	77.7168296	0.06	2026-11-23 18:53:50.578
320	13	1	13.2401230	77.7168143	0.08	2026-11-23 18:53:55.664
321	13	1	13.2401305	77.7168098	0.06	2026-11-23 18:54:01.683
322	13	1	13.2401375	77.7168040	0.07	2026-11-23 18:54:06.659
323	13	1	13.2401450	77.7167962	0.06	2026-11-23 18:54:11.635
324	13	1	13.2401519	77.7167923	0.07	2026-11-23 18:54:17.653
325	13	1	13.2401576	77.7167895	0.07	2026-11-23 18:54:23.671
326	13	1	13.2401633	77.7167871	0.06	2026-11-23 18:54:28.647
327	13	1	13.2401707	77.7167833	0.06	2026-11-23 18:54:34.572
328	13	1	13.2401741	77.7167797	0.06	2026-11-23 18:54:39.642
329	13	1	13.2401781	77.7167755	0.06	2026-11-23 18:54:45.659
330	13	1	13.2401815	77.7167714	0.07	2026-11-23 18:54:51.678
331	13	1	13.2401833	77.7167691	0.06	2026-11-23 18:54:56.654
332	13	1	13.2401863	77.7167662	0.06	2026-11-23 18:55:02.671
333	13	1	13.2401886	77.7167647	0.06	2026-11-23 18:55:07.648
334	13	1	13.2401916	77.7167632	0.06	2026-11-23 18:55:13.667
335	13	1	13.2401935	77.7167622	0.06	2026-11-23 18:55:18.643
336	13	1	13.2401970	77.7167589	0.06	2026-11-23 18:55:24.429
337	13	1	13.2401989	77.7167574	0.06	2026-11-23 18:55:29.637
338	13	1	13.2402000	77.7167562	0.05	2026-11-23 18:55:35.655
339	13	1	13.2402008	77.7167558	0.07	2026-11-23 18:55:41.671
340	13	1	13.2402017	77.7167551	0.06	2026-11-23 18:55:47.578
341	13	1	13.2402027	77.7167550	0.06	2026-11-23 18:55:53.592
342	13	1	13.2402027	77.7167543	0.07	2026-11-23 18:55:58.684
343	13	1	13.2402016	77.7167568	0.05	2026-11-23 18:56:14.655
344	13	1	13.2401920	77.7167742	0.09	2026-11-23 18:56:19.621
345	13	1	13.2401653	77.7167972	0.09	2026-11-23 18:56:24.597
346	13	1	13.2401523	77.7168183	0.29	2026-11-23 18:56:29.974
347	13	1	13.2401560	77.7168283	0.15	2026-11-23 18:56:35.591
348	13	1	13.2401595	77.7168246	0.11	2026-11-23 18:56:41.257
349	13	1	13.2401524	77.7167465	0.06	2026-11-23 18:57:07.655
350	13	1	13.2401548	77.7167440	0.06	2026-11-23 18:57:13.674
351	13	1	13.2401567	77.7167430	0.05	2026-11-23 18:57:18.65
352	13	1	13.2401578	77.7167406	0.06	2026-11-23 18:57:24.667
353	13	1	13.2401574	77.7167400	0.03	2026-11-23 18:57:30.684
354	13	1	13.2401578	77.7167390	0.03	2026-11-23 18:57:36.586
355	13	1	13.2401576	77.7167388	0.03	2026-11-23 18:57:41.678
356	13	1	13.2401576	77.7167395	0.04	2026-11-23 18:57:47.579
357	13	1	13.2401570	77.7167394	0.05	2026-11-23 18:57:52.67
358	13	1	13.2401569	77.7167397	0.04	2026-11-23 18:57:58.573
359	13	1	13.2401566	77.7167397	0.03	2026-11-23 18:58:03.664
360	13	1	13.2401564	77.7167401	0.04	2026-11-23 18:58:08.64
361	13	1	13.2401566	77.7167401	0.03	2026-11-23 18:58:13.616
362	13	1	13.2401590	77.7167383	0.04	2026-11-23 18:58:19.633
363	13	1	13.2401621	77.7167362	0.03	2026-11-23 18:58:24.608
364	13	1	13.2401647	77.7167345	0.03	2026-11-23 18:58:30.626
365	13	1	13.2401655	77.7167337	0.03	2026-11-23 18:58:35.603
366	13	1	13.2401664	77.7167333	0.04	2026-11-23 18:58:40.578
367	13	1	13.2401667	77.7167332	0.03	2026-11-23 18:58:46.017
368	13	1	13.2401705	77.7167379	0.03	2026-11-23 18:58:51.577
369	13	1	13.2401729	77.7167431	0.04	2026-11-23 18:58:57.588
370	13	1	13.2401743	77.7167463	0.04	2026-11-23 18:59:02.68
371	13	1	13.2401744	77.7167483	0.04	2026-11-23 18:59:08.581
372	13	1	13.2401740	77.7167493	0.04	2026-11-23 18:59:13.674
373	13	1	13.2401739	77.7167508	0.03	2026-11-23 18:59:19.575
374	13	1	13.2401747	77.7167515	0.04	2026-11-23 18:59:24.667
375	13	1	13.2401749	77.7167522	0.04	2026-11-23 18:59:30.577
376	13	1	13.2401746	77.7167529	0.04	2026-11-23 18:59:35.659
377	13	1	13.2401752	77.7167535	0.03	2026-11-23 18:59:41.574
378	13	1	13.2401754	77.7167534	0.03	2026-11-23 18:59:46.652
379	13	1	13.2401753	77.7167527	0.04	2026-11-23 18:59:51.628
380	13	1	13.2401747	77.7167511	0.04	2026-11-23 18:59:57.646
381	13	1	13.2401745	77.7167508	0.04	2026-11-23 19:00:02.622
382	13	1	13.2401748	77.7167499	0.05	2026-11-23 19:00:08.639
383	13	1	13.2401743	77.7167497	0.03	2026-11-23 19:00:14.657
384	13	1	13.2401754	77.7167496	0.03	2026-11-23 19:00:19.632
385	13	1	13.2401755	77.7167508	0.04	2026-11-23 19:00:24.608
386	13	1	13.2401749	77.7167503	0.04	2026-11-23 19:00:30.625
387	13	1	13.2401753	77.7167500	0.03	2026-11-23 19:00:35.601
388	13	1	13.2401756	77.7167503	0.04	2026-11-23 19:00:40.577
389	13	1	13.2401751	77.7167505	0.04	2026-11-23 19:00:45.669
390	13	1	13.2401757	77.7167501	0.04	2026-11-23 19:00:50.644
391	13	1	13.2401760	77.7167509	0.03	2026-11-23 19:00:55.966
392	13	1	13.2401738	77.7167516	0.04	2026-11-23 19:01:01.636
393	13	1	13.2401672	77.7167583	0.04	2026-11-23 19:01:07.653
394	13	1	13.2401635	77.7167612	0.04	2026-11-23 19:01:12.629
395	13	1	13.2401624	77.7167623	0.04	2026-11-23 19:01:17.606
396	13	1	13.2401613	77.7167639	0.03	2026-11-23 19:01:23.623
397	13	1	13.2401609	77.7167652	0.04	2026-11-23 19:01:29.64
398	13	1	13.2401608	77.7167658	0.04	2026-11-23 19:01:34.616
399	13	1	13.2401606	77.7167664	0.03	2026-11-23 19:01:39.591
400	13	1	13.2401601	77.7167668	0.04	2026-11-23 19:01:44.682
401	13	1	13.2401607	77.7167674	0.04	2026-11-23 19:01:50.584
402	13	1	13.2401605	77.7167680	0.04	2026-11-23 19:01:55.675
403	13	1	13.2401598	77.7167685	0.04	2026-11-23 19:02:00.651
404	13	1	13.2401594	77.7167687	0.03	2026-11-23 19:02:06.668
405	13	1	13.2401609	77.7167676	0.03	2026-11-23 19:02:12.579
406	13	1	13.2401615	77.7167671	0.04	2026-11-23 19:02:18.587
407	13	1	13.2401619	77.7167674	0.03	2026-11-23 19:02:24.604
408	13	1	13.2401616	77.7167671	0.04	2026-11-23 19:02:29.578
409	13	1	13.2401620	77.7167666	0.04	2026-11-23 19:02:35.481
410	13	1	13.2401620	77.7167658	0.04	2026-11-23 19:02:40.579
411	13	1	13.2401617	77.7167656	0.04	2026-11-23 19:02:46.588
412	13	1	13.2401621	77.7167661	0.03	2026-11-23 19:02:52.606
413	13	1	13.2401618	77.7167655	0.04	2026-11-23 19:02:57.581
414	13	1	13.2401612	77.7167651	0.04	2026-11-23 19:03:02.673
415	13	1	13.2401614	77.7167649	0.04	2026-11-23 19:03:08.581
416	13	1	13.2401617	77.7167649	0.04	2026-11-23 19:03:13.665
417	13	1	13.2401613	77.7167655	0.03	2026-11-23 19:03:19.577
418	13	1	13.2401615	77.7167657	0.04	2026-11-23 19:03:24.659
419	13	1	13.2401611	77.7167661	0.04	2026-11-23 19:03:29.635
420	13	1	13.2401619	77.7167661	0.04	2026-11-23 19:03:35.42
421	13	1	13.2401620	77.7167664	0.05	2026-11-23 19:03:40.627
422	13	1	13.2401618	77.7167668	0.04	2026-11-23 19:03:46.644
423	13	1	13.2401616	77.7167665	0.03	2026-11-23 19:03:52.661
424	13	1	13.2401616	77.7167665	0.03	2026-11-23 19:03:57.636
425	13	1	13.2401613	77.7167670	0.04	2026-11-23 19:04:03.654
426	13	1	13.2401607	77.7167665	0.03	2026-11-23 19:04:08.63
427	13	1	13.2401601	77.7167654	0.04	2026-11-23 19:04:13.604
428	13	1	13.2401600	77.7167662	0.04	2026-11-23 19:04:19.621
429	13	1	13.2401604	77.7167668	0.03	2026-11-23 19:04:24.597
430	13	1	13.2401603	77.7167663	0.04	2026-11-23 19:04:30.614
431	13	1	13.2401603	77.7167659	0.04	2026-11-23 19:04:36.631
432	13	1	13.2401601	77.7167655	0.04	2026-11-23 19:04:41.607
433	13	1	13.2401603	77.7167659	0.03	2026-11-23 19:04:47.625
434	13	1	13.2401608	77.7167659	0.05	2026-11-23 19:04:52.599
435	13	1	13.2401611	77.7167659	0.03	2026-11-23 19:04:58.617
436	13	1	13.2401618	77.7167661	0.04	2026-11-23 19:05:03.592
437	13	1	13.2401621	77.7167667	0.04	2026-11-23 19:05:08.578
438	13	1	13.2401627	77.7167666	0.04	2026-11-23 19:05:14.585
439	13	1	13.2401632	77.7167670	0.03	2026-11-23 19:05:20.602
440	13	1	13.2401625	77.7167677	0.04	2026-11-23 19:05:26.618
441	13	1	13.2401619	77.7167671	0.05	2026-11-23 19:05:32.636
442	13	1	13.2401620	77.7167668	0.04	2026-11-23 19:05:37.611
443	13	1	13.2401622	77.7167664	0.04	2026-11-23 19:05:43.629
444	13	1	13.2401610	77.7167670	0.03	2026-11-23 19:05:48.604
445	13	1	13.2401605	77.7167668	0.03	2026-11-23 19:05:53.579
446	13	1	13.2401600	77.7167681	0.03	2026-11-23 19:05:58.671
447	13	1	13.2401596	77.7167678	0.04	2026-11-23 19:06:04.58
448	13	1	13.2401598	77.7167677	0.03	2026-11-23 19:06:10.589
449	13	1	13.2401601	77.7167670	0.04	2026-11-23 19:06:15.681
450	13	1	13.2401605	77.7167658	0.04	2026-11-23 19:06:21.581
451	13	1	13.2401601	77.7167662	0.03	2026-11-23 19:06:26.674
452	13	1	13.2401607	77.7167669	0.04	2026-11-23 19:06:32.58
453	13	1	13.2401608	77.7167670	0.04	2026-11-23 19:06:37.666
454	13	1	13.2401618	77.7167678	0.04	2026-11-23 19:06:42.642
455	13	1	13.2401617	77.7167679	0.04	2026-11-23 19:06:47.616
456	13	1	13.2401619	77.7167678	0.03	2026-11-23 19:06:53.634
457	13	1	13.2401625	77.7167678	0.03	2026-11-23 19:06:59.651
458	13	1	13.2401628	77.7167676	0.04	2026-11-23 19:07:04.626
459	13	1	13.2401634	77.7167678	0.04	2026-11-23 19:07:10.643
460	13	1	13.2401634	77.7167667	0.04	2026-11-23 19:07:16.66
461	13	1	13.2401633	77.7167677	0.04	2026-11-23 19:07:22.677
462	13	1	13.2401629	77.7167680	0.04	2026-11-23 19:07:28.577
463	13	1	13.2401625	77.7167677	0.04	2026-11-23 19:07:33.67
464	13	1	13.2401613	77.7167666	0.04	2026-11-23 19:08:11.623
465	13	1	13.2401600	77.7167671	0.04	2026-11-23 19:08:16.598
466	13	1	13.2401628	77.7167929	0.03	2026-11-23 19:08:28.632
467	13	1	13.2401629	77.7167957	0.04	2026-11-23 19:08:33.606
468	13	1	13.2401571	77.7168078	0.04	2026-11-23 19:08:39.624
469	13	1	13.2401544	77.7168136	0.04	2026-11-23 19:08:44.599
470	13	1	13.2401546	77.7168219	0.05	2026-11-23 19:08:50.617
471	13	1	13.2401561	77.7168275	0.03	2026-11-23 19:08:56.633
472	13	1	13.2401571	77.7168316	0.04	2026-11-23 19:09:01.609
473	13	1	13.2401586	77.7168362	0.03	2026-11-23 19:09:07.625
474	13	1	13.2401591	77.7168378	0.04	2026-11-23 19:09:12.601
475	13	1	13.2401583	77.7168387	0.04	2026-11-23 19:09:18.617
476	13	1	13.2401581	77.7168389	0.03	2026-11-23 19:09:23.594
477	13	1	13.2401586	77.7168394	0.04	2026-11-23 19:09:28.685
478	13	1	13.2401591	77.7168400	0.03	2026-11-23 19:09:34.585
479	13	1	13.2401586	77.7168403	0.04	2026-11-23 19:09:40.602
480	13	1	13.2401582	77.7168405	0.04	2026-11-23 19:09:45.58
481	13	1	13.2401585	77.7168409	0.04	2026-11-23 19:09:51.595
482	13	1	13.2401591	77.7168407	0.03	2026-11-23 19:09:56.582
483	13	1	13.2401587	77.7168405	0.04	2026-11-23 19:10:02.24
484	13	1	13.2401589	77.7168413	0.04	2026-11-23 19:10:07.679
485	13	1	13.2401581	77.7168415	0.03	2026-11-23 19:10:12.655
486	13	1	13.2401575	77.7168419	0.04	2026-11-23 19:10:17.629
487	13	1	13.2401571	77.7168419	0.04	2026-11-23 19:10:23.646
488	13	1	13.2401565	77.7168416	0.04	2026-11-23 19:10:28.623
489	13	1	13.2401579	77.7168407	0.04	2026-11-23 19:10:34.64
490	13	1	13.2401586	77.7168399	0.04	2026-11-23 19:10:39.614
491	13	1	13.2401548	77.7168379	0.04	2026-11-23 19:10:45.632
492	13	1	13.2401515	77.7168351	0.05	2026-11-23 19:10:51.648
493	13	1	13.2401506	77.7168333	0.04	2026-11-23 19:10:56.624
494	13	1	13.2401502	77.7168319	0.04	2026-11-23 19:11:01.947
495	13	1	13.2401528	77.7168268	0.04	2026-11-23 19:11:07.617
496	13	1	13.2401574	77.7168199	0.04	2026-11-23 19:11:12.593
497	13	1	13.2401612	77.7168166	0.04	2026-11-23 19:11:18.61
498	13	1	13.2401640	77.7168154	0.04	2026-11-23 19:11:23.585
499	13	1	13.2401665	77.7168145	0.03	2026-11-23 19:11:29.602
500	13	1	13.2401681	77.7168131	0.05	2026-11-23 19:11:34.578
501	13	1	13.2401686	77.7168129	0.04	2026-11-23 19:11:40.595
502	13	1	13.2401686	77.7168125	0.04	2026-11-23 19:11:45.686
503	13	1	13.2401689	77.7168121	0.05	2026-11-23 19:11:51.586
504	13	1	13.2401688	77.7168116	0.05	2026-11-23 19:11:56.679
505	13	1	13.2401682	77.7168109	0.03	2026-11-23 19:12:02.402
506	13	1	13.2401673	77.7168101	0.03	2026-11-23 19:12:07.67
507	13	1	13.2401664	77.7168114	0.05	2026-11-23 19:12:12.646
508	13	1	13.2401661	77.7168117	0.04	2026-11-23 19:12:18.663
509	13	1	13.2401667	77.7168118	0.04	2026-11-23 19:12:23.639
510	13	1	13.2401671	77.7168118	0.04	2026-11-23 19:12:29.655
511	13	1	13.2401676	77.7168120	0.03	2026-11-23 19:12:35.673
512	13	1	13.2401678	77.7168128	0.04	2026-11-23 19:12:41.577
513	13	1	13.2401684	77.7168133	0.06	2026-11-23 19:12:46.666
514	13	1	13.2401692	77.7168133	0.06	2026-11-23 19:12:52.45
515	13	1	13.2401696	77.7168138	0.04	2026-11-23 19:12:57.658
516	13	1	13.2401694	77.7168136	0.06	2026-11-23 19:13:02.749
517	13	1	13.2401696	77.7168134	0.07	2026-11-23 19:13:08.651
518	13	1	13.2401692	77.7168134	0.05	2026-11-23 19:13:13.627
519	13	1	13.2401685	77.7168145	0.07	2026-11-23 19:13:18.601
520	13	1	13.2401679	77.7168149	0.06	2026-11-23 19:13:24.619
521	13	1	13.2401684	77.7168143	0.06	2026-11-23 19:13:29.595
522	13	1	13.2401687	77.7168129	0.06	2026-11-23 19:13:35.611
523	13	1	13.2401693	77.7168110	0.06	2026-11-23 19:13:41.629
524	13	1	13.2401692	77.7168108	0.07	2026-11-23 19:13:47.645
525	13	1	13.2401677	77.7168104	0.07	2026-11-23 19:13:53.662
526	13	1	13.2401679	77.7168106	0.06	2026-11-23 19:13:58.638
527	13	1	13.2401673	77.7168117	0.07	2026-11-23 19:14:04.572
528	13	1	13.2401671	77.7168112	0.07	2026-11-23 19:14:09.631
529	13	1	13.2401660	77.7168116	0.06	2026-11-23 19:14:14.605
530	13	1	13.2401652	77.7168131	0.05	2026-11-23 19:14:20.623
531	13	1	13.2401652	77.7168143	0.06	2026-11-23 19:14:25.599
532	13	1	13.2401655	77.7168142	0.06	2026-11-23 19:14:31.616
533	13	1	13.2401654	77.7168145	0.06	2026-11-23 19:14:36.59
534	13	1	13.2401660	77.7168143	0.07	2026-11-23 19:14:41.575
535	13	1	13.2401660	77.7168136	0.06	2026-11-23 19:14:47.584
536	13	1	13.2401673	77.7168137	0.07	2026-11-23 19:14:53.6
537	13	1	13.2401681	77.7168134	0.07	2026-11-23 19:14:59.617
538	13	1	13.2401682	77.7168140	0.06	2026-11-23 19:15:04.593
539	13	1	13.2401679	77.7168137	0.06	2026-11-23 19:15:10.609
540	13	1	13.2401680	77.7168136	0.06	2026-11-23 19:15:16.627
541	13	1	13.2401685	77.7168135	0.06	2026-11-23 19:15:22.644
542	13	1	13.2401686	77.7168144	0.04	2026-11-23 19:15:27.619
543	13	1	13.2401689	77.7168133	0.03	2026-11-23 19:15:32.595
544	13	1	13.2401686	77.7168127	0.04	2026-11-23 19:15:38.612
545	13	1	13.2401677	77.7168127	0.04	2026-11-23 19:15:44.629
546	13	1	13.2401683	77.7168123	0.03	2026-11-23 19:15:50.645
547	13	1	13.2401684	77.7168122	0.04	2026-11-23 19:15:56.663
548	13	1	13.2401688	77.7168125	0.06	2026-11-23 19:16:02.679
549	13	1	13.2401684	77.7168130	0.06	2026-11-23 19:16:07.656
550	13	1	13.2401678	77.7168133	0.06	2026-11-23 19:16:12.63
551	13	1	13.2401680	77.7168136	0.07	2026-11-23 19:16:18.647
552	13	1	13.2401679	77.7168144	0.06	2026-11-23 19:16:23.623
553	13	1	13.2401673	77.7168149	0.06	2026-11-23 19:16:28.598
554	13	1	13.2401664	77.7168153	0.07	2026-11-23 19:16:34.615
555	13	1	13.2401656	77.7168146	0.06	2026-11-23 19:16:39.591
556	13	1	13.2401647	77.7168143	0.07	2026-11-23 19:16:44.683
557	13	1	13.2401641	77.7168141	0.06	2026-11-23 19:16:50.583
558	13	1	13.2401631	77.7168142	0.06	2026-11-23 19:16:55.675
559	13	1	13.2401623	77.7168134	0.06	2026-11-23 19:17:01.577
560	13	1	13.2401623	77.7168127	0.06	2026-11-23 19:17:06.668
561	13	1	13.2401627	77.7168131	0.07	2026-11-23 19:17:11.642
562	13	1	13.2401640	77.7168118	0.06	2026-11-23 19:17:16.619
563	13	1	13.2401636	77.7168107	0.08	2026-11-23 19:17:22.636
564	13	1	13.2401634	77.7168111	0.07	2026-11-23 19:17:27.612
565	13	1	13.2401639	77.7168116	0.06	2026-11-23 19:17:32.587
566	13	1	13.2401645	77.7168116	0.06	2026-11-23 19:17:37.679
567	13	1	13.2401655	77.7168109	0.06	2026-11-23 19:17:43.579
568	13	1	13.2401670	77.7168121	0.07	2026-11-23 19:17:48.67
569	13	1	13.2401675	77.7168141	0.07	2026-11-23 19:17:54.581
570	13	1	13.2401686	77.7168146	0.06	2026-11-23 19:18:00.59
571	13	1	13.2401687	77.7168148	0.06	2026-11-23 19:18:05.576
572	13	1	13.2401687	77.7168149	0.06	2026-11-23 19:18:10.657
573	13	1	13.2401667	77.7168146	0.06	2026-11-23 19:18:15.631
574	13	1	13.2401658	77.7168142	0.07	2026-11-23 19:18:21.649
575	13	1	13.2401657	77.7168139	0.06	2026-11-23 19:18:27.665
576	13	1	13.2401662	77.7168143	0.07	2026-11-23 19:18:33.578
577	13	1	13.2401673	77.7168143	0.07	2026-11-23 19:18:39.585
578	13	1	13.2401667	77.7168140	0.06	2026-11-23 19:18:44.676
579	13	1	13.2401665	77.7168139	0.06	2026-11-23 19:18:50.579
580	13	1	13.2401657	77.7168146	0.07	2026-11-23 19:18:56.594
581	13	1	13.2401656	77.7168150	0.06	2026-11-23 19:19:01.579
582	13	1	13.2401653	77.7168152	0.06	2026-11-23 19:19:07.587
583	13	1	13.2401650	77.7168140	0.07	2026-11-23 19:19:12.678
584	13	1	13.2401652	77.7168139	0.07	2026-11-23 19:19:18.58
585	13	1	13.2401656	77.7168140	0.06	2026-11-23 19:19:23.902
586	13	1	13.2401654	77.7168141	0.07	2026-11-23 19:19:29.687
587	13	1	13.2401658	77.7168138	0.06	2026-11-23 19:19:35.588
588	13	1	13.2401659	77.7168136	0.06	2026-11-23 19:19:40.68
589	13	1	13.2401662	77.7168136	0.06	2026-11-23 19:19:46.581
590	13	1	13.2401678	77.7168133	0.05	2026-11-23 19:19:52.599
591	13	1	13.2401678	77.7168127	0.06	2026-11-23 19:19:57.576
592	13	1	13.2401675	77.7168120	0.07	2026-11-23 19:20:03.59
593	13	1	13.2401676	77.7168117	0.06	2026-11-23 19:20:08.682
594	13	1	13.2401679	77.7168122	0.07	2026-11-23 19:20:14.351
595	13	1	13.2401681	77.7168118	0.05	2026-11-23 19:20:19.578
596	13	1	13.2401681	77.7168114	0.07	2026-11-23 19:20:24.65
597	13	1	13.2401672	77.7168114	0.06	2026-11-23 19:20:30.668
598	13	1	13.2401660	77.7168114	0.06	2026-11-23 19:20:35.642
599	13	1	13.2401655	77.7168113	0.06	2026-11-23 19:20:41.66
600	13	1	13.2401657	77.7168111	0.06	2026-11-23 19:20:46.636
601	13	1	13.2401659	77.7168110	0.06	2026-11-23 19:20:52.652
602	13	1	13.2401661	77.7168123	0.07	2026-11-23 19:20:57.628
603	13	1	13.2401660	77.7168115	0.06	2026-11-23 19:21:03.645
604	13	1	13.2401656	77.7168108	0.06	2026-11-23 19:21:08.621
605	13	1	13.2401656	77.7168109	0.06	2026-11-23 19:21:13.596
606	13	1	13.2401657	77.7168099	0.07	2026-11-23 19:21:18.577
607	13	1	13.2401668	77.7168102	0.06	2026-11-23 19:21:24.403
608	13	1	13.2401672	77.7168107	0.06	2026-11-23 19:21:29.68
609	13	1	13.2401673	77.7168121	0.07	2026-11-23 19:21:34.655
610	13	1	13.2401677	77.7168135	0.07	2026-11-23 19:21:40.672
611	13	1	13.2401679	77.7168139	0.07	2026-11-23 19:21:45.647
612	13	1	13.2401680	77.7168141	0.07	2026-11-23 19:21:50.622
613	13	1	13.2401684	77.7168144	0.06	2026-11-23 19:21:56.64
614	13	1	13.2401686	77.7168144	0.06	2026-11-23 19:22:02.656
615	13	1	13.2401684	77.7168146	0.06	2026-11-23 19:22:08.572
616	13	1	13.2401686	77.7168142	0.04	2026-11-23 19:22:14.576
617	13	1	13.2401691	77.7168147	0.07	2026-11-23 19:22:20.593
618	13	1	13.2401686	77.7168149	0.06	2026-11-23 19:22:25.578
619	13	1	13.2401684	77.7168148	0.06	2026-11-23 19:22:30.66
620	13	1	13.2401681	77.7168150	0.07	2026-11-23 19:22:36.677
621	14	2	13.2401667	77.7168133	\N	2026-11-23 19:23:56.402
622	14	2	13.2401215	77.7168696	0.00	2026-11-23 19:24:01.577
623	14	2	13.2401218	77.7168709	0.59	2026-11-23 19:24:06.617
624	14	2	13.2401211	77.7168696	0.09	2026-11-23 19:24:12.634
625	14	2	13.2401215	77.7168329	0.09	2026-11-23 19:24:18.536
626	14	2	13.2401343	77.7168199	0.09	2026-11-23 19:24:23.627
627	14	2	13.2401382	77.7168142	0.09	2026-11-23 19:24:28.603
628	14	2	13.2401444	77.7168105	0.06	2026-11-23 19:24:33.579
629	14	2	13.2401499	77.7168074	0.07	2026-11-23 19:24:38.701
630	14	2	13.2401535	77.7168059	0.08	2026-11-23 19:24:44.686
631	14	2	13.2401561	77.7168048	0.06	2026-11-23 19:24:50.588
632	14	2	13.2401573	77.7168042	0.07	2026-11-23 19:24:56.605
633	14	2	13.2401580	77.7168036	0.05	2026-11-23 19:25:02.622
634	14	2	13.2401591	77.7168037	0.07	2026-11-23 19:25:08.407
635	14	2	13.2401589	77.7168034	0.07	2026-11-23 19:25:13.615
636	14	2	13.2401587	77.7168030	0.07	2026-11-23 19:25:18.591
637	14	2	13.2401583	77.7168023	0.08	2026-11-23 19:25:24.608
1153	13	1	13.2401624	77.7167232	0.05	2026-11-23 20:51:37.583
1154	13	1	13.2401625	77.7167233	0.06	2026-11-23 20:51:42.673
1155	13	1	13.2401628	77.7167231	0.06	2026-11-23 20:51:48.577
1156	13	1	13.2401623	77.7167236	0.06	2026-11-23 20:51:53.664
1157	13	1	13.2401620	77.7167244	0.06	2026-11-23 20:51:59.574
1158	13	1	13.2401616	77.7167257	0.06	2026-11-23 20:52:05.581
1159	13	1	13.2401634	77.7167247	0.06	2026-11-23 20:52:11.597
1160	13	1	13.2401635	77.7167242	0.07	2026-11-23 20:52:17.614
1161	13	1	13.2401628	77.7167236	0.06	2026-11-23 20:52:22.588
1162	13	1	13.2401617	77.7167219	0.06	2026-11-23 20:52:28.605
1163	13	1	13.2401617	77.7167215	0.07	2026-11-23 20:52:33.579
1164	13	1	13.2401620	77.7167211	0.06	2026-11-23 20:52:39.596
1165	13	1	13.2401613	77.7167204	0.07	2026-11-23 20:52:44.576
1166	13	1	13.2401623	77.7167202	0.06	2026-11-23 20:52:50.587
1167	13	1	13.2401626	77.7167200	0.06	2026-11-23 20:52:55.677
1168	13	1	13.2401641	77.7167206	0.07	2026-11-23 20:53:01.23
1169	13	1	13.2401644	77.7167214	0.05	2026-11-23 20:53:06.669
1170	13	1	13.2401641	77.7167215	0.06	2026-11-23 20:53:12.58
1171	13	1	13.2401636	77.7167217	0.06	2026-11-23 20:53:18.585
1172	13	1	13.2401631	77.7167217	0.06	2026-11-23 20:53:23.676
1173	13	1	13.2401629	77.7167222	0.06	2026-11-23 20:53:29.577
1174	13	1	13.2401634	77.7167223	0.05	2026-11-23 20:53:35.593
1175	13	1	13.2401632	77.7167225	0.06	2026-11-23 20:53:40.577
1176	13	1	13.2401632	77.7167228	0.07	2026-11-23 20:53:45.658
1177	13	1	13.2401635	77.7167230	0.04	2026-11-23 20:53:50.633
1178	13	1	13.2401640	77.7167233	0.06	2026-11-23 20:53:56.649
1179	13	1	13.2401642	77.7167233	0.06	2026-11-23 20:54:02.666
1180	13	1	13.2401641	77.7167224	0.06	2026-11-23 20:54:08.578
1181	13	1	13.2401642	77.7167222	0.06	2026-11-23 20:54:13.657
1182	13	1	13.2401640	77.7167213	0.07	2026-11-23 20:54:19.673
1183	13	1	13.2401640	77.7167215	0.06	2026-11-23 20:54:24.648
1184	13	1	13.2401646	77.7167209	0.06	2026-11-23 20:54:30.432
1185	13	1	13.2401638	77.7167203	0.05	2026-11-23 20:54:35.638
1186	13	1	13.2401639	77.7167200	0.06	2026-11-23 20:54:40.613
1187	13	1	13.2401635	77.7167194	0.06	2026-11-23 20:54:45.589
1188	13	1	13.2401635	77.7167193	0.07	2026-11-23 20:54:50.678
1189	13	1	13.2401632	77.7167183	0.06	2026-11-23 20:54:56.58
1190	13	1	13.2401632	77.7167179	0.06	2026-11-23 20:55:01.669
1191	13	1	13.2401642	77.7167193	0.06	2026-11-23 20:55:07.576
1192	13	1	13.2401641	77.7167204	0.06	2026-11-23 20:55:12.661
1193	13	1	13.2401639	77.7167214	0.04	2026-11-23 20:55:18.677
1194	13	1	13.2401635	77.7167216	0.05	2026-11-23 20:55:23.652
1195	13	1	13.2401630	77.7167222	0.05	2026-11-23 20:55:29.669
1196	13	1	13.2401620	77.7167228	0.07	2026-11-23 20:55:35.576
1197	13	1	13.2401618	77.7167234	0.06	2026-11-23 20:55:41.585
1198	13	1	13.2401616	77.7167235	0.06	2026-11-23 20:55:47.602
1199	13	1	13.2401617	77.7167225	0.06	2026-11-23 20:55:52.577
1200	13	1	13.2401625	77.7167212	0.07	2026-11-23 20:55:58.592
1201	13	1	13.2401626	77.7167212	0.05	2026-11-23 20:56:03.575
1202	13	1	13.2401629	77.7167215	0.06	2026-11-23 20:56:08.659
1203	13	1	13.2401633	77.7167214	0.06	2026-11-23 20:56:14.674
1204	13	1	13.2401969	77.7168111	0.06	2026-11-23 20:57:04.655
1205	13	1	13.2401975	77.7168108	0.04	2026-11-23 20:57:09.629
1206	13	1	13.2401976	77.7168107	0.04	2026-11-23 20:57:15.646
1207	13	1	13.2401973	77.7168102	0.03	2026-11-23 20:57:20.622
1208	13	1	13.2401971	77.7168103	0.05	2026-11-23 20:57:25.596
1209	13	1	13.2401975	77.7168106	0.04	2026-11-23 20:57:30.576
1210	13	1	13.2401974	77.7168109	0.04	2026-11-23 20:57:36.587
1211	13	1	13.2401971	77.7168106	0.04	2026-11-23 20:57:41.678
1455	14	2	13.2401298	77.7168990	0.04	2026-11-23 21:22:27.639
1456	14	2	13.2401296	77.7168991	0.04	2026-11-23 21:22:32.613
1457	14	2	13.2401302	77.7168993	0.04	2026-11-23 21:22:38.63
1458	14	2	13.2401314	77.7169003	0.04	2026-11-23 21:22:44.645
1459	14	2	13.2401312	77.7169006	0.04	2026-11-23 21:22:49.62
1460	14	2	13.2401311	77.7169007	0.03	2026-11-23 21:22:55.638
1461	14	2	13.2401314	77.7169001	0.03	2026-11-23 21:23:00.612
1462	14	2	13.2401316	77.7168997	0.03	2026-11-23 21:23:06.629
1463	14	2	13.2401323	77.7168982	0.04	2026-11-23 21:23:12.066
1464	14	2	13.2401324	77.7168977	0.04	2026-11-23 21:23:17.62
1465	14	2	13.2401326	77.7168977	0.04	2026-11-23 21:23:22.595
1466	14	2	13.2401353	77.7168881	0.04	2026-11-23 21:23:28.61
1467	14	2	13.2401403	77.7168817	0.04	2026-11-23 21:23:33.585
1468	14	2	13.2401419	77.7168797	0.02	2026-11-23 21:23:39.601
1469	14	2	13.2401428	77.7168790	0.04	2026-11-23 21:23:44.577
1470	14	2	13.2401447	77.7168799	0.03	2026-11-23 21:23:50.593
1471	14	2	13.2401454	77.7168809	0.03	2026-11-23 21:23:56.609
1472	14	2	13.2401493	77.7168908	0.04	2026-11-23 21:24:02.626
1473	14	2	13.2401507	77.7168962	0.04	2026-11-23 21:24:08.643
1474	14	2	13.2401513	77.7168988	0.04	2026-11-23 21:24:13.618
1475	14	2	13.2401514	77.7168999	0.05	2026-11-23 21:24:19.633
1476	14	2	13.2401519	77.7169006	0.04	2026-11-23 21:24:24.608
1477	14	2	13.2401528	77.7169011	0.05	2026-11-23 21:24:30.625
1478	14	2	13.2401529	77.7169017	0.04	2026-11-23 21:24:36.641
1479	14	2	13.2401529	77.7169020	0.03	2026-11-23 21:24:42.657
1480	14	2	13.2401534	77.7169030	0.04	2026-11-23 21:24:48.674
1481	14	2	13.2401534	77.7169027	0.03	2026-11-23 21:24:54.577
1482	14	2	13.2401529	77.7169033	0.04	2026-11-23 21:25:00.59
1483	14	2	13.2401524	77.7169034	0.04	2026-11-23 21:25:05.575
1484	14	2	13.2401521	77.7169037	0.04	2026-11-23 21:25:10.656
1485	14	2	13.2401512	77.7169041	0.04	2026-11-23 21:25:16.671
1486	14	2	13.2401502	77.7169048	0.04	2026-11-23 21:25:22.573
1487	14	2	13.2401502	77.7169046	0.05	2026-11-23 21:25:28.589
1488	14	2	13.2401512	77.7169037	0.04	2026-11-23 21:25:34.604
1489	14	2	13.2401510	77.7169036	0.04	2026-11-23 21:25:40.621
1490	13	1	13.2401507	77.7169036	\N	2026-11-23 21:28:05.702
1491	13	1	13.2399196	77.7168001	0.07	2026-11-23 21:28:11.867
1492	13	1	13.2400270	77.7168704	0.19	2026-11-23 21:28:16.948
1493	13	1	13.2400495	77.7168658	0.27	2026-11-23 21:28:22.617
1494	13	1	13.2400237	77.7168531	0.23	2026-11-23 21:28:27.592
1495	13	1	13.2400042	77.7168449	0.15	2026-11-23 21:28:32.682
1496	13	1	13.2399955	77.7168375	0.10	2026-11-23 21:28:37.773
1497	13	1	13.2399909	77.7168362	0.08	2026-11-23 21:28:43.673
1498	13	1	13.2399881	77.7168349	0.03	2026-11-23 21:28:49.574
773	13	1	13.2401186	77.7166931	0.06	2026-11-23 20:10:16.594
1212	13	1	13.2401970	77.7168101	0.04	2026-11-23 20:57:47.578
1213	13	1	13.2401974	77.7168101	0.04	2026-11-23 20:57:53.594
1214	13	1	13.2401970	77.7168105	0.04	2026-11-23 20:57:59.148
1215	13	1	13.2401964	77.7168109	0.03	2026-11-23 20:58:04.586
1216	13	1	13.2401966	77.7168108	0.04	2026-11-23 20:58:09.677
1217	13	1	13.2401962	77.7168107	0.04	2026-11-23 20:58:15.58
1218	13	1	13.2401965	77.7168113	0.04	2026-11-23 20:58:20.668
1219	13	1	13.2401966	77.7168119	0.04	2026-11-23 20:58:26.574
1220	13	1	13.2401971	77.7168120	0.04	2026-11-23 20:58:36.633
1221	13	1	13.2401972	77.7168121	0.04	2026-11-23 20:58:42.65
1222	13	1	13.2401979	77.7168112	0.04	2026-11-23 20:58:48.665
1223	13	1	13.2401979	77.7168101	0.05	2026-11-23 20:58:54.576
1224	13	1	13.2401973	77.7168102	0.04	2026-11-23 20:58:59.657
1225	13	1	13.2401979	77.7168101	0.03	2026-11-23 20:59:04.633
1226	13	1	13.2401983	77.7168099	0.03	2026-11-23 20:59:10.648
1227	13	1	13.2401981	77.7168100	0.04	2026-11-23 20:59:16.664
1228	13	1	13.2401976	77.7168096	0.04	2026-11-23 20:59:21.64
1229	13	1	13.2401970	77.7168096	0.03	2026-11-23 20:59:27.655
1230	13	1	13.2401970	77.7168089	0.04	2026-11-23 20:59:33.672
1231	13	1	13.2401968	77.7168084	0.04	2026-11-23 20:59:39.573
1232	13	1	13.2401971	77.7168081	0.04	2026-11-23 20:59:45.589
1233	13	1	13.2401971	77.7168085	0.05	2026-11-23 20:59:50.679
1234	13	1	13.2401968	77.7168097	0.03	2026-11-23 20:59:56.579
1235	13	1	13.2401970	77.7168099	0.04	2026-11-23 21:00:02.596
1236	13	1	13.2401969	77.7168098	0.03	2026-11-23 21:00:08.265
1237	13	1	13.2401963	77.7168104	0.04	2026-11-23 21:00:13.587
1238	13	1	13.2401966	77.7168109	0.04	2026-11-23 21:00:18.678
1239	13	1	13.2401961	77.7168105	0.03	2026-11-23 21:00:24.578
1240	13	1	13.2401966	77.7168108	0.04	2026-11-23 21:00:29.669
1241	13	1	13.2401969	77.7168104	0.04	2026-11-23 21:00:35.574
1242	13	1	13.2401967	77.7168099	0.04	2026-11-23 21:00:40.66
1243	13	1	13.2401969	77.7168101	0.03	2026-11-23 21:00:46.575
1244	13	1	13.2401964	77.7168108	0.04	2026-11-23 21:00:52.576
1245	13	1	13.2401962	77.7168108	0.03	2026-11-23 21:00:58.131
1246	13	1	13.2401959	77.7168110	0.03	2026-11-23 21:01:03.572
1247	13	1	13.2401940	77.7168092	0.04	2026-11-23 21:01:08.66
1248	13	1	13.2401913	77.7168079	0.04	2026-11-23 21:01:14.676
1249	13	1	13.2401883	77.7168064	0.05	2026-11-23 21:01:20.576
1250	13	1	13.2401825	77.7167965	0.04	2026-11-23 21:01:26.593
1251	13	1	13.2401787	77.7167915	0.03	2026-11-23 21:01:31.576
1252	13	1	13.2401767	77.7167899	0.04	2026-11-23 21:01:37.585
1253	13	1	13.2401690	77.7167799	0.03	2026-11-23 21:01:47.766
1254	13	1	13.2401661	77.7167763	0.03	2026-11-23 21:01:53.666
1255	13	1	13.2401647	77.7167733	0.04	2026-11-23 21:01:58.642
1256	13	1	13.2401638	77.7167718	0.04	2026-11-23 21:02:03.617
1257	13	1	13.2401629	77.7167708	0.05	2026-11-23 21:02:08.592
1258	13	1	13.2401628	77.7167701	0.03	2026-11-23 21:02:14.608
1259	13	1	13.2401629	77.7167699	0.04	2026-11-23 21:02:19.582
1260	13	1	13.2401628	77.7167703	0.03	2026-11-23 21:02:25.598
1261	13	1	13.2401630	77.7167700	0.04	2026-11-23 21:02:30.578
1262	13	1	13.2401630	77.7167696	0.04	2026-11-23 21:02:35.663
1263	13	1	13.2401625	77.7167695	0.04	2026-11-23 21:02:40.638
1264	13	1	13.2401634	77.7167707	0.04	2026-11-23 21:02:46.655
1265	13	1	13.2401624	77.7167708	0.04	2026-11-23 21:02:52.671
1266	13	1	13.2401629	77.7167728	0.04	2026-11-23 21:02:58.575
1267	13	1	13.2401617	77.7167736	0.05	2026-11-23 21:03:04.589
1268	13	1	13.2401614	77.7167738	0.04	2026-11-23 21:03:09.678
1269	13	1	13.2401613	77.7167731	0.04	2026-11-23 21:03:14.653
1270	13	1	13.2401619	77.7167729	0.03	2026-11-23 21:03:20.67
1271	13	1	13.2401624	77.7167733	0.05	2026-11-23 21:03:25.645
1272	13	1	13.2401629	77.7167724	0.04	2026-11-23 21:03:31.661
1273	13	1	13.2401632	77.7167727	0.04	2026-11-23 21:03:36.636
1274	13	1	13.2401611	77.7167920	0.05	2026-11-23 21:03:41.611
1275	13	1	13.2401552	77.7168129	0.05	2026-11-23 21:03:52.602
1276	13	1	13.2401525	77.7168248	0.04	2026-11-23 21:03:57.578
1277	13	1	13.2401513	77.7168292	0.03	2026-11-23 21:04:02.668
1278	13	1	13.2401511	77.7168361	0.03	2026-11-23 21:04:08.579
1279	13	1	13.2401517	77.7168399	0.04	2026-11-23 21:04:13.659
1280	13	1	13.2401523	77.7168437	0.04	2026-11-23 21:04:18.634
1281	13	1	13.2401519	77.7168469	0.04	2026-11-23 21:04:24.649
1282	13	1	13.2401522	77.7168477	0.04	2026-11-23 21:04:29.624
1283	13	1	13.2401518	77.7168484	0.04	2026-11-23 21:04:35.641
1284	13	1	13.2401519	77.7168488	0.04	2026-11-23 21:04:41.643
1285	13	1	13.2401520	77.7168496	0.04	2026-11-23 21:04:46.617
1286	13	1	13.2401517	77.7168480	0.03	2026-11-23 21:04:51.592
1287	13	1	13.2401485	77.7168320	0.03	2026-11-23 21:04:56.575
1288	13	1	13.2401487	77.7168281	0.04	2026-11-23 21:05:01.658
1289	13	1	13.2401472	77.7168245	0.03	2026-11-23 21:05:06.634
1290	13	1	13.2401452	77.7168208	0.03	2026-11-23 21:05:12.65
1291	13	1	13.2401441	77.7168184	0.04	2026-11-23 21:05:18.666
1292	13	1	13.2401430	77.7168176	0.04	2026-11-23 21:05:24.576
1293	13	1	13.2401430	77.7168166	0.04	2026-11-23 21:05:30.583
1294	13	1	13.2401426	77.7168159	0.03	2026-11-23 21:05:36.252
1295	13	1	13.2401337	77.7169064	\N	2026-11-23 21:07:13.933
1296	13	1	13.2401891	77.7169448	0.01	2026-11-23 21:07:20.572
1297	13	1	13.2401900	77.7169475	0.14	2026-11-23 21:07:26.66
1298	13	1	13.2401878	77.7169539	0.14	2026-11-23 21:07:31.635
1299	13	1	13.2401868	77.7169577	0.12	2026-11-23 21:07:37.651
1300	13	1	13.2401874	77.7169581	0.10	2026-11-23 21:07:42.625
1301	13	1	13.2401879	77.7169587	0.11	2026-11-23 21:07:48.643
1302	13	1	13.2401884	77.7168479	0.06	2026-11-23 21:07:53.617
1303	13	1	13.2401877	77.7168475	0.07	2026-11-23 21:07:58.593
1304	13	1	13.2401868	77.7168474	0.06	2026-11-23 21:08:04.608
1305	13	1	13.2401866	77.7168469	0.07	2026-11-23 21:08:10.624
1306	13	1	13.2401866	77.7168482	0.06	2026-11-23 21:08:15.599
1307	13	1	13.2401863	77.7168493	0.07	2026-11-23 21:08:21.616
1308	13	1	13.2401869	77.7168494	0.05	2026-11-23 21:08:27.632
1309	13	1	13.2401877	77.7168493	0.06	2026-11-23 21:08:32.606
1310	13	1	13.2401882	77.7168499	0.06	2026-11-23 21:08:38.624
1311	13	1	13.2401879	77.7168494	0.07	2026-11-23 21:08:43.599
1312	13	1	13.2401880	77.7168498	0.06	2026-11-23 21:08:48.574
1313	13	1	13.2401885	77.7168488	0.06	2026-11-23 21:08:54.59
1314	13	1	13.2401882	77.7168482	0.06	2026-11-23 21:08:59.577
1315	13	1	13.2401888	77.7168480	0.06	2026-11-23 21:09:05.581
1316	13	1	13.2401896	77.7168484	0.07	2026-11-23 21:09:10.672
1317	13	1	13.2401903	77.7168484	0.06	2026-11-23 21:09:16.574
1500	13	1	13.2401217	77.7168830	0.04	2026-11-23 21:29:00.574
1501	13	1	13.2401221	77.7168832	0.03	2026-11-23 21:29:06.583
1502	13	1	13.2401226	77.7168833	0.04	2026-11-23 21:29:11.673
1503	13	1	13.2401227	77.7168839	0.04	2026-11-23 21:29:17.574
1504	13	1	13.2401236	77.7168843	0.05	2026-11-23 21:29:23.59
1505	13	1	13.2401306	77.7168864	0.03	2026-11-23 21:29:28.681
1506	13	1	13.2401361	77.7168877	0.04	2026-11-23 21:29:33.656
1507	13	1	13.2401394	77.7168877	0.05	2026-11-23 21:29:39.571
1508	13	1	13.2401439	77.7168836	0.03	2026-11-23 21:29:44.647
1509	13	1	13.2401493	77.7168824	0.04	2026-11-23 21:29:50.662
1510	13	1	13.2401526	77.7168828	0.04	2026-11-23 21:29:55.638
1511	13	1	13.2401556	77.7168842	0.05	2026-11-23 21:30:01.655
1512	13	1	13.2401590	77.7168938	0.04	2026-11-23 21:30:07.324
1513	13	1	13.2401591	77.7168968	0.04	2026-11-23 21:30:12.646
1514	13	1	13.2401593	77.7168985	0.04	2026-11-23 21:30:17.621
1515	13	1	13.2401604	77.7169014	0.04	2026-11-23 21:30:23.637
1516	13	1	13.2401635	77.7169066	0.03	2026-11-23 21:30:28.612
1517	13	1	13.2401652	77.7169081	0.04	2026-11-23 21:30:34.628
1518	13	1	13.2401665	77.7169087	0.04	2026-11-23 21:30:39.602
1519	13	1	13.2401680	77.7169101	0.05	2026-11-23 21:30:44.577
1520	13	1	13.2401699	77.7169117	0.05	2026-11-23 21:30:49.669
1521	13	1	13.2401708	77.7169123	0.04	2026-11-23 21:30:55.575
1522	13	1	13.2401717	77.7169121	0.04	2026-11-23 21:31:01.586
1523	13	1	13.2401721	77.7169117	0.03	2026-11-23 21:31:06.676
1524	13	1	13.2401715	77.7169120	0.03	2026-11-23 21:31:12.577
1525	13	1	13.2401712	77.7169116	0.03	2026-11-23 21:31:18.592
1526	13	1	13.2401709	77.7169121	0.04	2026-11-23 21:31:23.576
1527	13	1	13.2401710	77.7169119	0.05	2026-11-23 21:31:28.658
1528	13	1	13.2401707	77.7169112	0.05	2026-11-23 21:31:34.675
1529	13	1	13.2401712	77.7169108	0.04	2026-11-23 21:31:40.575
1530	13	1	13.2401712	77.7169109	0.04	2026-11-23 21:31:45.665
1531	13	1	13.2401714	77.7169104	0.03	2026-11-23 21:31:51.574
1532	13	1	13.2401719	77.7169100	0.04	2026-11-23 21:31:56.656
1533	13	1	13.2401716	77.7169097	0.04	2026-11-23 21:32:02.673
1534	13	1	13.2401712	77.7169100	0.04	2026-11-23 21:32:07.648
1535	13	1	13.2401711	77.7169111	0.04	2026-11-23 21:32:13.664
1536	13	1	13.2401701	77.7169118	0.04	2026-11-23 21:32:18.639
1537	13	1	13.2401693	77.7169119	0.04	2026-11-23 21:32:24.655
1538	13	1	13.2401692	77.7169117	0.03	2026-11-23 21:32:29.63
1539	13	1	13.2401693	77.7169125	0.05	2026-11-23 21:32:35.646
1540	13	1	13.2401699	77.7169122	0.03	2026-11-23 21:32:40.621
1541	13	1	13.2401702	77.7169124	0.03	2026-11-23 21:32:45.596
1542	13	1	13.2401702	77.7169119	0.04	2026-11-23 21:32:50.576
1543	13	1	13.2401703	77.7169110	0.03	2026-11-23 21:32:56.471
1544	13	1	13.2401707	77.7169114	0.04	2026-11-23 21:33:01.677
1545	13	1	13.2401707	77.7169122	0.04	2026-11-23 21:33:07.577
1546	13	1	13.2401699	77.7169116	0.03	2026-11-23 21:33:13.595
1547	13	1	13.2401705	77.7169121	0.04	2026-11-23 21:33:19.611
1548	13	1	13.2401698	77.7169125	0.03	2026-11-23 21:33:24.586
1549	13	1	13.2401692	77.7169125	0.04	2026-11-23 21:33:30.602
1550	13	1	13.2401689	77.7169121	0.04	2026-11-23 21:33:36.155
1551	13	1	13.2401654	77.7169053	0.03	2026-11-23 21:33:41.593
1552	13	1	13.2401620	77.7168938	0.04	2026-11-23 21:33:46.575
1553	13	1	13.2401595	77.7168875	0.03	2026-11-23 21:33:52.583
1554	13	1	13.2401570	77.7168821	0.04	2026-11-23 21:33:58.6
1555	13	1	13.2401564	77.7168787	0.04	2026-11-23 21:34:03.574
1556	13	1	13.2401558	77.7168767	0.03	2026-11-23 21:34:08.666
1557	13	1	13.2401561	77.7168759	0.03	2026-11-23 21:34:14.576
1558	13	1	13.2401568	77.7168746	0.03	2026-11-23 21:34:20.583
1559	13	1	13.2401573	77.7168739	0.04	2026-11-23 21:34:25.673
1560	13	1	13.2401567	77.7168728	0.04	2026-11-23 21:34:31.578
1561	13	1	13.2401573	77.7168711	0.04	2026-11-23 21:34:36.665
1562	13	1	13.2401569	77.7168706	0.04	2026-11-23 21:34:42.576
1563	13	1	13.2401565	77.7168720	0.04	2026-11-23 21:34:48.581
1564	13	1	13.2401563	77.7168728	0.04	2026-11-23 21:34:54.597
1565	13	1	13.2401564	77.7168726	0.04	2026-11-23 21:34:59.573
1566	13	1	13.2401562	77.7168728	0.04	2026-11-23 21:35:05.588
1567	13	1	13.2401562	77.7168722	0.04	2026-11-23 21:35:10.577
1568	13	1	13.2401564	77.7168720	0.04	2026-11-23 21:35:15.812
1569	13	1	13.2401567	77.7168716	0.04	2026-11-23 21:35:21.67
1570	13	1	13.2401566	77.7168719	0.04	2026-11-23 21:35:26.645
1571	13	1	13.2401567	77.7168720	0.04	2026-11-23 21:35:32.662
1572	13	1	13.2401566	77.7168723	0.04	2026-11-23 21:35:37.636
1573	13	1	13.2401575	77.7168722	0.04	2026-11-23 21:35:42.61
1574	13	1	13.2401568	77.7168725	0.04	2026-11-23 21:35:48.628
1575	13	1	13.2401572	77.7168737	0.04	2026-11-23 21:35:54.644
1576	13	1	13.2401573	77.7168735	0.04	2026-11-23 21:36:00.66
1577	13	1	13.2401582	77.7168728	0.04	2026-11-23 21:36:06.676
1578	13	1	13.2401578	77.7168731	0.03	2026-11-23 21:36:12.577
1579	13	1	13.2401584	77.7168722	0.04	2026-11-23 21:36:17.667
1580	13	1	13.2401583	77.7168726	0.04	2026-11-23 21:36:23.575
1581	13	1	13.2401580	77.7168728	0.03	2026-11-23 21:36:28.658
1582	13	1	13.2401583	77.7168729	0.04	2026-11-23 21:36:34.673
1583	13	1	13.2401579	77.7168707	0.04	2026-11-23 21:36:39.648
1584	13	1	13.2401566	77.7168629	0.04	2026-11-23 21:36:45.434
1585	13	1	13.2401547	77.7168573	0.04	2026-11-23 21:36:50.64
1586	13	1	13.2401540	77.7168563	0.04	2026-11-23 21:36:55.614
1587	13	1	13.2401541	77.7168514	0.03	2026-11-23 21:37:00.589
1588	13	1	13.2401564	77.7168448	0.04	2026-11-23 21:37:06.606
1589	13	1	13.2401577	77.7168405	0.04	2026-11-23 21:37:11.58
1590	13	1	13.2401577	77.7168370	0.03	2026-11-23 21:37:16.671
1591	13	1	13.2401561	77.7168316	0.04	2026-11-23 21:37:22.572
1592	13	1	13.2401542	77.7168260	0.03	2026-11-23 21:37:28.589
1593	13	1	13.2401489	77.7168133	0.04	2026-11-23 21:37:33.574
1594	13	1	13.2401483	77.7168093	0.04	2026-11-23 21:37:39.58
1595	13	1	13.2401471	77.7168080	0.04	2026-11-23 21:37:44.67
1596	13	1	13.2401464	77.7168066	0.04	2026-11-23 21:37:49.646
1597	13	1	13.2401460	77.7168034	0.03	2026-11-23 21:37:54.737
1598	13	1	13.2401451	77.7168009	0.03	2026-11-23 21:38:00.636
1599	13	1	13.2401452	77.7167993	0.05	2026-11-23 21:38:05.611
1600	13	1	13.2401448	77.7167986	0.03	2026-11-23 21:38:10.587
1601	13	1	13.2401447	77.7167978	0.03	2026-11-23 21:38:16.603
1602	13	1	13.2401451	77.7167970	0.05	2026-11-23 21:38:22.619
1603	13	1	13.2401458	77.7167969	0.04	2026-11-23 21:38:28.636
1604	13	1	13.2401448	77.7167972	0.03	2026-11-23 21:38:34.536
1605	13	1	13.2401448	77.7167971	0.03	2026-11-23 21:38:39.627
1606	13	1	13.2401444	77.7167974	0.05	2026-11-23 21:38:45.643
1607	13	1	13.2401438	77.7167974	0.04	2026-11-23 21:38:50.618
1608	13	1	13.2401436	77.7167972	0.04	2026-11-23 21:38:55.592
1609	13	1	13.2401439	77.7167979	0.04	2026-11-23 21:39:01.61
1610	13	1	13.2401439	77.7167984	0.05	2026-11-23 21:39:06.584
1611	13	1	13.2401436	77.7167982	0.04	2026-11-23 21:39:11.675
1612	13	1	13.2401437	77.7167986	0.04	2026-11-23 21:39:16.65
1613	13	1	13.2401438	77.7167989	0.05	2026-11-23 21:39:22.666
1614	13	1	13.2401444	77.7167997	0.03	2026-11-23 21:39:27.64
1615	13	1	13.2401445	77.7167999	0.04	2026-11-23 21:39:33.657
1616	13	1	13.2401446	77.7167997	0.05	2026-11-23 21:39:38.632
1617	13	1	13.2401445	77.7167996	0.05	2026-11-23 21:39:43.606
1618	13	1	13.2401444	77.7167995	0.04	2026-11-23 21:39:48.582
1619	13	1	13.2401445	77.7167988	0.04	2026-11-23 21:39:54.019
1620	13	1	13.2401441	77.7167987	0.03	2026-11-23 21:39:59.574
1621	13	1	13.2401442	77.7167984	0.04	2026-11-23 21:40:04.664
1622	13	1	13.2401441	77.7167986	0.03	2026-11-23 21:40:10.576
1623	13	1	13.2401443	77.7167989	0.03	2026-11-23 21:40:15.654
1624	13	1	13.2401432	77.7167984	0.05	2026-11-23 21:40:21.67
1625	13	1	13.2401435	77.7167981	0.04	2026-11-23 21:40:27.686
1626	13	1	13.2401445	77.7167984	0.03	2026-11-23 21:40:33.588
1627	13	1	13.2401446	77.7167983	0.04	2026-11-23 21:40:39.604
1628	13	1	13.2401455	77.7167983	0.03	2026-11-23 21:40:44.579
1629	13	1	13.2401452	77.7167975	0.04	2026-11-23 21:40:50.595
1630	13	1	13.2401456	77.7167973	0.05	2026-11-23 21:40:56.611
1631	13	1	13.2401464	77.7167966	0.03	2026-11-23 21:41:02.613
1632	13	1	13.2401650	77.7168730	0.04	2026-11-23 21:41:07.588
1633	13	1	13.2401642	77.7168924	0.03	2026-11-23 21:41:13.488
1634	13	1	13.2401599	77.7168955	0.04	2026-11-23 21:41:18.578
1635	13	1	13.2401578	77.7168970	0.04	2026-11-23 21:41:24.595
1636	13	1	13.2401581	77.7168980	0.04	2026-11-23 21:41:30.611
1637	13	1	13.2401576	77.7168992	0.04	2026-11-23 21:41:35.585
1638	13	1	13.2401572	77.7168998	0.05	2026-11-23 21:41:40.676
1639	13	1	13.2401571	77.7168999	0.04	2026-11-23 21:41:45.651
1640	13	1	13.2401562	77.7168996	0.04	2026-11-23 21:41:51.668
1641	13	1	13.2401565	77.7169003	0.03	2026-11-23 21:41:57.579
1642	13	1	13.2401566	77.7168992	0.04	2026-11-23 21:42:03.122
1643	13	1	13.2401566	77.7168990	0.04	2026-11-23 21:42:08.674
1644	13	1	13.2401574	77.7168985	0.03	2026-11-23 21:42:14.577
1645	13	1	13.2401577	77.7168983	0.04	2026-11-23 21:42:19.666
1646	13	1	13.2401578	77.7168987	0.04	2026-11-23 21:42:24.64
1647	13	1	13.2401585	77.7168983	0.04	2026-11-23 21:42:30.656
1648	13	1	13.2401585	77.7168981	0.04	2026-11-23 21:42:36.673
1649	13	1	13.2401592	77.7168849	0.05	2026-11-23 21:42:41.647
1650	13	1	13.2401573	77.7168697	0.04	2026-11-23 21:42:47.664
1651	13	1	13.2401545	77.7168635	0.04	2026-11-23 21:42:52.638
1652	13	1	13.2401527	77.7168591	0.04	2026-11-23 21:42:58.654
1653	13	1	13.2401524	77.7168539	0.04	2026-11-23 21:43:04.57
1654	13	1	13.2401524	77.7168539	\N	2026-11-23 21:43:42.395
1655	13	1	13.2401107	77.7167869	0.03	2026-11-23 21:43:48.518
1656	13	1	13.2401009	77.7167866	0.20	2026-11-23 21:43:53.578
1657	13	1	13.2400993	77.7167844	0.13	2026-11-23 21:43:59.59
1658	13	1	13.2400991	77.7167824	0.08	2026-11-23 21:44:05.606
1659	13	1	13.2400999	77.7167831	0.08	2026-11-23 21:44:10.582
1660	13	1	13.2401001	77.7167833	0.08	2026-11-23 21:44:16.597
1661	13	1	13.2401256	77.7168730	0.04	2026-11-23 21:44:21.574
1662	13	1	13.2401266	77.7168747	0.03	2026-11-23 21:44:27.59
1663	13	1	13.2401271	77.7168751	0.06	2026-11-23 21:44:32.576
1664	13	1	13.2401283	77.7168753	0.07	2026-11-23 21:44:37.655
1665	13	1	13.2401294	77.7168748	0.03	2026-11-23 21:44:42.63
1666	13	1	13.2401303	77.7168757	0.03	2026-11-23 21:44:47.605
1667	13	1	13.2401312	77.7168765	0.03	2026-11-23 21:44:53.623
1668	13	1	13.2401316	77.7168770	0.03	2026-11-23 21:44:59.638
1669	13	1	13.2401320	77.7168775	0.04	2026-11-23 21:45:05.655
1670	13	1	13.2401323	77.7168781	0.05	2026-11-23 21:45:11.672
1671	13	1	13.2401319	77.7168785	0.04	2026-11-23 21:45:16.647
1672	13	1	13.2401317	77.7168787	0.04	2026-11-23 21:45:21.622
1673	13	1	13.2401328	77.7168781	0.03	2026-11-23 21:45:26.597
1674	13	1	13.2401389	77.7168765	0.03	2026-11-23 21:45:31.576
1675	13	1	13.2401434	77.7168736	0.03	2026-11-23 21:45:37.588
1676	13	1	13.2401462	77.7168717	0.04	2026-11-23 21:45:42.679
1677	13	1	13.2401479	77.7168704	0.04	2026-11-23 21:45:48.578
1678	13	1	13.2401481	77.7168701	0.04	2026-11-23 21:45:54.596
1679	13	1	13.2401494	77.7168706	0.03	2026-11-23 21:46:00.612
1680	13	1	13.2401515	77.7168692	0.04	2026-11-23 21:46:05.587
1681	13	1	13.2401518	77.7168695	0.03	2026-11-23 21:46:10.678
1682	13	1	13.2401519	77.7168705	0.04	2026-11-23 21:46:16.577
1683	13	1	13.2401521	77.7168704	0.06	2026-11-23 21:46:21.669
1684	13	1	13.2401530	77.7168701	0.07	2026-11-23 21:46:27.577
1685	13	1	13.2401536	77.7168700	0.06	2026-11-23 21:46:32.659
1686	13	1	13.2401531	77.7168698	0.06	2026-11-23 21:46:37.634
1687	13	1	13.2401532	77.7168699	0.07	2026-11-23 21:46:42.61
1688	13	1	13.2401528	77.7168701	0.06	2026-11-23 21:46:48.627
1689	13	1	13.2401525	77.7168701	0.06	2026-11-23 21:46:54.642
1690	13	1	13.2401527	77.7168701	0.06	2026-11-23 21:47:00.659
1691	13	1	13.2401522	77.7168711	0.07	2026-11-23 21:47:05.633
1692	13	1	13.2401523	77.7168709	0.07	2026-11-23 21:47:11.572
1693	13	1	13.2401529	77.7168710	0.06	2026-11-23 21:47:16.625
1694	13	1	13.2401526	77.7168711	0.06	2026-11-23 21:47:22.642
1695	13	1	13.2401528	77.7168700	0.06	2026-11-23 21:47:28.657
1696	13	1	13.2401519	77.7168698	0.07	2026-11-23 21:47:33.632
1697	13	1	13.2401527	77.7168704	0.07	2026-11-23 21:47:38.609
1698	13	1	13.2401527	77.7168713	0.07	2026-11-23 21:47:44.625
1699	13	1	13.2401532	77.7168719	0.06	2026-11-23 21:47:49.6
1700	13	1	13.2401535	77.7168721	0.06	2026-11-23 21:47:54.578
1701	13	1	13.2401537	77.7168723	0.06	2026-11-23 21:47:59.665
1702	13	1	13.2401543	77.7168723	0.06	2026-11-23 21:48:05.577
1703	13	1	13.2401545	77.7168726	0.06	2026-11-23 21:48:10.657
1704	13	1	13.2401543	77.7168730	0.06	2026-11-23 21:48:16.674
1705	13	1	13.2401541	77.7168728	0.07	2026-11-23 21:48:22.575
1706	13	1	13.2401529	77.7168728	0.06	2026-11-23 21:48:28.591
1707	13	1	13.2401528	77.7168712	0.06	2026-11-23 21:48:33.575
1708	13	1	13.2401525	77.7168710	0.07	2026-11-23 21:48:38.658
1709	13	1	13.2401520	77.7168706	0.07	2026-11-23 21:48:43.633
1710	13	1	13.2401513	77.7168711	0.06	2026-11-23 21:48:49.649
1711	13	1	13.2401508	77.7168715	0.06	2026-11-23 21:48:54.624
1712	13	1	13.2401508	77.7168708	0.07	2026-11-23 21:49:00.641
1713	13	1	13.2401497	77.7168705	0.07	2026-11-23 21:49:05.615
1714	13	1	13.2401481	77.7168707	0.05	2026-11-23 21:49:11.632
1715	13	1	13.2401477	77.7168701	0.06	2026-11-23 21:49:16.607
1716	13	1	13.2401475	77.7168709	0.07	2026-11-23 21:49:22.277
1717	13	1	13.2401466	77.7168713	0.07	2026-11-23 21:49:27.599
1718	13	1	13.2401469	77.7168711	0.07	2026-11-23 21:49:32.578
1719	13	1	13.2401482	77.7168711	0.06	2026-11-23 21:49:38.591
1720	13	1	13.2401500	77.7168706	0.06	2026-11-23 21:49:43.682
1721	13	1	13.2401507	77.7168713	0.06	2026-11-23 21:49:49.582
1722	13	1	13.2401503	77.7168721	0.05	2026-11-23 21:49:54.673
1723	13	1	13.2401510	77.7168726	0.06	2026-11-23 21:50:00.579
1724	13	1	13.2401515	77.7168724	0.03	2026-11-23 21:50:06.591
1725	13	1	13.2401514	77.7168727	0.06	2026-11-23 21:50:11.682
1726	13	1	13.2401517	77.7168729	0.06	2026-11-23 21:50:16.657
1727	13	1	13.2401526	77.7168728	0.06	2026-11-23 21:50:22.211
1728	13	1	13.2401533	77.7168729	0.07	2026-11-23 21:50:27.65
1729	13	1	13.2401530	77.7168726	0.06	2026-11-23 21:50:33.666
1730	13	1	13.2401530	77.7168721	0.06	2026-11-23 21:50:38.642
1731	13	1	13.2401517	77.7168723	0.06	2026-11-23 21:50:43.617
1732	13	1	13.2401509	77.7168729	0.06	2026-11-23 21:50:48.592
1733	13	1	13.2401499	77.7168726	0.07	2026-11-23 21:50:54.61
1734	13	1	13.2401499	77.7168720	0.06	2026-11-23 21:51:00.626
1735	13	1	13.2401487	77.7168717	0.06	2026-11-23 21:51:05.602
1736	13	1	13.2401492	77.7168712	0.06	2026-11-23 21:51:10.576
1737	13	1	13.2401479	77.7168703	0.06	2026-11-23 21:51:15.668
1738	13	1	13.2401486	77.7168709	0.06	2026-11-23 21:51:21.575
1739	13	1	13.2401495	77.7168711	0.06	2026-11-23 21:51:27.585
1740	13	1	13.2401504	77.7168707	0.06	2026-11-23 21:51:32.676
1741	13	1	13.2401500	77.7168700	0.07	2026-11-23 21:51:38.578
1742	13	1	13.2401515	77.7168692	0.06	2026-11-23 21:51:44.593
1743	13	1	13.2401519	77.7168705	0.06	2026-11-23 21:51:49.574
1744	13	1	13.2401515	77.7168712	0.06	2026-11-23 21:51:54.66
1745	13	1	13.2401519	77.7168721	0.06	2026-11-23 21:52:00.677
1746	13	1	13.2401525	77.7168724	0.06	2026-11-23 21:52:05.651
1747	13	1	13.2401523	77.7168728	0.07	2026-11-23 21:52:11.322
1748	13	1	13.2401517	77.7168741	0.07	2026-11-23 21:52:16.643
1749	13	1	13.2401519	77.7168747	0.07	2026-11-23 21:52:21.619
1750	13	1	13.2401521	77.7168751	0.07	2026-11-23 21:52:27.636
1751	13	1	13.2401517	77.7168770	0.07	2026-11-23 21:52:32.612
1752	13	1	13.2401518	77.7168769	0.07	2026-11-23 21:52:37.587
1753	13	1	13.2401517	77.7168759	0.06	2026-11-23 21:52:42.678
1754	13	1	13.2401515	77.7168755	0.07	2026-11-23 21:52:48.579
1755	13	1	13.2401510	77.7168759	0.06	2026-11-23 21:52:53.669
1756	13	1	13.2401513	77.7168752	0.06	2026-11-23 21:52:59.575
1757	13	1	13.2401518	77.7168743	0.07	2026-11-23 21:53:04.661
1758	13	1	13.2401510	77.7168745	0.06	2026-11-23 21:53:10.678
1759	13	1	13.2401496	77.7168730	0.07	2026-11-23 21:53:15.654
1760	13	1	13.2401499	77.7168728	0.07	2026-11-23 21:53:20.859
1761	13	1	13.2401496	77.7168730	0.06	2026-11-23 21:53:26.646
1762	13	1	13.2401498	77.7168729	0.05	2026-11-23 21:53:32.663
1763	13	1	13.2401514	77.7168723	0.07	2026-11-23 21:53:38.573
1764	13	1	13.2401522	77.7168718	0.07	2026-11-23 21:53:43.655
1765	13	1	13.2401525	77.7168715	0.07	2026-11-23 21:53:49.671
1766	13	1	13.2401525	77.7168713	0.07	2026-11-23 21:53:54.648
1767	13	1	13.2401523	77.7168701	0.06	2026-11-23 21:54:00.665
1768	13	1	13.2401527	77.7168704	0.07	2026-11-23 21:54:05.64
1769	13	1	13.2401531	77.7168703	0.05	2026-11-23 21:54:10.616
1770	13	1	13.2401531	77.7168704	0.07	2026-11-23 21:54:16.632
1771	13	1	13.2401531	77.7168708	0.06	2026-11-23 21:54:21.607
1772	13	1	13.2401529	77.7168707	0.06	2026-11-23 21:54:26.582
1773	13	1	13.2401536	77.7168702	0.06	2026-11-23 21:54:32.599
1774	13	1	13.2401538	77.7168701	0.07	2026-11-23 21:54:38.616
1775	13	1	13.2401538	77.7168705	0.07	2026-11-23 21:54:44.632
1776	13	1	13.2401534	77.7168707	0.06	2026-11-23 21:54:50.65
1777	13	1	13.2401526	77.7168712	0.06	2026-11-23 21:54:55.625
1778	13	1	13.2401525	77.7168713	0.02	2026-11-23 21:55:01.063
1779	13	1	13.2401528	77.7168712	0.07	2026-11-23 21:55:06.617
1780	13	1	13.2401531	77.7168707	0.06	2026-11-23 21:55:11.593
1781	13	1	13.2401523	77.7168712	0.06	2026-11-23 21:55:17.61
1782	13	1	13.2401589	77.7167933	0.06	2026-11-23 21:55:22.585
1783	13	1	13.2401628	77.7167789	0.07	2026-11-23 21:55:28.602
1784	13	1	13.2401633	77.7167784	0.07	2026-11-23 21:55:34.618
1785	13	1	13.2401636	77.7167783	0.08	2026-11-23 21:55:39.594
1786	13	1	13.2401637	77.7167777	0.06	2026-11-23 21:55:45.61
1787	13	1	13.2401644	77.7167775	0.07	2026-11-23 21:55:50.585
1788	13	1	13.2401650	77.7167784	0.07	2026-11-23 21:55:56.602
1789	13	1	13.2401647	77.7167788	0.07	2026-11-23 21:56:01.577
1790	13	1	13.2401652	77.7167801	0.07	2026-11-23 21:56:07.593
1791	13	1	13.2401646	77.7167800	0.06	2026-11-23 21:56:12.686
1792	13	1	13.2401645	77.7167794	0.06	2026-11-23 21:56:18.587
1793	13	1	13.2401635	77.7167789	0.06	2026-11-23 21:56:23.678
1794	13	1	13.2401633	77.7167787	0.07	2026-11-23 21:56:29.578
1795	13	1	13.2401636	77.7167778	0.07	2026-11-23 21:56:34.67
1796	13	1	13.2401640	77.7167774	0.07	2026-11-23 21:56:40.338
1797	13	1	13.2401642	77.7167769	0.06	2026-11-23 21:56:45.662
1798	13	1	13.2401631	77.7167763	0.06	2026-11-23 21:56:51.574
1799	13	1	13.2401624	77.7167765	0.05	2026-11-23 21:56:56.653
1800	13	1	13.2401621	77.7167771	0.05	2026-11-23 21:57:01.628
1801	13	1	13.2401628	77.7167774	0.07	2026-11-23 21:57:07.646
1802	13	1	13.2401632	77.7167768	0.07	2026-11-23 21:57:12.62
1803	13	1	13.2401640	77.7167761	0.06	2026-11-23 21:57:18.638
1804	13	1	13.2401641	77.7167760	0.06	2026-11-23 21:57:23.614
1805	13	1	13.2401638	77.7167753	0.06	2026-11-23 21:57:29.63
1806	13	1	13.2401634	77.7167751	0.07	2026-11-23 21:57:35.647
1807	13	1	13.2401629	77.7167756	0.03	2026-11-23 21:57:40.623
1808	13	1	13.2401633	77.7167763	0.06	2026-11-23 21:57:46.639
1809	13	1	13.2401625	77.7167766	0.06	2026-11-23 21:57:51.614
1810	13	1	13.2401622	77.7167783	0.07	2026-11-23 21:57:56.59
1811	13	1	13.2401611	77.7167786	0.07	2026-11-23 21:58:02.608
1812	13	1	13.2401611	77.7167785	0.06	2026-11-23 21:58:07.583
1813	13	1	13.2401616	77.7167784	0.07	2026-11-23 21:58:12.673
1814	13	1	13.2401625	77.7167790	0.05	2026-11-23 21:58:18.578
1815	13	1	13.2401626	77.7167800	0.07	2026-11-23 21:58:24.592
1816	13	1	13.2401620	77.7167800	0.07	2026-11-23 21:58:29.571
1817	13	1	13.2401631	77.7167805	0.07	2026-11-23 21:58:35.584
1818	13	1	13.2401633	77.7167812	0.07	2026-11-23 21:58:40.675
1819	13	1	13.2401644	77.7167805	0.07	2026-11-23 21:58:46.576
1820	13	1	13.2401646	77.7167810	0.06	2026-11-23 21:58:52.593
1821	13	1	13.2401646	77.7167801	0.07	2026-11-23 21:58:57.576
1822	13	1	13.2401639	77.7167810	0.06	2026-11-23 21:59:02.66
1823	13	1	13.2401625	77.7167815	0.07	2026-11-23 21:59:08.578
1824	13	1	13.2401622	77.7167824	0.07	2026-11-23 21:59:13.652
1825	13	1	13.2401629	77.7167807	0.07	2026-11-23 21:59:19.552
1826	13	1	13.2401621	77.7167808	0.06	2026-11-23 21:59:24.644
1827	13	1	13.2401608	77.7167818	0.07	2026-11-23 21:59:30.661
1828	13	1	13.2401603	77.7167811	0.06	2026-11-23 21:59:35.637
1829	13	1	13.2401607	77.7167808	0.07	2026-11-23 21:59:41.653
1830	13	1	13.2401600	77.7167805	0.06	2026-11-23 21:59:47.67
1831	13	1	13.2401605	77.7167802	0.06	2026-11-23 21:59:52.645
1832	13	1	13.2401614	77.7167801	0.06	2026-11-23 21:59:58.661
1833	13	1	13.2401624	77.7167790	0.06	2026-11-23 22:00:03.638
1834	13	1	13.2401638	77.7167785	0.07	2026-11-23 22:00:09.307
1835	13	1	13.2401642	77.7167788	0.06	2026-11-23 22:00:14.63
1836	13	1	13.2401640	77.7167791	0.07	2026-11-23 22:00:20.647
1837	13	1	13.2401644	77.7167796	0.07	2026-11-23 22:00:25.622
1838	13	1	13.2401639	77.7167795	0.07	2026-11-23 22:00:30.597
1839	13	1	13.2401644	77.7167796	0.07	2026-11-23 22:00:36.615
1840	13	1	13.2401645	77.7167809	0.07	2026-11-23 22:00:41.589
1841	13	1	13.2401632	77.7167798	0.06	2026-11-23 22:00:47.606
1842	13	1	13.2401615	77.7167793	0.06	2026-11-23 22:00:52.581
1843	13	1	13.2401611	77.7167793	0.07	2026-11-23 22:00:58.598
1844	13	1	13.2401604	77.7167783	0.07	2026-11-23 22:01:03.579
1845	13	1	13.2401624	77.7167783	0.07	2026-11-23 22:01:08.78
1846	13	1	13.2401629	77.7167782	0.07	2026-11-23 22:01:14.578
1847	13	1	13.2401625	77.7167782	0.07	2026-11-23 22:01:19.657
1848	13	1	13.2401619	77.7167783	0.08	2026-11-23 22:01:25.674
1849	13	1	13.2401617	77.7167782	0.06	2026-11-23 22:01:30.649
1850	13	1	13.2401614	77.7167785	0.06	2026-11-23 22:01:36.667
1851	13	1	13.2401620	77.7167785	0.06	2026-11-23 22:01:42.575
1852	13	1	13.2401613	77.7167775	0.08	2026-11-23 22:01:47.659
1853	13	1	13.2401621	77.7167778	0.07	2026-11-23 22:01:53.574
1854	13	1	13.2401627	77.7167780	0.06	2026-11-23 22:01:58.651
1855	13	1	13.2401633	77.7167789	0.06	2026-11-23 22:02:04.668
1856	13	1	13.2401638	77.7167794	0.07	2026-11-23 22:02:10.573
1857	13	1	13.2401636	77.7167803	0.07	2026-11-23 22:02:15.659
1858	13	1	13.2401634	77.7167809	0.06	2026-11-23 22:02:20.636
1859	13	1	13.2401645	77.7167807	0.06	2026-11-23 22:02:26.652
1860	13	1	13.2401647	77.7167820	0.06	2026-11-23 22:02:32.669
1861	13	1	13.2401642	77.7167801	0.07	2026-11-23 22:02:38.107
1862	13	1	13.2401644	77.7167787	0.06	2026-11-23 22:02:43.661
1863	13	1	13.2401639	77.7167775	0.06	2026-11-23 22:02:48.637
1864	13	1	13.2401634	77.7167777	0.06	2026-11-23 22:02:54.653
1865	13	1	13.2401632	77.7167776	0.06	2026-11-23 22:03:00.67
1866	13	1	13.2401637	77.7167779	0.06	2026-11-23 22:03:05.645
1867	13	1	13.2401642	77.7167788	0.06	2026-11-23 22:03:10.621
1868	13	1	13.2401644	77.7167791	0.06	2026-11-23 22:03:16.637
1869	13	1	13.2401639	77.7167791	0.07	2026-11-23 22:03:21.612
1870	13	1	13.2401639	77.7167780	0.07	2026-11-23 22:03:27.63
1871	13	1	13.2401636	77.7167779	0.06	2026-11-23 22:03:32.606
1872	13	1	13.2401636	77.7167775	0.07	2026-11-23 22:03:37.813
1873	13	1	13.2401627	77.7167779	0.06	2026-11-23 22:03:43.598
1874	13	1	13.2401641	77.7167796	0.07	2026-11-23 22:03:48.575
1875	13	1	13.2401644	77.7167798	0.07	2026-11-23 22:03:54.59
1876	13	1	13.2401645	77.7167797	0.07	2026-11-23 22:03:59.575
1877	13	1	13.2401644	77.7167798	0.06	2026-11-23 22:04:05.583
1878	13	1	13.2401640	77.7167808	0.07	2026-11-23 22:04:10.673
1879	13	1	13.2401645	77.7167807	0.06	2026-11-23 22:04:16.574
1880	13	1	13.2401650	77.7167811	0.06	2026-11-23 22:04:21.666
1881	13	1	13.2401640	77.7167822	0.07	2026-11-23 22:04:26.642
1882	13	1	13.2401628	77.7167827	0.07	2026-11-23 22:04:31.616
1883	13	1	13.2401622	77.7167821	0.07	2026-11-23 22:04:37.287
1884	13	1	13.2401604	77.7167821	0.07	2026-11-23 22:04:42.609
1885	13	1	13.2401597	77.7167814	0.06	2026-11-23 22:04:47.585
1886	13	1	13.2401606	77.7167804	0.06	2026-11-23 22:04:53.602
1887	13	1	13.2401620	77.7167802	0.07	2026-11-23 22:04:58.579
1888	13	1	13.2401622	77.7167799	0.07	2026-11-23 22:05:04.593
1889	13	1	13.2401619	77.7167803	0.06	2026-11-23 22:05:09.685
1890	13	1	13.2401624	77.7167799	0.06	2026-11-23 22:05:15.587
1891	13	1	13.2401610	77.7167788	0.06	2026-11-23 22:05:20.678
1892	13	1	13.2401607	77.7167787	0.06	2026-11-23 22:05:26.579
1893	13	1	13.2401595	77.7167792	0.06	2026-11-23 22:05:32.596
1894	13	1	13.2401608	77.7167765	0.06	2026-11-23 22:05:38.613
1895	13	1	13.2401618	77.7167763	0.07	2026-11-23 22:05:44.63
1896	13	1	13.2401626	77.7167767	0.07	2026-11-23 22:05:50.646
1897	13	1	13.2401634	77.7167775	0.07	2026-11-23 22:05:56.662
1898	13	1	13.2401632	77.7167777	0.06	2026-11-23 22:06:01.638
1899	13	1	13.2401633	77.7167773	0.06	2026-11-23 22:06:06.697
1900	13	1	13.2401628	77.7167779	0.06	2026-11-23 22:06:12.63
1901	13	1	13.2401631	77.7167783	0.06	2026-11-23 22:06:18.647
1902	13	1	13.2401634	77.7167792	0.06	2026-11-23 22:06:24.665
1903	13	1	13.2401630	77.7167798	0.06	2026-11-23 22:06:30.682
1904	13	1	13.2401616	77.7167798	0.07	2026-11-23 22:06:36.583
1905	13	1	13.2401612	77.7167808	0.06	2026-11-23 22:06:41.674
1906	13	1	13.2401616	77.7167801	0.06	2026-11-23 22:06:47.577
1907	13	1	13.2401633	77.7167792	0.06	2026-11-23 22:06:53.591
1908	13	1	13.2401638	77.7167785	0.07	2026-11-23 22:06:58.576
1909	13	1	13.2401638	77.7167786	0.07	2026-11-23 22:07:04.585
1910	13	1	13.2401649	77.7167781	0.06	2026-11-23 22:07:10.602
1911	13	1	13.2401647	77.7167777	0.06	2026-11-23 22:07:15.577
1912	13	1	13.2401650	77.7167771	0.06	2026-11-23 22:07:21.594
1913	13	1	13.2401643	77.7167780	0.07	2026-11-23 22:07:27.611
1914	13	1	13.2401642	77.7167770	0.07	2026-11-23 22:07:32.585
1915	13	1	13.2401661	77.7167767	0.06	2026-11-23 22:07:38.603
1916	13	1	13.2401653	77.7167768	0.06	2026-11-23 22:07:43.578
1917	13	1	13.2401654	77.7167772	0.07	2026-11-23 22:07:48.669
1918	13	1	13.2401654	77.7167777	0.07	2026-11-23 22:07:54.576
1919	13	1	13.2401654	77.7167783	0.07	2026-11-23 22:07:59.661
1920	13	1	13.2401656	77.7167783	0.07	2026-11-23 22:08:04.637
1921	13	1	13.2401651	77.7167783	0.06	2026-11-23 22:08:10.653
1922	13	1	13.2401647	77.7167782	0.07	2026-11-23 22:08:15.629
1923	13	1	13.2401640	77.7167781	0.06	2026-11-23 22:08:20.604
1924	13	1	13.2401645	77.7167790	0.07	2026-11-23 22:08:25.696
1925	13	1	13.2401648	77.7167794	0.06	2026-11-23 22:08:31.596
1926	13	1	13.2401632	77.7167807	0.07	2026-11-23 22:08:36.575
1927	13	1	13.2401633	77.7167810	0.07	2026-11-23 22:08:41.662
1928	13	1	13.2401637	77.7167814	0.07	2026-11-23 22:08:47.68
1929	13	1	13.2401637	77.7167802	0.06	2026-11-23 22:08:53.581
1930	13	1	13.2401635	77.7167799	0.06	2026-11-23 22:08:58.671
1931	13	1	13.2401639	77.7167789	0.05	2026-11-23 22:09:04.575
1932	13	1	13.2401642	77.7167792	0.06	2026-11-23 22:09:10.59
1933	13	1	13.2401638	77.7167793	0.06	2026-11-23 22:09:15.576
1934	13	1	13.2401638	77.7167797	0.06	2026-11-23 22:09:20.658
1935	13	1	13.2401639	77.7167803	0.06	2026-11-23 22:09:25.632
1936	13	1	13.2401639	77.7167809	0.07	2026-11-23 22:09:31.65
1937	13	1	13.2401631	77.7167811	0.06	2026-11-23 22:09:36.626
1938	13	1	13.2401631	77.7167821	0.06	2026-11-23 22:09:41.601
1939	13	1	13.2401622	77.7167828	0.06	2026-11-23 22:09:47.618
1940	13	1	13.2401623	77.7167812	0.06	2026-11-23 22:09:53.634
1941	13	1	13.2401636	77.7167795	0.06	2026-11-23 22:09:58.609
1942	13	1	13.2401644	77.7167792	0.06	2026-11-23 22:10:04.627
1943	13	1	13.2401655	77.7167783	0.07	2026-11-23 22:10:10.643
1944	13	1	13.2401656	77.7167793	0.07	2026-11-23 22:10:16.659
1945	13	1	13.2401653	77.7167787	0.06	2026-11-23 22:10:21.636
1946	13	1	13.2401645	77.7167783	0.07	2026-11-23 22:10:26.61
1947	13	1	13.2401642	77.7167776	0.06	2026-11-23 22:10:32.627
1948	13	1	13.2401645	77.7167770	0.05	2026-11-23 22:10:37.603
1949	13	1	13.2401642	77.7167766	0.07	2026-11-23 22:10:43.62
1950	13	1	13.2401644	77.7167761	0.07	2026-11-23 22:10:48.594
1951	13	1	13.2401643	77.7167755	0.06	2026-11-23 22:10:54.442
1952	13	1	13.2401648	77.7167749	0.07	2026-11-23 22:10:59.586
1953	13	1	13.2401650	77.7167749	0.07	2026-11-23 22:11:04.678
1954	13	1	13.2401642	77.7167757	0.06	2026-11-23 22:11:10.579
1955	13	1	13.2401644	77.7167766	0.06	2026-11-23 22:11:15.669
1956	13	1	13.2401643	77.7167770	0.06	2026-11-23 22:11:20.645
1957	13	1	13.2401640	77.7167762	0.06	2026-11-23 22:11:26.575
1958	13	1	13.2401639	77.7167756	0.07	2026-11-23 22:11:31.636
1959	13	1	13.2401635	77.7167746	0.06	2026-11-23 22:11:36.613
1960	13	1	13.2401633	77.7167748	0.07	2026-11-23 22:11:41.588
1961	13	1	13.2401641	77.7167754	0.07	2026-11-23 22:11:47.605
1962	13	1	13.2401647	77.7167785	0.07	2026-11-23 22:11:53.62
1963	13	1	13.2401652	77.7167802	0.06	2026-11-23 22:11:58.597
1964	13	1	13.2401656	77.7167808	0.07	2026-11-23 22:12:03.803
1965	13	1	13.2401660	77.7167820	0.06	2026-11-23 22:12:09.588
1966	13	1	13.2401654	77.7167825	0.06	2026-11-23 22:12:14.679
1967	13	1	13.2401662	77.7167829	0.07	2026-11-23 22:12:20.579
1968	13	1	13.2401654	77.7167817	0.06	2026-11-23 22:12:26.597
1969	13	1	13.2401658	77.7167807	0.06	2026-11-23 22:12:31.576
1970	13	1	13.2401653	77.7167796	0.07	2026-11-23 22:12:37.589
1971	13	1	13.2401642	77.7167790	0.07	2026-11-23 22:12:43.489
1972	13	1	13.2401641	77.7167789	0.06	2026-11-23 22:12:48.58
1973	13	1	13.2401636	77.7167787	0.06	2026-11-23 22:12:53.672
1974	13	1	13.2401633	77.7167799	0.07	2026-11-23 22:12:59.573
1975	13	1	13.2401631	77.7167800	0.07	2026-11-23 22:13:04.664
1976	13	1	13.2401636	77.7167801	0.06	2026-11-23 22:13:10.679
1977	13	1	13.2401637	77.7167803	0.06	2026-11-23 22:13:15.656
1978	13	1	13.2401651	77.7167808	0.06	2026-11-23 22:13:21.671
1979	13	1	13.2401662	77.7167806	0.07	2026-11-23 22:13:26.647
1980	13	1	13.2401665	77.7167797	0.06	2026-11-23 22:13:36.598
1981	13	1	13.2401670	77.7167801	0.07	2026-11-23 22:13:42.615
1982	13	1	13.2401658	77.7167792	0.06	2026-11-23 22:13:47.589
1983	13	1	13.2401637	77.7167777	0.07	2026-11-23 22:13:52.913
1984	13	1	13.2401633	77.7167766	0.06	2026-11-23 22:13:58.582
1985	13	1	13.2401631	77.7167766	0.06	2026-11-23 22:14:04.598
1986	13	1	13.2401633	77.7167759	0.07	2026-11-23 22:14:10.614
1987	13	1	13.2401636	77.7167755	0.06	2026-11-23 22:14:16.631
1988	13	1	13.2401650	77.7167759	0.06	2026-11-23 22:14:21.606
1989	13	1	13.2401654	77.7167764	0.07	2026-11-23 22:14:26.582
1990	13	1	13.2401641	77.7167776	0.06	2026-11-23 22:14:31.673
1991	13	1	13.2401643	77.7167768	0.08	2026-11-23 22:14:36.649
1992	13	1	13.2401638	77.7167770	0.07	2026-11-23 22:14:42.434
1993	13	1	13.2401636	77.7167770	0.07	2026-11-23 22:14:47.641
1994	13	1	13.2401637	77.7167780	0.06	2026-11-23 22:14:53.657
1995	13	1	13.2401630	77.7167776	0.07	2026-11-23 22:14:59.673
1996	13	1	13.2401630	77.7167777	0.06	2026-11-23 22:15:04.648
1997	13	1	13.2401633	77.7167786	0.06	2026-11-23 22:15:10.666
1998	13	1	13.2401638	77.7167783	0.05	2026-11-23 22:15:16.681
1999	13	1	13.2401638	77.7167792	0.07	2026-11-23 22:15:22.468
2000	13	1	13.2401641	77.7167802	0.07	2026-11-23 22:15:27.674
2001	13	1	13.2401639	77.7167805	0.07	2026-11-23 22:15:32.649
2002	13	1	13.2401635	77.7167800	0.07	2026-11-23 22:15:38.665
2003	13	1	13.2401639	77.7167793	0.05	2026-11-23 22:15:43.64
2004	13	1	13.2401631	77.7167782	0.06	2026-11-23 22:15:49.658
2005	13	1	13.2401628	77.7167780	0.07	2026-11-23 22:15:55.673
2006	13	1	13.2401627	77.7167773	0.06	2026-11-23 22:16:00.65
2007	13	1	13.2401619	77.7167766	0.07	2026-11-23 22:16:06.666
2008	13	1	13.2401616	77.7167772	0.07	2026-11-23 22:16:12.104
2009	13	1	13.2401618	77.7167775	0.06	2026-11-23 22:16:17.658
2010	13	1	13.2401614	77.7167779	0.07	2026-11-23 22:16:22.632
2011	13	1	13.2401608	77.7167781	0.05	2026-11-23 22:16:27.607
2012	13	1	13.2401592	77.7167790	0.06	2026-11-23 22:16:33.624
2013	13	1	13.2401592	77.7167794	0.06	2026-11-23 22:16:39.642
2014	13	1	13.2401589	77.7167796	0.06	2026-11-23 22:16:44.617
2015	13	1	13.2401592	77.7167803	0.06	2026-11-23 22:16:49.592
2016	13	1	13.2401586	77.7167813	0.07	2026-11-23 22:16:54.575
2017	13	1	13.2401596	77.7167812	0.05	2026-11-23 22:16:59.658
2018	13	1	13.2401601	77.7167788	0.07	2026-11-23 22:17:05.676
2019	13	1	13.2401601	77.7167796	0.07	2026-11-23 22:17:11.608
2020	13	1	13.2401617	77.7167788	0.06	2026-11-23 22:17:16.668
2021	13	1	13.2401618	77.7167790	0.07	2026-11-23 22:17:22.577
2022	13	1	13.2401630	77.7167786	0.07	2026-11-23 22:17:27.659
2023	13	1	13.2401620	77.7167798	0.06	2026-11-23 22:17:33.676
2024	13	1	13.2401633	77.7167798	0.06	2026-11-23 22:17:39.576
2025	13	1	13.2401645	77.7167814	0.06	2026-11-23 22:17:45.593
2026	13	1	13.2401633	77.7167812	0.06	2026-11-23 22:17:51.328
2027	13	1	13.2401633	77.7167821	0.05	2026-11-23 22:17:56.584
2028	13	1	13.2401633	77.7167823	0.06	2026-11-23 22:18:02.602
2029	13	1	13.2401631	77.7167829	0.07	2026-11-23 22:18:07.576
2030	13	1	13.2401615	77.7167839	0.06	2026-11-23 22:18:13.594
2031	13	1	13.2401596	77.7167810	0.06	2026-11-23 22:18:29.677
2032	13	1	13.2401616	77.7167802	0.07	2026-11-23 22:18:35.578
2033	13	1	13.2401612	77.7167784	0.06	2026-11-23 22:18:40.668
2034	13	1	13.2401620	77.7167787	0.05	2026-11-23 22:18:45.643
2035	13	1	13.2401623	77.7167788	0.07	2026-11-23 22:18:50.618
2036	13	1	13.2401625	77.7167797	0.06	2026-11-23 22:18:56.635
2037	13	1	13.2401629	77.7167794	0.06	2026-11-23 22:19:01.611
2038	13	1	13.2401635	77.7167794	0.06	2026-11-23 22:19:07.627
2039	13	1	13.2401634	77.7167803	0.07	2026-11-23 22:19:12.603
2040	13	1	13.2401635	77.7167807	0.06	2026-11-23 22:19:17.577
2041	13	1	13.2401637	77.7167806	0.05	2026-11-23 22:19:23.595
2042	13	1	13.2401634	77.7167804	0.06	2026-11-23 22:19:29.611
2043	13	1	13.2401630	77.7167798	0.07	2026-11-23 22:19:35.628
2044	13	1	13.2401634	77.7167799	0.06	2026-11-23 22:19:41.644
2045	13	1	13.2401630	77.7167797	0.06	2026-11-23 22:19:47.66
2046	13	1	13.2401615	77.7167798	0.05	2026-11-23 22:19:52.636
2047	13	1	13.2401619	77.7167793	0.07	2026-11-23 22:19:57.611
2048	13	1	13.2401612	77.7167794	0.08	2026-11-23 22:20:02.587
2049	13	1	13.2401615	77.7167788	0.06	2026-11-23 22:20:07.677
2050	13	1	13.2401609	77.7167786	0.06	2026-11-23 22:20:13.579
2051	13	1	13.2401604	77.7167786	0.06	2026-11-23 22:20:19.596
2052	13	1	13.2401608	77.7167780	0.06	2026-11-23 22:20:24.578
2053	13	1	13.2401635	77.7167798	0.06	2026-11-23 22:20:30.023
2054	13	1	13.2401644	77.7167800	0.06	2026-11-23 22:20:35.679
2055	13	1	13.2401640	77.7167794	0.07	2026-11-23 22:20:40.653
2056	13	1	13.2401655	77.7167788	0.07	2026-11-23 22:20:46.576
2057	13	1	13.2401658	77.7167785	0.06	2026-11-23 22:20:51.646
2058	13	1	13.2401657	77.7167786	0.06	2026-11-23 22:20:56.621
2059	13	1	13.2401658	77.7167792	0.07	2026-11-23 22:21:01.596
2060	13	1	13.2401652	77.7167793	0.06	2026-11-23 22:21:07.612
2061	13	1	13.2401656	77.7167794	0.05	2026-11-23 22:21:12.587
2062	13	1	13.2401644	77.7167788	0.06	2026-11-23 22:21:18.604
2063	13	1	13.2401634	77.7167788	0.06	2026-11-23 22:21:23.58
2064	13	1	13.2401622	77.7167798	0.06	2026-11-23 22:21:28.67
2065	13	1	13.2401614	77.7167801	0.06	2026-11-23 22:21:34.575
2066	13	1	13.2401610	77.7167802	0.07	2026-11-23 22:21:39.663
2067	13	1	13.2401610	77.7167797	0.07	2026-11-23 22:21:45.68
2068	13	1	13.2401607	77.7167789	0.07	2026-11-23 22:21:51.581
2069	13	1	13.2401612	77.7167782	0.07	2026-11-23 22:21:57.596
2070	13	1	13.2401605	77.7167780	0.06	2026-11-23 22:22:02.574
2071	13	1	13.2401605	77.7167781	0.07	2026-11-23 22:22:08.589
2072	13	1	13.2401616	77.7167782	0.07	2026-11-23 22:22:14.605
2073	13	1	13.2401614	77.7167782	0.06	2026-11-23 22:22:20.621
2074	13	1	13.2401624	77.7167777	0.07	2026-11-23 22:22:25.713
2075	13	1	13.2401620	77.7167788	0.05	2026-11-23 22:22:31.614
2076	13	1	13.2401606	77.7167782	0.04	2026-11-23 22:22:37.632
2077	13	1	13.2401606	77.7167780	0.07	2026-11-23 22:22:42.607
2078	13	1	13.2401620	77.7167770	0.06	2026-11-23 22:22:47.584
2079	13	1	13.2401626	77.7167778	0.06	2026-11-23 22:22:53.601
2080	13	1	13.2401629	77.7167790	0.07	2026-11-23 22:22:58.58
2081	13	1	13.2401628	77.7167801	0.08	2026-11-23 22:23:04.594
2082	13	1	13.2401635	77.7167809	0.07	2026-11-23 22:23:10.612
2083	13	1	13.2401641	77.7167813	0.06	2026-11-23 22:23:15.587
2084	13	1	13.2401636	77.7167802	0.06	2026-11-23 22:23:21.604
2085	13	1	13.2401636	77.7167794	0.07	2026-11-23 22:23:27.621
2086	13	1	13.2401632	77.7167793	0.06	2026-11-23 22:23:33.638
2087	13	1	13.2401630	77.7167785	0.07	2026-11-23 22:23:38.614
2088	13	1	13.2401627	77.7167777	0.07	2026-11-23 22:23:44.631
2089	13	1	13.2401622	77.7167787	0.07	2026-11-23 22:23:49.605
2090	13	1	13.2401618	77.7167787	0.06	2026-11-23 22:23:55.622
2091	13	1	13.2401609	77.7167784	0.08	2026-11-23 22:24:01.638
2092	13	1	13.2401614	77.7167783	0.07	2026-11-23 22:24:06.615
2093	13	1	13.2401618	77.7167794	0.06	2026-11-23 22:24:12.632
2094	13	1	13.2401628	77.7167791	0.07	2026-11-23 22:24:17.953
2095	13	1	13.2401615	77.7167792	0.04	2026-11-23 22:24:23.623
2096	13	1	13.2401620	77.7167790	0.05	2026-11-23 22:24:28.6
2097	13	1	13.2401619	77.7167802	0.06	2026-11-23 22:24:34.616
2098	13	1	13.2401610	77.7167807	0.06	2026-11-23 22:24:39.592
2099	13	1	13.2401617	77.7167808	0.06	2026-11-23 22:24:45.609
2100	13	1	13.2401621	77.7167811	0.05	2026-11-23 22:24:50.584
2101	13	1	13.2401627	77.7167807	0.07	2026-11-23 22:24:55.576
2102	13	1	13.2401635	77.7167803	0.07	2026-11-23 22:25:01.576
2103	13	1	13.2401642	77.7167799	0.07	2026-11-23 22:25:06.667
2104	13	1	13.2401645	77.7167793	0.06	2026-11-23 22:25:12.573
2105	13	1	13.2401644	77.7167787	0.06	2026-11-23 22:25:17.661
2106	13	1	13.2401648	77.7167788	0.05	2026-11-23 22:25:23.57
2107	13	1	13.2401640	77.7167790	0.07	2026-11-23 22:25:28.652
2108	13	1	13.2401629	77.7167783	0.07	2026-11-23 22:25:34.669
2109	13	1	13.2401633	77.7167780	0.07	2026-11-23 22:25:40.574
2110	13	1	13.2401628	77.7167775	0.06	2026-11-23 22:25:45.662
2111	13	1	13.2401625	77.7167780	0.06	2026-11-23 22:25:50.636
2112	13	1	13.2401617	77.7167784	0.07	2026-11-23 22:25:55.612
2113	13	1	13.2400302	77.7168371	\N	2026-11-23 22:27:38.54
2114	13	1	13.2401476	77.7168189	0.07	2026-11-23 22:27:43.642
2115	13	1	13.2401630	77.7168136	0.08	2026-11-23 22:27:49.576
2116	13	1	13.2401602	77.7168180	0.08	2026-11-23 22:27:58.382
2117	13	1	13.2401555	77.7168256	0.12	2026-11-23 22:28:03.575
2118	13	1	13.2401562	77.7168279	0.09	2026-11-23 22:28:09.012
2119	13	1	13.2401571	77.7168305	0.11	2026-11-23 22:28:14.682
2120	13	1	13.2401574	77.7168361	0.10	2026-11-23 22:28:20.583
2121	13	1	13.2401576	77.7168392	0.09	2026-11-23 22:28:26.599
2122	13	1	13.2401580	77.7168082	0.06	2026-11-23 22:28:31.575
2123	13	1	13.2401554	77.7167943	0.06	2026-11-23 22:28:37.591
2124	13	1	13.2401571	77.7167828	0.08	2026-11-23 22:28:43.608
2125	13	1	13.2401607	77.7167734	0.07	2026-11-23 22:28:48.698
2126	13	1	13.2401635	77.7167688	0.06	2026-11-23 22:28:54.6
2127	13	1	13.2401648	77.7167655	0.05	2026-11-23 22:28:59.577
2128	13	1	13.2401657	77.7167637	0.06	2026-11-23 22:29:05.592
2129	13	1	13.2401660	77.7167619	0.07	2026-11-23 22:29:10.683
2130	13	1	13.2401664	77.7167604	0.06	2026-11-23 22:29:16.585
2131	13	1	13.2401667	77.7167605	0.07	2026-11-23 22:29:21.676
2132	13	1	13.2401673	77.7167600	0.06	2026-11-23 22:29:27.577
2133	13	1	13.2401678	77.7167598	0.06	2026-11-23 22:29:32.668
2134	13	1	13.2401691	77.7167594	0.06	2026-11-23 22:29:37.643
2135	13	1	13.2401706	77.7167591	0.07	2026-11-23 22:29:43.573
2136	13	1	13.2401714	77.7167585	0.07	2026-11-23 22:29:48.636
2137	13	1	13.2401710	77.7167584	0.07	2026-11-23 22:29:54.652
2138	13	1	13.2401712	77.7167583	0.05	2026-11-23 22:30:00.668
2139	13	1	13.2401711	77.7167571	0.06	2026-11-23 22:30:06.572
2140	13	1	13.2401707	77.7167581	0.05	2026-11-23 22:30:11.66
2141	13	1	13.2401710	77.7167586	0.07	2026-11-23 22:30:16.636
2142	13	1	13.2401689	77.7167588	0.07	2026-11-23 22:30:22.653
2143	13	1	13.2401680	77.7167589	0.07	2026-11-23 22:30:27.628
2144	13	1	13.2401663	77.7167595	0.07	2026-11-23 22:30:33.645
2145	13	1	13.2401659	77.7167593	0.07	2026-11-23 22:30:38.62
2146	13	1	13.2401673	77.7167598	0.06	2026-11-23 22:30:44.637
2147	13	1	13.2401671	77.7167597	0.07	2026-11-23 22:30:49.613
2148	13	1	13.2401673	77.7167607	0.05	2026-11-23 22:30:55.628
2149	13	1	13.2401680	77.7167614	0.08	2026-11-23 22:31:01.645
2150	13	1	13.2401681	77.7167614	0.07	2026-11-23 22:31:07.486
2151	13	1	13.2401677	77.7167611	0.05	2026-11-23 22:31:12.638
2152	13	1	13.2401673	77.7167613	0.06	2026-11-23 22:31:18.653
2153	13	1	13.2401674	77.7167608	0.06	2026-11-23 22:31:24.671
2154	13	1	13.2401668	77.7167605	0.06	2026-11-23 22:31:29.646
2155	13	1	13.2401663	77.7167600	0.07	2026-11-23 22:31:35.662
2156	13	1	13.2401666	77.7167590	0.06	2026-11-23 22:31:41.678
2157	13	1	13.2401668	77.7167580	0.06	2026-11-23 22:31:47.117
2158	13	1	13.2401681	77.7167576	0.07	2026-11-23 22:31:52.67
2159	13	1	13.2401687	77.7167574	0.07	2026-11-23 22:31:57.646
2160	13	1	13.2401691	77.7167568	0.06	2026-11-23 22:32:02.621
2161	13	1	13.2401693	77.7167570	0.06	2026-11-23 22:32:07.596
2162	13	1	13.2401697	77.7167579	0.06	2026-11-23 22:32:13.612
2163	13	1	13.2401688	77.7167584	0.08	2026-11-23 22:32:18.586
2164	13	1	13.2401690	77.7167589	0.06	2026-11-23 22:32:24.604
2165	13	1	13.2401686	77.7167591	0.06	2026-11-23 22:32:29.579
2166	13	1	13.2401682	77.7167593	0.06	2026-11-23 22:32:34.669
2167	13	1	13.2401692	77.7167589	0.07	2026-11-23 22:32:40.574
2168	13	1	13.2401685	77.7167582	0.06	2026-11-23 22:32:45.661
2169	13	1	13.2401687	77.7167580	0.07	2026-11-23 22:32:50.637
2170	13	1	13.2401683	77.7167596	0.06	2026-11-23 22:32:56.652
2171	13	1	13.2401683	77.7167599	0.07	2026-11-23 22:33:02.574
2172	13	1	13.2401684	77.7167602	0.06	2026-11-23 22:33:07.645
2173	13	1	13.2401685	77.7167609	0.06	2026-11-23 22:33:13.661
2174	13	1	13.2401685	77.7167615	0.06	2026-11-23 22:33:19.678
2175	13	1	13.2401683	77.7167612	0.06	2026-11-23 22:33:25.578
2176	13	1	13.2401682	77.7167604	0.07	2026-11-23 22:33:30.669
2177	13	1	13.2401676	77.7167604	0.06	2026-11-23 22:33:36.453
2178	13	1	13.2401663	77.7167610	0.07	2026-11-23 22:33:41.66
2179	13	1	13.2401664	77.7167610	0.06	2026-11-23 22:33:47.577
2180	13	1	13.2401674	77.7167605	0.07	2026-11-23 22:33:53.577
2181	13	1	13.2401673	77.7167601	0.06	2026-11-23 22:33:58.668
2182	13	1	13.2401671	77.7167597	0.08	2026-11-23 22:34:04.577
2183	13	1	13.2401673	77.7167601	0.06	2026-11-23 22:34:09.66
2184	13	1	13.2401674	77.7167605	0.07	2026-11-23 22:34:15.575
2185	13	1	13.2401676	77.7167602	0.06	2026-11-23 22:34:20.65
2186	13	1	13.2401680	77.7167601	0.06	2026-11-23 22:34:26.204
2187	13	1	13.2401687	77.7167592	0.06	2026-11-23 22:34:31.643
2188	13	1	13.2401692	77.7167589	0.07	2026-11-23 22:34:36.618
2189	13	1	13.2401695	77.7167596	0.06	2026-11-23 22:34:42.635
2190	13	1	13.2401698	77.7167594	0.07	2026-11-23 22:34:48.65
2191	13	1	13.2401699	77.7167590	0.06	2026-11-23 22:34:53.625
2192	13	1	13.2401695	77.7167587	0.06	2026-11-23 22:34:59.642
2193	13	1	13.2401695	77.7167580	0.06	2026-11-23 22:35:04.617
2194	13	1	13.2401695	77.7167574	0.06	2026-11-23 22:35:10.634
2195	13	1	13.2401692	77.7167570	0.06	2026-11-23 22:35:15.61
2196	13	1	13.2401679	77.7167561	0.06	2026-11-23 22:35:20.585
2197	13	1	13.2401680	77.7167568	0.07	2026-11-23 22:35:25.791
2198	13	1	13.2401663	77.7167570	0.07	2026-11-23 22:35:31.576
2199	13	1	13.2401660	77.7167569	0.06	2026-11-23 22:35:36.667
2200	13	1	13.2401662	77.7167575	0.05	2026-11-23 22:35:41.643
2201	13	1	13.2401688	77.7167592	0.07	2026-11-23 22:35:46.617
2202	13	1	13.2401694	77.7167592	0.07	2026-11-23 22:35:52.633
2203	13	1	13.2401684	77.7167595	0.07	2026-11-23 22:35:57.609
2204	13	1	13.2401673	77.7167592	0.06	2026-11-23 22:36:03.625
2205	13	1	13.2401659	77.7167599	0.06	2026-11-23 22:36:09.641
2206	13	1	13.2401659	77.7167599	0.06	2026-11-23 22:36:15.312
2207	13	1	13.2401652	77.7167599	0.06	2026-11-23 22:36:20.634
2208	13	1	13.2401661	77.7167615	0.06	2026-11-23 22:36:26.65
2209	13	1	13.2401668	77.7167614	0.06	2026-11-23 22:36:32.667
2210	13	1	13.2401674	77.7167610	0.06	2026-11-23 22:36:37.642
2211	13	1	13.2401682	77.7167616	0.07	2026-11-23 22:36:43.658
2212	13	1	13.2401690	77.7167611	0.06	2026-11-23 22:36:49.57
2213	13	1	13.2401692	77.7167614	0.05	2026-11-23 22:36:54.997
2214	13	1	13.2401694	77.7167614	0.06	2026-11-23 22:37:00.57
2215	13	1	13.2401696	77.7167613	0.07	2026-11-23 22:37:05.642
2216	13	1	13.2401702	77.7167612	0.07	2026-11-23 22:37:10.617
2217	13	1	13.2401697	77.7167610	0.07	2026-11-23 22:37:15.592
2218	13	1	13.2401691	77.7167593	0.06	2026-11-23 22:37:25.657
2219	13	1	13.2401698	77.7167587	0.05	2026-11-23 22:37:31.673
2220	13	1	13.2401693	77.7167585	0.06	2026-11-23 22:37:36.649
2221	13	1	13.2401688	77.7167589	0.06	2026-11-23 22:37:41.624
2222	13	1	13.2401674	77.7167589	0.07	2026-11-23 22:37:47.64
2223	13	1	13.2401674	77.7167592	0.07	2026-11-23 22:37:52.616
2224	13	1	13.2401677	77.7167593	0.06	2026-11-23 22:37:57.59
2225	13	1	13.2401676	77.7167590	0.06	2026-11-23 22:38:03.606
2226	13	1	13.2401668	77.7167599	0.07	2026-11-23 22:39:41.606
2227	13	1	13.2401674	77.7167605	0.06	2026-11-23 22:39:47.622
2228	13	1	13.2401671	77.7167604	0.07	2026-11-23 22:39:53.638
2229	13	1	13.2401659	77.7167608	0.07	2026-11-23 22:39:59.655
2230	13	1	13.2401651	77.7167602	0.06	2026-11-23 22:40:05.671
2231	13	1	13.2401651	77.7167592	0.05	2026-11-23 22:40:11.573
2232	13	1	13.2401656	77.7167582	0.06	2026-11-23 22:40:16.664
2233	13	1	13.2401662	77.7167579	0.06	2026-11-23 22:40:21.638
2234	13	1	13.2401670	77.7167581	0.06	2026-11-23 22:40:26.614
2235	13	1	13.2401671	77.7167597	0.06	2026-11-23 22:40:32.63
2236	13	1	13.2401674	77.7167608	0.06	2026-11-23 22:40:38.645
2237	13	1	13.2401678	77.7167609	0.06	2026-11-23 22:40:43.968
2238	13	1	13.2401682	77.7167602	0.06	2026-11-23 22:40:49.638
2239	13	1	13.2401682	77.7167601	0.06	2026-11-23 22:40:54.613
2240	13	1	13.2401683	77.7167592	0.07	2026-11-23 22:40:59.588
2241	13	1	13.2401684	77.7167595	0.06	2026-11-23 22:41:05.604
2242	13	1	13.2401685	77.7167599	0.06	2026-11-23 22:42:01.602
2243	13	1	13.2401682	77.7167609	0.07	2026-11-23 22:42:06.576
2244	13	1	13.2401680	77.7167616	0.08	2026-11-23 22:42:12.592
2245	13	1	13.2401680	77.7167617	0.07	2026-11-23 22:42:17.684
2246	13	1	13.2401682	77.7167619	0.06	2026-11-23 22:42:23.353
2247	13	1	13.2401677	77.7167615	0.07	2026-11-23 22:42:28.675
2248	13	1	13.2401672	77.7167604	0.06	2026-11-23 22:42:34.575
2249	13	1	13.2401662	77.7167604	0.06	2026-11-23 22:42:40.592
2250	13	1	13.2401662	77.7167609	0.06	2026-11-23 22:42:45.683
2251	13	1	13.2401665	77.7167608	0.08	2026-11-23 22:42:51.583
2252	13	1	13.2401666	77.7167605	0.07	2026-11-23 22:42:56.674
2253	13	1	13.2401671	77.7167600	0.06	2026-11-23 22:43:02.577
2254	13	1	13.2401676	77.7167591	0.07	2026-11-23 22:43:07.665
2255	13	1	13.2401683	77.7167593	0.06	2026-11-23 22:43:13.102
2256	13	1	13.2401682	77.7167598	0.08	2026-11-23 22:43:18.656
2257	13	1	13.2401677	77.7167612	0.07	2026-11-23 22:43:23.63
2258	13	1	13.2401670	77.7167614	0.07	2026-11-23 22:43:29.647
2259	13	1	13.2401658	77.7167631	0.06	2026-11-23 22:43:35.664
2260	13	1	13.2401655	77.7167623	0.07	2026-11-23 22:43:40.638
2261	13	1	13.2401658	77.7167630	0.06	2026-11-23 22:43:46.655
2262	13	1	13.2401666	77.7167621	0.07	2026-11-23 22:43:52.671
2263	13	1	13.2401667	77.7167622	0.07	2026-11-23 22:43:57.645
2264	13	1	13.2401665	77.7167621	0.07	2026-11-23 22:44:02.737
2265	13	1	13.2401674	77.7167615	0.07	2026-11-23 22:44:08.637
2266	13	1	13.2401677	77.7167610	0.07	2026-11-23 22:44:13.612
2267	13	1	13.2401687	77.7167601	0.08	2026-11-23 22:44:19.628
2268	13	1	13.2401683	77.7167597	0.06	2026-11-23 22:44:24.603
2269	13	1	13.2401678	77.7167584	0.07	2026-11-23 22:44:30.62
2270	13	1	13.2401687	77.7167584	0.06	2026-11-23 22:44:35.595
2271	13	1	13.2401686	77.7167585	0.07	2026-11-23 22:44:41.611
2272	13	1	13.2401686	77.7167590	0.07	2026-11-23 22:44:46.585
2273	13	1	13.2401689	77.7167591	0.07	2026-11-23 22:44:52.371
2274	13	1	13.2401684	77.7167594	0.06	2026-11-23 22:44:57.579
2275	13	1	13.2401677	77.7167593	0.07	2026-11-23 22:45:03.593
2276	13	1	13.2401670	77.7167592	0.07	2026-11-23 22:45:09.609
2277	13	1	13.2401668	77.7167595	0.06	2026-11-23 22:45:15.626
2278	13	1	13.2401666	77.7167593	0.06	2026-11-23 22:45:17.593
2279	13	1	13.2401568	77.7167845	0.00	2026-11-23 22:45:28.578
2280	13	1	13.2401642	77.7167850	0.08	2026-11-23 22:45:34.573
2281	13	1	13.2401641	77.7167822	0.07	2026-11-23 22:45:39.662
2282	13	1	13.2401632	77.7167840	0.06	2026-11-23 22:45:44.637
2283	13	1	13.2401629	77.7167858	0.07	2026-11-23 22:45:50.652
2284	13	1	13.2401680	77.7167843	0.08	2026-11-23 22:45:55.782
2285	13	1	13.2401699	77.7167784	0.08	2026-11-23 22:46:01.625
2286	13	1	13.2401689	77.7167726	0.08	2026-11-23 22:46:07.641
2287	13	1	13.2401690	77.7167694	0.07	2026-11-23 22:46:12.615
2288	13	1	13.2401687	77.7167666	0.06	2026-11-23 22:46:17.591
2289	13	1	13.2401682	77.7167645	0.06	2026-11-23 22:46:23.608
2290	13	1	13.2401684	77.7167631	0.06	2026-11-23 22:46:29.624
2291	13	1	13.2401688	77.7167626	0.08	2026-11-23 22:46:35.64
2292	13	1	13.2401688	77.7167622	0.07	2026-11-23 22:46:40.615
2293	13	1	13.2401688	77.7167624	0.07	2026-11-23 22:46:46.631
2294	13	1	13.2401686	77.7167621	0.06	2026-11-23 22:46:52.646
2295	13	1	13.2401686	77.7167618	0.06	2026-11-23 22:46:57.622
2296	13	1	13.2401690	77.7167620	0.06	2026-11-23 22:47:02.598
2297	13	1	13.2401692	77.7167622	0.04	2026-11-23 22:47:08.614
2298	13	1	13.2401683	77.7167633	\N	2026-11-23 22:47:36.281
2299	13	1	13.2401920	77.7168009	0.09	2026-11-23 22:47:41.636
2300	13	1	13.2401868	77.7168018	0.11	2026-11-23 22:47:47.569
2301	13	1	13.2401812	77.7168042	0.09	2026-11-23 22:47:52.626
2302	13	1	13.2401661	77.7168207	0.08	2026-11-23 22:47:58.644
2303	13	1	13.2401525	77.7168348	0.09	2026-11-23 22:48:03.618
2304	13	1	13.2401381	77.7168420	0.04	2026-11-23 22:48:08.593
2305	13	1	13.2401258	77.7168456	0.03	2026-11-23 22:48:14.609
2306	13	1	13.2401244	77.7168369	0.03	2026-11-23 22:48:20.626
2307	13	1	13.2401381	77.7168255	0.04	2026-11-23 22:48:25.832
2308	13	1	13.2401385	77.7168153	0.04	2026-11-23 22:48:31.617
2309	13	1	13.2401387	77.7168077	0.03	2026-11-23 22:48:37.633
2310	13	1	13.2401386	77.7168049	0.03	2026-11-23 22:48:42.607
2311	13	1	13.2401385	77.7168036	0.04	2026-11-23 22:48:47.583
2312	13	1	13.2401397	77.7168026	0.03	2026-11-23 22:48:53.598
2313	13	1	13.2401403	77.7168010	0.03	2026-11-23 22:48:58.576
2314	13	1	13.2401411	77.7167997	0.04	2026-11-23 22:49:03.665
2315	13	1	13.2401411	77.7167971	0.04	2026-11-23 22:49:09.576
2316	13	1	13.2401410	77.7167968	0.05	2026-11-23 22:49:15.465
2317	13	1	13.2401405	77.7167979	0.05	2026-11-23 22:49:24.316
2318	13	1	13.2401363	77.7168031	0.09	2026-11-23 22:49:29.639
2319	13	1	13.2401331	77.7168103	0.10	2026-11-23 22:49:34.614
2320	13	1	13.2401324	77.7168123	0.11	2026-11-23 22:49:40.63
2321	13	1	13.2401315	77.7168138	0.09	2026-11-23 22:49:46.646
2322	13	1	13.2401301	77.7168136	0.10	2026-11-23 22:49:51.622
2323	13	1	13.2401303	77.7168159	0.03	2026-11-23 22:49:57.638
2324	13	1	13.2401323	77.7168166	0.03	2026-11-23 22:50:02.614
2325	13	1	13.2401443	77.7168046	0.03	2026-11-23 22:50:07.589
2326	13	1	13.2402177	77.7167401	0.04	2026-11-23 22:50:12.678
2327	13	1	13.2402177	77.7167405	0.04	2026-11-23 22:50:18.58
2328	13	1	13.2402177	77.7167407	0.04	2026-11-23 22:50:23.67
2329	13	1	13.2402179	77.7167406	0.04	2026-11-23 22:50:29.575
2330	13	1	13.2402186	77.7167410	0.03	2026-11-23 22:50:34.66
2331	13	1	13.2402186	77.7167402	0.05	2026-11-23 22:50:39.636
2332	13	1	13.2402187	77.7167399	0.04	2026-11-23 22:50:45.652
2333	13	1	13.2402188	77.7167399	0.04	2026-11-23 22:50:50.627
2334	13	1	13.2402188	77.7167401	0.04	2026-11-23 22:50:56.572
2335	13	1	13.2402185	77.7167398	0.07	2026-11-23 22:51:01.617
2336	13	1	13.2402184	77.7167403	0.04	2026-11-23 22:51:06.593
2337	13	1	13.2402146	77.7167406	0.04	2026-11-23 22:51:12.609
2338	13	1	13.2402148	77.7167392	0.03	2026-11-23 22:51:17.584
2339	13	1	13.2402184	77.7167363	0.03	2026-11-23 22:51:22.675
2340	13	1	13.2402220	77.7167316	0.02	2026-11-23 22:51:28.576
2341	13	1	13.2402245	77.7167277	0.03	2026-11-23 22:51:34.128
2342	13	1	13.2402344	77.7167179	0.02	2026-11-23 22:51:39.575
2343	13	1	13.2402384	77.7167135	0.04	2026-11-23 22:51:45.582
2344	13	1	13.2402414	77.7167101	0.04	2026-11-23 22:51:51.597
2345	13	1	13.2402448	77.7167087	0.04	2026-11-23 22:51:57.613
2346	13	1	13.2402465	77.7167076	0.04	2026-11-23 22:52:02.588
2347	13	1	13.2402484	77.7167073	0.03	2026-11-23 22:52:07.575
2348	13	1	13.2402492	77.7167069	0.04	2026-11-23 22:52:12.654
2349	13	1	13.2402499	77.7167071	0.04	2026-11-23 22:52:18.67
2350	13	1	13.2402506	77.7167074	0.04	2026-11-23 22:52:23.76
2351	13	1	13.2402513	77.7167075	0.04	2026-11-23 22:52:29.661
2352	13	1	13.2402437	77.7167261	0.03	2026-11-23 22:52:35.571
2353	13	1	13.2402426	77.7167286	0.03	2026-11-23 22:52:40.652
2354	13	1	13.2402407	77.7167312	0.04	2026-11-23 22:52:45.627
2355	13	1	13.2402302	77.7167526	0.03	2026-11-23 22:52:55.578
2356	13	1	13.2402302	77.7167601	0.03	2026-11-23 22:53:00.667
2357	13	1	13.2402292	77.7167704	0.03	2026-11-23 22:53:06.575
2358	13	1	13.2402314	77.7167753	0.04	2026-11-23 22:53:11.657
2359	13	1	13.2402373	77.7167814	0.03	2026-11-23 22:53:17.674
2360	13	1	13.2402395	77.7167833	0.03	2026-11-23 22:53:23.343
2361	13	1	13.2402404	77.7167841	0.04	2026-11-23 22:53:28.665
2362	13	1	13.2402410	77.7167843	0.04	2026-11-23 22:53:33.638
2363	13	1	13.2402418	77.7167849	0.04	2026-11-23 22:53:39.655
2364	13	1	13.2402420	77.7167845	0.04	2026-11-23 22:53:44.629
2365	13	1	13.2402430	77.7167835	0.04	2026-11-23 22:53:50.646
2366	13	1	13.2402435	77.7167834	0.04	2026-11-23 22:53:56.661
2367	13	1	13.2402438	77.7167830	0.03	2026-11-23 22:54:01.636
2368	13	1	13.2402444	77.7167825	0.03	2026-11-23 22:54:07.652
2369	13	1	13.2402445	77.7167825	0.03	2026-11-23 22:54:12.628
2370	13	1	13.2402446	77.7167827	0.04	2026-11-23 22:54:18.643
2371	13	1	13.2402448	77.7167825	0.03	2026-11-23 22:54:24.66
2372	13	1	13.2402450	77.7167825	0.03	2026-11-23 22:54:30.676
2373	13	1	13.2402376	77.7167912	0.03	2026-11-23 22:54:36.576
2374	13	1	13.2402276	77.7167971	0.02	2026-11-23 22:54:42.592
2375	13	1	13.2402247	77.7167998	0.03	2026-11-23 22:54:47.574
2376	13	1	13.2402234	77.7168004	0.04	2026-11-23 22:54:52.656
2377	13	1	13.2402213	77.7168017	0.03	2026-11-23 22:54:58.673
2378	13	1	13.2402145	77.7168081	0.03	2026-11-23 22:55:03.647
2379	13	1	13.2402113	77.7168107	0.03	2026-11-23 22:55:09.664
2380	13	1	13.2402080	77.7168140	0.03	2026-11-23 22:55:15.576
2381	13	1	13.2402060	77.7168163	0.04	2026-11-23 22:55:21.58
2382	13	1	13.2402037	77.7168189	0.03	2026-11-23 22:55:27.595
2383	13	1	13.2401992	77.7168262	0.03	2026-11-23 22:55:32.576
2384	13	1	13.2401966	77.7168298	0.06	2026-11-23 22:55:37.66
2385	13	1	13.2401944	77.7168344	0.04	2026-11-23 22:55:42.636
2386	13	1	13.2401929	77.7168385	0.04	2026-11-23 22:55:48.651
2387	13	1	13.2401905	77.7168401	0.03	2026-11-23 22:55:54.667
2388	13	1	13.2401894	77.7168407	0.03	2026-11-23 22:56:00.575
2389	13	1	13.2401887	77.7168411	0.04	2026-11-23 22:56:05.658
2390	13	1	13.2401883	77.7168424	0.04	2026-11-23 22:56:11.674
2391	13	1	13.2401870	77.7168415	0.06	2026-11-23 22:56:17.578
2392	13	1	13.2401810	77.7168242	0.03	2026-11-23 22:56:23.59
2393	13	1	13.2401808	77.7168214	0.03	2026-11-23 22:56:28.575
2394	13	1	13.2401808	77.7168182	0.05	2026-11-23 22:56:33.655
2395	13	1	13.2401770	77.7168085	0.04	2026-11-23 22:56:39.671
2396	13	1	13.2401718	77.7168047	0.05	2026-11-23 22:56:44.646
2397	13	1	13.2401688	77.7168031	0.04	2026-11-23 22:56:49.62
2398	13	1	13.2401656	77.7168021	0.04	2026-11-23 22:56:54.595
2399	13	1	13.2401637	77.7168021	0.03	2026-11-23 22:57:00.61
2400	13	1	13.2401608	77.7168117	0.04	2026-11-23 22:57:05.585
2401	13	1	13.2401497	77.7168193	0.04	2026-11-23 22:57:10.57
2402	13	1	13.2401327	77.7168196	0.03	2026-11-23 22:57:15.651
2403	13	1	13.2401254	77.7168220	0.03	2026-11-23 22:57:20.626
2404	13	1	13.2401168	77.7168226	0.04	2026-11-23 22:57:26.641
2405	13	1	13.2401143	77.7168219	0.04	2026-11-23 22:57:31.616
2406	13	1	13.2401139	77.7168221	0.02	2026-11-23 22:57:37.633
2407	13	1	13.2401249	77.7168226	0.02	2026-11-23 22:57:43.571
2408	13	1	13.2401270	77.7168214	0.02	2026-11-23 22:57:48.623
2409	13	1	13.2401241	77.7168217	0.03	2026-11-23 22:57:54.64
2410	13	1	13.2401173	77.7168234	0.04	2026-11-23 22:58:00.657
2411	13	1	13.2401149	77.7168248	0.04	2026-11-23 22:58:05.631
2412	13	1	13.2401147	77.7168264	0.04	2026-11-23 22:58:11.646
2413	13	1	13.2401177	77.7168256	0.04	2026-11-23 22:58:16.622
2414	13	1	13.2401196	77.7168234	0.04	2026-11-23 22:58:21.827
2415	13	1	13.2401161	77.7168195	0.06	2026-11-23 22:58:27.612
2416	13	1	13.2400416	77.7168911	0.03	2026-11-23 22:58:32.588
2417	13	1	13.2400334	77.7169046	0.03	2026-11-23 22:58:37.679
2418	13	1	13.2400348	77.7169151	0.03	2026-11-23 22:58:43.579
2419	13	1	13.2400448	77.7169176	0.03	2026-11-23 22:58:48.669
2420	13	1	13.2400495	77.7169189	0.04	2026-11-23 22:58:53.644
2421	13	1	13.2400566	77.7169180	0.04	2026-11-23 22:58:59.66
2422	13	1	13.2400617	77.7169160	0.04	2026-11-23 22:59:05.573
2423	13	1	13.2400701	77.7169192	0.03	2026-11-23 22:59:10.651
2424	13	1	13.2400773	77.7169265	0.04	2026-11-23 22:59:16.667
2425	13	1	13.2400861	77.7169311	0.03	2026-11-23 22:59:21.641
2426	13	1	13.2400968	77.7169341	0.04	2026-11-23 22:59:26.617
2427	13	1	13.2401031	77.7169343	0.03	2026-11-23 22:59:32.632
2428	13	1	13.2401046	77.7169327	0.03	2026-11-23 22:59:38.649
2429	13	1	13.2401080	77.7169261	0.03	2026-11-23 22:59:44.665
2430	13	1	13.2401100	77.7169214	0.05	2026-11-23 22:59:49.639
2431	13	1	13.2401123	77.7169168	0.03	2026-11-23 22:59:54.613
2432	13	1	13.2401229	77.7168941	0.04	2026-11-23 23:00:00.629
2433	13	1	13.2401293	77.7168848	0.03	2026-11-23 23:00:05.604
2434	13	1	13.2401278	77.7168740	0.04	2026-11-23 23:00:10.58
2435	13	1	13.2401283	77.7168706	0.04	2026-11-23 23:00:16.595
2436	13	1	13.2401280	77.7168687	0.03	2026-11-23 23:00:21.577
2437	13	1	13.2401265	77.7168667	0.03	2026-11-23 23:00:27.586
2438	13	1	13.2401265	77.7168645	0.03	2026-11-23 23:00:32.676
2439	13	1	13.2401270	77.7168628	0.03	2026-11-23 23:00:38.577
2440	13	1	13.2401277	77.7168607	0.03	2026-11-23 23:00:44.592
2441	13	1	13.2401319	77.7168558	0.04	2026-11-23 23:00:50.609
2442	13	1	13.2401340	77.7168533	0.05	2026-11-23 23:00:55.583
2443	13	1	13.2401323	77.7168520	0.03	2026-11-23 23:01:01.599
2444	13	1	13.2401253	77.7168553	0.03	2026-11-23 23:01:07.615
2445	13	1	13.2401202	77.7168619	0.03	2026-11-23 23:01:12.59
2446	13	1	13.2401168	77.7168646	0.04	2026-11-23 23:01:18.606
2447	13	1	13.2401133	77.7168670	0.04	2026-11-23 23:01:24.622
2448	13	1	13.2401104	77.7168680	0.04	2026-11-23 23:01:29.596
2449	13	1	13.2401091	77.7168687	0.03	2026-11-23 23:01:34.574
2450	13	1	13.2401051	77.7168678	0.04	2026-11-23 23:01:40.371
2451	13	1	13.2401040	77.7168671	0.03	2026-11-23 23:01:45.574
2452	13	1	13.2401035	77.7168666	0.04	2026-11-23 23:01:50.652
2453	13	1	13.2401028	77.7168652	0.03	2026-11-23 23:01:55.627
2454	13	1	13.2401003	77.7168614	0.04	2026-11-23 23:02:01.642
2455	13	1	13.2400995	77.7168604	0.04	2026-11-23 23:02:06.616
2456	13	1	13.2400990	77.7168596	0.03	2026-11-23 23:02:11.591
2457	13	1	13.2400984	77.7168580	0.03	2026-11-23 23:02:17.608
2458	13	1	13.2400979	77.7168581	0.04	2026-11-23 23:02:23.624
2459	13	1	13.2400974	77.7168582	0.03	2026-11-23 23:02:28.598
2460	13	1	13.2400980	77.7168584	0.04	2026-11-23 23:02:34.614
2461	13	1	13.2400971	77.7168593	0.04	2026-11-23 23:02:39.935
2462	13	1	13.2400963	77.7168588	0.03	2026-11-23 23:02:45.605
2463	13	1	13.2400965	77.7168589	0.04	2026-11-23 23:02:50.58
2464	13	1	13.2400967	77.7168588	0.04	2026-11-23 23:02:55.67
2465	13	1	13.2400966	77.7168596	0.03	2026-11-23 23:03:01.574
2466	13	1	13.2400963	77.7168594	0.04	2026-11-23 23:03:06.66
2467	13	1	13.2400966	77.7168596	0.05	2026-11-23 23:03:11.635
2468	13	1	13.2400962	77.7168599	0.03	2026-11-23 23:03:17.651
2469	13	1	13.2400965	77.7168600	0.03	2026-11-23 23:03:22.625
2470	13	1	13.2400954	77.7168602	0.05	2026-11-23 23:03:28.642
2471	13	1	13.2401018	77.7168562	0.06	2026-11-23 23:03:33.616
2472	13	1	13.2401918	77.7168105	0.04	2026-11-23 23:03:39.421
2473	13	1	13.2401916	77.7168080	0.04	2026-11-23 23:03:44.607
2474	13	1	13.2401928	77.7167887	0.03	2026-11-23 23:03:49.581
2475	13	1	13.2401833	77.7167840	0.03	2026-11-23 23:03:55.597
2476	13	1	13.2401796	77.7167752	0.03	2026-11-23 23:04:00.575
2477	13	1	13.2401744	77.7167671	0.03	2026-11-23 23:04:06.588
2478	13	1	13.2401715	77.7167624	0.03	2026-11-23 23:04:11.576
2479	13	1	13.2401716	77.7167608	0.05	2026-11-23 23:04:17.579
2480	13	1	13.2401705	77.7167589	0.04	2026-11-23 23:04:23.595
2481	13	1	13.2401648	77.7167520	0.06	2026-11-23 23:04:28.575
2482	13	1	13.2401598	77.7167470	0.04	2026-11-23 23:04:33.66
2483	13	1	13.2401558	77.7167421	0.04	2026-11-23 23:04:38.634
2484	13	1	13.2401516	77.7167355	0.03	2026-11-23 23:04:43.608
2485	13	1	13.2401519	77.7167310	0.04	2026-11-23 23:04:49.278
2486	13	1	13.2401509	77.7167295	0.03	2026-11-23 23:04:54.599
2487	13	1	13.2401499	77.7167311	0.05	2026-11-23 23:04:59.577
2488	13	1	13.2401478	77.7167361	0.04	2026-11-23 23:05:05.59
2489	13	1	13.2401449	77.7167474	0.04	2026-11-23 23:05:11.605
2490	13	1	13.2401414	77.7167626	0.03	2026-11-23 23:05:17.621
2491	13	1	13.2401200	77.7167702	0.03	2026-11-23 23:05:23.637
2492	13	1	13.2401067	77.7167762	0.03	2026-11-23 23:05:28.612
2493	13	1	13.2401051	77.7167897	0.03	2026-11-23 23:05:34.627
2494	13	1	13.2401040	77.7167936	0.03	2026-11-23 23:05:39.603
2495	13	1	13.2400949	77.7167849	0.03	2026-11-23 23:05:44.577
2496	13	1	13.2400875	77.7167842	0.07	2026-11-23 23:05:50.594
2497	13	1	13.2400857	77.7167888	0.03	2026-11-23 23:05:56.61
2498	13	1	13.2400845	77.7167937	0.03	2026-11-23 23:06:02.626
2499	13	1	13.2400827	77.7168036	0.03	2026-11-23 23:06:08.525
2500	13	1	13.2400818	77.7168105	0.03	2026-11-23 23:06:13.617
2501	13	1	13.2400836	77.7168136	0.04	2026-11-23 23:06:19.632
2502	13	1	13.2400887	77.7168166	0.04	2026-11-23 23:06:25.648
2503	13	1	13.2400996	77.7168203	0.03	2026-11-23 23:06:31.665
2504	13	1	13.2401049	77.7168246	0.03	2026-11-23 23:06:37.573
2505	13	1	13.2401063	77.7168257	0.02	2026-11-23 23:06:42.654
2506	13	1	13.2401093	77.7168275	0.05	2026-11-23 23:06:48.271
2507	13	1	13.2401121	77.7168286	0.03	2026-11-23 23:06:53.645
2508	13	1	13.2401264	77.7168613	0.04	2026-11-23 23:07:20.602
2509	13	1	13.2401266	77.7168640	0.03	2026-11-23 23:07:25.576
2510	13	1	13.2401262	77.7168638	0.04	2026-11-23 23:07:30.666
2511	13	1	13.2401208	77.7168705	0.04	2026-11-23 23:07:36.578
2512	13	1	13.2401090	77.7168881	0.03	2026-11-23 23:07:42.583
2513	13	1	13.2401080	77.7169046	0.03	2026-11-23 23:07:47.674
2514	13	1	13.2401130	77.7169140	0.03	2026-11-23 23:07:53.575
2515	13	1	13.2401166	77.7169183	0.03	2026-11-23 23:07:58.663
2516	13	1	13.2401239	77.7169242	0.03	2026-11-23 23:08:04.576
2517	13	1	13.2401284	77.7169291	0.03	2026-11-23 23:08:09.654
2518	13	1	13.2401282	77.7169302	0.03	2026-11-23 23:08:15.572
2519	13	1	13.2401238	77.7169283	0.03	2026-11-23 23:08:20.646
2520	13	1	13.2401173	77.7169291	0.04	2026-11-23 23:08:25.62
2521	13	1	13.2401117	77.7169360	0.04	2026-11-23 23:08:30.595
2522	13	1	13.2401061	77.7169392	0.03	2026-11-23 23:08:36.611
2523	13	1	13.2401033	77.7169397	0.04	2026-11-23 23:08:41.585
2524	13	1	13.2400994	77.7169383	0.03	2026-11-23 23:08:47.253
2525	13	1	13.2400837	77.7169316	0.04	2026-11-23 23:08:52.575
2526	13	1	13.2400769	77.7169304	0.03	2026-11-23 23:08:57.665
2527	13	1	13.2400725	77.7169297	0.03	2026-11-23 23:09:02.64
2528	13	1	13.2400688	77.7169332	0.02	2026-11-23 23:09:08.657
2529	13	1	13.2400760	77.7169434	0.04	2026-11-23 23:09:20.576
2530	13	1	13.2400812	77.7169441	0.03	2026-11-23 23:09:26.588
2531	13	1	13.2400920	77.7169430	0.04	2026-11-23 23:09:32.604
2532	13	1	13.2401094	77.7169439	0.03	2026-11-23 23:09:38.621
2533	13	1	13.2401130	77.7169447	0.03	2026-11-23 23:09:44.636
2534	13	1	13.2401161	77.7169454	0.03	2026-11-23 23:09:50.651
2535	13	1	13.2401309	77.7169512	0.03	2026-11-23 23:09:56.553
2536	13	1	13.2401407	77.7169602	0.03	2026-11-23 23:10:01.643
2537	13	1	13.2401483	77.7169586	0.04	2026-11-23 23:10:07.659
2538	13	1	13.2401554	77.7169552	0.04	2026-11-23 23:10:13.674
2539	13	1	13.2401609	77.7169470	0.04	2026-11-23 23:10:19.577
2540	13	1	13.2401608	77.7169397	0.04	2026-11-23 23:10:24.665
2541	13	1	13.2401613	77.7169339	0.04	2026-11-23 23:10:29.639
2542	13	1	13.2401623	77.7169295	0.03	2026-11-23 23:10:34.614
2543	13	1	13.2401633	77.7169236	0.03	2026-11-23 23:10:40.63
2544	13	1	13.2401638	77.7169167	0.03	2026-11-23 23:10:46.299
2545	13	1	13.2401645	77.7169131	0.03	2026-11-23 23:10:51.621
2546	13	1	13.2401575	77.7168214	0.03	2026-11-23 23:10:56.595
2547	13	1	13.2401575	77.7168198	0.04	2026-11-23 23:11:02.61
2548	13	1	13.2401572	77.7168205	0.04	2026-11-23 23:11:07.585
2549	13	1	13.2401573	77.7168201	0.03	2026-11-23 23:11:13.601
2550	13	1	13.2401564	77.7168195	0.04	2026-11-23 23:11:18.575
2551	13	1	13.2401543	77.7168115	0.03	2026-11-23 23:11:24.591
2552	13	1	13.2401466	77.7168043	0.03	2026-11-23 23:11:29.683
2553	13	1	13.2401410	77.7167984	0.06	2026-11-23 23:11:35.583
2554	13	1	13.2401411	77.7168023	0.03	2026-11-23 23:11:40.673
2555	13	1	13.2401377	77.7168157	0.04	2026-11-23 23:11:45.995
2556	13	1	13.2401367	77.7168178	0.03	2026-11-23 23:11:51.663
2557	13	1	13.2401351	77.7168215	0.04	2026-11-23 23:11:56.638
2558	13	1	13.2401346	77.7168260	0.04	2026-11-23 23:12:02.654
2559	13	1	13.2401352	77.7168306	0.04	2026-11-23 23:12:07.629
2560	13	1	13.2401380	77.7168363	0.06	2026-11-23 23:12:13.644
2561	13	1	13.2401432	77.7168317	0.03	2026-11-23 23:12:18.618
2562	13	1	13.2401505	77.7168248	0.03	2026-11-23 23:12:24.635
2563	13	1	13.2401599	77.7168187	0.04	2026-11-23 23:12:30.651
2564	13	1	13.2401669	77.7168125	0.05	2026-11-23 23:12:35.856
2565	13	1	13.2401683	77.7168074	0.03	2026-11-23 23:12:41.641
2566	13	1	13.2401693	77.7168030	0.03	2026-11-23 23:12:47.656
2567	13	1	13.2401699	77.7168006	0.04	2026-11-23 23:12:53.672
2568	13	1	13.2401698	77.7167982	0.04	2026-11-23 23:12:59.574
2569	13	1	13.2401690	77.7167966	0.04	2026-11-23 23:13:04.663
2570	13	1	13.2401684	77.7167956	0.03	2026-11-23 23:13:10.575
2571	13	1	13.2401681	77.7167946	0.04	2026-11-23 23:13:16.575
2572	13	1	13.2401591	77.7168021	0.04	2026-11-23 23:13:22.581
2573	13	1	13.2401558	77.7168102	0.04	2026-11-23 23:13:27.67
2574	13	1	13.2401549	77.7168129	0.03	2026-11-23 23:13:33.574
2575	13	1	13.2401534	77.7168146	0.03	2026-11-23 23:13:38.66
2576	13	1	13.2401488	77.7168234	0.04	2026-11-23 23:13:43.635
2577	13	1	13.2401451	77.7168264	0.04	2026-11-23 23:13:48.611
2578	13	1	13.2401439	77.7168292	0.04	2026-11-23 23:13:53.585
2579	13	1	13.2401510	77.7168262	0.03	2026-11-23 23:13:58.676
2580	13	1	13.2401552	77.7168182	0.03	2026-11-23 23:14:04.576
2581	13	1	13.2401568	77.7168164	0.03	2026-11-23 23:14:10.591
2582	13	1	13.2401570	77.7168153	0.04	2026-11-23 23:14:16.607
2583	13	1	13.2401566	77.7168088	0.03	2026-11-23 23:14:22.622
2584	13	1	13.2401562	77.7168096	0.04	2026-11-23 23:14:27.597
2585	13	1	13.2401540	77.7168123	0.03	2026-11-23 23:14:32.688
2586	13	1	13.2401507	77.7168178	0.04	2026-11-23 23:14:38.587
2587	13	1	13.2401517	77.7168302	0.03	2026-11-23 23:14:43.574
2588	13	1	13.2401514	77.7168372	0.04	2026-11-23 23:14:48.653
2589	13	1	13.2401506	77.7168529	0.03	2026-11-23 23:14:54.669
2590	13	1	13.2401532	77.7168568	0.06	2026-11-23 23:15:00.577
2591	13	1	13.2401693	77.7168479	0.03	2026-11-23 23:15:05.66
2592	13	1	13.2401766	77.7168390	0.05	2026-11-23 23:15:11.676
2593	13	1	13.2401820	77.7168305	0.03	2026-11-23 23:15:16.65
2594	13	1	13.2402191	77.7167409	0.03	2026-11-23 23:15:22.665
2595	13	1	13.2402294	77.7167051	0.04	2026-11-23 23:15:28.574
2596	13	1	13.2402345	77.7166971	0.04	2026-11-23 23:15:34.581
2597	13	1	13.2402333	77.7166941	0.04	2026-11-23 23:15:40.598
2598	13	1	13.2402319	77.7166918	0.03	2026-11-23 23:15:46.613
2599	13	1	13.2402323	77.7166897	0.04	2026-11-23 23:15:52.628
2600	13	1	13.2402317	77.7166881	0.03	2026-11-23 23:15:57.603
2601	13	1	13.2402269	77.7166831	0.04	2026-11-23 23:16:03.619
2602	13	1	13.2402248	77.7166803	0.03	2026-11-23 23:16:09.635
2603	13	1	13.2402231	77.7166781	0.05	2026-11-23 23:16:14.61
2604	13	1	13.2402157	77.7166729	0.03	2026-11-23 23:16:20.626
2605	13	1	13.2402104	77.7166687	0.03	2026-11-23 23:16:25.6
2606	13	1	13.2402054	77.7166683	0.07	2026-11-23 23:16:31.616
2607	13	1	13.2402019	77.7166677	0.02	2026-11-23 23:16:36.591
2608	13	1	13.2401973	77.7166705	0.03	2026-11-23 23:16:42.607
2609	13	1	13.2401920	77.7166747	0.03	2026-11-23 23:16:47.58
2610	13	1	13.2401904	77.7166765	0.03	2026-11-23 23:16:52.672
2611	13	1	13.2401890	77.7166786	0.03	2026-11-23 23:16:57.646
2612	13	1	13.2401819	77.7166792	0.03	2026-11-23 23:17:03.662
2613	13	1	13.2401682	77.7166811	0.06	2026-11-23 23:17:09.573
2614	13	1	13.2401613	77.7166866	0.04	2026-11-23 23:17:14.652
2615	13	1	13.2401579	77.7166933	0.04	2026-11-23 23:17:20.572
2616	13	1	13.2401510	77.7167085	0.08	2026-11-23 23:17:25.642
2617	13	1	13.2401496	77.7167142	0.03	2026-11-23 23:17:31.659
2618	13	1	13.2400965	77.7167957	0.03	2026-11-23 23:17:36.634
2619	13	1	13.2400928	77.7167979	0.03	2026-11-23 23:17:42.65
2620	13	1	13.2400919	77.7167967	0.02	2026-11-23 23:17:48.665
2621	13	1	13.2400910	77.7167966	0.04	2026-11-23 23:17:54.68
2622	13	1	13.2400908	77.7167968	0.04	2026-11-23 23:18:00.581
2623	13	1	13.2400909	77.7167960	0.03	2026-11-23 23:18:05.671
2624	13	1	13.2400922	77.7167939	0.03	2026-11-23 23:18:11.574
2625	13	1	13.2400937	77.7167918	0.04	2026-11-23 23:18:16.662
2626	13	1	13.2400951	77.7167895	0.03	2026-11-23 23:18:21.637
2627	13	1	13.2400975	77.7167869	0.03	2026-11-23 23:18:27.653
2628	13	1	13.2401034	77.7167742	0.04	2026-11-23 23:18:32.627
2629	13	1	13.2401048	77.7167697	0.04	2026-11-23 23:18:37.601
2630	13	1	13.2401074	77.7167672	0.04	2026-11-23 23:18:43.31
2631	13	1	13.2401084	77.7167666	0.03	2026-11-23 23:18:48.591
2632	13	1	13.2401100	77.7167632	0.04	2026-11-23 23:18:54.608
2633	13	1	13.2401120	77.7167422	0.03	2026-11-23 23:19:00.624
2634	13	1	13.2401203	77.7167312	0.03	2026-11-23 23:19:05.597
2635	13	1	13.2401261	77.7167254	0.04	2026-11-23 23:19:11.613
2636	13	1	13.2401285	77.7167218	0.03	2026-11-23 23:19:16.589
2637	13	1	13.2401300	77.7167160	0.02	2026-11-23 23:19:22.604
2638	13	1	13.2401338	77.7167093	0.04	2026-11-23 23:19:27.578
2639	13	1	13.2401365	77.7167051	0.04	2026-11-23 23:19:32.669
2640	13	1	13.2401400	77.7167011	0.03	2026-11-23 23:19:37.643
2641	13	1	13.2401432	77.7166991	0.03	2026-11-23 23:19:42.619
2642	13	1	13.2401454	77.7166974	0.04	2026-11-23 23:19:48.635
2643	13	1	13.2401533	77.7166976	0.03	2026-11-23 23:19:53.609
2644	13	1	13.2401632	77.7167013	0.05	2026-11-23 23:19:58.583
2645	13	1	13.2401790	77.7167152	0.03	2026-11-23 23:20:04.6
2646	13	1	13.2401817	77.7167190	0.03	2026-11-23 23:20:09.576
2647	13	1	13.2401821	77.7167199	0.03	2026-11-23 23:20:14.663
2648	13	1	13.2401636	77.7168129	0.03	2026-11-23 23:20:20.575
2649	13	1	13.2401636	77.7168125	0.05	2026-11-23 23:20:25.654
2650	13	1	13.2401640	77.7168098	0.03	2026-11-23 23:20:30.629
2651	13	1	13.2401620	77.7168046	0.03	2026-11-23 23:20:36.644
2652	13	1	13.2401553	77.7167999	0.03	2026-11-23 23:20:42.313
2653	13	1	13.2401518	77.7167992	0.03	2026-11-23 23:20:47.636
2654	13	1	13.2401463	77.7168086	0.04	2026-11-23 23:20:53.651
2655	13	1	13.2401476	77.7168208	0.04	2026-11-23 23:20:58.626
2656	13	1	13.2401454	77.7168375	0.05	2026-11-23 23:21:04.642
2657	13	1	13.2401450	77.7168454	0.02	2026-11-23 23:21:10.657
2658	13	1	13.2401467	77.7168540	0.03	2026-11-23 23:21:15.632
2659	13	1	13.2401422	77.7168628	0.04	2026-11-23 23:21:21.648
2660	13	1	13.2401393	77.7168676	0.03	2026-11-23 23:21:26.622
2661	13	1	13.2401382	77.7168690	0.04	2026-11-23 23:21:31.597
2662	13	1	13.2401367	77.7168684	0.04	2026-11-23 23:21:36.574
2663	13	1	13.2401359	77.7168672	0.04	2026-11-23 23:21:41.662
2664	13	1	13.2401342	77.7168644	0.03	2026-11-23 23:21:47.677
2665	13	1	13.2401316	77.7168513	0.05	2026-11-23 23:21:52.652
2666	13	1	13.2401296	77.7168432	0.03	2026-11-23 23:21:58.667
2667	13	1	13.2401293	77.7168396	0.02	2026-11-23 23:22:03.642
2668	13	1	13.2401280	77.7168379	0.04	2026-11-23 23:22:09.657
2669	13	1	13.2401270	77.7168374	0.04	2026-11-23 23:22:14.632
2670	13	1	13.2401274	77.7168380	0.04	2026-11-23 23:22:20.649
2671	13	1	13.2401279	77.7168380	0.04	2026-11-23 23:22:25.623
2672	13	1	13.2401276	77.7168384	0.04	2026-11-23 23:22:30.598
2673	13	1	13.2401277	77.7168385	0.03	2026-11-23 23:22:35.576
2674	13	1	13.2401276	77.7168390	0.04	2026-11-23 23:22:41.241
2675	13	1	13.2401264	77.7168385	0.04	2026-11-23 23:22:46.679
2676	13	1	13.2401190	77.7168355	0.04	2026-11-23 23:22:52.579
2677	13	1	13.2401124	77.7168349	0.03	2026-11-23 23:22:58.58
2678	13	1	13.2401042	77.7168343	0.06	2026-11-23 23:23:04.596
2679	13	1	13.2400927	77.7168395	0.04	2026-11-23 23:23:10.611
2680	13	1	13.2400863	77.7168456	0.04	2026-11-23 23:23:16.626
2681	13	1	13.2400727	77.7168612	0.03	2026-11-23 23:23:22.643
2682	13	1	13.2400712	77.7168681	0.03	2026-11-23 23:23:28.659
2683	13	1	13.2400732	77.7168685	0.03	2026-11-23 23:23:34.674
2684	13	1	13.2400737	77.7168642	0.03	2026-11-23 23:23:40.576
2685	13	1	13.2400722	77.7168617	0.04	2026-11-23 23:23:46.59
2686	13	1	13.2400709	77.7168605	0.03	2026-11-23 23:23:52.605
2687	13	1	13.2400696	77.7168598	0.06	2026-11-23 23:23:58.621
2688	13	1	13.2400683	77.7168597	0.08	2026-11-23 23:24:03.597
2689	13	1	13.2400902	77.7168512	0.02	2026-11-23 23:24:08.573
2690	13	1	13.2400934	77.7168504	0.04	2026-11-23 23:24:14.588
2691	13	1	13.2400971	77.7168496	0.03	2026-11-23 23:24:19.573
2692	13	1	13.2400996	77.7168488	0.04	2026-11-23 23:24:24.652
2693	13	1	13.2401021	77.7168463	0.04	2026-11-23 23:24:29.627
2694	13	1	13.2401019	77.7168411	0.04	2026-11-23 23:24:34.602
2695	13	1	13.2401027	77.7168345	0.03	2026-11-23 23:24:40.271
2696	13	1	13.2401116	77.7167419	0.04	2026-11-23 23:24:45.593
2697	13	1	13.2401107	77.7167392	0.03	2026-11-23 23:24:50.683
2698	13	1	13.2401098	77.7167395	0.03	2026-11-23 23:24:56.583
2699	13	1	13.2401067	77.7167419	0.02	2026-11-23 23:25:02.598
2700	13	1	13.2400945	77.7167604	0.02	2026-11-23 23:25:08.614
2701	13	1	13.2400873	77.7167668	0.04	2026-11-23 23:25:14.631
2702	13	1	13.2400862	77.7167682	0.04	2026-11-23 23:25:19.604
2703	13	1	13.2400860	77.7167715	0.03	2026-11-23 23:25:25.621
2704	13	1	13.2400832	77.7167856	0.04	2026-11-23 23:25:31.637
2705	13	1	13.2400825	77.7167908	0.04	2026-11-23 23:25:36.61
2706	13	1	13.2400838	77.7167958	0.04	2026-11-23 23:25:42.627
2707	13	1	13.2400859	77.7167991	0.03	2026-11-23 23:25:48.643
2708	13	1	13.2400870	77.7168012	0.03	2026-11-23 23:25:53.617
2709	13	1	13.2400879	77.7168024	0.04	2026-11-23 23:25:58.592
2710	13	1	13.2400885	77.7168037	0.05	2026-11-23 23:26:04.608
2711	13	1	13.2400884	77.7168042	0.04	2026-11-23 23:26:09.93
2712	13	1	13.2400882	77.7168052	0.04	2026-11-23 23:26:15.598
2713	13	1	13.2400871	77.7168061	0.03	2026-11-23 23:26:20.576
2714	13	1	13.2400929	77.7168071	0.03	2026-11-23 23:26:26.589
2715	13	1	13.2401034	77.7168099	0.04	2026-11-23 23:26:31.577
2716	13	1	13.2401094	77.7168122	0.04	2026-11-23 23:26:36.653
2717	13	1	13.2401144	77.7168120	0.04	2026-11-23 23:26:42.67
2718	13	1	13.2401189	77.7168116	0.03	2026-11-23 23:26:48.577
2719	13	1	13.2401223	77.7168109	0.05	2026-11-23 23:26:54.586
2720	13	1	13.2401246	77.7168111	0.04	2026-11-23 23:26:59.907
2721	13	1	13.2401236	77.7168042	0.02	2026-11-23 23:27:05.577
2722	13	1	13.2401251	77.7167980	0.03	2026-11-23 23:27:11.591
2723	13	1	13.2401253	77.7167945	0.03	2026-11-23 23:27:17.608
2724	13	1	13.2401207	77.7167918	0.03	2026-11-23 23:27:22.582
2725	13	1	13.2401170	77.7167909	0.05	2026-11-23 23:27:27.571
2726	13	1	13.2401154	77.7167896	0.03	2026-11-23 23:27:32.647
2727	13	1	13.2399941	77.7173824	\N	2026-11-23 23:28:59.595
2728	13	1	13.2400744	77.7168530	0.03	2026-11-23 23:29:05.57
2729	13	1	13.2400781	77.7168593	0.15	2026-11-23 23:29:10.62
2730	13	1	13.2400766	77.7168578	0.13	2026-11-23 23:29:15.595
2731	13	1	13.2400752	77.7168576	0.12	2026-11-23 23:29:20.584
2732	13	1	13.2400745	77.7168571	0.11	2026-11-23 23:29:25.66
2733	13	1	13.2400754	77.7168553	0.10	2026-11-23 23:29:31.583
2734	13	1	13.2400805	77.7168426	0.07	2026-11-23 23:29:36.652
2735	13	1	13.2400900	77.7168100	0.06	2026-11-23 23:29:41.626
2736	13	1	13.2400906	77.7168063	0.04	2026-11-23 23:29:47.644
2737	13	1	13.2400916	77.7168007	0.04	2026-11-23 23:29:52.617
2738	13	1	13.2400930	77.7167928	0.03	2026-11-23 23:29:58.635
2739	13	1	13.2400969	77.7167863	0.03	2026-11-23 23:30:04.651
2740	13	1	13.2400982	77.7167819	0.04	2026-11-23 23:30:09.624
2741	13	1	13.2400987	77.7167785	0.04	2026-11-23 23:30:15.64
2742	13	1	13.2400994	77.7167758	0.04	2026-11-23 23:30:20.615
2743	13	1	13.2400994	77.7167730	0.04	2026-11-23 23:30:26.632
2744	13	1	13.2401002	77.7167721	0.04	2026-11-23 23:30:32.648
2745	13	1	13.2401004	77.7167712	0.04	2026-11-23 23:30:38.664
2746	13	1	13.2401045	77.7167648	0.04	2026-11-23 23:30:43.639
2747	13	1	13.2401102	77.7167547	0.03	2026-11-23 23:30:48.96
2748	13	1	13.2401130	77.7167514	0.05	2026-11-23 23:30:54.628
2749	13	1	13.2401093	77.7167636	0.02	2026-11-23 23:31:00.645
2750	13	1	13.2401055	77.7167749	0.04	2026-11-23 23:31:06.661
2751	13	1	13.2401031	77.7167779	0.03	2026-11-23 23:31:12.584
2752	13	1	13.2401044	77.7167854	0.03	2026-11-23 23:31:17.652
2753	13	1	13.2401104	77.7167926	0.04	2026-11-23 23:31:23.668
2754	13	1	13.2401239	77.7167904	0.04	2026-11-23 23:31:29.584
2755	13	1	13.2401355	77.7167935	0.04	2026-11-23 23:31:35.584
2756	13	1	13.2401418	77.7167965	0.03	2026-11-23 23:31:40.674
2757	13	1	13.2401455	77.7167999	0.03	2026-11-23 23:31:45.65
2758	13	1	13.2401483	77.7168023	0.02	2026-11-23 23:31:51.666
2759	13	1	13.2401496	77.7168028	0.03	2026-11-23 23:31:57.584
2760	13	1	13.2401495	77.7168037	0.05	2026-11-23 23:32:02.656
2761	13	1	13.2401497	77.7168191	0.04	2026-11-23 23:32:08.095
2762	13	1	13.2401477	77.7168358	0.02	2026-11-23 23:32:13.647
2763	13	1	13.2401409	77.7168502	0.03	2026-11-23 23:32:18.623
2764	13	1	13.2401327	77.7168554	0.03	2026-11-23 23:32:23.597
2765	13	1	13.2401253	77.7168622	0.04	2026-11-23 23:32:28.584
2766	13	1	13.2401259	77.7168640	0.04	2026-11-23 23:32:34.588
2767	13	1	13.2401376	77.7168665	0.03	2026-11-23 23:32:39.679
2768	13	1	13.2401497	77.7168695	0.04	2026-11-23 23:32:45.584
2769	13	1	13.2401596	77.7168683	0.04	2026-11-23 23:32:51.595
2770	13	1	13.2401648	77.7168639	0.03	2026-11-23 23:32:57.611
2771	13	1	13.2401690	77.7168699	0.03	2026-11-23 23:33:03.626
2772	13	1	13.2401715	77.7168727	0.03	2026-11-23 23:33:08.602
2773	13	1	13.2401746	77.7168742	0.04	2026-11-23 23:33:14.618
2774	13	1	13.2401755	77.7168751	0.03	2026-11-23 23:33:20.633
2775	13	1	13.2401716	77.7168778	0.04	2026-11-23 23:33:26.65
2776	13	1	13.2401687	77.7168792	0.04	2026-11-23 23:33:31.625
2777	13	1	13.2401664	77.7168803	0.04	2026-11-23 23:33:37.293
2778	13	1	13.2401633	77.7168825	0.03	2026-11-23 23:33:42.615
2779	13	1	13.2401528	77.7168888	0.04	2026-11-23 23:33:47.59
2780	13	1	13.2401487	77.7168928	0.03	2026-11-23 23:33:52.679
2781	13	1	13.2401432	77.7168964	0.03	2026-11-23 23:33:58.583
2782	13	1	13.2401348	77.7169032	0.04	2026-11-23 23:34:03.671
2783	13	1	13.2401291	77.7169082	0.03	2026-11-23 23:34:09.584
2784	13	1	13.2401279	77.7169094	0.03	2026-11-23 23:34:14.66
2785	13	1	13.2401269	77.7169106	0.03	2026-11-23 23:34:20.676
2786	13	1	13.2401251	77.7169139	0.04	2026-11-23 23:34:26.584
2787	13	1	13.2401220	77.7169162	0.03	2026-11-23 23:34:31.667
2788	13	1	13.2401119	77.7169180	0.04	2026-11-23 23:34:36.642
2789	13	1	13.2400998	77.7169280	0.07	2026-11-23 23:34:41.617
2790	13	1	13.2400951	77.7169328	0.04	2026-11-23 23:34:46.823
2791	13	1	13.2400663	77.7170273	0.03	2026-11-23 23:34:52.607
2792	13	1	13.2400606	77.7170401	0.03	2026-11-23 23:34:58.624
2793	13	1	13.2400588	77.7170378	0.03	2026-11-23 23:35:03.598
2794	13	1	13.2400584	77.7170365	0.03	2026-11-23 23:35:08.584
2795	13	1	13.2400575	77.7170354	0.04	2026-11-23 23:35:14.588
2796	13	1	13.2400574	77.7170345	0.03	2026-11-23 23:35:19.678
2797	13	1	13.2400576	77.7170371	0.03	2026-11-23 23:35:25.583
2798	13	1	13.2400592	77.7170332	0.03	2026-11-23 23:35:31.595
2799	13	1	13.2400650	77.7170274	0.03	2026-11-23 23:35:36.584
2800	13	1	13.2400707	77.7170269	0.03	2026-11-23 23:35:42.585
2801	13	1	13.2400736	77.7170268	0.03	2026-11-23 23:35:48.601
2802	13	1	13.2400714	77.7170318	0.05	2026-11-23 23:35:53.583
2803	13	1	13.2400636	77.7170379	0.03	2026-11-23 23:35:58.667
2804	13	1	13.2400598	77.7170441	0.03	2026-11-23 23:36:04.682
2805	13	1	13.2400580	77.7170488	0.03	2026-11-23 23:36:10.584
2806	13	1	13.2400542	77.7170583	0.07	2026-11-23 23:36:15.674
2807	13	1	13.2400416	77.7170669	0.04	2026-11-23 23:36:20.648
2808	13	1	13.2400287	77.7170716	0.04	2026-11-23 23:36:26.317
2809	13	1	13.2400237	77.7170725	0.04	2026-11-23 23:36:31.639
2810	13	1	13.2400178	77.7170761	0.03	2026-11-23 23:36:36.613
2811	13	1	13.2400109	77.7170807	0.04	2026-11-23 23:36:42.629
2812	13	1	13.2400093	77.7170830	0.04	2026-11-23 23:36:47.604
2813	13	1	13.2400101	77.7170774	0.05	2026-11-23 23:36:53.62
2814	13	1	13.2400067	77.7170666	0.03	2026-11-23 23:36:59.635
2815	13	1	13.2400121	77.7170602	0.03	2026-11-23 23:37:05.652
2816	13	1	13.2400163	77.7170558	0.04	2026-11-23 23:37:10.627
2817	13	1	13.2400188	77.7170508	0.03	2026-11-23 23:37:15.833
2818	13	1	13.2400207	77.7170466	0.09	2026-11-23 23:37:21.616
2819	13	1	13.2400125	77.7170277	0.03	2026-11-23 23:37:27.633
2820	13	1	13.2400109	77.7170222	0.03	2026-11-23 23:37:33.649
2821	13	1	13.2400088	77.7170202	0.04	2026-11-23 23:37:39.665
2822	13	1	13.2400108	77.7170210	0.03	2026-11-23 23:37:44.64
2823	13	1	13.2400136	77.7170209	0.04	2026-11-23 23:37:49.615
2824	13	1	13.2400217	77.7170209	0.03	2026-11-23 23:37:55.631
2825	13	1	13.2400287	77.7170152	0.03	2026-11-23 23:38:00.605
2826	13	1	13.2400347	77.7170112	0.03	2026-11-23 23:38:05.812
2827	13	1	13.2400366	77.7170098	0.03	2026-11-23 23:38:11.596
2828	13	1	13.2400377	77.7170093	0.06	2026-11-23 23:38:16.583
2829	13	1	13.2400385	77.7170113	0.03	2026-11-23 23:38:22.587
2830	13	1	13.2400339	77.7170209	0.03	2026-11-23 23:38:28.603
2831	13	1	13.2400296	77.7170245	0.03	2026-11-23 23:38:34.618
2832	13	1	13.2400277	77.7170256	0.03	2026-11-23 23:38:39.592
2833	13	1	13.2400262	77.7170262	0.04	2026-11-23 23:38:44.584
2834	13	1	13.2400212	77.7170316	0.03	2026-11-23 23:38:50.584
2835	13	1	13.2400167	77.7170359	0.04	2026-11-23 23:38:56.599
2836	13	1	13.2400147	77.7170366	0.04	2026-11-23 23:39:01.584
2837	13	1	13.2400135	77.7170374	0.03	2026-11-23 23:39:06.665
2838	13	1	13.2400118	77.7170400	0.03	2026-11-23 23:39:12.583
2839	13	1	13.2400109	77.7170431	0.04	2026-11-23 23:39:18.584
2840	13	1	13.2400108	77.7170446	0.04	2026-11-23 23:39:23.67
2841	13	1	13.2400111	77.7170456	0.04	2026-11-23 23:39:29.584
2842	13	1	13.2400112	77.7170464	0.03	2026-11-23 23:39:35.009
2843	13	1	13.2400120	77.7170470	0.04	2026-11-23 23:39:40.583
2844	13	1	13.2400119	77.7170475	0.05	2026-11-23 23:39:45.651
2845	13	1	13.2400113	77.7170478	0.03	2026-11-23 23:39:50.627
2846	13	1	13.2400106	77.7170480	0.04	2026-11-23 23:39:55.601
2847	13	1	13.2400570	77.7169675	0.04	2026-11-23 23:40:00.584
2848	13	1	13.2400572	77.7169624	0.03	2026-11-23 23:40:05.666
2849	13	1	13.2400557	77.7169597	0.03	2026-11-23 23:40:11.583
2850	13	1	13.2400588	77.7169543	0.03	2026-11-23 23:40:16.657
2851	13	1	13.2400647	77.7169441	0.03	2026-11-23 23:40:22.673
2852	13	1	13.2400699	77.7169352	0.03	2026-11-23 23:40:27.647
2853	13	1	13.2400781	77.7169253	0.03	2026-11-23 23:40:33.663
2854	13	1	13.2400839	77.7169204	0.06	2026-11-23 23:40:38.637
2855	13	1	13.2400970	77.7169070	0.03	2026-11-23 23:40:44.408
2856	13	1	13.2400921	77.7168890	0.03	2026-11-23 23:40:49.614
2857	13	1	13.2400979	77.7168757	0.03	2026-11-23 23:40:54.588
2858	13	1	13.2401050	77.7168719	0.04	2026-11-23 23:40:59.679
2859	13	1	13.2401126	77.7168696	0.03	2026-11-23 23:41:04.653
2860	13	1	13.2401172	77.7168670	0.04	2026-11-23 23:41:10.669
2861	13	1	13.2401241	77.7168564	0.03	2026-11-23 23:41:15.643
2862	13	1	13.2401285	77.7168474	0.03	2026-11-23 23:41:21.66
2863	13	1	13.2401318	77.7168455	0.06	2026-11-23 23:41:26.634
2864	13	1	13.2401343	77.7168472	0.03	2026-11-23 23:41:32.65
2865	13	1	13.2401381	77.7168544	0.03	2026-11-23 23:41:38.665
2866	13	1	13.2401402	77.7168671	0.03	2026-11-23 23:41:43.871
2867	13	1	13.2401061	77.7169585	0.03	2026-11-23 23:41:49.656
2868	13	1	13.2401065	77.7169682	0.03	2026-11-23 23:41:55.673
2869	13	1	13.2401099	77.7169803	0.04	2026-11-23 23:42:01.584
2870	13	1	13.2401135	77.7169846	0.03	2026-11-23 23:42:07.589
2871	13	1	13.2401138	77.7169822	0.03	2026-11-23 23:42:13.605
2872	13	1	13.2401106	77.7169763	0.03	2026-11-23 23:42:19.62
2873	13	1	13.2401081	77.7169732	0.03	2026-11-23 23:42:24.595
2874	13	1	13.2401059	77.7169705	0.03	2026-11-23 23:42:30.61
2875	13	1	13.2401051	77.7169690	0.03	2026-11-23 23:42:35.585
2876	13	1	13.2401039	77.7169680	0.03	2026-11-23 23:42:40.675
2877	13	1	13.2401023	77.7169692	0.04	2026-11-23 23:42:46.584
2878	13	1	13.2400989	77.7169720	0.07	2026-11-23 23:42:51.667
2879	13	1	13.2400810	77.7169872	0.04	2026-11-23 23:42:56.64
2880	13	1	13.2400744	77.7169898	0.03	2026-11-23 23:43:01.615
2881	13	1	13.2400712	77.7169944	0.06	2026-11-23 23:43:07.632
2882	13	1	13.2400720	77.7169968	0.03	2026-11-23 23:43:13.417
2883	13	1	13.2400773	77.7169935	0.03	2026-11-23 23:43:18.623
2884	13	1	13.2400844	77.7169888	0.03	2026-11-23 23:43:24.637
2885	13	1	13.2400920	77.7169744	0.03	2026-11-23 23:43:30.654
2886	13	1	13.2400976	77.7169651	0.03	2026-11-23 23:43:36.669
2887	13	1	13.2401037	77.7169577	0.03	2026-11-23 23:43:42.583
2888	13	1	13.2401065	77.7169530	0.03	2026-11-23 23:43:47.661
2889	13	1	13.2401078	77.7169489	0.04	2026-11-23 23:43:52.634
2890	13	1	13.2401083	77.7169462	0.03	2026-11-23 23:43:57.61
2891	13	1	13.2401087	77.7169435	0.04	2026-11-23 23:44:02.932
2892	13	1	13.2401089	77.7169419	0.03	2026-11-23 23:44:08.6
2893	13	1	13.2401087	77.7169405	0.04	2026-11-23 23:44:13.583
2894	13	1	13.2401084	77.7169397	0.04	2026-11-23 23:44:19.59
2895	13	1	13.2401085	77.7169397	0.04	2026-11-23 23:44:24.584
2896	13	1	13.2401080	77.7169345	0.03	2026-11-23 23:44:29.656
2897	13	1	13.2401116	77.7169240	0.02	2026-11-23 23:44:34.63
2898	13	1	13.2401173	77.7169191	0.03	2026-11-23 23:44:40.646
2899	13	1	13.2401212	77.7169171	0.04	2026-11-23 23:44:46.662
2900	13	1	13.2401210	77.7169146	0.04	2026-11-23 23:44:52.447
2901	13	1	13.2401187	77.7169089	0.03	2026-11-23 23:44:57.652
2902	13	1	13.2400996	77.7168910	0.06	2026-11-23 23:45:03.668
2903	13	1	13.2400859	77.7168739	0.03	2026-11-23 23:45:08.643
2904	13	1	13.2400837	77.7168632	0.03	2026-11-23 23:45:13.618
2905	13	1	13.2400794	77.7168551	0.04	2026-11-23 23:45:19.633
2906	13	1	13.2400757	77.7168520	0.04	2026-11-23 23:45:24.608
2907	13	1	13.2400697	77.7168591	0.03	2026-11-23 23:45:30.624
2908	13	1	13.2400680	77.7168683	0.03	2026-11-23 23:45:36.64
2909	13	1	13.2400685	77.7168705	0.03	2026-11-23 23:45:41.615
2910	13	1	13.2400719	77.7168695	0.03	2026-11-23 23:45:46.589
2911	13	1	13.2400743	77.7168688	0.03	2026-11-23 23:45:51.679
2912	13	1	13.2400755	77.7168715	0.03	2026-11-23 23:45:56.885
2913	13	1	13.2400720	77.7168784	0.03	2026-11-23 23:46:02.67
2914	13	1	13.2400684	77.7168838	0.03	2026-11-23 23:46:07.644
2915	13	1	13.2400648	77.7168939	0.03	2026-11-23 23:46:13.66
2916	13	1	13.2400629	77.7169003	0.03	2026-11-23 23:46:18.635
2917	13	1	13.2400613	77.7169025	0.04	2026-11-23 23:46:24.65
2918	13	1	13.2400588	77.7169047	0.04	2026-11-23 23:46:30.666
2919	13	1	13.2400559	77.7169072	0.04	2026-11-23 23:46:35.641
2920	13	1	13.2400534	77.7169083	0.03	2026-11-23 23:46:40.616
2921	13	1	13.2400520	77.7169094	0.04	2026-11-23 23:46:45.59
2922	13	1	13.2400540	77.7169227	0.03	2026-11-23 23:46:51.605
2923	13	1	13.2400621	77.7169353	0.04	2026-11-23 23:46:57.621
2924	13	1	13.2400640	77.7169520	0.03	2026-11-23 23:47:03.638
2925	13	1	13.2400640	77.7169632	0.05	2026-11-23 23:47:09.653
2926	13	1	13.2400576	77.7169839	0.03	2026-11-23 23:47:14.627
2927	13	1	13.2400510	77.7169976	0.04	2026-11-23 23:47:20.643
2928	13	1	13.2400498	77.7170001	0.03	2026-11-23 23:47:26.082
2929	13	1	13.2400487	77.7170017	0.03	2026-11-23 23:47:31.635
2930	13	1	13.2400420	77.7170083	0.05	2026-11-23 23:47:36.608
2931	13	1	13.2400372	77.7170037	0.09	2026-11-23 23:47:42.625
2932	13	1	13.2400619	77.7168970	0.03	2026-11-23 23:47:47.6
2933	13	1	13.2400728	77.7169017	0.03	2026-11-23 23:47:53.616
2934	13	1	13.2400864	77.7169051	0.03	2026-11-23 23:47:58.591
2935	13	1	13.2400872	77.7169047	0.06	2026-11-23 23:48:03.584
2936	13	1	13.2400877	77.7169038	0.09	2026-11-23 23:48:09.583
2937	13	1	13.2400948	77.7169044	0.05	2026-11-23 23:48:15.597
2938	13	1	13.2401008	77.7169030	0.04	2026-11-23 23:48:20.687
2939	13	1	13.2401105	77.7168942	0.04	2026-11-23 23:48:26.587
2940	13	1	13.2401219	77.7168708	0.04	2026-11-23 23:48:32.604
2941	13	1	13.2401258	77.7168518	0.03	2026-11-23 23:48:38.619
2942	13	1	13.2401260	77.7168395	0.07	2026-11-23 23:48:43.594
2943	13	1	13.2401505	77.7167138	0.03	2026-11-23 23:48:48.584
2944	13	1	13.2401549	77.7167033	0.03	2026-11-23 23:48:54.584
2945	13	1	13.2401573	77.7166997	0.03	2026-11-23 23:48:59.675
2946	13	1	13.2401585	77.7166973	0.03	2026-11-23 23:49:05.227
2947	13	1	13.2401592	77.7166949	0.03	2026-11-23 23:49:10.665
2948	13	1	13.2401599	77.7166999	0.06	2026-11-23 23:49:15.64
2949	13	1	13.2401612	77.7167157	0.03	2026-11-23 23:49:20.613
2950	13	1	13.2401610	77.7167327	0.03	2026-11-23 23:49:25.589
2951	13	1	13.2401557	77.7167467	0.04	2026-11-23 23:49:31.605
2952	13	1	13.2401595	77.7167601	0.03	2026-11-23 23:49:37.621
2953	13	1	13.2401662	77.7167660	0.03	2026-11-23 23:49:43.637
2954	13	1	13.2401695	77.7167694	0.03	2026-11-23 23:49:48.61
2955	13	1	13.2401733	77.7167687	0.03	2026-11-23 23:49:53.586
2956	13	1	13.2401756	77.7167676	0.03	2026-11-23 23:49:59.602
2957	13	1	13.2401764	77.7167666	0.03	2026-11-23 23:50:04.583
2958	13	1	13.2401789	77.7167654	0.03	2026-11-23 23:50:10.592
2959	13	1	13.2401898	77.7167460	0.04	2026-11-23 23:50:15.584
2960	13	1	13.2401945	77.7167360	0.03	2026-11-23 23:50:20.657
2961	13	1	13.2401973	77.7167298	0.03	2026-11-23 23:50:25.616
2962	13	1	13.2402008	77.7167226	0.02	2026-11-23 23:50:30.591
2963	13	1	13.2402048	77.7167138	0.04	2026-11-23 23:50:36.608
2964	13	1	13.2402087	77.7167044	0.03	2026-11-23 23:50:41.584
2965	13	1	13.2402110	77.7166973	0.03	2026-11-23 23:50:47.597
2966	13	1	13.2402106	77.7166905	0.06	2026-11-23 23:50:53.614
2967	13	1	13.2402133	77.7166788	0.03	2026-11-23 23:50:58.589
2968	13	1	13.2402146	77.7166718	0.06	2026-11-23 23:51:04.256
2969	13	1	13.2402148	77.7166660	0.03	2026-11-23 23:51:09.584
2970	13	1	13.2402138	77.7166604	0.06	2026-11-23 23:51:14.669
2971	13	1	13.2402132	77.7166584	0.03	2026-11-23 23:51:19.644
2972	13	1	13.2402122	77.7166562	0.06	2026-11-23 23:51:25.66
2973	13	1	13.2402094	77.7166577	0.03	2026-11-23 23:51:31.674
2974	13	1	13.2402073	77.7166607	0.03	2026-11-23 23:51:36.65
2975	13	1	13.2402059	77.7166619	0.06	2026-11-23 23:51:42.666
2976	13	1	13.2402036	77.7166662	0.04	2026-11-23 23:51:47.64
2977	13	1	13.2401761	77.7167815	0.03	2026-11-23 23:51:53.656
2978	13	1	13.2401737	77.7167914	0.03	2026-11-23 23:51:58.63
2979	13	1	13.2401735	77.7167981	0.06	2026-11-23 23:52:03.721
2980	13	1	13.2401725	77.7168029	0.03	2026-11-23 23:52:09.621
2981	13	1	13.2401720	77.7168055	0.04	2026-11-23 23:52:14.595
2982	13	1	13.2401702	77.7168099	0.05	2026-11-23 23:52:20.611
2983	13	1	13.2401650	77.7168217	0.02	2026-11-23 23:52:25.586
2984	13	1	13.2401567	77.7168564	0.06	2026-11-23 23:52:31.602
2985	13	1	13.2401531	77.7168642	0.05	2026-11-23 23:52:37.618
2986	13	1	13.2401498	77.7168697	0.04	2026-11-23 23:52:42.591
2987	13	1	13.2401032	77.7170048	0.05	2026-11-23 23:52:48.608
2988	13	1	13.2400941	77.7170313	0.02	2026-11-23 23:52:54.623
2989	13	1	13.2400994	77.7170216	0.05	2026-11-23 23:53:00.64
2990	13	1	13.2401036	77.7170184	0.03	2026-11-23 23:53:06.654
2991	13	1	13.2401435	77.7169318	0.04	2026-11-23 23:53:11.63
2992	13	1	13.2401525	77.7169311	0.05	2026-11-23 23:53:17.646
2993	13	1	13.2401570	77.7169373	0.08	2026-11-23 23:53:22.967
2994	13	1	13.2401684	77.7169487	0.14	2026-11-23 23:53:28.635
2995	13	1	13.2401783	77.7169683	0.18	2026-11-23 23:53:33.611
2996	13	1	13.2401735	77.7170115	0.03	2026-11-23 23:53:39.626
2997	13	1	13.2401729	77.7170167	0.06	2026-11-23 23:53:44.6
2998	13	1	13.2401634	77.7170356	0.03	2026-11-23 23:53:50.616
2999	13	1	13.2401498	77.7170420	0.04	2026-11-23 23:53:55.592
3000	13	1	13.2401407	77.7170464	0.10	2026-11-23 23:54:00.583
3001	13	1	13.2401140	77.7170535	0.06	2026-11-23 23:54:06.583
3002	13	1	13.2400966	77.7170736	0.03	2026-11-23 23:54:12.481
3003	13	1	13.2400908	77.7170787	0.03	2026-11-23 23:54:17.584
3004	13	1	13.2400863	77.7170824	0.03	2026-11-23 23:54:23.587
3005	13	1	13.2400900	77.7170932	0.03	2026-11-23 23:54:28.677
3006	13	1	13.2400923	77.7171037	0.03	2026-11-23 23:54:34.583
3007	13	1	13.2400936	77.7171129	0.05	2026-11-23 23:54:40.594
3008	13	1	13.2400912	77.7171217	0.02	2026-11-23 23:54:45.584
3009	13	1	13.2400886	77.7171253	0.04	2026-11-23 23:54:50.658
3010	13	1	13.2400867	77.7171252	0.04	2026-11-23 23:54:56.675
3011	13	1	13.2400843	77.7171237	0.04	2026-11-23 23:55:01.997
3012	13	1	13.2400866	77.7171108	0.02	2026-11-23 23:55:07.665
3013	13	1	13.2400895	77.7170831	0.04	2026-11-23 23:55:13.681
3014	13	1	13.2400946	77.7170716	0.04	2026-11-23 23:55:19.584
3015	13	1	13.2400964	77.7170617	0.03	2026-11-23 23:55:24.67
3016	13	1	13.2400980	77.7170571	0.07	2026-11-23 23:55:33.652
3017	13	1	13.2401047	77.7170437	0.06	2026-11-23 23:55:43.531
3018	13	1	13.2400881	77.7170388	0.23	2026-11-23 23:55:51.572
3019	13	1	13.2400860	77.7170283	0.15	2026-11-23 23:55:56.622
3020	13	1	13.2400881	77.7169984	0.12	2026-11-23 23:56:01.596
3021	13	1	13.2400882	77.7170066	0.17	2026-11-23 23:56:07.612
3022	13	1	13.2400874	77.7170144	0.17	2026-11-23 23:56:12.588
3023	13	1	13.2400851	77.7170235	0.19	2026-11-23 23:56:17.677
3024	13	1	13.2400929	77.7169930	0.21	2026-11-23 23:56:23.463
3025	13	1	13.2401297	77.7169386	0.06	2026-11-23 23:56:28.668
3026	13	1	13.2401213	77.7169087	0.03	2026-11-23 23:56:34.573
3027	13	1	13.2401216	77.7168988	0.05	2026-11-23 23:56:39.66
3028	13	1	13.2401384	77.7168882	0.04	2026-11-23 23:56:45.676
3029	13	1	13.2401455	77.7168837	0.04	2026-11-23 23:56:50.65
3030	13	1	13.2401487	77.7168811	0.04	2026-11-23 23:56:55.624
3031	13	1	13.2401566	77.7168676	0.04	2026-11-23 23:57:00.599
3032	13	1	13.2401594	77.7168607	0.04	2026-11-23 23:57:05.576
3033	13	1	13.2401604	77.7168597	0.03	2026-11-23 23:57:11.59
3034	13	1	13.2401612	77.7168605	0.04	2026-11-23 23:57:16.576
3035	13	1	13.2401617	77.7168603	0.03	2026-11-23 23:57:21.655
3036	13	1	13.2401642	77.7168678	0.03	2026-11-23 23:57:26.63
3037	13	1	13.2401653	77.7168753	0.03	2026-11-23 23:57:32.645
3038	13	1	13.2401596	77.7168839	0.04	2026-11-23 23:57:38.661
3039	13	1	13.2401564	77.7168907	0.04	2026-11-23 23:57:43.636
3040	13	1	13.2401559	77.7168937	0.04	2026-11-23 23:57:48.611
3041	13	1	13.2401548	77.7168967	0.05	2026-11-23 23:57:53.586
3042	13	1	13.2401473	77.7169100	0.06	2026-11-23 23:57:59.602
3043	13	1	13.2401433	77.7169238	0.03	2026-11-23 23:58:05.617
3044	13	1	13.2401471	77.7169328	0.02	2026-11-23 23:58:10.593
3045	13	1	13.2401500	77.7169358	0.04	2026-11-23 23:58:16.61
3046	13	1	13.2401519	77.7169377	0.03	2026-11-23 23:58:22.626
3047	13	1	13.2401533	77.7169394	0.03	2026-11-23 23:58:27.6
3048	13	1	13.2401545	77.7169393	0.08	2026-11-23 23:58:33.616
3049	13	1	13.2401660	77.7169370	0.03	2026-11-23 23:58:39.632
3050	13	1	13.2401776	77.7169297	0.03	2026-11-23 23:58:44.607
3051	13	1	13.2401909	77.7169266	0.03	2026-11-23 23:58:49.582
3052	13	1	13.2402118	77.7169217	0.04	2026-11-23 23:58:55.599
3053	13	1	13.2402271	77.7169111	0.09	2026-11-23 23:59:00.578
3054	13	1	13.2403152	77.7168516	0.03	2026-11-23 23:59:06.59
3055	13	1	13.2403305	77.7168419	0.03	2026-11-23 23:59:11.578
3056	13	1	13.2403327	77.7168389	0.06	2026-11-23 23:59:18.621
3057	13	1	13.2403325	77.7168340	0.12	2026-11-23 23:59:23.596
3058	13	1	13.2403279	77.7168114	0.15	2026-11-23 23:59:29.612
3059	13	1	13.2402890	77.7167619	0.03	2026-11-23 23:59:34.587
3060	13	1	13.2402822	77.7167549	0.03	2026-11-23 23:59:40.603
3061	13	1	13.2402757	77.7167463	0.03	2026-11-23 23:59:46.619
3062	13	1	13.2402705	77.7167409	0.04	2026-11-23 23:59:51.593
3063	13	1	13.2402669	77.7167384	0.04	2026-11-23 23:59:57.609
3064	13	1	13.2402600	77.7167425	0.03	2026-11-24 00:00:02.584
3065	13	1	13.2402451	77.7167572	0.03	2026-11-24 00:00:08.599
3066	13	1	13.2402378	77.7167642	0.08	2026-11-24 00:00:14.616
3067	13	1	13.2402391	77.7167846	0.04	2026-11-24 00:00:19.591
3068	13	1	13.2402414	77.7167968	0.04	2026-11-24 00:00:24.681
3069	13	1	13.2402379	77.7168081	0.04	2026-11-24 00:00:30.582
3070	13	1	13.2402384	77.7168175	0.04	2026-11-24 00:00:36.597
3071	13	1	13.2402377	77.7168253	0.03	2026-11-24 00:00:42.613
3072	13	1	13.2402382	77.7168294	0.05	2026-11-24 00:00:47.588
3073	13	1	13.2402393	77.7168327	0.04	2026-11-24 00:00:52.678
3074	13	1	13.2402374	77.7168350	0.04	2026-11-24 00:00:57.653
3075	13	1	13.2402206	77.7168322	0.07	2026-11-24 00:01:03.668
3076	13	1	13.2402080	77.7168282	0.04	2026-11-24 00:01:08.643
3077	13	1	13.2402039	77.7168293	0.05	2026-11-24 00:01:13.618
3078	13	1	13.2401946	77.7168332	0.04	2026-11-24 00:01:19.634
3079	13	1	13.2401887	77.7168389	0.03	2026-11-24 00:01:24.609
3080	13	1	13.2401839	77.7168424	0.03	2026-11-24 00:01:30.624
3081	13	1	13.2401818	77.7168443	0.03	2026-11-24 00:01:35.599
3082	13	1	13.2401798	77.7168457	0.03	2026-11-24 00:01:41.614
3083	13	1	13.2401787	77.7168467	0.03	2026-11-24 00:01:47.631
3084	13	1	13.2401781	77.7168470	0.04	2026-11-24 00:01:52.605
3085	13	1	13.2401773	77.7168472	0.04	2026-11-24 00:01:57.581
3086	13	1	13.2401769	77.7168475	0.04	2026-11-24 00:02:03.595
3087	13	1	13.2401768	77.7168482	0.03	2026-11-24 00:02:08.576
3088	13	1	13.2401768	77.7168490	0.04	2026-11-24 00:02:14.587
3089	13	1	13.2401773	77.7168498	0.05	2026-11-24 00:02:19.677
3090	13	1	13.2401775	77.7168496	0.04	2026-11-24 00:02:25.579
3091	13	1	13.2401743	77.7168456	0.06	2026-11-24 00:02:31.593
3092	13	1	13.2401494	77.7168159	0.04	2026-11-24 00:02:37.609
3093	13	1	13.2401421	77.7168078	0.03	2026-11-24 00:02:42.583
3094	13	1	13.2401401	77.7167891	0.03	2026-11-24 00:02:48.599
3095	13	1	13.2401807	77.7166784	0.02	2026-11-24 00:02:54.616
3096	13	1	13.2401834	77.7166753	0.04	2026-11-24 00:02:59.589
3097	13	1	13.2401925	77.7166886	0.03	2026-11-24 00:03:05.606
3098	13	1	13.2401986	77.7166998	0.03	2026-11-24 00:03:11.621
3099	13	1	13.2401996	77.7167014	0.03	2026-11-24 00:03:17.638
3100	13	1	13.2402011	77.7167037	0.04	2026-11-24 00:03:23.654
3101	13	1	13.2402058	77.7167086	0.03	2026-11-24 00:03:28.628
3102	13	1	13.2402084	77.7167151	0.04	2026-11-24 00:03:33.603
3103	13	1	13.2402086	77.7167186	0.02	2026-11-24 00:03:39.513
3104	13	1	13.2402086	77.7167192	0.02	2026-11-24 00:03:44.593
3105	13	1	13.2402085	77.7167202	0.03	2026-11-24 00:03:50.608
3106	13	1	13.2402087	77.7167204	0.03	2026-11-24 00:03:55.584
3141	13	1	13.2399689	77.7168203	\N	2026-11-24 09:17:09.237
3142	13	1	13.2399699	77.7168399	\N	2026-11-24 09:17:15.863
3143	13	1	13.2399656	77.7168257	\N	2026-11-24 09:17:29.086
3144	13	1	13.2399619	77.7168250	\N	2026-11-24 09:17:38.967
3145	13	1	13.2399684	77.7168436	\N	2026-11-24 09:17:46.993
3146	13	1	13.2399619	77.7168250	\N	2026-11-24 09:17:58.755
3147	13	1	13.2399864	77.7171198	\N	2026-11-24 09:18:08.598
3148	13	1	13.2404802	77.7160415	\N	2026-11-24 09:18:18.51
3149	13	1	13.2399676	77.7168227	\N	2026-11-24 09:18:28.377
3150	13	1	13.2399676	77.7168227	\N	2026-11-24 09:18:38.256
3151	13	1	13.2401166	77.7168309	\N	2026-11-24 09:18:48.121
3152	13	1	13.2399689	77.7168203	\N	2026-11-24 09:18:58.022
3153	13	1	13.2399686	77.7168214	\N	2026-11-24 09:19:07.936
3154	13	1	13.2399667	77.7168200	\N	2026-11-24 09:19:17.858
3155	13	1	13.2399730	77.7173481	\N	2026-11-24 09:19:27.761
3156	13	1	13.2399689	77.7168203	\N	2026-11-24 09:19:37.681
3157	13	1	13.2399680	77.7168251	\N	2026-11-24 09:19:47.56
3158	13	1	13.2399680	77.7168251	\N	2026-11-24 09:19:52.57
3159	13	1	13.2399689	77.7168203	\N	2026-11-24 09:20:07.764
3160	13	1	13.2399656	77.7168257	\N	2026-11-24 09:20:27.539
3161	13	1	13.2399666	77.7168186	\N	2026-11-24 09:20:37.446
3162	13	1	13.2399680	77.7168251	\N	2026-11-24 09:20:47.353
3163	13	1	13.2399688	77.7168193	\N	2026-11-24 09:20:57.256
3164	13	1	13.2399688	77.7168193	\N	2026-11-24 09:21:07.15
3165	13	1	13.2399688	77.7168193	\N	2026-11-24 09:21:17.047
3166	13	1	13.2399676	77.7168259	\N	2026-11-24 09:21:26.943
3167	13	1	13.2399689	77.7168203	\N	2026-11-24 09:21:36.882
3168	13	1	13.2399680	77.7168251	\N	2026-11-24 09:21:46.744
3169	13	1	13.2399689	77.7168203	\N	2026-11-24 09:21:56.653
3170	13	1	13.2399680	77.7168251	\N	2026-11-24 09:22:06.558
3171	13	1	13.2399732	77.7173575	\N	2026-11-24 09:22:16.435
3172	13	1	13.2399689	77.7168203	\N	2026-11-24 09:22:26.309
3173	13	1	13.2399666	77.7168186	\N	2026-11-24 09:22:36.215
3174	13	1	13.2399656	77.7168257	\N	2026-11-24 09:22:46.132
3175	13	1	13.2399676	77.7168259	\N	2026-11-24 09:22:56.005
3176	13	1	13.2399676	77.7168227	\N	2026-11-24 09:23:05.9
3177	13	1	13.2399680	77.7168251	\N	2026-11-24 09:23:15.806
3178	13	1	13.2399682	77.7168191	\N	2026-11-24 09:23:25.704
3179	13	1	13.2399680	77.7168251	\N	2026-11-24 09:23:35.603
3180	13	1	13.2399681	77.7168245	\N	2026-11-24 09:23:45.467
3181	13	1	13.2399680	77.7168251	\N	2026-11-24 09:23:55.368
3182	13	1	13.2399686	77.7168214	\N	2026-11-24 09:24:05.25
3183	13	1	13.2399686	77.7168214	\N	2026-11-24 09:24:15.168
3184	13	1	13.2399686	77.7168214	\N	2026-11-24 09:24:25.082
3185	13	1	13.2399619	77.7168250	\N	2026-11-24 09:24:35.002
3186	13	1	13.2399686	77.7168214	\N	2026-11-24 09:24:44.939
3187	13	1	13.2399684	77.7168225	\N	2026-11-24 09:24:54.848
3188	13	1	13.2399684	77.7168225	\N	2026-11-24 09:25:04.736
3189	13	1	13.2399684	77.7168225	\N	2026-11-24 09:25:14.649
3190	13	1	13.2399684	77.7168225	\N	2026-11-24 09:25:19.657
3191	13	1	13.2399684	77.7168225	\N	2026-11-24 09:25:34.785
3192	13	1	13.2399656	77.7168257	\N	2026-11-24 09:25:44.663
3193	13	1	13.2399686	77.7168214	\N	2026-11-24 09:25:54.561
3194	13	1	13.2399689	77.7168203	\N	2026-11-24 09:26:04.462
3195	13	1	13.2399676	77.7168259	\N	2026-11-24 09:26:14.385
3196	13	1	13.2399666	77.7168186	\N	2026-11-24 09:26:24.258
3197	13	1	13.2399686	77.7168214	\N	2026-11-24 09:26:34.122
3198	13	1	13.2399711	77.7168358	\N	2026-11-24 09:26:41.525
3199	13	1	13.2399686	77.7168214	\N	2026-11-24 09:26:53.914
3200	13	1	13.2399704	77.7168359	\N	2026-11-24 09:27:03.811
3201	13	1	13.2399686	77.7168214	\N	2026-11-24 09:27:13.707
3202	13	1	13.2399682	77.7168191	\N	2026-11-24 09:27:23.615
3203	13	1	13.2399680	77.7168251	\N	2026-11-24 09:27:33.496
3204	13	1	13.2400108	77.7168100	\N	2026-11-24 09:27:42.66
3205	13	1	13.2400108	77.7168100	\N	2026-11-24 09:27:48.42
3206	13	1	13.2399696	77.7168414	\N	2026-11-24 09:28:02.115
3207	13	1	13.2399709	77.7168336	\N	2026-11-24 09:28:13.475
3208	13	1	13.2399676	77.7168227	\N	2026-11-24 09:28:23.387
3209	13	1	13.2399689	77.7168203	\N	2026-11-24 09:28:33.312
3210	13	1	13.2399689	77.7168203	\N	2026-11-24 09:28:38.321
3211	13	1	13.2399676	77.7168259	\N	2026-11-24 09:28:58.225
3212	13	1	13.2399676	77.7168259	\N	2026-11-24 09:29:08.137
3213	13	1	13.2399676	77.7168227	\N	2026-11-24 09:29:18.033
3214	13	1	13.2400464	77.7167184	\N	2026-11-24 09:29:27.415
3215	13	1	13.2399666	77.7168186	\N	2026-11-24 09:29:37.87
3216	13	1	13.2399680	77.7168251	\N	2026-11-24 09:29:47.754
3217	13	1	13.2399680	77.7168251	\N	2026-11-24 09:29:52.757
3218	13	1	13.2399689	77.7168203	\N	2026-11-24 09:30:07.919
3219	13	1	13.2399680	77.7168251	\N	2026-11-24 09:30:17.779
3220	13	1	13.2399680	77.7168251	\N	2026-11-24 09:30:22.795
3221	13	1	13.2399680	77.7168251	\N	2026-11-24 09:30:37.923
3222	13	1	13.2399680	77.7168251	\N	2026-11-24 09:30:47.788
3223	13	1	13.2399684	77.7168225	\N	2026-11-24 09:30:57.673
3224	13	1	13.2399684	77.7168225	\N	2026-11-24 09:31:02.683
3225	13	1	13.2399689	77.7168203	\N	2026-11-24 09:31:17.826
3226	13	1	13.2399689	77.7168203	\N	2026-11-24 09:31:22.837
3227	13	1	13.2399656	77.7168257	\N	2026-11-24 09:31:33.126
3228	13	1	13.2399680	77.7168251	\N	2026-11-24 09:31:47.966
3229	13	1	13.2399689	77.7168203	\N	2026-11-24 09:31:57.874
3230	13	1	13.2399676	77.7168259	\N	2026-11-24 09:32:07.809
3231	13	1	13.2399676	77.7168227	\N	2026-11-24 09:32:17.753
3232	13	1	13.2399689	77.7168203	\N	2026-11-24 09:32:27.657
3233	13	1	13.2399689	77.7168203	\N	2026-11-24 09:32:37.571
3234	13	1	13.2399688	77.7168193	\N	2026-11-24 09:32:47.42
3235	13	1	13.2399619	77.7168250	\N	2026-11-24 09:32:57.331
3236	13	1	13.2399619	77.7168250	\N	2026-11-24 09:33:02.342
3237	13	1	13.2399656	77.7168257	\N	2026-11-24 09:33:17.476
3238	13	1	13.2399688	77.7168193	\N	2026-11-24 09:33:27.387
3239	13	1	13.2399676	77.7168259	\N	2026-11-24 09:33:37.289
3240	13	1	13.2399710	77.7168348	\N	2026-11-24 09:33:47.208
3241	13	1	13.2399710	77.7168348	\N	2026-11-24 09:33:52.217
3242	13	1	13.2399689	77.7168203	\N	2026-11-24 09:34:02.506
3243	13	1	13.2400389	77.7168549	\N	2026-11-24 09:34:13.012
3244	13	1	13.2399682	77.7168191	\N	2026-11-24 09:34:27.616
3245	13	1	13.2399689	77.7168203	\N	2026-11-24 09:34:37.49
3246	13	1	13.2399689	77.7168203	\N	2026-11-24 09:34:42.499
3247	13	1	13.2399514	77.7168256	\N	2026-11-24 09:34:57.737
3248	13	1	13.2399607	77.7168256	\N	2026-11-24 09:35:07.927
3249	13	1	13.2399607	77.7168256	\N	2026-11-24 09:35:17.869
3250	13	1	13.2399684	77.7168225	\N	2026-11-24 09:35:28.091
3251	13	1	13.2399758	77.7168364	\N	2026-11-24 09:35:38.019
3252	13	1	13.2399758	77.7168363	\N	2026-11-24 09:35:47.893
3253	13	1	13.2399684	77.7168225	\N	2026-11-24 09:35:57.843
3254	13	1	13.2399684	77.7168225	\N	2026-11-24 09:36:02.854
3255	13	1	13.2399648	77.7168422	\N	2026-11-24 09:36:18.106
3256	13	1	13.2399684	77.7168225	\N	2026-11-24 09:36:28.029
3257	13	1	13.2399686	77.7168214	\N	2026-11-24 09:36:37.953
3258	13	1	13.2399686	77.7168214	\N	2026-11-24 09:36:42.963
3259	13	1	13.2399684	77.7168225	\N	2026-11-24 09:36:57.724
3260	13	1	13.2399607	77.7168243	\N	2026-11-24 09:37:06.992
3261	13	1	13.2399682	77.7168252	\N	2026-11-24 09:37:17.55
3262	13	1	13.2399676	77.7168259	\N	2026-11-24 09:37:27.464
3263	13	1	13.2399772	77.7167903	\N	2026-11-24 09:37:37.374
3264	13	1	13.2399703	77.7168400	\N	2026-11-24 09:37:42.933
3265	13	1	13.2399683	77.7168522	\N	2026-11-24 09:37:57.204
3266	13	1	13.2399682	77.7168252	\N	2026-11-24 09:38:07.114
3267	13	1	13.2399657	77.7168478	\N	2026-11-24 09:38:17.013
3268	13	1	13.2399684	77.7168225	\N	2026-11-24 09:38:26.953
3269	13	1	13.2399660	77.7168483	\N	2026-11-24 09:38:36.872
3270	13	1	13.2399682	77.7168191	\N	2026-11-24 09:38:46.803
3271	13	1	13.2399676	77.7168259	\N	2026-11-24 09:38:56.69
3272	13	1	13.2399682	77.7168236	\N	2026-11-24 09:39:06.582
3273	13	1	13.2399686	77.7168214	\N	2026-11-24 09:39:16.497
3274	13	1	13.2399676	77.7168227	\N	2026-11-24 09:39:26.388
3275	13	1	13.2399681	77.7168245	\N	2026-11-24 09:39:36.294
3276	13	1	13.2399685	77.7168262	\N	2026-11-24 09:39:46.187
3277	13	1	13.2399683	77.7168258	\N	2026-11-24 09:39:56.069
3278	13	1	13.2399682	77.7168252	\N	2026-11-24 09:40:06.001
3279	13	1	13.2399682	77.7168252	\N	2026-11-24 09:40:15.908
3280	13	1	13.2399608	77.7168111	\N	2026-11-24 09:40:25.896
3281	13	1	13.2399692	77.7168247	\N	2026-11-24 09:40:36.076
3282	13	1	13.2399683	77.7168258	\N	2026-11-24 09:40:45.95
3283	13	1	13.2399747	77.7168225	\N	2026-11-24 09:40:55.874
3284	13	1	13.2399718	77.7168229	\N	2026-11-24 09:41:05.777
3285	13	1	13.2399718	77.7168229	\N	2026-11-24 09:41:15.705
3286	13	1	13.2399703	77.7168223	\N	2026-11-24 09:41:25.54
3287	13	1	13.2399681	77.7168245	\N	2026-11-24 09:41:35.504
3288	13	1	13.2399888	77.7168284	\N	2026-11-24 09:41:45.382
3289	13	1	13.2399681	77.7168245	\N	2026-11-24 09:41:55.37
3290	13	1	13.2399653	77.7168469	\N	2026-11-24 09:42:05.28
3291	13	1	13.2399653	77.7168469	\N	2026-11-24 09:42:10.284
3292	13	1	13.2399682	77.7168236	\N	2026-11-24 09:42:25.065
3293	13	1	13.2399680	77.7168251	\N	2026-11-24 09:42:34.931
3294	13	1	13.2399683	77.7168258	\N	2026-11-24 09:42:44.871
3295	13	1	13.2399683	77.7168258	\N	2026-11-24 09:42:54.789
3296	13	1	13.2399687	77.7168267	\N	2026-11-24 09:43:04.67
3297	13	1	13.2399682	77.7168252	\N	2026-11-24 09:43:14.562
3298	13	1	13.2399688	77.7168193	\N	2026-11-24 09:43:24.495
3299	13	1	13.2399682	77.7168236	\N	2026-11-24 09:43:34.448
3300	13	1	13.2399685	77.7168262	\N	2026-11-24 09:43:44.365
3301	13	1	13.2399684	77.7168225	\N	2026-11-24 09:43:54.294
3302	13	1	13.2399684	77.7168225	\N	2026-11-24 09:44:04.172
3303	13	1	13.2399684	77.7168225	\N	2026-11-24 09:44:09.179
3304	13	1	13.2399672	77.7168318	\N	2026-11-24 09:51:35.09
3305	13	1	13.2399679	77.7168303	\N	2026-11-24 09:51:42.371
3306	13	1	13.2399671	77.7168252	\N	2026-11-24 09:51:52.679
3307	13	1	13.2399641	77.7168272	\N	2026-11-24 09:52:02.985
3308	13	1	13.2399663	77.7168240	\N	2026-11-24 09:52:18.151
3309	13	1	13.2399647	77.7168294	\N	2026-11-24 09:52:28.084
3310	13	1	13.2399664	77.7168267	\N	2026-11-24 09:52:37.709
3311	13	1	13.2399664	77.7168267	\N	2026-11-24 09:52:43.065
3312	13	1	13.2399671	77.7168226	\N	2026-11-24 09:52:58.087
3313	13	1	13.2399671	77.7168226	\N	2026-11-24 09:53:03.29
3314	13	1	13.2399655	77.7168235	\N	2026-11-24 09:53:18.364
3315	13	1	13.2399657	77.7168258	\N	2026-11-24 09:53:28.295
3316	13	1	13.2399663	77.7168240	\N	2026-11-24 09:53:38.229
3317	13	1	13.2399656	77.7168256	\N	2026-11-24 09:53:48.058
3318	13	1	13.2399686	77.7168339	\N	2026-11-24 09:53:58.095
3319	13	1	13.2399678	77.7168311	\N	2026-11-24 09:54:07.924
3320	13	1	13.2399649	77.7168358	\N	2026-11-24 09:54:17.857
3321	13	1	13.2399649	77.7168358	\N	2026-11-24 09:54:23.014
3322	13	1	13.2399665	77.7168332	\N	2026-11-24 09:54:38.031
3323	13	1	13.2399947	77.7172386	\N	2026-11-24 09:54:48.066
3324	13	1	13.2399693	77.7168325	\N	2026-11-24 09:54:57.999
3325	13	1	13.2399699	77.7168311	\N	2026-11-24 09:55:07.727
3326	13	1	13.2399673	77.7168361	\N	2026-11-24 09:55:17.66
3327	13	1	13.2399669	77.7168284	\N	2026-11-24 09:55:27.797
3328	13	1	13.2399699	77.7168311	\N	2026-11-24 09:55:37.627
3329	13	1	13.2399699	77.7168311	\N	2026-11-24 09:55:42.802
3330	13	1	13.2399678	77.7168311	\N	2026-11-24 09:55:53.083
3331	13	1	13.2399708	77.7173566	\N	2026-11-24 09:56:08.142
3332	13	1	13.2399693	77.7168283	\N	2026-11-24 09:56:17.974
3333	13	1	13.2399693	77.7168283	\N	2026-11-24 09:56:28.007
3334	13	1	13.2399622	77.7168358	\N	2026-11-24 09:56:37.942
3335	13	1	13.2399693	77.7168283	\N	2026-11-24 09:56:47.874
3336	13	1	13.2399693	77.7168283	\N	2026-11-24 09:56:52.967
3337	13	1	13.2399694	77.7168317	\N	2026-11-24 09:57:07.409
3338	13	1	13.2399694	77.7168317	\N	2026-11-24 09:57:12.423
3339	13	1	13.2399699	77.7168310	\N	2026-11-24 09:57:22.69
3340	13	1	13.2399679	77.7167919	\N	2026-11-24 09:57:32.622
3341	13	1	13.2399680	77.7167920	\N	2026-11-24 09:57:42.675
3342	13	1	13.2399711	77.7168281	\N	2026-11-24 09:57:52.284
3343	13	1	13.2399689	77.7168398	\N	2026-11-24 09:58:00.885
3344	13	1	13.2399689	77.7168398	\N	2026-11-24 09:58:07.571
3345	13	1	13.2399651	77.7168443	\N	2026-11-24 09:58:22.595
3346	13	1	13.2399651	77.7168443	\N	2026-11-24 09:58:27.794
3347	13	1	13.2399692	77.7168324	\N	2026-11-24 09:58:42.972
3348	13	1	13.2399706	77.7168296	\N	2026-11-24 09:58:52.7
3349	13	1	13.2399699	77.7168311	\N	2026-11-24 09:59:02.837
3350	13	1	13.2399701	77.7168358	\N	2026-11-24 09:59:12.566
3351	13	1	13.2399737	77.7168147	\N	2026-11-24 09:59:22.704
3352	13	1	13.2399685	77.7168336	\N	2026-11-24 09:59:32.329
3353	13	1	13.2399685	77.7168338	\N	2026-11-24 09:59:42.571
3354	13	1	13.2399568	77.7169027	\N	2026-11-24 09:59:52.399
3355	13	1	13.2399694	77.7168385	\N	2026-11-24 10:00:02.332
3356	13	1	13.2399612	77.7168596	\N	2026-11-24 10:00:12.265
3357	13	1	13.2399685	77.7168460	\N	2026-11-24 10:00:22.198
3358	13	1	13.2399693	77.7168325	\N	2026-11-24 10:00:32.027
3359	13	1	13.2399692	77.7168324	\N	2026-11-24 10:00:41.96
3360	13	1	13.2399692	77.7168324	\N	2026-11-24 10:00:47.055
3361	13	1	13.2399679	77.7168303	\N	2026-11-24 10:01:01.621
3362	13	1	13.2399681	77.7168347	\N	2026-11-24 10:01:52.208
3363	13	1	13.2399699	77.7168311	\N	2026-11-24 10:02:02.242
3364	13	1	13.2399687	77.7168333	\N	2026-11-24 10:02:12.176
3365	13	1	13.2399678	77.7168311	\N	2026-11-24 10:02:22.006
3366	13	1	13.2399701	77.7168105	\N	2026-11-24 10:02:31.938
3367	13	1	13.2399700	77.7168104	\N	2026-11-24 10:02:42
3368	13	1	13.2399687	77.7168333	\N	2026-11-24 10:02:47.024
3369	13	1	13.2399699	77.7168311	\N	2026-11-24 10:03:02.147
3370	13	1	13.2399657	77.7168383	\N	2026-11-24 10:03:12.079
3371	13	1	13.2399657	77.7168383	\N	2026-11-24 10:03:17.207
3372	13	1	13.2399767	77.7168006	\N	2026-11-24 10:03:32.356
3373	13	1	13.2399699	77.7168311	\N	2026-11-24 10:03:41.98
3374	13	1	13.2399699	77.7168311	\N	2026-11-24 10:03:52.117
3375	13	1	13.2399681	77.7168347	\N	2026-11-24 10:04:02.051
3376	13	1	13.2399602	77.7168288	\N	2026-11-24 10:04:11.984
3377	13	1	13.2399686	77.7168339	\N	2026-11-24 10:04:21.917
3378	13	1	13.2399699	77.7168311	\N	2026-11-24 10:04:31.85
3379	13	1	13.2399692	77.7168324	\N	2026-11-24 10:04:41.68
3380	13	1	13.2399696	77.7168351	\N	2026-11-24 10:04:51.612
3381	13	1	13.2399687	77.7168376	\N	2026-11-24 10:05:01.443
3382	13	1	13.2399687	77.7168376	\N	2026-11-24 10:05:06.649
3383	13	1	13.2399644	77.7168432	\N	2026-11-24 10:05:16.911
3384	13	1	13.2399699	77.7168311	\N	2026-11-24 10:05:32.061
3385	13	1	13.2399699	77.7168311	\N	2026-11-24 10:05:37.147
3386	13	1	13.2399684	77.7168437	\N	2026-11-24 10:05:52.233
3387	13	1	13.2399664	77.7168330	\N	2026-11-24 10:06:07.257
3388	13	1	13.2400074	77.7168257	\N	2026-11-24 10:06:22.237
3389	13	1	13.2399674	77.7168406	\N	2026-11-24 10:06:32.17
3390	13	1	13.2399727	77.7168308	\N	2026-11-24 10:06:40.465
3391	13	1	13.2399697	77.7168417	\N	2026-11-24 10:06:52.137
3392	13	1	13.2399697	77.7168417	\N	2026-11-24 10:06:57.232
3393	13	1	13.2399686	77.7168287	\N	2026-11-24 10:07:12.412
3394	13	1	13.2399717	77.7168174	\N	2026-11-24 10:07:22.242
3395	13	1	13.2399717	77.7168174	\N	2026-11-24 10:07:27.381
3396	13	1	13.2399692	77.7168281	\N	2026-11-24 10:07:42.314
3397	13	1	13.2399664	77.7168291	\N	2026-11-24 10:07:52.349
3398	13	1	13.2399678	77.7168271	\N	2026-11-24 10:08:02.281
3399	13	1	13.2399668	77.7168218	\N	2026-11-24 10:08:12.112
3400	13	1	13.2399664	77.7168291	\N	2026-11-24 10:08:22.045
3401	13	1	13.2399664	77.7168291	\N	2026-11-24 10:08:27.153
3402	13	1	13.2399700	77.7168268	\N	2026-11-24 10:08:41.808
3403	13	1	13.2399671	77.7168275	\N	2026-11-24 10:08:52.151
3404	13	1	13.2399690	77.7168199	\N	2026-11-24 10:08:59.217
3405	13	1	13.2399687	77.7168267	\N	2026-11-24 10:09:12.093
3406	13	1	13.2399671	77.7168236	\N	2026-11-24 10:09:21.744
3407	13	1	13.2399679	77.7168303	\N	2026-11-24 10:09:31.78
3408	13	1	13.2399686	77.7168257	\N	2026-11-24 10:09:41.713
3409	13	1	13.2399566	77.7168280	\N	2026-11-24 10:09:51.44
3410	13	1	13.2399687	77.7168333	\N	2026-11-24 10:09:59.633
3411	13	1	13.2399675	77.7168724	\N	2026-11-24 10:10:11.511
3412	13	1	13.2399654	77.7168460	\N	2026-11-24 10:10:21.24
3413	13	1	13.2399702	77.7168336	\N	2026-11-24 10:10:30.351
3414	13	1	13.2400188	77.7169238	\N	2026-11-24 10:10:39.261
3415	13	1	13.2399699	77.7168310	\N	2026-11-24 10:10:50.219
3416	13	1	13.2399699	77.7168310	\N	2026-11-24 10:10:56.297
3417	13	1	13.2399692	77.7168281	\N	2026-11-24 10:11:11.313
3418	13	1	13.2399676	77.7168230	\N	2026-11-24 10:11:20.63
3419	13	1	13.2399679	77.7168303	\N	2026-11-24 10:11:27.594
3420	13	1	13.2399668	77.7168215	\N	2026-11-24 10:11:37.015
3421	13	1	13.2399678	77.7168259	\N	2026-11-24 10:11:48.279
3422	13	1	13.2399671	77.7168236	\N	2026-11-24 10:11:59.952
3423	13	1	13.2399679	77.7168303	\N	2026-11-24 10:12:08.452
3424	13	1	13.2399693	77.7168283	\N	2026-11-24 10:12:20.536
3425	13	1	13.2399706	77.7168296	\N	2026-11-24 10:12:29.751
3426	13	1	13.2399668	77.7168215	\N	2026-11-24 10:12:40.298
3427	13	1	13.2399678	77.7168210	\N	2026-11-24 10:12:50.54
3428	13	1	13.2399685	77.7168216	\N	2026-11-24 10:13:00.163
3429	13	1	13.2399707	77.7168292	\N	2026-11-24 10:13:07.64
3430	13	1	13.2399707	77.7168323	\N	2026-11-24 10:13:18.391
3431	13	1	13.2399684	77.7168294	\N	2026-11-24 10:13:28.12
3432	13	1	13.2399685	77.7168255	\N	2026-11-24 10:13:39.793
3433	13	1	13.2399685	77.7168255	\N	2026-11-24 10:13:45.101
3434	13	1	13.2399640	77.7168447	\N	2026-11-24 10:13:58.839
3435	13	1	13.2399678	77.7168210	\N	2026-11-24 10:14:10.163
3436	13	1	13.2399683	77.7168258	\N	2026-11-24 10:14:20.065
3437	13	1	13.2399683	77.7168258	\N	2026-11-24 10:14:29.957
3438	13	1	13.2399683	77.7168258	\N	2026-11-24 10:14:39.865
3439	13	1	13.2399683	77.7168258	\N	2026-11-24 10:14:59.698
3440	13	1	13.2399682	77.7168252	\N	2026-11-24 10:15:09.609
3441	13	1	13.2399678	77.7168247	\N	2026-11-24 10:15:19.504
3442	13	1	13.2399685	77.7168262	\N	2026-11-24 10:15:29.411
3443	13	1	13.2399682	77.7168236	\N	2026-11-24 10:15:39.311
3444	13	1	13.2399328	77.7167387	\N	2026-11-24 10:16:09.062
3445	13	1	13.2399673	77.7168560	\N	2026-11-24 10:16:16.875
3446	13	1	13.2399681	77.7168245	\N	2026-11-24 10:16:28.877
3447	13	1	13.2399681	77.7168245	\N	2026-11-24 10:16:34.045
3448	13	1	13.2399685	77.7168291	\N	2026-11-24 10:16:47.389
3449	13	1	13.2399685	77.7168291	\N	2026-11-24 10:16:55.07
3450	13	1	13.2399683	77.7168258	\N	2026-11-24 10:17:08.564
3451	13	1	13.2399619	77.7168195	\N	2026-11-24 10:17:18.535
3452	13	1	13.2399657	77.7168243	\N	2026-11-24 10:17:28.717
3453	13	1	13.2399680	77.7168251	\N	2026-11-24 10:17:38.621
3454	13	1	13.2399700	77.7168268	\N	2026-11-24 10:17:47.805
3455	13	1	13.2399671	77.7168275	\N	2026-11-24 10:17:57.021
3456	13	1	13.2399700	77.7168268	\N	2026-11-24 10:18:06.341
3457	13	1	13.2399693	77.7168283	\N	2026-11-24 10:18:17.502
3458	13	1	13.2399685	77.7168262	\N	2026-11-24 10:18:28.171
3459	13	1	13.2399686	77.7168265	\N	2026-11-24 10:18:38.051
3460	13	1	13.2399699	77.7168310	\N	2026-11-24 10:18:45.048
3461	13	1	13.2399687	77.7168333	\N	2026-11-24 10:18:53.956
3462	13	1	13.2427310	77.7164136	\N	2026-11-24 10:19:02.848
3463	13	1	13.2399683	77.7168258	\N	2026-11-24 10:19:18.032
3464	13	1	13.2399685	77.7168262	\N	2026-11-24 10:19:27.972
3465	13	1	13.2399685	77.7168262	\N	2026-11-24 10:19:37.922
3466	13	1	13.2399683	77.7168258	\N	2026-11-24 10:19:47.821
3467	13	1	13.2399683	77.7168258	\N	2026-11-24 10:19:57.714
3468	13	1	13.2399682	77.7168252	\N	2026-11-24 10:20:07.638
3469	13	1	13.2399684	77.7168225	\N	2026-11-24 10:20:17.554
3470	13	1	13.2400004	77.7170148	\N	2026-11-24 10:20:25.196
3471	13	1	13.2399682	77.7168236	\N	2026-11-24 10:20:37.424
3472	13	1	13.2399646	77.7168149	\N	2026-11-24 10:20:47.327
3473	13	1	13.2399682	77.7168252	\N	2026-11-24 10:20:57.241
3474	13	1	13.2399681	77.7168245	\N	2026-11-24 10:21:07.14
3475	13	1	13.2399668	77.7168243	\N	2026-11-24 10:21:15.68
3476	13	1	13.2399682	77.7168252	\N	2026-11-24 10:21:26.975
3477	13	1	13.2399685	77.7168262	\N	2026-11-24 10:21:36.897
3478	13	1	13.2399707	77.7168323	\N	2026-11-24 10:21:46.193
3479	13	1	13.2399682	77.7168236	\N	2026-11-24 10:21:56.736
3480	13	1	13.2399681	77.7168245	\N	2026-11-24 10:22:06.651
3481	13	1	13.2399666	77.7168186	\N	2026-11-24 10:22:16.553
3482	13	1	13.2399648	77.7168331	\N	2026-11-24 10:22:26.46
3483	13	1	13.2399648	77.7168331	\N	2026-11-24 10:22:36.371
3484	13	1	13.2399626	77.7168217	\N	2026-11-24 10:22:46.251
3485	13	1	13.2399632	77.7168231	\N	2026-11-24 10:22:56.128
3486	13	1	13.2399636	77.7168224	\N	2026-11-24 10:23:06.024
3487	13	1	13.2399637	77.7168224	\N	2026-11-24 10:23:15.938
3488	13	1	13.2399643	77.7168224	\N	2026-11-24 10:23:25.832
3489	13	1	13.2399646	77.7168225	\N	2026-11-24 10:23:35.713
3490	13	1	13.2399646	77.7168220	\N	2026-11-24 10:23:45.6
3491	13	1	13.2399649	77.7168223	\N	2026-11-24 10:23:55.523
3492	13	1	13.2399646	77.7168149	\N	2026-11-24 10:24:05.417
3493	13	1	13.2399682	77.7168236	\N	2026-11-24 10:24:15.319
3494	13	1	13.2399684	77.7168225	\N	2026-11-24 10:24:25.211
3495	13	1	13.2399684	77.7168225	\N	2026-11-24 10:24:30.221
3496	13	1	13.2399682	77.7168236	\N	2026-11-24 10:24:45.385
3497	13	1	13.2399682	77.7168236	\N	2026-11-24 10:24:55.282
3498	13	1	13.2399676	77.7168227	\N	2026-11-24 10:25:05.18
3499	13	1	13.2399680	77.7168251	\N	2026-11-24 10:25:15.088
3500	13	1	13.2399680	77.7168251	\N	2026-11-24 10:25:20.101
3501	13	1	13.2399681	77.7168245	\N	2026-11-24 10:25:35.072
3502	13	1	13.2399681	77.7168245	\N	2026-11-24 10:25:40.082
3503	13	1	13.2399681	77.7168245	\N	2026-11-24 10:25:55.235
3504	13	1	13.2399684	77.7168225	\N	2026-11-24 10:26:05.126
3505	13	1	13.2399682	77.7168236	\N	2026-11-24 10:26:15.018
3506	13	1	13.2399682	77.7168236	\N	2026-11-24 10:26:24.914
3507	13	1	13.2399683	77.7168258	\N	2026-11-24 10:26:34.795
3508	13	1	13.2399685	77.7168262	\N	2026-11-24 10:26:44.687
3509	13	1	13.2399683	77.7168258	\N	2026-11-24 10:26:54.574
3510	13	1	13.2399683	77.7168258	\N	2026-11-24 10:27:04.509
3511	13	1	13.2399630	77.7168167	\N	2026-11-24 10:27:14.378
3512	13	1	13.2399682	77.7168252	\N	2026-11-24 10:27:24.284
3513	13	1	13.2399645	77.7168245	\N	2026-11-24 10:27:34.17
3514	13	1	13.2399647	77.7168245	\N	2026-11-24 10:27:44.093
3515	13	1	13.2399676	77.7168227	\N	2026-11-24 10:27:54.004
3516	13	1	13.2399704	77.7168203	\N	2026-11-24 10:28:03.875
3517	13	1	13.2399703	77.7168204	\N	2026-11-24 10:28:12.782
3518	13	1	13.2400261	77.7168307	\N	2026-11-24 10:28:23.661
3519	13	1	13.2399683	77.7168258	\N	2026-11-24 10:28:33.577
3520	13	1	13.2399684	77.7168225	\N	2026-11-24 10:28:43.482
3521	13	1	13.2399666	77.7168186	\N	2026-11-24 10:28:53.334
3522	13	1	13.2401516	77.7168841	\N	2026-11-24 10:33:01.42
3523	13	1	13.2401516	77.7168841	\N	2026-11-24 10:33:06.743
3524	13	1	13.2399689	77.7168203	\N	2026-11-24 10:33:16.861
3525	13	1	13.2399676	77.7168227	\N	2026-11-24 10:33:26.765
3526	13	1	13.2399683	77.7168456	\N	2026-11-24 10:33:36.662
3527	13	1	13.2399685	77.7168456	\N	2026-11-24 10:33:46.512
3528	13	1	13.2399609	77.7168117	\N	2026-11-24 10:33:56.529
3529	13	1	13.2399579	77.7167972	\N	2026-11-24 10:34:06.393
3530	13	1	13.2399682	77.7168252	\N	2026-11-24 10:34:16.374
3531	13	1	13.2399604	77.7168224	\N	2026-11-24 10:34:26.352
3532	13	1	13.2399708	77.7168227	\N	2026-11-24 10:34:36.648
3533	13	1	13.2399682	77.7168228	\N	2026-11-24 10:34:46.839
3534	13	1	13.2399679	77.7168237	\N	2026-11-24 10:34:56.741
3535	13	1	13.2399682	77.7168252	\N	2026-11-24 10:35:06.658
3536	13	1	13.2399683	77.7168258	\N	2026-11-24 10:35:16.563
3537	13	1	13.2399617	77.7168391	\N	2026-11-24 10:35:26.428
3538	13	1	13.2399666	77.7168305	\N	2026-11-24 10:35:36.326
3539	13	1	13.2399694	77.7168259	\N	2026-11-24 10:35:46.228
3540	13	1	13.2400261	77.7168307	\N	2026-11-24 10:35:56.122
3541	13	1	13.2399681	77.7168245	\N	2026-11-24 10:36:06.014
3542	13	1	13.2399654	77.7168471	\N	2026-11-24 10:36:15.982
3543	13	1	13.2399654	77.7168471	\N	2026-11-24 10:36:20.996
3544	13	1	13.2399682	77.7168236	\N	2026-11-24 10:36:36.18
3545	13	1	13.2399666	77.7168489	\N	2026-11-24 10:36:46.107
3546	13	1	13.2399693	77.7168401	\N	2026-11-24 10:36:55.816
3547	13	1	13.2399659	77.7168442	\N	2026-11-24 10:37:05.338
3548	13	1	13.2399681	77.7168245	\N	2026-11-24 10:37:15.804
3549	13	1	13.2399688	77.7168193	\N	2026-11-24 10:37:25.692
3550	13	1	13.2399881	77.7168912	\N	2026-11-24 10:37:35.578
3551	13	1	13.2399682	77.7168236	\N	2026-11-24 10:37:45.478
3552	13	1	13.2399682	77.7168252	\N	2026-11-24 10:37:55.36
3553	13	1	13.2399595	77.7168412	\N	2026-11-24 10:38:04.219
3554	13	1	13.2399684	77.7168225	\N	2026-11-24 10:38:15.22
3555	13	1	13.2399778	77.7168310	\N	2026-11-24 10:38:25.143
3556	13	1	13.2399777	77.7168310	\N	2026-11-24 10:38:35.026
3557	13	1	13.2399693	77.7168417	\N	2026-11-24 10:38:43.54
3558	13	1	13.2400494	77.7168409	\N	2026-11-24 10:38:54.92
3559	13	1	13.2399684	77.7168225	\N	2026-11-24 10:39:04.806
3560	13	1	13.2399652	77.7168452	\N	2026-11-24 10:39:13.339
3561	13	1	13.2399702	77.7168336	\N	2026-11-24 10:39:24.501
3562	13	1	13.2399677	77.7168471	\N	2026-11-24 10:39:33.205
3563	13	1	13.2399738	77.7168138	\N	2026-11-24 10:39:44.365
3564	13	1	13.2399681	77.7168245	\N	2026-11-24 10:39:54.444
3565	13	1	13.2399705	77.7168344	\N	2026-11-24 10:40:04.231
3566	13	1	13.2399712	77.7168372	\N	2026-11-24 10:40:13.037
3567	13	1	13.2399660	77.7168363	\N	2026-11-24 10:40:23.689
3568	13	1	13.2399562	77.7168090	\N	2026-11-24 10:40:32.699
3569	13	1	13.2399562	77.7168090	\N	2026-11-24 10:40:39.149
3570	13	1	13.2399622	77.7168469	\N	2026-11-24 10:40:54.25
3571	13	1	13.2399890	77.7170211	\N	2026-11-24 10:41:04.175
3572	13	1	13.2399855	77.7168753	\N	2026-11-24 10:41:14.126
3573	13	1	13.2399717	77.7168730	\N	2026-11-24 10:41:24.002
3574	13	1	13.2400267	77.7168310	\N	2026-11-24 10:41:34.023
3575	13	1	13.2400208	77.7168208	\N	2026-11-24 10:41:43.902
3576	13	1	13.2401030	77.7169864	\N	2026-11-24 10:41:53.815
3577	13	1	13.2399700	77.7168328	\N	2026-11-24 10:42:02.709
3578	13	1	13.2400606	77.7167007	\N	2026-11-24 10:42:11.618
3579	13	1	13.2399706	77.7168296	\N	2026-11-24 10:42:22.984
3580	13	1	13.2399700	77.7168305	\N	2026-11-24 10:42:30.561
3581	13	1	13.2399688	77.7168193	\N	2026-11-24 10:42:43.446
3582	13	1	13.2399688	77.7168193	\N	2026-11-24 10:42:48.454
3583	13	1	13.2399682	77.7168236	\N	2026-11-24 10:43:03.55
3584	13	1	13.2399682	77.7168236	\N	2026-11-24 10:43:08.559
3585	13	1	13.2399706	77.7168372	\N	2026-11-24 10:43:20.43
3586	13	1	13.2399681	77.7168245	\N	2026-11-24 10:43:33.255
3587	13	1	13.2399561	77.7168157	\N	2026-11-24 10:43:43.245
3588	13	1	13.2399684	77.7168225	\N	2026-11-24 10:43:53.46
3589	13	1	13.2400735	77.7168391	\N	2026-11-24 10:43:59.035
3590	13	1	13.2399658	77.7168490	\N	2026-11-24 10:44:13.285
3591	13	1	13.2399427	77.7168292	\N	2026-11-24 10:44:23.179
3592	13	1	13.2399703	77.7168543	\N	2026-11-24 10:44:30.781
3593	13	1	13.2399762	77.7168481	\N	2026-11-24 10:44:41.941
3594	13	1	13.2400439	77.7168350	\N	2026-11-24 10:44:50.85
3595	13	1	13.2399676	77.7168227	\N	2026-11-24 10:45:02.803
3596	13	1	13.2399682	77.7168252	\N	2026-11-24 10:45:12.705
3597	13	1	13.2399647	77.7168508	\N	2026-11-24 10:45:19.419
3598	13	1	13.2399706	77.7168296	\N	2026-11-24 10:45:30.174
3599	13	1	13.2399681	77.7168245	\N	2026-11-24 10:45:42.439
3600	13	1	13.2399707	77.7168323	\N	2026-11-24 10:45:49.527
3601	13	1	13.2399670	77.7168507	\N	2026-11-24 10:46:02.316
3602	13	1	13.2399689	77.7168355	\N	2026-11-24 10:46:11.439
3603	13	1	13.2399685	77.7168262	\N	2026-11-24 10:46:22.114
3604	13	1	13.2399699	77.7168311	\N	2026-11-24 10:46:31.919
3605	13	1	13.2399699	77.7168311	\N	2026-11-24 10:46:40.931
3606	13	1	13.2399706	77.7168296	\N	2026-11-24 10:46:51.581
3607	13	1	13.2399685	77.7168262	\N	2026-11-24 10:47:01.705
3608	13	1	13.2400343	77.7168339	\N	2026-11-24 10:47:09.193
3609	13	1	13.2399683	77.7168258	\N	2026-11-24 10:47:21.468
3610	13	1	13.2399683	77.7168258	\N	2026-11-24 10:47:31.382
3611	13	1	13.2399685	77.7168262	\N	2026-11-24 10:47:41.317
3612	13	1	13.2399678	77.7168210	\N	2026-11-24 10:47:51.207
3613	13	1	13.2399685	77.7168262	\N	2026-11-24 10:48:01.121
3614	13	1	13.2399704	77.7168343	\N	2026-11-24 10:48:09.917
3615	13	1	13.2399681	77.7168245	\N	2026-11-24 10:48:20.902
3616	13	1	13.2399728	77.7168317	\N	2026-11-24 10:48:30.808
3617	13	1	13.2399728	77.7168317	\N	2026-11-24 10:48:40.596
3618	13	1	13.2399682	77.7168252	\N	2026-11-24 10:48:50.579
3619	13	1	13.2399680	77.7168236	\N	2026-11-24 10:49:00.475
3620	13	1	13.2399681	77.7168245	\N	2026-11-24 10:49:10.345
3621	13	1	13.2399569	77.7168145	\N	2026-11-24 10:49:20.241
3622	13	1	13.2399609	77.7168143	\N	2026-11-24 10:49:30.121
3623	13	1	13.2399699	77.7168311	\N	2026-11-24 10:49:39.108
3624	13	1	13.2400083	77.7176073	\N	2026-11-24 10:49:49.859
3625	13	1	13.2399683	77.7168258	\N	2026-11-24 10:49:59.837
3626	13	1	13.2399762	77.7168179	\N	2026-11-24 10:50:09.747
3627	13	1	13.2399763	77.7168179	\N	2026-11-24 10:50:19.655
3628	13	1	13.2399683	77.7168258	\N	2026-11-24 10:50:29.553
3629	13	1	13.2399657	77.7168290	\N	2026-11-24 10:50:39.42
3630	13	1	13.2399681	77.7168292	\N	2026-11-24 10:50:47.817
3631	13	1	13.2399686	77.7168206	\N	2026-11-24 10:50:59.298
3632	13	1	13.2399692	77.7168245	\N	2026-11-24 10:51:09.217
3633	13	1	13.2399682	77.7168252	\N	2026-11-24 10:51:19.116
3634	13	1	13.2399845	77.7168314	\N	2026-11-24 10:52:23.337
3635	13	1	13.2399587	77.7168437	\N	2026-11-24 10:52:35.96
3636	13	1	13.2399699	77.7168347	\N	2026-11-24 10:52:45.68
3637	13	1	13.2399707	77.7168323	\N	2026-11-24 10:52:52.643
3638	13	1	13.2400203	77.7175972	\N	2026-11-24 10:53:05.701
3639	13	1	13.2400203	77.7175972	\N	2026-11-24 10:53:10.715
3640	13	1	13.2400203	77.7175972	\N	2026-11-24 10:53:25.399
3641	13	1	13.2400192	77.7175925	\N	2026-11-24 10:53:34.628
3642	13	1	13.2400192	77.7175925	\N	2026-11-24 10:53:40.275
3643	13	1	13.2400025	77.7175961	\N	2026-11-24 10:53:51.729
3644	13	1	13.2400002	77.7175809	\N	2026-11-24 10:54:04.854
3645	13	1	13.2399915	77.7173976	\N	2026-11-24 10:54:13.539
3646	13	1	13.2400016	77.7175866	\N	2026-11-24 10:54:23.473
3647	13	1	13.2401457	77.7168589	\N	2026-11-24 10:54:32.996
3648	13	1	13.2400195	77.7175964	\N	2026-11-24 10:54:44.244
3649	13	1	13.2400201	77.7175983	\N	2026-11-24 10:54:54.1
3650	13	1	13.2401521	77.7168289	\N	2026-11-24 10:55:03.967
3651	13	1	13.2401521	77.7168289	\N	2026-11-24 10:55:08.98
3652	13	1	13.2427310	77.7164136	\N	2026-11-24 10:55:18.829
3653	13	1	13.2412305	77.7157270	\N	2026-11-24 10:55:29.049
3654	13	1	13.2400203	77.7175972	\N	2026-11-24 10:55:43.757
3655	13	1	13.2400201	77.7175983	\N	2026-11-24 10:55:53.633
3656	13	1	13.2400203	77.7175972	\N	2026-11-24 10:56:03.525
3657	13	1	13.2400200	77.7175922	\N	2026-11-24 10:56:11.608
3658	13	1	13.2399862	77.7168681	\N	2026-11-24 10:56:23.276
3659	13	1	13.2399686	77.7168214	\N	2026-11-24 10:56:33.188
3660	13	1	13.2399826	77.7168186	\N	2026-11-24 10:56:43.139
3661	13	1	13.2399826	77.7168186	\N	2026-11-24 10:56:53.01
3662	13	1	13.2399646	77.7168149	\N	2026-11-24 10:57:02.921
3663	13	1	13.2399670	77.7168552	\N	2026-11-24 10:57:10.078
3664	13	1	13.2399787	77.7168184	\N	2026-11-24 10:57:22.707
3665	13	1	13.2399650	77.7168281	\N	2026-11-24 10:57:32.578
3666	13	1	13.2399642	77.7168280	\N	2026-11-24 10:57:42.527
3667	13	1	13.2399763	77.7168230	\N	2026-11-24 10:57:52.406
3668	13	1	13.2399666	77.7168186	\N	2026-11-24 10:58:42.264
3669	13	1	13.2399734	77.7168323	\N	2026-11-24 10:58:52.151
3670	13	1	13.2399734	77.7168322	\N	2026-11-24 10:59:02.068
3671	13	1	13.2399678	77.7168259	\N	2026-11-24 10:59:11.729
3672	13	1	13.2399685	77.7168220	\N	2026-11-24 10:59:17.771
3673	13	1	13.2399685	77.7168255	\N	2026-11-24 10:59:27.499
3674	13	1	13.2399691	77.7168239	\N	2026-11-24 10:59:38.763
3675	13	1	13.2400009	77.7168134	\N	2026-11-24 10:59:47.877
3676	13	1	13.2399681	77.7168200	\N	2026-11-24 11:00:00.88
3677	13	1	13.2399694	77.7168240	\N	2026-11-24 11:00:09.381
3678	13	1	13.2399684	77.7168225	\N	2026-11-24 11:00:21.352
3679	13	1	13.2399666	77.7168186	\N	2026-11-24 11:00:31.274
3680	13	1	13.2399681	77.7168245	\N	2026-11-24 11:00:41.198
3681	13	1	13.2398633	77.7154673	\N	2026-11-24 11:00:51.126
3682	13	1	13.2400193	77.7168526	\N	2026-11-24 11:01:01.047
3683	13	1	13.2400195	77.7168766	\N	2026-11-24 11:01:11.037
3684	13	1	13.2399683	77.7168258	\N	2026-11-24 11:01:21.174
3685	13	1	13.2399661	77.7168151	\N	2026-11-24 11:01:31.067
3686	13	1	13.2399661	77.7168151	\N	2026-11-24 11:01:40.887
3687	13	1	13.2400102	77.7175310	\N	2026-11-24 11:01:50.819
3688	13	1	13.2399682	77.7168236	\N	2026-11-24 11:02:00.724
3689	13	1	13.2399682	77.7168236	\N	2026-11-24 11:02:10.616
3690	13	1	13.2399681	77.7168245	\N	2026-11-24 11:02:20.528
3691	13	1	13.2400029	77.7168569	\N	2026-11-24 11:02:30.456
3692	13	1	13.2399624	77.7168414	\N	2026-11-24 11:02:40.383
3693	13	1	13.2399682	77.7168252	\N	2026-11-24 11:02:50.295
3694	13	1	13.2399701	77.7168292	\N	2026-11-24 11:03:00.207
3695	13	1	13.2399670	77.7168507	\N	2026-11-24 11:03:10.09
3696	13	1	13.2399844	77.7168868	\N	2026-11-24 11:03:19.435
3697	13	1	13.2400193	77.7168396	\N	2026-11-24 11:03:29.907
3698	13	1	13.2400193	77.7168396	\N	2026-11-24 11:03:34.922
3699	13	1	13.2399676	77.7168227	\N	2026-11-24 11:03:50.036
3700	13	1	13.2399603	77.7168376	\N	2026-11-24 11:03:59.928
3701	13	1	13.2399604	77.7168376	\N	2026-11-24 11:04:09.763
3702	13	1	13.2399686	77.7168214	\N	2026-11-24 11:04:19.736
3703	13	1	13.2400120	77.7175323	\N	2026-11-24 11:04:29.64
3704	13	1	13.2400120	77.7175323	\N	2026-11-24 11:04:34.654
3705	13	1	13.2400980	77.7164925	\N	2026-11-24 11:04:46.885
3706	13	1	13.2399686	77.7168214	\N	2026-11-24 11:04:59.274
3707	13	1	13.2399695	77.7168323	\N	2026-11-24 11:05:09.156
3708	13	1	13.2400120	77.7175323	\N	2026-11-24 11:05:28.92
3709	13	1	13.2399596	77.7168228	\N	2026-11-24 11:05:38.788
3710	13	1	13.2399596	77.7168227	\N	2026-11-24 11:05:48.614
3711	13	1	13.2399676	77.7168227	\N	2026-11-24 11:05:58.586
3712	13	1	13.2399676	77.7168227	\N	2026-11-24 11:06:03.593
3713	13	1	13.2399682	77.7168236	\N	2026-11-24 11:06:18.326
3714	13	1	13.2399653	77.7168263	\N	2026-11-24 11:06:28.203
3715	13	1	13.2399682	77.7168236	\N	2026-11-24 11:06:38.159
3716	13	1	13.2399681	77.7168245	\N	2026-11-24 11:06:48.044
3717	13	1	13.2399646	77.7168149	\N	2026-11-24 11:06:57.93
3718	13	1	13.2399697	77.7168401	\N	2026-11-24 11:07:05.022
3719	13	1	13.2400187	77.7168648	\N	2026-11-24 11:07:17.726
3720	13	1	13.2399666	77.7168479	\N	2026-11-24 11:07:24.785
3721	13	1	13.2400493	77.7168427	\N	2026-11-24 11:07:36.46
3722	13	1	13.2400321	77.7168614	\N	2026-11-24 11:07:47.467
3723	13	1	13.2399682	77.7168191	\N	2026-11-24 11:07:57.363
3724	13	1	13.2399722	77.7168534	\N	2026-11-24 11:08:07.28
3725	13	1	13.2399722	77.7168534	\N	2026-11-24 11:08:12.296
3726	13	1	13.2399684	77.7168225	\N	2026-11-24 11:08:27.427
3727	13	1	13.2399684	77.7168225	\N	2026-11-24 11:08:32.439
3728	13	1	13.2399668	77.7168548	\N	2026-11-24 11:08:45.17
3729	13	1	13.2400075	77.7174660	\N	2026-11-24 11:08:56.435
3730	13	1	13.2399684	77.7168225	\N	2026-11-24 11:09:06.981
3731	13	1	13.2399684	77.7168225	\N	2026-11-24 11:09:16.879
3732	13	1	13.2399753	77.7168248	\N	2026-11-24 11:09:26.768
3733	13	1	13.2399671	77.7168187	\N	2026-11-24 11:09:36.663
3734	13	1	13.2399672	77.7168187	\N	2026-11-24 11:09:46.56
3735	13	1	13.2399686	77.7168214	\N	2026-11-24 11:09:51.566
3736	13	1	13.2399684	77.7168225	\N	2026-11-24 11:10:06.687
3737	13	1	13.2399646	77.7168149	\N	2026-11-24 11:10:16.577
3738	13	1	13.2399682	77.7168236	\N	2026-11-24 11:10:26.511
3739	13	1	13.2399682	77.7168236	\N	2026-11-24 11:10:31.531
3740	13	1	13.2400081	77.7169344	\N	2026-11-24 11:10:46.625
3741	13	1	13.2399706	77.7168372	\N	2026-11-24 11:10:53.99
3742	13	1	13.2399684	77.7168225	\N	2026-11-24 11:11:06.439
3743	13	1	13.2399684	77.7168225	\N	2026-11-24 11:11:11.449
3744	13	1	13.2399689	77.7168203	\N	2026-11-24 11:11:26.242
3745	13	1	13.2399676	77.7168227	\N	2026-11-24 11:11:36.136
3746	13	1	13.2400481	77.7168242	\N	2026-11-24 11:11:46.083
3747	13	1	13.2399829	77.7168289	\N	2026-11-24 11:11:56.012
3748	13	1	13.2400414	77.7168343	\N	2026-11-24 11:12:17.835
3749	13	1	13.2399683	77.7168522	\N	2026-11-24 11:12:27.744
3750	13	1	13.2399683	77.7168522	\N	2026-11-24 11:12:32.758
3751	13	1	13.2399647	77.7168469	\N	2026-11-24 11:12:47.486
3752	13	1	13.2399647	77.7168469	\N	2026-11-24 11:12:52.495
3753	13	1	13.2399799	77.7168699	\N	2026-11-24 11:13:07.278
3754	13	1	13.2400345	77.7168053	\N	2026-11-24 11:13:17.216
3755	13	1	13.2400345	77.7168054	\N	2026-11-24 11:13:27.109
3756	13	1	13.2401510	77.7168308	\N	2026-11-24 11:13:37.038
3757	13	1	13.2399740	77.7168559	\N	2026-11-24 11:14:09.014
3758	13	1	13.2399740	77.7168559	\N	2026-11-24 11:14:18.872
3759	13	1	13.2399684	77.7168225	\N	2026-11-24 11:14:28.743
3760	13	1	13.2401558	77.7168597	\N	2026-11-24 11:14:38.602
3761	13	1	13.2399784	77.7168619	\N	2026-11-24 11:14:48.483
3762	13	1	13.2399741	77.7168530	\N	2026-11-24 11:14:58.405
3763	13	1	13.2399689	77.7168203	\N	2026-11-24 11:15:08.333
3764	13	1	13.2399684	77.7168225	\N	2026-11-24 11:15:18.219
3765	13	1	13.2399901	77.7169066	\N	2026-11-24 11:15:28.123
3766	13	1	13.2399901	77.7169066	\N	2026-11-24 11:15:33.142
3767	13	1	13.2400826	77.7168218	\N	2026-11-24 11:15:48.338
3768	13	1	13.2399668	77.7168500	\N	2026-11-24 11:15:58.258
3769	13	1	13.2399684	77.7168225	\N	2026-11-24 11:16:08.191
3770	13	1	13.2399684	77.7168225	\N	2026-11-24 11:16:18.07
3771	13	1	13.2399682	77.7168191	\N	2026-11-24 11:16:27.968
3772	13	1	13.2399667	77.7168200	\N	2026-11-24 11:16:37.88
3773	13	1	13.2399667	77.7168200	\N	2026-11-24 11:16:42.89
3774	13	1	13.2399397	77.7165689	\N	2026-11-24 11:16:53.126
3775	13	1	13.2399688	77.7168193	\N	2026-11-24 11:17:03.343
3776	13	1	13.2411089	77.7156985	\N	2026-11-24 11:17:18.093
3777	13	1	13.2400125	77.7169409	\N	2026-11-24 11:17:27.961
3778	13	1	13.2411198	77.7157299	\N	2026-11-24 11:17:37.873
3779	13	1	13.2400116	77.7167329	\N	2026-11-24 11:17:47.752
3780	13	1	13.2399751	77.7172219	\N	2026-11-24 11:17:57.004
3781	13	1	13.2400125	77.7169409	\N	2026-11-24 11:18:07.522
3782	13	1	13.2400928	77.7168293	\N	2026-11-24 11:18:17.38
3783	13	1	13.2400248	77.7168353	\N	2026-11-24 11:18:23.322
3784	13	1	13.2399706	77.7168381	\N	2026-11-24 11:18:35.302
3785	13	1	13.2399697	77.7168386	\N	2026-11-24 11:18:44.315
3786	13	1	13.2399695	77.7168323	\N	2026-11-24 11:18:56.993
3787	13	1	13.2399695	77.7168323	\N	2026-11-24 11:19:02.008
3788	13	1	13.2399702	77.7168266	\N	2026-11-24 11:19:15.034
3789	13	1	13.2402242	77.7166703	\N	2026-11-24 11:19:26.998
3790	13	1	13.2399705	77.7168358	\N	2026-11-24 11:19:36.23
3791	13	1	13.2399688	77.7168193	\N	2026-11-24 11:19:46.785
3792	13	1	13.2399961	77.7171263	\N	2026-11-24 11:19:55.482
3793	13	1	13.2399961	77.7171263	\N	2026-11-24 11:20:01.687
3794	13	1	13.2399712	77.7168372	\N	2026-11-24 11:20:16.782
3795	13	1	13.2399695	77.7168323	\N	2026-11-24 11:20:26.787
3796	13	1	13.2399940	77.7168421	\N	2026-11-24 11:20:36.135
3797	13	1	13.2399656	77.7168469	\N	2026-11-24 11:20:46.273
3798	13	1	13.2399697	77.7168386	\N	2026-11-24 11:20:56.41
3799	13	1	13.2399686	77.7168214	\N	2026-11-24 11:21:06.494
3800	13	1	13.2399686	77.7168214	\N	2026-11-24 11:21:16.411
3801	13	1	13.2399683	77.7168258	\N	2026-11-24 11:21:26.364
3802	13	1	13.2401040	77.7168309	\N	2026-11-24 11:21:36.313
3803	13	1	13.2399779	77.7167602	\N	2026-11-24 11:21:46.177
3804	13	1	13.2399740	77.7168106	\N	2026-11-24 11:21:55.393
3805	13	1	13.2400329	77.7168322	\N	2026-11-24 11:22:06.092
3806	13	1	13.2401508	77.7168321	\N	2026-11-24 11:22:16.016
3807	13	1	13.2399682	77.7168252	\N	2026-11-24 11:22:25.937
3808	13	1	13.2400271	77.7168309	\N	2026-11-24 11:22:35.915
3809	13	1	13.2400166	77.7168080	\N	2026-11-24 11:22:45.828
3810	13	1	13.2399709	77.7168082	\N	2026-11-24 11:22:51.509
3811	13	1	13.2399712	77.7168080	\N	2026-11-24 11:23:05.127
3812	13	1	13.2399974	77.7168287	\N	2026-11-24 11:23:15.633
3813	13	1	13.2400420	77.7168326	\N	2026-11-24 11:23:25.499
3814	13	1	13.2399684	77.7168225	\N	2026-11-24 11:23:35.441
3815	13	1	13.2400343	77.7168306	\N	2026-11-24 11:23:45.346
3816	13	1	13.2400150	77.7168211	\N	2026-11-24 11:23:55.244
3817	13	1	13.2400149	77.7168211	\N	2026-11-24 11:24:05.16
3818	13	1	13.2399688	77.7168193	\N	2026-11-24 11:24:15.065
3819	13	1	13.2399689	77.7168203	\N	2026-11-24 11:24:24.986
3820	13	1	13.2399689	77.7168203	\N	2026-11-24 11:24:29.997
3821	13	1	13.2400972	77.7168307	\N	2026-11-24 11:24:45.132
3822	13	1	13.2399686	77.7168214	\N	2026-11-24 11:24:55.057
3823	13	1	13.2400903	77.7168306	\N	2026-11-24 11:25:04.957
3824	13	1	13.2401341	77.7167819	\N	2026-11-24 11:25:14.871
3825	13	1	13.2410983	77.7157003	\N	2026-11-24 11:25:24.779
3826	13	1	13.2400644	77.7168102	\N	2026-11-24 11:25:34.708
3827	13	1	13.2399682	77.7168191	\N	2026-11-24 11:25:44.632
3828	13	1	13.2410883	77.7157198	\N	2026-11-24 11:25:54.532
3829	13	1	13.2399667	77.7168200	\N	2026-11-24 11:26:04.445
3830	13	1	13.2399682	77.7168191	\N	2026-11-24 11:26:14.311
3831	13	1	13.2400719	77.7168040	\N	2026-11-24 11:26:24.198
3832	13	1	13.2399686	77.7168214	\N	2026-11-24 11:26:34.083
3833	13	1	13.2399688	77.7168193	\N	2026-11-24 11:26:44.036
3834	13	1	13.2400413	77.7168283	\N	2026-11-24 11:26:53.939
3835	13	1	13.2399689	77.7168203	\N	2026-11-24 11:27:03.852
3836	13	1	13.2399646	77.7168149	\N	2026-11-24 11:27:13.783
3837	13	1	13.2400821	77.7168262	\N	2026-11-24 11:27:23.705
3838	13	1	13.2399609	77.7168143	\N	2026-11-24 11:27:33.606
3839	13	1	13.2399609	77.7168143	\N	2026-11-24 11:27:38.616
3840	13	1	13.2401068	77.7168309	\N	2026-11-24 11:27:53.796
3841	13	1	13.2399523	77.7168144	\N	2026-11-24 11:28:03.66
3842	13	1	13.2399666	77.7168186	\N	2026-11-24 11:28:13.555
3843	13	1	13.2411208	77.7157321	\N	2026-11-24 11:28:23.464
3844	13	1	13.2399667	77.7168200	\N	2026-11-24 11:28:33.359
3845	13	1	13.2400643	77.7168109	\N	2026-11-24 11:28:43.283
3846	13	1	13.2411231	77.7158535	\N	2026-11-24 11:28:53.176
3847	13	1	13.2400632	77.7167800	\N	2026-11-24 11:29:03.063
3848	13	1	13.2401869	77.7167654	\N	2026-11-24 11:29:12.966
3849	13	1	13.2399676	77.7168227	\N	2026-11-24 11:29:22.87
3850	13	1	13.2399689	77.7168203	\N	2026-11-24 11:29:32.804
3851	13	1	13.2399689	77.7168203	\N	2026-11-24 11:29:37.814
3852	13	1	13.2399688	77.7168193	\N	2026-11-24 11:29:53.043
3853	13	1	13.2411208	77.7157325	\N	2026-11-24 11:30:02.948
3854	13	1	13.2400926	77.7168286	\N	2026-11-24 11:30:12.879
3855	13	1	13.2402367	77.7203700	0.00	2026-11-24 11:30:19.177
3856	13	1	13.2403233	77.7217483	0.00	2026-11-24 11:30:24.217
3857	13	1	13.2403233	77.7217483	\N	2026-11-24 11:30:38.296
3858	13	1	13.2399666	77.7168186	\N	2026-11-24 11:30:48.226
3859	13	1	13.2399676	77.7168259	\N	2026-11-24 11:30:58.134
3860	13	1	13.2411087	77.7156901	\N	2026-11-24 11:31:08.06
3861	13	1	13.2401403	77.7168325	\N	2026-11-24 11:31:18
3862	13	1	13.2399609	77.7168143	\N	2026-11-24 11:31:27.932
3863	13	1	13.2411042	77.7156982	\N	2026-11-24 11:31:37.835
3864	13	1	13.2400328	77.7168300	\N	2026-11-24 11:31:47.757
3865	13	1	13.2399680	77.7168251	\N	2026-11-24 11:31:57.666
3866	13	1	13.2411183	77.7157350	\N	2026-11-24 11:32:07.591
3867	13	1	13.2411301	77.7157441	\N	2026-11-24 11:32:17.47
3868	13	1	13.2400573	77.7168180	\N	2026-11-24 11:32:27.35
3869	13	1	13.2400514	77.7168242	\N	2026-11-24 11:32:37.292
3870	13	1	13.2410991	77.7157121	\N	2026-11-24 11:32:47.236
3871	13	1	13.2401522	77.7168317	\N	2026-11-24 11:32:57.158
3872	13	1	13.2399676	77.7168227	\N	2026-11-24 11:33:07.05
3873	13	1	13.2399676	77.7168227	\N	2026-11-24 11:33:12.057
3874	13	1	13.2408509	77.7159871	\N	2026-11-24 11:33:27.2
3875	13	1	13.2399609	77.7168143	\N	2026-11-24 11:33:37.103
3876	13	1	13.2401970	77.7168096	\N	2026-11-24 11:33:47.013
3877	13	1	13.2401970	77.7168096	\N	2026-11-24 11:33:56.926
3878	13	1	13.2399406	77.7167460	\N	2026-11-24 11:34:06.819
3879	13	1	13.2399676	77.7168227	\N	2026-11-24 11:34:16.719
3880	13	1	13.2399676	77.7168227	\N	2026-11-24 11:34:21.736
3881	13	1	13.2399646	77.7168149	\N	2026-11-24 11:34:36.834
3882	13	1	13.2399676	77.7168227	\N	2026-11-24 11:34:46.744
3883	13	1	13.2401523	77.7168334	\N	2026-11-24 11:34:56.635
3884	13	1	13.2399646	77.7168149	\N	2026-11-24 11:35:06.549
3885	13	1	13.2399646	77.7168149	\N	2026-11-24 11:35:11.563
3886	13	1	13.2399311	77.7172067	\N	2026-11-24 11:35:26.669
3887	13	1	13.2406819	77.7160167	\N	2026-11-24 11:35:36.572
3888	13	1	13.2399676	77.7168227	\N	2026-11-24 11:35:46.448
3889	13	1	13.2411237	77.7157403	\N	2026-11-24 11:35:56.388
3890	13	1	13.2399680	77.7168251	\N	2026-11-24 11:36:06.284
3891	13	1	13.2399680	77.7168251	\N	2026-11-24 11:36:11.296
3892	13	1	13.2410792	77.7157251	\N	2026-11-24 11:36:26.432
3893	13	1	13.2411220	77.7157366	\N	2026-11-24 11:36:36.332
3894	13	1	13.2411220	77.7157366	\N	2026-11-24 11:36:46.232
3895	13	1	13.2411220	77.7157366	\N	2026-11-24 11:36:51.238
3896	13	1	13.2399667	77.7168200	\N	2026-11-24 11:37:06.354
3897	13	1	13.2411198	77.7157299	\N	2026-11-24 11:37:16.264
3898	13	1	13.2403047	77.7164112	\N	2026-11-24 11:37:26.159
3899	13	1	13.2399666	77.7168186	\N	2026-11-24 11:37:36.053
3900	13	1	13.2411646	77.7157309	\N	2026-11-24 11:37:45.929
3901	13	1	13.2399044	77.7173077	\N	2026-11-24 11:37:55.846
3902	13	1	13.2411241	77.7157415	\N	2026-11-24 11:38:05.718
3903	13	1	13.2401458	77.7168307	\N	2026-11-24 11:38:15.627
3904	13	1	13.2399646	77.7168149	\N	2026-11-24 11:38:25.493
3905	13	1	13.2411208	77.7157371	\N	2026-11-24 11:38:35.368
3906	13	1	13.2399628	77.7168400	\N	2026-11-24 11:38:45.299
3907	13	1	13.2399646	77.7168149	\N	2026-11-24 11:38:55.19
3908	13	1	13.2399688	77.7168193	\N	2026-11-24 11:39:05.106
3909	13	1	13.2411122	77.7157175	\N	2026-11-24 11:39:15.026
3910	13	1	13.2410983	77.7157003	\N	2026-11-24 11:39:24.973
3911	13	1	13.2401871	77.7167943	\N	2026-11-24 11:39:34.884
3912	13	1	13.2401871	77.7167943	\N	2026-11-24 11:39:44.74
3913	13	1	13.2411030	77.7158472	\N	2026-11-24 11:39:54.75
3914	13	1	13.2401318	77.7168636	\N	2026-11-24 11:40:04.672
3915	13	1	13.2401318	77.7168636	\N	2026-11-24 11:40:09.683
3916	13	1	13.2399911	77.7172507	\N	2026-11-24 11:40:24.834
3917	13	1	13.2411277	77.7157477	\N	2026-11-24 11:40:34.71
3918	13	1	13.2399676	77.7168227	\N	2026-11-24 11:40:44.613
3919	13	1	13.2399414	77.7172000	\N	2026-11-24 11:40:54.489
3920	13	1	13.2399414	77.7172000	\N	2026-11-24 11:40:59.497
3921	13	1	13.2400306	77.7165393	\N	2026-11-24 11:41:14.646
3922	13	1	13.2399386	77.7168310	\N	2026-11-24 11:41:24.568
3923	13	1	13.2408571	77.7160082	\N	2026-11-24 11:41:34.484
3924	13	1	13.2408571	77.7160082	\N	2026-11-24 11:41:39.506
3925	13	1	13.2401171	77.7167073	\N	2026-11-24 11:41:54.711
3926	13	1	13.2399609	77.7168143	\N	2026-11-24 11:42:04.638
3927	13	1	13.2399646	77.7168149	\N	2026-11-24 11:42:14.522
3928	13	1	13.2399383	77.7167852	\N	2026-11-24 11:42:24.421
3929	13	1	13.2398742	77.7168212	\N	2026-11-24 11:42:34.345
3930	13	1	13.2399676	77.7168227	\N	2026-11-24 11:42:44.224
3931	13	1	13.2404676	77.7162757	\N	2026-11-24 11:42:54.124
3932	13	1	13.2404676	77.7162757	\N	2026-11-24 11:42:59.132
3933	13	1	13.2399676	77.7168227	\N	2026-11-24 11:43:14.273
3934	13	1	13.2399676	77.7168227	\N	2026-11-24 11:43:19.289
3935	13	1	13.2399682	77.7168191	\N	2026-11-24 11:43:29.505
3936	13	1	13.2411237	77.7157403	\N	2026-11-24 11:43:44.659
3937	13	1	13.2399684	77.7168225	\N	2026-11-24 11:43:54.561
3938	13	1	13.2399646	77.7168149	\N	2026-11-24 11:44:04.441
3939	13	1	13.2399619	77.7168250	\N	2026-11-24 11:44:14.376
3940	13	1	13.2399689	77.7168203	\N	2026-11-24 11:44:24.289
3941	13	1	13.2399689	77.7168203	\N	2026-11-24 11:44:34.193
3942	13	1	13.2399646	77.7168149	\N	2026-11-24 11:44:44.089
3943	13	1	13.2399646	77.7168149	\N	2026-11-24 11:44:53.982
3944	13	1	13.2400643	77.7168117	\N	2026-11-24 11:45:03.868
3945	13	1	13.2411198	77.7157299	\N	2026-11-24 11:45:13.735
3946	13	1	13.2411230	77.7157437	\N	2026-11-24 11:45:23.636
3947	13	1	13.2399485	77.7168138	\N	2026-11-24 11:45:33.545
3948	13	1	13.2399077	77.7172813	\N	2026-11-24 11:45:43.407
3949	13	1	13.2399077	77.7172813	\N	2026-11-24 11:45:48.422
3950	13	1	13.2399646	77.7168149	\N	2026-11-24 11:46:03.551
3951	13	1	13.2399609	77.7168143	\N	2026-11-24 11:46:13.419
3952	13	1	13.2399688	77.7168193	\N	2026-11-24 11:46:23.505
3953	13	1	13.2411647	77.7157295	\N	2026-11-24 11:46:43.237
3954	13	1	13.2411647	77.7157295	\N	2026-11-24 11:46:48.253
3955	13	1	13.2399141	77.7172787	\N	2026-11-24 11:47:03.375
3956	13	1	13.2411259	77.7157468	\N	2026-11-24 11:47:13.273
3957	13	1	13.2399609	77.7168143	\N	2026-11-24 11:47:23.155
3958	13	1	13.2399676	77.7168227	\N	2026-11-24 11:47:46.645
3959	13	1	13.2399676	77.7168259	\N	2026-11-24 11:48:06.378
3960	13	1	13.2399689	77.7168203	\N	2026-11-24 11:48:16.301
3961	13	1	13.2399676	77.7168259	\N	2026-11-24 11:48:26.19
3962	13	1	13.2411234	77.7157417	\N	2026-11-24 11:48:36.081
3963	13	1	13.2399680	77.7168251	\N	2026-11-24 11:48:45.982
3964	13	1	13.2399689	77.7168203	\N	2026-11-24 11:48:55.887
3965	13	1	13.2399691	77.7168149	\N	2026-11-24 11:49:05.792
3966	13	1	13.2399810	77.7168214	\N	2026-11-24 11:49:15.667
3967	13	1	13.2399811	77.7168213	\N	2026-11-24 11:49:25.554
3968	13	1	13.2399682	77.7168236	\N	2026-11-24 11:49:35.489
3969	13	1	13.2399668	77.7168109	\N	2026-11-24 11:49:45.472
3970	13	1	13.2399684	77.7168225	\N	2026-11-24 11:49:55.714
3971	13	1	13.2399680	77.7168251	\N	2026-11-24 11:50:05.67
3972	13	1	13.2399617	77.7168473	\N	2026-11-24 11:50:15.577
3973	13	1	13.2399676	77.7168259	\N	2026-11-24 11:50:25.469
3974	13	1	13.2400636	77.7168095	\N	2026-11-24 11:50:35.409
3975	13	1	13.2399667	77.7168200	\N	2026-11-24 11:50:45.307
3976	13	1	13.2399684	77.7168225	\N	2026-11-24 11:50:55.219
3977	13	1	13.2399682	77.7168191	\N	2026-11-24 11:51:05.12
3978	13	1	13.2399689	77.7168203	\N	2026-11-24 11:51:15.05
3979	13	1	13.2399689	77.7168203	\N	2026-11-24 11:51:24.974
3980	13	1	13.2399689	77.7168203	\N	2026-11-24 11:51:29.979
3981	13	1	13.2399682	77.7168191	\N	2026-11-24 11:51:45.147
3982	13	1	13.2399682	77.7168191	\N	2026-11-24 11:51:50.159
3983	13	1	13.2411113	77.7157126	\N	2026-11-24 11:52:05.294
3984	13	1	13.2399686	77.7168214	\N	2026-11-24 11:52:15.234
3985	13	1	13.2399558	77.7168498	\N	2026-11-24 11:54:36.225
3986	13	1	13.2399676	77.7168227	\N	2026-11-24 11:54:43.549
3987	13	1	13.2427310	77.7164136	\N	2026-11-24 11:54:53.434
3988	13	1	13.2399656	77.7168257	\N	2026-11-24 11:55:08.596
3989	13	1	13.2399656	77.7168257	\N	2026-11-24 11:55:18.505
3990	13	1	13.2399656	77.7168257	\N	2026-11-24 11:55:23.514
3991	13	1	13.2399656	77.7168257	\N	2026-11-24 11:55:38.262
3992	13	1	13.2399846	77.7168372	\N	2026-11-24 11:55:48.164
3993	13	1	13.2399626	77.7168240	\N	2026-11-24 11:55:58.076
3994	13	1	13.2399626	77.7168240	\N	2026-11-24 11:56:03.085
3995	13	1	13.2411230	77.7157437	\N	2026-11-24 11:56:18.227
3996	13	1	13.2411230	77.7157437	\N	2026-11-24 11:56:23.233
3997	13	1	13.2411230	77.7157437	\N	2026-11-24 11:56:37.985
3998	13	1	13.2411230	77.7157437	\N	2026-11-24 11:56:47.916
3999	13	1	13.2399842	77.7169096	\N	2026-11-24 11:56:57.806
4000	13	1	13.2399619	77.7168250	\N	2026-11-24 11:57:07.712
4001	13	1	13.2399656	77.7168257	\N	2026-11-24 11:57:17.644
4002	13	1	13.2399626	77.7168240	\N	2026-11-24 11:57:27.555
4003	13	1	13.2399688	77.7168193	\N	2026-11-24 11:57:37.47
4004	13	1	13.2399568	77.7168475	\N	2026-11-24 11:57:47.371
4005	13	1	13.2399568	77.7168475	\N	2026-11-24 11:57:52.377
4006	13	1	13.2400394	77.7167056	\N	2026-11-24 11:58:07.146
4007	13	1	13.2400394	77.7167056	\N	2026-11-24 11:58:12.155
4008	13	1	13.2410190	77.7196216	\N	2026-11-24 11:58:27.344
4009	13	1	13.2400138	77.7167622	\N	2026-11-24 11:58:37.245
4010	13	1	13.2399567	77.7170233	0.00	2026-11-24 11:58:42.385
4011	13	1	13.2400017	77.7170283	0.00	2026-11-24 11:58:47.383
4012	13	1	13.2400417	77.7171550	0.00	2026-11-24 11:58:52.382
4013	13	1	13.2400667	77.7172550	0.00	2026-11-24 11:58:58.382
4014	13	1	13.2400699	77.7172786	0.22	2026-11-24 11:59:07.372
4015	13	1	13.2400394	77.7167056	\N	2026-11-24 11:59:17.284
4016	13	1	13.2401600	77.7168167	0.00	2026-11-24 11:59:22.578
4017	13	1	13.2401616	77.7168136	0.29	2026-11-24 11:59:28.632
4018	13	1	13.2401591	77.7168142	0.30	2026-11-24 11:59:34.647
4019	13	1	13.2401540	77.7168109	0.20	2026-11-24 11:59:39.622
4020	13	1	13.2401442	77.7167825	0.19	2026-11-24 11:59:44.598
4021	13	1	13.2401317	77.7167550	0.00	2026-11-24 11:59:50.581
4022	13	1	13.2401317	77.7167650	0.00	2026-11-24 11:59:55.575
4023	13	1	13.2401300	77.7167633	0.00	2026-11-24 12:00:01.572
4024	13	1	13.2401500	77.7167750	0.00	2026-11-24 12:00:06.576
4025	13	1	13.2401517	77.7167750	0.00	2026-11-24 12:00:11.576
4026	13	1	13.2401300	77.7168017	0.00	2026-11-24 12:00:17.571
4027	13	1	13.2401333	77.7168017	0.00	2026-11-24 12:00:22.574
4028	13	1	13.2401467	77.7168083	0.00	2026-11-24 12:00:28.575
4029	13	1	13.2402017	77.7168483	\N	2026-11-24 12:00:33.956
4030	13	1	13.2402783	77.7168917	0.00	2026-11-24 12:00:39.578
4031	13	1	13.2403467	77.7169267	0.00	2026-11-24 12:00:45.575
4032	13	1	13.2403317	77.7169150	0.00	2026-11-24 12:00:51.576
4033	13	1	13.2403200	77.7169033	0.00	2026-11-24 12:00:57.574
4034	13	1	13.2403083	77.7169067	\N	2026-11-24 12:01:06.961
4035	13	1	13.2399626	77.7168240	\N	2026-11-24 12:01:16.853
4036	13	1	13.2399682	77.7168236	\N	2026-11-24 12:01:26.761
4037	13	1	13.2400450	77.7168261	\N	2026-11-24 12:01:36.714
4038	13	1	13.2399682	77.7168236	\N	2026-11-24 12:01:46.631
4039	13	1	13.2399681	77.7168245	\N	2026-11-24 12:01:56.554
4040	13	1	13.2399682	77.7168236	\N	2026-11-24 12:02:06.501
4041	13	1	13.2399682	77.7168236	\N	2026-11-24 12:02:16.404
4042	13	1	13.2400433	77.7168290	\N	2026-11-24 12:02:26.349
4043	13	1	13.2399514	77.7168436	\N	2026-11-24 12:02:36.254
4044	13	1	13.2399937	77.7167979	\N	2026-11-24 12:02:46.195
4045	13	1	13.2399822	77.7168204	\N	2026-11-24 12:02:56.136
4046	13	1	13.2400053	77.7167716	\N	2026-11-24 12:03:06.071
4047	13	1	13.2399847	77.7168189	\N	2026-11-24 12:03:16.019
4048	13	1	13.2399540	77.7168456	\N	2026-11-24 12:03:25.912
4049	13	1	13.2401650	77.7166683	0.00	2026-11-24 12:03:31.574
4050	13	1	13.2402083	77.7167850	0.00	2026-11-24 12:03:37.576
4051	13	1	13.2402383	77.7168050	0.00	2026-11-24 12:03:43.575
4052	13	1	13.2402617	77.7168367	0.00	2026-11-24 12:03:48.576
4053	13	1	13.2402683	77.7168883	0.00	2026-11-24 12:03:54.576
4054	13	1	13.2403150	77.7169567	0.00	2026-11-24 12:04:00.572
4055	13	1	13.2403833	77.7169983	0.00	2026-11-24 12:04:05.572
4056	13	1	13.2404083	77.7170900	0.00	2026-11-24 12:04:10.576
4057	13	1	13.2404200	77.7171400	0.00	2026-11-24 12:04:16.575
4058	13	1	13.2404750	77.7171900	0.00	2026-11-24 12:04:21.579
4059	13	1	13.2404983	77.7171600	0.00	2026-11-24 12:04:27.579
4060	13	1	13.2405017	77.7171767	0.00	2026-11-24 12:04:33.574
4061	13	1	13.2404683	77.7172683	0.00	2026-11-24 12:04:38.577
4062	13	1	13.2404250	77.7172983	0.00	2026-11-24 12:04:43.579
4063	13	1	13.2403767	77.7172983	0.00	2026-11-24 12:04:49.576
4064	13	1	13.2403833	77.7172367	0.00	2026-11-24 12:04:54.576
4065	13	1	13.2404250	77.7172200	0.00	2026-11-24 12:04:59.576
4066	13	1	13.2405017	77.7172500	0.00	2026-11-24 12:05:04.578
4067	13	1	13.2405817	77.7172983	0.00	2026-11-24 12:05:10.576
4068	13	1	13.2405517	77.7172083	0.00	2026-11-24 12:05:15.576
4069	13	1	13.2405133	77.7172000	0.00	2026-11-24 12:05:21.575
4070	13	1	13.2405300	77.7172417	0.00	2026-11-24 12:05:26.578
4071	13	1	13.2405783	77.7172800	0.00	2026-11-24 12:05:32.579
4072	13	1	13.2406217	77.7172983	0.00	2026-11-24 12:05:38.577
4073	13	1	13.2406700	77.7173333	0.00	2026-11-24 12:05:43.577
4074	13	1	13.2407450	77.7173983	0.00	2026-11-24 12:05:49.577
4075	13	1	13.2407567	77.7173733	0.00	2026-11-24 12:05:54.576
4076	13	1	13.2407833	77.7173583	0.00	2026-11-24 12:06:00.572
4077	13	1	13.2407817	77.7173483	0.00	2026-11-24 12:06:05.577
4078	13	1	13.2407483	77.7173683	0.00	2026-11-24 12:06:11.576
4079	13	1	13.2407800	77.7173533	0.00	2026-11-24 12:06:17.577
4080	13	1	13.2408000	77.7173583	0.00	2026-11-24 12:06:22.575
4081	13	1	13.2408483	77.7174017	0.00	2026-11-24 12:06:28.575
4082	13	1	13.2408967	77.7174250	0.00	2026-11-24 12:06:33.577
4083	13	1	13.2408967	77.7174100	0.00	2026-11-24 12:06:39.577
4084	13	1	13.2408867	77.7174050	0.00	2026-11-24 12:06:44.578
4085	13	1	13.2409100	77.7174283	0.00	2026-11-24 12:06:50.579
4086	13	1	13.2409017	77.7174417	0.00	2026-11-24 12:06:56.579
4087	13	1	13.2409083	77.7174517	0.00	2026-11-24 12:07:01.575
4088	13	1	13.2409200	77.7174283	0.00	2026-11-24 12:07:06.574
4089	13	1	13.2409383	77.7174267	0.00	2026-11-24 12:07:11.575
4090	13	1	13.2409383	77.7174417	0.00	2026-11-24 12:07:17.577
4091	13	1	13.2408633	77.7173817	0.00	2026-11-24 12:07:23.578
4092	13	1	13.2407617	77.7173200	0.00	2026-11-24 12:07:28.576
4093	13	1	13.2406500	77.7172783	0.00	2026-11-24 12:07:34.578
4094	13	1	13.2406467	77.7173283	0.00	2026-11-24 12:07:40.578
4095	13	1	13.2406600	77.7173967	0.00	2026-11-24 12:07:46.579
4096	13	1	13.2406717	77.7174167	0.00	2026-11-24 12:07:51.576
4097	13	1	13.2406967	77.7174767	0.00	2026-11-24 12:07:57.574
4098	13	1	13.2405583	77.7172383	0.00	2026-11-24 12:08:03.58
4099	13	1	13.2404633	77.7171233	0.00	2026-11-24 12:08:09.578
4100	13	1	13.2405300	77.7172083	0.00	2026-11-24 12:08:15.574
4101	13	1	13.2406067	77.7173317	0.00	2026-11-24 12:08:20.578
4102	13	1	13.2407050	77.7174667	0.00	2026-11-24 12:08:26.578
4103	13	1	13.2406767	77.7174267	0.00	2026-11-24 12:08:31.578
4104	13	1	13.2406967	77.7172850	0.00	2026-11-24 12:08:42.574
4105	13	1	13.2406600	77.7172500	0.00	2026-11-24 12:08:48.576
4106	13	1	13.2406233	77.7172383	0.00	2026-11-24 12:08:53.578
4107	13	1	13.2405917	77.7172717	0.00	2026-11-24 12:08:58.577
4108	13	1	13.2405367	77.7172817	0.00	2026-11-24 12:09:04.571
4109	13	1	13.2404383	77.7171883	0.00	2026-11-24 12:09:09.577
4110	13	1	13.2404567	77.7172117	0.00	2026-11-24 12:09:14.578
4111	13	1	13.2405567	77.7173133	0.00	2026-11-24 12:09:20.581
4112	13	1	13.2406350	77.7174600	0.00	2026-11-24 12:09:26.579
4113	13	1	13.2407117	77.7174550	0.00	2026-11-24 12:09:32.577
4114	13	1	13.2407300	77.7174533	0.00	2026-11-24 12:09:37.577
4115	13	1	13.2406533	77.7174367	0.00	2026-11-24 12:09:43.576
4116	13	1	13.2405917	77.7174617	0.00	2026-11-24 12:09:49.579
4117	13	1	13.2406433	77.7175750	0.00	2026-11-24 12:09:55.578
4118	13	1	13.2400572	77.7168168	\N	2026-11-24 12:10:11.637
4119	13	1	13.2402402	77.7163933	\N	2026-11-24 12:10:21.545
4120	13	1	13.2399676	77.7168227	\N	2026-11-24 12:10:31.434
4121	13	1	13.2399650	77.7168269	\N	2026-11-24 12:10:41.317
4122	13	1	13.2399650	77.7168268	\N	2026-11-24 12:10:51.242
4123	13	1	13.2399682	77.7168236	\N	2026-11-24 12:11:01.098
4124	13	1	13.2399610	77.7168227	\N	2026-11-24 12:11:10.968
4125	13	1	13.2400572	77.7168175	\N	2026-11-24 12:11:20.913
4126	13	1	13.2400572	77.7168175	\N	2026-11-24 12:11:25.92
4127	13	1	13.2400213	77.7165329	\N	2026-11-24 12:11:41.141
4128	13	1	13.2399609	77.7168143	\N	2026-11-24 12:11:51.042
4129	13	1	13.2399689	77.7168203	\N	2026-11-24 12:12:00.94
4130	13	1	13.2399688	77.7168193	\N	2026-11-24 12:12:10.848
4131	13	1	13.2411203	77.7157346	\N	2026-11-24 12:12:20.753
4132	13	1	13.2399689	77.7168203	\N	2026-11-24 12:12:30.683
4133	13	1	13.2404047	77.7163042	\N	2026-11-24 12:12:40.625
4134	13	1	13.2401261	77.7166733	\N	2026-11-24 12:12:50.558
4135	13	1	13.2399689	77.7168203	\N	2026-11-24 12:13:00.506
4136	13	1	13.2399924	77.7167548	\N	2026-11-24 12:13:10.465
4137	13	1	13.2411267	77.7157478	\N	2026-11-24 12:13:20.399
4138	13	1	13.2411179	77.7157227	\N	2026-11-24 12:13:30.322
4139	13	1	13.2400643	77.7168117	\N	2026-11-24 12:13:40.235
4140	13	1	13.2399689	77.7168203	\N	2026-11-24 12:13:50.176
4141	13	1	13.2399689	77.7168203	\N	2026-11-24 12:13:55.191
4142	13	1	13.2411299	77.7157462	\N	2026-11-24 12:14:10.347
4143	13	1	13.2399469	77.7166933	\N	2026-11-24 12:14:20.27
4144	13	1	13.2400719	77.7168040	\N	2026-11-24 12:14:30.171
4145	13	1	13.2399686	77.7168214	\N	2026-11-24 12:14:40.08
4146	13	1	13.2399646	77.7168149	\N	2026-11-24 12:14:49.995
4147	13	1	13.2399689	77.7168203	\N	2026-11-24 12:14:59.906
4148	13	1	13.2399650	77.7168220	\N	2026-11-24 12:15:09.793
4149	13	1	13.2399650	77.7168220	\N	2026-11-24 12:15:14.804
4150	13	1	13.2399453	77.7174391	\N	2026-11-24 12:15:29.585
4151	13	1	13.2399453	77.7174391	\N	2026-11-24 12:15:34.592
4152	13	1	13.2398967	77.7171239	\N	2026-11-24 12:15:49.336
4153	13	1	13.2399609	77.7168143	\N	2026-11-24 12:15:59.247
4154	13	1	13.2399609	77.7168143	\N	2026-11-24 12:16:04.261
4155	13	1	13.2399828	77.7175239	\N	2026-11-24 12:16:19.053
4156	13	1	13.2399523	77.7168144	\N	2026-11-24 12:16:28.95
4157	13	1	13.2399470	77.7168122	\N	2026-11-24 12:16:38.865
4158	13	1	13.2411225	77.7157386	\N	2026-11-24 12:16:48.806
4159	13	1	13.2399386	77.7170732	\N	2026-11-24 12:16:58.681
4160	13	1	13.2411637	77.7157303	\N	2026-11-24 12:17:08.565
4161	13	1	13.2399688	77.7168193	\N	2026-11-24 12:17:18.463
4162	13	1	13.2400248	77.7167210	\N	2026-11-24 12:17:28.372
4163	13	1	13.2400341	77.7166988	\N	2026-11-24 12:17:38.291
4164	13	1	13.2399523	77.7168144	\N	2026-11-24 12:17:48.197
4165	13	1	13.2399971	77.7165940	\N	2026-11-24 12:17:57.73
4166	13	1	13.2399406	77.7176062	\N	2026-11-24 12:18:07.973
4167	13	1	13.2399485	77.7168138	\N	2026-11-24 12:18:17.875
4168	13	1	13.2411182	77.7157280	\N	2026-11-24 12:18:27.782
4169	13	1	13.2411182	77.7157280	\N	2026-11-24 12:18:32.796
4170	13	1	13.2427310	77.7164136	\N	2026-11-24 12:18:42.669
4171	13	1	13.2411230	77.7157437	\N	2026-11-24 12:18:57.806
4172	13	1	13.2398973	77.7173259	\N	2026-11-24 12:19:07.703
4173	13	1	13.2399609	77.7168143	\N	2026-11-24 12:19:17.588
4174	13	1	13.2399977	77.7174886	\N	2026-11-24 12:19:27.473
4175	13	1	13.2399977	77.7174886	\N	2026-11-24 12:19:32.477
4176	13	1	13.2399676	77.7168259	\N	2026-11-24 12:19:47.28
4177	13	1	13.2399676	77.7168259	\N	2026-11-24 12:19:52.291
4178	13	1	13.2399523	77.7168144	\N	2026-11-24 12:20:07.438
4179	13	1	13.2399466	77.7174206	\N	2026-11-24 12:20:17.316
4180	13	1	13.2399523	77.7168144	\N	2026-11-24 12:20:27.223
4181	13	1	13.2399611	77.7168463	\N	2026-11-24 12:21:12.09
4182	13	1	13.2399469	77.7173992	\N	2026-11-24 12:22:01.879
4183	13	1	13.2399466	77.7174206	\N	2026-11-24 12:23:01.965
4184	13	1	13.2399466	77.7174206	\N	2026-11-24 12:23:37.226
4185	13	1	13.2399611	77.7168463	\N	2026-11-24 12:21:12.09
4186	13	1	13.2399469	77.7173992	\N	2026-11-24 12:22:01.879
4187	13	1	13.2399466	77.7174206	\N	2026-11-24 12:23:01.965
4188	13	1	13.2399466	77.7174206	\N	2026-11-24 12:23:37.226
4189	14	2	13.2407963	77.7174947	\N	2026-11-27 02:41:09.138
4190	14	2	13.2409986	77.7176680	\N	2026-11-27 02:45:01.466
4191	14	2	13.2409986	77.7176680	\N	2026-11-27 02:45:05.06
4192	14	2	13.2407462	77.7182259	\N	2026-11-27 02:57:24.494
4193	14	2	13.2413700	77.7174733	\N	2026-11-27 03:02:41.368
4194	14	2	13.2412398	77.7173680	\N	2026-11-27 03:02:46.774
4195	14	2	13.2406433	77.7181690	\N	2026-11-27 03:10:07.635
4196	14	2	13.2406858	77.7178843	\N	2026-11-27 03:10:21.724
4197	14	2	13.2406684	77.7176725	\N	2026-11-27 03:10:29.642
4198	14	2	13.2407915	77.7173785	\N	2026-11-27 03:10:35.786
4199	14	2	13.2407915	77.7173785	\N	2026-11-27 03:10:56.47
4200	14	2	13.0721000	77.7922000	\N	2026-11-27 03:12:04.991
4201	14	2	13.2408478	77.7179662	\N	2026-11-27 03:12:27.168
4202	14	2	13.2408559	77.7179998	\N	2026-11-27 03:12:41.119
4203	14	2	13.0721000	77.7922000	\N	2026-11-27 03:20:13.155
4204	14	2	13.2408485	77.7173973	\N	2026-11-27 03:20:30.106
4205	14	2	13.0721000	77.7922000	\N	2026-11-27 03:20:53.978
4206	14	2	13.2409936	77.7173206	\N	2026-11-27 03:22:09.698
4207	14	2	13.2409464	77.7172400	\N	2026-11-27 03:22:15.774
4208	14	2	13.2409464	77.7172400	\N	2026-11-27 03:23:00.426
4209	14	2	13.2408184	77.7173268	\N	2026-11-27 03:23:06.762
4210	14	2	13.2408553	77.7182653	\N	2026-11-27 03:26:16.761
4211	14	2	13.2408503	77.7180777	\N	2026-11-27 03:26:32.824
4212	14	2	13.2408734	77.7179108	\N	2026-11-27 03:26:44.258
4213	14	2	13.2408981	77.7179850	\N	2026-11-27 03:27:22.265
4214	14	2	13.2411111	77.7176887	\N	2026-11-27 03:28:31.775
4215	14	2	13.2408357	77.7176035	\N	2026-11-27 03:28:44.264
4216	13	1	13.2407800	77.7174172	\N	2026-11-27 03:29:38.389
4217	14	2	13.2408103	77.7178344	\N	2026-11-27 03:29:52.281
4218	14	2	13.2408464	77.7176881	\N	2026-11-27 03:30:05.575
4219	13	1	13.0721000	77.7922000	\N	2026-11-27 03:30:41.092
4220	14	2	13.2409649	77.7178825	\N	2026-11-27 03:30:44.725
4221	13	1	13.2409649	77.7178825	\N	2026-11-27 03:30:59.247
4222	13	1	13.0721000	77.7922000	\N	2026-11-27 03:31:16.592
4223	13	1	13.2408841	77.7174045	\N	2026-11-27 03:31:42.237
4224	13	1	13.2407587	77.7179076	\N	2026-11-27 03:32:02.381
4225	13	1	13.2407415	77.7181783	\N	2026-11-27 03:32:16.248
4226	13	1	13.2407522	77.7181988	\N	2026-11-27 03:32:42.09
4227	14	2	13.2407732	77.7178932	\N	2026-11-27 04:08:00.755
4228	14	2	13.2407732	77.7178932	\N	2026-11-27 04:08:03.474
4229	14	2	13.2406081	77.7177593	\N	2026-11-27 04:08:21.519
4230	14	2	13.2406211	77.7179605	\N	2026-11-27 04:08:42.689
4231	13	1	13.2406211	77.7179605	\N	2026-11-27 04:09:52.377
4232	13	1	13.2406207	77.7179902	\N	2026-11-27 04:10:06.377
4233	13	1	13.2406878	77.7177842	\N	2026-11-27 04:10:17.579
4234	13	1	13.0721000	77.7922000	\N	2026-11-27 04:10:39.397
4235	13	1	13.2406908	77.7178163	\N	2026-11-27 04:11:02.464
4236	14	2	13.0721000	77.7922000	\N	2026-11-27 04:33:10.267
4237	14	2	13.2407682	77.7183146	\N	2026-11-27 04:38:26.598
4238	14	2	13.2405429	77.7185191	\N	2026-11-27 04:54:12.333
4239	14	2	13.2405316	77.7185604	\N	2026-11-27 04:54:24.769
4240	14	2	13.2405661	77.7182276	\N	2026-11-27 04:54:37.271
4241	14	2	13.2405661	77.7182276	\N	2026-11-27 04:55:05.222
4242	14	2	13.2408461	77.7180410	\N	2026-11-27 05:02:10.694
4243	14	2	13.2408461	77.7180410	\N	2026-11-27 05:02:17.816
4244	14	2	13.2406181	77.7178785	\N	2026-11-27 05:03:38.023
4245	14	2	13.2407502	77.7173096	\N	2026-11-27 05:07:22.905
4246	14	2	13.2403539	77.7179715	\N	2026-11-27 05:32:57.428
4247	14	2	13.0721000	77.7922000	\N	2026-11-27 05:33:49.972
4248	14	2	13.2406742	77.7178962	\N	2026-11-27 05:34:38.906
4249	14	2	13.0721000	77.7922000	\N	2026-11-27 05:35:05.441
4250	14	2	13.2405735	77.7182632	\N	2026-11-27 05:59:17.766
4251	14	2	13.2405735	77.7182632	\N	2026-11-27 05:59:24.104
4252	14	2	13.2404050	77.7180587	\N	2026-11-27 05:59:38.146
4253	14	2	13.2408197	77.7179768	\N	2026-11-27 06:03:59.609
4254	14	2	13.2408197	77.7179768	\N	2026-11-27 06:04:07.394
4255	14	2	13.2406060	77.7190690	\N	2026-11-27 06:10:48.344
4256	14	2	13.2406825	77.7174190	\N	2026-11-27 06:12:51.502
4257	14	2	13.2406280	77.7166955	\N	2026-11-27 06:21:09.615
4258	14	2	13.2406382	77.7176778	\N	2026-11-27 06:22:19.008
4259	14	2	13.2407210	77.7183995	\N	2026-11-27 06:22:38.28
4260	14	2	13.2407036	77.7184469	\N	2026-11-27 06:22:58.175
4261	14	2	12.9786000	77.3640000	\N	2026-11-27 06:24:13.898
4262	14	2	12.9786000	77.3640000	\N	2026-11-27 06:24:35.507
4263	14	2	13.2401545	77.7188260	\N	2026-11-27 06:26:57.148
4264	14	2	13.2401545	77.7188260	\N	2026-11-27 06:27:01.607
4265	14	2	13.2406483	77.7171530	\N	2026-11-27 06:29:02.721
4266	14	2	13.2409171	77.7177461	\N	2026-11-27 08:04:01.188
4267	14	2	13.2405102	77.7181876	\N	2026-11-27 08:04:47.53
4268	14	2	13.2405318	77.7182197	\N	2026-11-27 08:05:07.763
\.


--
-- Data for Name: bus_locations_timezone_backup_20261124; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus_locations_timezone_backup_20261124 (location_id, trip_id, bus_id, latitude, longitude, speed, recorded_at) FROM stdin;
121	12	1	13.2401604	77.7167967	0.07	2026-11-24 00:04:00.602
122	12	1	13.2401589	77.7167994	0.07	2026-11-24 00:04:48.628
123	12	1	13.2401593	77.7167989	0.06	2026-11-24 00:04:54.646
124	12	1	13.2401581	77.7167987	0.06	2026-11-24 00:04:59.622
125	12	1	13.2401584	77.7167984	0.06	2026-11-24 00:05:05.64
126	12	1	13.2401570	77.7167983	0.06	2026-11-24 00:05:10.616
127	12	1	13.2401559	77.7167975	0.06	2026-11-24 00:05:16.632
128	12	1	13.2401559	77.7167955	0.06	2026-11-24 00:05:22.651
129	12	1	13.2401567	77.7167954	0.03	2026-11-24 00:05:28.572
130	12	1	13.2401565	77.7167950	0.06	2026-11-24 00:05:33.644
131	12	1	13.2401567	77.7167954	0.06	2026-11-24 00:05:39.664
132	12	1	13.2401566	77.7167947	0.06	2026-11-24 00:05:44.64
133	12	1	13.2401571	77.7167950	0.06	2026-11-24 00:05:49.615
134	12	1	13.2401579	77.7167947	0.07	2026-11-24 00:05:54.593
135	12	1	13.2401578	77.7167946	0.07	2026-11-24 00:05:59.685
136	12	1	13.2401581	77.7167938	0.06	2026-11-24 00:06:05.586
137	12	1	13.2401579	77.7167935	0.07	2026-11-24 00:06:10.679
138	12	1	13.2401588	77.7167934	0.06	2026-11-24 00:06:16.58
139	12	1	13.2401590	77.7167935	0.06	2026-11-24 00:06:21.672
140	12	1	13.2401590	77.7167929	0.06	2026-11-24 00:06:26.649
141	12	1	13.2401574	77.7167932	0.07	2026-11-24 00:06:32.667
142	12	1	13.2401587	77.7167934	0.07	2026-11-24 00:06:37.642
143	12	1	13.2401591	77.7167938	0.06	2026-11-24 00:06:42.62
144	12	1	13.2401584	77.7167963	0.07	2026-11-24 00:06:48.638
145	12	1	13.2401591	77.7167970	0.06	2026-11-24 00:06:54.655
146	12	1	13.2401580	77.7167976	0.06	2026-11-24 00:07:00.673
147	12	1	13.2401582	77.7167981	0.06	2026-11-24 00:07:06.574
148	12	1	13.2401578	77.7167988	0.07	2026-11-24 00:07:11.667
149	12	1	13.2401566	77.7167991	0.06	2026-11-24 00:07:16.643
150	12	1	13.2401565	77.7167987	0.07	2026-11-24 00:07:22.661
151	12	1	13.2401563	77.7167997	0.07	2026-11-24 00:07:27.637
152	12	1	13.2401562	77.7168000	0.06	2026-11-24 00:07:33.654
153	12	1	13.2401547	77.7167994	0.06	2026-11-24 00:07:38.631
154	12	1	13.2401540	77.7167991	0.06	2026-11-24 00:07:44.649
155	12	1	13.2401544	77.7167994	0.06	2026-11-24 00:07:49.625
156	12	1	13.2401572	77.7167988	0.06	2026-11-24 00:07:55.643
157	12	1	13.2401584	77.7167976	0.06	2026-11-24 00:08:00.618
158	12	1	13.2401584	77.7167969	0.07	2026-11-24 00:08:06.521
159	12	1	13.2401587	77.7167972	0.07	2026-11-24 00:08:11.613
160	12	1	13.2401592	77.7167968	0.06	2026-11-24 00:08:17.629
161	12	1	13.2401600	77.7167969	0.06	2026-11-24 00:08:23.648
162	12	1	13.2401597	77.7167969	0.06	2026-11-24 00:08:28.623
163	12	1	13.2401597	77.7167979	0.06	2026-11-24 00:08:34.642
164	12	1	13.2401586	77.7167977	0.06	2026-11-24 00:08:40.572
165	12	1	13.2401589	77.7167988	0.07	2026-11-24 00:08:45.636
166	12	1	13.2401583	77.7167989	0.06	2026-11-24 00:08:50.612
167	12	1	13.2401577	77.7167989	0.06	2026-11-24 00:08:56.63
168	12	1	13.2401575	77.7168004	0.06	2026-11-24 00:09:01.606
169	12	1	13.2401568	77.7168010	0.07	2026-11-24 00:09:07.623
170	12	1	13.2401555	77.7168013	0.06	2026-11-24 00:09:12.6
171	12	1	13.2401545	77.7168008	0.05	2026-11-24 00:09:18.616
172	12	1	13.2401551	77.7168000	0.07	2026-11-24 00:09:24.635
173	12	1	13.2401548	77.7167993	0.06	2026-11-24 00:09:30.652
174	12	1	13.2401555	77.7167992	0.06	2026-11-24 00:09:35.628
175	12	1	13.2401579	77.7167993	0.06	2026-11-24 00:09:41.646
176	12	1	13.2401589	77.7167985	0.07	2026-11-24 00:09:47.664
177	12	1	13.2401590	77.7167977	0.06	2026-11-24 00:09:52.64
178	12	1	13.2401583	77.7167977	0.06	2026-11-24 00:09:58.658
179	12	1	13.2401585	77.7167970	0.07	2026-11-24 00:10:03.634
180	12	1	13.2401581	77.7167968	0.07	2026-11-24 00:10:09.651
181	12	1	13.2401581	77.7167969	0.07	2026-11-24 00:10:15.669
182	12	1	13.2401587	77.7167965	0.06	2026-11-24 00:10:20.644
183	12	1	13.2401589	77.7167967	0.07	2026-11-24 00:10:26.125
184	12	1	13.2401591	77.7167973	0.06	2026-11-24 00:10:31.638
185	12	1	13.2401573	77.7167979	0.07	2026-11-24 00:10:36.615
186	12	1	13.2401571	77.7167983	0.07	2026-11-24 00:10:42.633
187	12	1	13.2401556	77.7167988	0.07	2026-11-24 00:10:47.608
188	12	1	13.2401571	77.7167991	0.06	2026-11-24 00:10:53.625
189	12	1	13.2401565	77.7168010	0.06	2026-11-24 00:10:59.644
190	12	1	13.2401567	77.7168009	0.07	2026-11-24 00:11:04.62
191	12	1	13.2401557	77.7168010	0.07	2026-11-24 00:11:10.638
192	12	1	13.2401557	77.7168022	0.07	2026-11-24 00:11:16.655
193	12	1	13.2401559	77.7168016	0.06	2026-11-24 00:11:22.673
194	12	1	13.2401558	77.7168017	0.07	2026-11-24 00:11:27.648
195	12	1	13.2401578	77.7168019	0.06	2026-11-24 00:11:33.667
196	12	1	13.2401574	77.7168020	0.06	2026-11-24 00:11:39.579
197	12	1	13.2401576	77.7168031	0.06	2026-11-24 00:11:45.585
198	12	1	13.2401580	77.7168050	0.06	2026-11-24 00:11:51.604
199	12	1	13.2401586	77.7168014	0.06	2026-11-24 00:11:56.927
200	12	1	13.2401570	77.7168015	0.06	2026-11-24 00:12:02.598
201	12	1	13.2401543	77.7168017	0.05	2026-11-24 00:12:08.615
202	12	1	13.2401539	77.7168003	0.06	2026-11-24 00:12:14.632
203	12	1	13.2401534	77.7167987	0.07	2026-11-24 00:12:20.651
204	12	1	13.2401537	77.7167974	0.07	2026-11-24 00:12:26.667
205	12	1	13.2401537	77.7167972	0.06	2026-11-24 00:12:31.644
206	12	1	13.2401552	77.7167954	0.06	2026-11-24 00:12:36.621
207	12	1	13.2401552	77.7167944	0.06	2026-11-24 00:12:42.637
208	12	1	13.2401565	77.7167948	0.07	2026-11-24 00:12:47.613
209	12	1	13.2401575	77.7167957	0.05	2026-11-24 00:12:52.589
210	12	1	13.2401574	77.7167963	0.06	2026-11-24 00:12:57.681
211	12	1	13.2401586	77.7167959	0.06	2026-11-24 00:13:03.583
212	12	1	13.2401590	77.7167965	0.06	2026-11-24 00:13:08.676
213	12	1	13.2401596	77.7167965	0.06	2026-11-24 00:13:13.651
214	12	1	13.2401600	77.7167978	0.07	2026-11-24 00:13:19.67
215	12	1	13.2401607	77.7167984	0.06	2026-11-24 00:13:25.577
216	12	1	13.2401604	77.7167990	0.07	2026-11-24 00:13:31.59
217	12	1	13.2401599	77.7168004	0.06	2026-11-24 00:13:36.574
218	12	1	13.2401576	77.7168000	0.06	2026-11-24 00:13:41.658
219	12	1	13.2401568	77.7167991	0.06	2026-11-24 00:13:46.749
220	12	1	13.2401557	77.7167996	0.06	2026-11-24 00:13:52.652
221	12	1	13.2401555	77.7167995	0.06	2026-11-24 00:13:57.628
222	12	1	13.2401557	77.7167998	0.07	2026-11-24 00:14:02.604
223	12	1	13.2401554	77.7168003	0.06	2026-11-24 00:14:08.622
224	12	1	13.2401552	77.7168008	0.07	2026-11-24 00:14:13.598
225	12	1	13.2401564	77.7168007	0.05	2026-11-24 00:14:19.616
226	12	1	13.2401580	77.7168010	0.06	2026-11-24 00:14:25.633
227	12	1	13.2401572	77.7168004	0.06	2026-11-24 00:14:30.61
228	12	1	13.2401572	77.7168005	0.05	2026-11-24 00:14:35.585
229	12	1	13.2401558	77.7168001	0.06	2026-11-24 00:14:41.604
230	12	1	13.2401574	77.7167995	0.07	2026-11-24 00:14:46.694
231	12	1	13.2401571	77.7167993	0.05	2026-11-24 00:14:52.596
232	12	1	13.2401570	77.7167985	0.06	2026-11-24 00:14:58.614
233	12	1	13.2401577	77.7167979	0.07	2026-11-24 00:15:04.632
234	12	1	13.2401576	77.7167983	0.06	2026-11-24 00:15:09.608
235	12	1	13.2401572	77.7167979	0.06	2026-11-24 00:15:15.626
236	12	1	13.2401570	77.7167987	0.07	2026-11-24 00:15:20.602
237	12	1	13.2401575	77.7167987	0.07	2026-11-24 00:15:26.62
238	12	1	13.2401570	77.7167987	0.06	2026-11-24 00:15:31.596
239	12	1	13.2401567	77.7167984	0.06	2026-11-24 00:15:37.151
240	12	1	13.2401553	77.7167980	0.07	2026-11-24 00:15:42.589
241	12	1	13.2401556	77.7167976	0.06	2026-11-24 00:15:47.682
242	12	1	13.2401561	77.7167819	0.05	2026-11-24 00:15:53.584
243	12	1	13.2401555	77.7167706	0.06	2026-11-24 00:15:58.675
244	12	1	13.2401557	77.7167603	0.06	2026-11-24 00:16:03.883
245	12	1	13.2401557	77.7167541	0.07	2026-11-24 00:16:09.669
246	12	1	13.2401637	77.7167388	0.08	2026-11-24 00:16:15.577
247	12	1	13.2401751	77.7167246	0.07	2026-11-24 00:16:21.589
248	12	1	13.2401748	77.7167196	0.06	2026-11-24 00:16:26.681
249	12	1	13.2401746	77.7167170	0.07	2026-11-24 00:16:32.583
250	12	1	13.2401730	77.7167132	0.06	2026-11-24 00:16:37.675
251	12	1	13.2401691	77.7167082	0.06	2026-11-24 00:16:43.576
252	12	1	13.2401682	77.7167069	0.06	2026-11-24 00:16:48.667
253	12	1	13.2401670	77.7167055	0.06	2026-11-24 00:16:54.455
254	12	1	13.2401655	77.7167048	0.06	2026-11-24 00:16:59.662
255	12	1	13.2401650	77.7167046	0.07	2026-11-24 00:17:05.575
256	12	1	13.2401650	77.7167045	0.06	2026-11-24 00:17:10.656
257	12	1	13.2401651	77.7167052	0.06	2026-11-24 00:17:15.631
258	12	1	13.2401650	77.7167058	0.05	2026-11-24 00:17:20.607
259	12	1	13.2401650	77.7167060	0.06	2026-11-24 00:17:25.584
260	12	1	13.2401650	77.7167062	0.06	2026-11-24 00:17:30.675
261	12	1	13.2401644	77.7167067	0.06	2026-11-24 00:17:36.577
262	12	1	13.2401646	77.7167071	0.06	2026-11-24 00:17:42.595
263	12	1	13.2401648	77.7167086	0.06	2026-11-24 00:17:47.686
264	12	1	13.2401643	77.7167094	0.07	2026-11-24 00:17:53.589
265	12	1	13.2401653	77.7167105	0.06	2026-11-24 00:17:59.607
266	12	1	13.2401667	77.7167093	0.07	2026-11-24 00:18:04.583
267	12	1	13.2401677	77.7167084	0.06	2026-11-24 00:18:10.601
268	12	1	13.2401683	77.7167084	0.07	2026-11-24 00:18:15.691
269	12	1	13.2401684	77.7167078	0.07	2026-11-24 00:18:21.594
270	12	1	13.2401673	77.7167085	0.07	2026-11-24 00:18:26.686
271	12	1	13.2401669	77.7167078	0.07	2026-11-24 00:18:32.588
272	12	1	13.2401671	77.7167083	0.06	2026-11-24 00:18:37.68
273	12	1	13.2401679	77.7167072	0.05	2026-11-24 00:18:42.655
274	12	1	13.2401660	77.7167068	0.07	2026-11-24 00:18:48.674
275	12	1	13.2401655	77.7167053	0.07	2026-11-24 00:18:54.579
276	12	1	13.2401641	77.7167055	0.05	2026-11-24 00:19:00.593
277	12	1	13.2401646	77.7167063	0.07	2026-11-24 00:19:05.578
278	12	1	13.2401638	77.7167077	0.06	2026-11-24 00:19:11.586
279	12	1	13.2401640	77.7167092	0.06	2026-11-24 00:19:16.678
280	12	1	13.2401654	77.7167089	0.06	2026-11-24 00:19:22.58
281	12	1	13.2401666	77.7167086	0.06	2026-11-24 00:19:27.673
282	12	1	13.2401668	77.7167087	0.07	2026-11-24 00:19:33.575
283	12	1	13.2401668	77.7167087	0.06	2026-11-24 00:19:38.666
284	12	1	13.2401682	77.7167079	0.06	2026-11-24 00:19:44.575
285	12	1	13.2401689	77.7167076	0.06	2026-11-24 00:19:49.66
286	12	1	13.2401705	77.7167074	0.07	2026-11-24 00:19:55.678
287	12	1	13.2401703	77.7167074	0.07	2026-11-24 00:20:00.655
288	12	1	13.2401705	77.7167067	0.06	2026-11-24 00:20:05.901
289	12	1	13.2401702	77.7167061	0.07	2026-11-24 00:20:11.648
290	12	1	13.2401697	77.7167056	0.06	2026-11-24 00:20:16.624
291	12	1	13.2401691	77.7167059	0.08	2026-11-24 00:20:22.642
292	12	1	13.2401681	77.7167059	0.05	2026-11-24 00:20:28.659
293	12	1	13.2401676	77.7167045	0.06	2026-11-24 00:20:34.678
294	12	1	13.2401679	77.7167042	0.07	2026-11-24 00:20:40.58
295	12	1	13.2401667	77.7167043	0.07	2026-11-24 00:20:45.671
296	12	1	13.2401651	77.7167051	0.07	2026-11-24 00:20:51.576
297	12	1	13.2401637	77.7167055	0.07	2026-11-24 00:20:56.664
298	12	1	13.2401633	77.7167054	0.06	2026-11-24 00:21:02.572
299	12	1	13.2401623	77.7167064	0.06	2026-11-24 00:21:07.659
300	12	1	13.2401626	77.7167074	0.06	2026-11-24 00:21:13.675
301	12	1	13.2401630	77.7167077	0.07	2026-11-24 00:21:19.577
302	12	1	13.2401635	77.7167083	0.07	2026-11-24 00:21:24.67
303	12	1	13.2401626	77.7167095	0.06	2026-11-24 00:21:30.58
304	12	1	13.2401638	77.7167102	0.06	2026-11-24 00:21:35.663
305	12	1	13.2401646	77.7167094	0.06	2026-11-24 00:21:41.682
306	12	1	13.2401641	77.7167078	0.06	2026-11-24 00:21:47.582
307	12	1	13.2401635	77.7167072	0.06	2026-11-24 00:21:53.601
308	12	1	13.2401631	77.7167079	0.05	2026-11-24 00:21:58.577
309	12	1	13.2401624	77.7167072	0.07	2026-11-24 00:22:03.669
310	12	1	13.2401623	77.7167077	0.06	2026-11-24 00:22:08.645
311	12	1	13.2401632	77.7167068	0.07	2026-11-24 00:22:14.662
312	13	1	13.2401646	77.7167120	\N	2026-11-24 00:23:12.089
313	13	1	13.2400221	77.7168420	0.26	2026-11-24 00:23:18.213
314	13	1	13.2400833	77.7168317	0.20	2026-11-24 00:23:23.609
315	13	1	13.2400886	77.7168338	0.11	2026-11-24 00:23:28.585
316	13	1	13.2400943	77.7168347	0.09	2026-11-24 00:23:34.603
317	13	1	13.2400951	77.7168369	0.09	2026-11-24 00:23:39.579
318	13	1	13.2400975	77.7168378	0.09	2026-11-24 00:23:44.671
319	13	1	13.2401106	77.7168296	0.06	2026-11-24 00:23:50.578
320	13	1	13.2401230	77.7168143	0.08	2026-11-24 00:23:55.664
321	13	1	13.2401305	77.7168098	0.06	2026-11-24 00:24:01.683
322	13	1	13.2401375	77.7168040	0.07	2026-11-24 00:24:06.659
323	13	1	13.2401450	77.7167962	0.06	2026-11-24 00:24:11.635
324	13	1	13.2401519	77.7167923	0.07	2026-11-24 00:24:17.653
325	13	1	13.2401576	77.7167895	0.07	2026-11-24 00:24:23.671
326	13	1	13.2401633	77.7167871	0.06	2026-11-24 00:24:28.647
327	13	1	13.2401707	77.7167833	0.06	2026-11-24 00:24:34.572
328	13	1	13.2401741	77.7167797	0.06	2026-11-24 00:24:39.642
329	13	1	13.2401781	77.7167755	0.06	2026-11-24 00:24:45.659
330	13	1	13.2401815	77.7167714	0.07	2026-11-24 00:24:51.678
331	13	1	13.2401833	77.7167691	0.06	2026-11-24 00:24:56.654
332	13	1	13.2401863	77.7167662	0.06	2026-11-24 00:25:02.671
333	13	1	13.2401886	77.7167647	0.06	2026-11-24 00:25:07.648
334	13	1	13.2401916	77.7167632	0.06	2026-11-24 00:25:13.667
335	13	1	13.2401935	77.7167622	0.06	2026-11-24 00:25:18.643
336	13	1	13.2401970	77.7167589	0.06	2026-11-24 00:25:24.429
337	13	1	13.2401989	77.7167574	0.06	2026-11-24 00:25:29.637
338	13	1	13.2402000	77.7167562	0.05	2026-11-24 00:25:35.655
339	13	1	13.2402008	77.7167558	0.07	2026-11-24 00:25:41.671
340	13	1	13.2402017	77.7167551	0.06	2026-11-24 00:25:47.578
341	13	1	13.2402027	77.7167550	0.06	2026-11-24 00:25:53.592
342	13	1	13.2402027	77.7167543	0.07	2026-11-24 00:25:58.684
343	13	1	13.2402016	77.7167568	0.05	2026-11-24 00:26:14.655
344	13	1	13.2401920	77.7167742	0.09	2026-11-24 00:26:19.621
345	13	1	13.2401653	77.7167972	0.09	2026-11-24 00:26:24.597
346	13	1	13.2401523	77.7168183	0.29	2026-11-24 00:26:29.974
347	13	1	13.2401560	77.7168283	0.15	2026-11-24 00:26:35.591
348	13	1	13.2401595	77.7168246	0.11	2026-11-24 00:26:41.257
349	13	1	13.2401524	77.7167465	0.06	2026-11-24 00:27:07.655
350	13	1	13.2401548	77.7167440	0.06	2026-11-24 00:27:13.674
351	13	1	13.2401567	77.7167430	0.05	2026-11-24 00:27:18.65
352	13	1	13.2401578	77.7167406	0.06	2026-11-24 00:27:24.667
353	13	1	13.2401574	77.7167400	0.03	2026-11-24 00:27:30.684
354	13	1	13.2401578	77.7167390	0.03	2026-11-24 00:27:36.586
355	13	1	13.2401576	77.7167388	0.03	2026-11-24 00:27:41.678
356	13	1	13.2401576	77.7167395	0.04	2026-11-24 00:27:47.579
357	13	1	13.2401570	77.7167394	0.05	2026-11-24 00:27:52.67
358	13	1	13.2401569	77.7167397	0.04	2026-11-24 00:27:58.573
359	13	1	13.2401566	77.7167397	0.03	2026-11-24 00:28:03.664
360	13	1	13.2401564	77.7167401	0.04	2026-11-24 00:28:08.64
361	13	1	13.2401566	77.7167401	0.03	2026-11-24 00:28:13.616
362	13	1	13.2401590	77.7167383	0.04	2026-11-24 00:28:19.633
363	13	1	13.2401621	77.7167362	0.03	2026-11-24 00:28:24.608
364	13	1	13.2401647	77.7167345	0.03	2026-11-24 00:28:30.626
365	13	1	13.2401655	77.7167337	0.03	2026-11-24 00:28:35.603
366	13	1	13.2401664	77.7167333	0.04	2026-11-24 00:28:40.578
367	13	1	13.2401667	77.7167332	0.03	2026-11-24 00:28:46.017
368	13	1	13.2401705	77.7167379	0.03	2026-11-24 00:28:51.577
369	13	1	13.2401729	77.7167431	0.04	2026-11-24 00:28:57.588
370	13	1	13.2401743	77.7167463	0.04	2026-11-24 00:29:02.68
371	13	1	13.2401744	77.7167483	0.04	2026-11-24 00:29:08.581
372	13	1	13.2401740	77.7167493	0.04	2026-11-24 00:29:13.674
373	13	1	13.2401739	77.7167508	0.03	2026-11-24 00:29:19.575
374	13	1	13.2401747	77.7167515	0.04	2026-11-24 00:29:24.667
375	13	1	13.2401749	77.7167522	0.04	2026-11-24 00:29:30.577
376	13	1	13.2401746	77.7167529	0.04	2026-11-24 00:29:35.659
377	13	1	13.2401752	77.7167535	0.03	2026-11-24 00:29:41.574
378	13	1	13.2401754	77.7167534	0.03	2026-11-24 00:29:46.652
379	13	1	13.2401753	77.7167527	0.04	2026-11-24 00:29:51.628
380	13	1	13.2401747	77.7167511	0.04	2026-11-24 00:29:57.646
381	13	1	13.2401745	77.7167508	0.04	2026-11-24 00:30:02.622
382	13	1	13.2401748	77.7167499	0.05	2026-11-24 00:30:08.639
383	13	1	13.2401743	77.7167497	0.03	2026-11-24 00:30:14.657
384	13	1	13.2401754	77.7167496	0.03	2026-11-24 00:30:19.632
385	13	1	13.2401755	77.7167508	0.04	2026-11-24 00:30:24.608
386	13	1	13.2401749	77.7167503	0.04	2026-11-24 00:30:30.625
387	13	1	13.2401753	77.7167500	0.03	2026-11-24 00:30:35.601
388	13	1	13.2401756	77.7167503	0.04	2026-11-24 00:30:40.577
389	13	1	13.2401751	77.7167505	0.04	2026-11-24 00:30:45.669
390	13	1	13.2401757	77.7167501	0.04	2026-11-24 00:30:50.644
391	13	1	13.2401760	77.7167509	0.03	2026-11-24 00:30:55.966
392	13	1	13.2401738	77.7167516	0.04	2026-11-24 00:31:01.636
393	13	1	13.2401672	77.7167583	0.04	2026-11-24 00:31:07.653
394	13	1	13.2401635	77.7167612	0.04	2026-11-24 00:31:12.629
395	13	1	13.2401624	77.7167623	0.04	2026-11-24 00:31:17.606
396	13	1	13.2401613	77.7167639	0.03	2026-11-24 00:31:23.623
397	13	1	13.2401609	77.7167652	0.04	2026-11-24 00:31:29.64
398	13	1	13.2401608	77.7167658	0.04	2026-11-24 00:31:34.616
399	13	1	13.2401606	77.7167664	0.03	2026-11-24 00:31:39.591
400	13	1	13.2401601	77.7167668	0.04	2026-11-24 00:31:44.682
401	13	1	13.2401607	77.7167674	0.04	2026-11-24 00:31:50.584
402	13	1	13.2401605	77.7167680	0.04	2026-11-24 00:31:55.675
403	13	1	13.2401598	77.7167685	0.04	2026-11-24 00:32:00.651
404	13	1	13.2401594	77.7167687	0.03	2026-11-24 00:32:06.668
405	13	1	13.2401609	77.7167676	0.03	2026-11-24 00:32:12.579
406	13	1	13.2401615	77.7167671	0.04	2026-11-24 00:32:18.587
407	13	1	13.2401619	77.7167674	0.03	2026-11-24 00:32:24.604
408	13	1	13.2401616	77.7167671	0.04	2026-11-24 00:32:29.578
409	13	1	13.2401620	77.7167666	0.04	2026-11-24 00:32:35.481
410	13	1	13.2401620	77.7167658	0.04	2026-11-24 00:32:40.579
411	13	1	13.2401617	77.7167656	0.04	2026-11-24 00:32:46.588
412	13	1	13.2401621	77.7167661	0.03	2026-11-24 00:32:52.606
413	13	1	13.2401618	77.7167655	0.04	2026-11-24 00:32:57.581
414	13	1	13.2401612	77.7167651	0.04	2026-11-24 00:33:02.673
415	13	1	13.2401614	77.7167649	0.04	2026-11-24 00:33:08.581
416	13	1	13.2401617	77.7167649	0.04	2026-11-24 00:33:13.665
417	13	1	13.2401613	77.7167655	0.03	2026-11-24 00:33:19.577
418	13	1	13.2401615	77.7167657	0.04	2026-11-24 00:33:24.659
419	13	1	13.2401611	77.7167661	0.04	2026-11-24 00:33:29.635
420	13	1	13.2401619	77.7167661	0.04	2026-11-24 00:33:35.42
421	13	1	13.2401620	77.7167664	0.05	2026-11-24 00:33:40.627
422	13	1	13.2401618	77.7167668	0.04	2026-11-24 00:33:46.644
423	13	1	13.2401616	77.7167665	0.03	2026-11-24 00:33:52.661
424	13	1	13.2401616	77.7167665	0.03	2026-11-24 00:33:57.636
425	13	1	13.2401613	77.7167670	0.04	2026-11-24 00:34:03.654
426	13	1	13.2401607	77.7167665	0.03	2026-11-24 00:34:08.63
427	13	1	13.2401601	77.7167654	0.04	2026-11-24 00:34:13.604
428	13	1	13.2401600	77.7167662	0.04	2026-11-24 00:34:19.621
429	13	1	13.2401604	77.7167668	0.03	2026-11-24 00:34:24.597
430	13	1	13.2401603	77.7167663	0.04	2026-11-24 00:34:30.614
431	13	1	13.2401603	77.7167659	0.04	2026-11-24 00:34:36.631
432	13	1	13.2401601	77.7167655	0.04	2026-11-24 00:34:41.607
433	13	1	13.2401603	77.7167659	0.03	2026-11-24 00:34:47.625
434	13	1	13.2401608	77.7167659	0.05	2026-11-24 00:34:52.599
435	13	1	13.2401611	77.7167659	0.03	2026-11-24 00:34:58.617
436	13	1	13.2401618	77.7167661	0.04	2026-11-24 00:35:03.592
437	13	1	13.2401621	77.7167667	0.04	2026-11-24 00:35:08.578
438	13	1	13.2401627	77.7167666	0.04	2026-11-24 00:35:14.585
439	13	1	13.2401632	77.7167670	0.03	2026-11-24 00:35:20.602
440	13	1	13.2401625	77.7167677	0.04	2026-11-24 00:35:26.618
441	13	1	13.2401619	77.7167671	0.05	2026-11-24 00:35:32.636
442	13	1	13.2401620	77.7167668	0.04	2026-11-24 00:35:37.611
443	13	1	13.2401622	77.7167664	0.04	2026-11-24 00:35:43.629
444	13	1	13.2401610	77.7167670	0.03	2026-11-24 00:35:48.604
445	13	1	13.2401605	77.7167668	0.03	2026-11-24 00:35:53.579
446	13	1	13.2401600	77.7167681	0.03	2026-11-24 00:35:58.671
447	13	1	13.2401596	77.7167678	0.04	2026-11-24 00:36:04.58
448	13	1	13.2401598	77.7167677	0.03	2026-11-24 00:36:10.589
449	13	1	13.2401601	77.7167670	0.04	2026-11-24 00:36:15.681
450	13	1	13.2401605	77.7167658	0.04	2026-11-24 00:36:21.581
451	13	1	13.2401601	77.7167662	0.03	2026-11-24 00:36:26.674
452	13	1	13.2401607	77.7167669	0.04	2026-11-24 00:36:32.58
453	13	1	13.2401608	77.7167670	0.04	2026-11-24 00:36:37.666
454	13	1	13.2401618	77.7167678	0.04	2026-11-24 00:36:42.642
455	13	1	13.2401617	77.7167679	0.04	2026-11-24 00:36:47.616
456	13	1	13.2401619	77.7167678	0.03	2026-11-24 00:36:53.634
457	13	1	13.2401625	77.7167678	0.03	2026-11-24 00:36:59.651
458	13	1	13.2401628	77.7167676	0.04	2026-11-24 00:37:04.626
459	13	1	13.2401634	77.7167678	0.04	2026-11-24 00:37:10.643
460	13	1	13.2401634	77.7167667	0.04	2026-11-24 00:37:16.66
461	13	1	13.2401633	77.7167677	0.04	2026-11-24 00:37:22.677
462	13	1	13.2401629	77.7167680	0.04	2026-11-24 00:37:28.577
463	13	1	13.2401625	77.7167677	0.04	2026-11-24 00:37:33.67
464	13	1	13.2401613	77.7167666	0.04	2026-11-24 00:38:11.623
465	13	1	13.2401600	77.7167671	0.04	2026-11-24 00:38:16.598
466	13	1	13.2401628	77.7167929	0.03	2026-11-24 00:38:28.632
467	13	1	13.2401629	77.7167957	0.04	2026-11-24 00:38:33.606
468	13	1	13.2401571	77.7168078	0.04	2026-11-24 00:38:39.624
469	13	1	13.2401544	77.7168136	0.04	2026-11-24 00:38:44.599
470	13	1	13.2401546	77.7168219	0.05	2026-11-24 00:38:50.617
471	13	1	13.2401561	77.7168275	0.03	2026-11-24 00:38:56.633
472	13	1	13.2401571	77.7168316	0.04	2026-11-24 00:39:01.609
473	13	1	13.2401586	77.7168362	0.03	2026-11-24 00:39:07.625
474	13	1	13.2401591	77.7168378	0.04	2026-11-24 00:39:12.601
475	13	1	13.2401583	77.7168387	0.04	2026-11-24 00:39:18.617
476	13	1	13.2401581	77.7168389	0.03	2026-11-24 00:39:23.594
477	13	1	13.2401586	77.7168394	0.04	2026-11-24 00:39:28.685
478	13	1	13.2401591	77.7168400	0.03	2026-11-24 00:39:34.585
479	13	1	13.2401586	77.7168403	0.04	2026-11-24 00:39:40.602
480	13	1	13.2401582	77.7168405	0.04	2026-11-24 00:39:45.58
481	13	1	13.2401585	77.7168409	0.04	2026-11-24 00:39:51.595
482	13	1	13.2401591	77.7168407	0.03	2026-11-24 00:39:56.582
483	13	1	13.2401587	77.7168405	0.04	2026-11-24 00:40:02.24
484	13	1	13.2401589	77.7168413	0.04	2026-11-24 00:40:07.679
485	13	1	13.2401581	77.7168415	0.03	2026-11-24 00:40:12.655
486	13	1	13.2401575	77.7168419	0.04	2026-11-24 00:40:17.629
487	13	1	13.2401571	77.7168419	0.04	2026-11-24 00:40:23.646
488	13	1	13.2401565	77.7168416	0.04	2026-11-24 00:40:28.623
489	13	1	13.2401579	77.7168407	0.04	2026-11-24 00:40:34.64
490	13	1	13.2401586	77.7168399	0.04	2026-11-24 00:40:39.614
491	13	1	13.2401548	77.7168379	0.04	2026-11-24 00:40:45.632
492	13	1	13.2401515	77.7168351	0.05	2026-11-24 00:40:51.648
493	13	1	13.2401506	77.7168333	0.04	2026-11-24 00:40:56.624
494	13	1	13.2401502	77.7168319	0.04	2026-11-24 00:41:01.947
495	13	1	13.2401528	77.7168268	0.04	2026-11-24 00:41:07.617
496	13	1	13.2401574	77.7168199	0.04	2026-11-24 00:41:12.593
497	13	1	13.2401612	77.7168166	0.04	2026-11-24 00:41:18.61
498	13	1	13.2401640	77.7168154	0.04	2026-11-24 00:41:23.585
499	13	1	13.2401665	77.7168145	0.03	2026-11-24 00:41:29.602
500	13	1	13.2401681	77.7168131	0.05	2026-11-24 00:41:34.578
501	13	1	13.2401686	77.7168129	0.04	2026-11-24 00:41:40.595
502	13	1	13.2401686	77.7168125	0.04	2026-11-24 00:41:45.686
503	13	1	13.2401689	77.7168121	0.05	2026-11-24 00:41:51.586
504	13	1	13.2401688	77.7168116	0.05	2026-11-24 00:41:56.679
505	13	1	13.2401682	77.7168109	0.03	2026-11-24 00:42:02.402
506	13	1	13.2401673	77.7168101	0.03	2026-11-24 00:42:07.67
507	13	1	13.2401664	77.7168114	0.05	2026-11-24 00:42:12.646
508	13	1	13.2401661	77.7168117	0.04	2026-11-24 00:42:18.663
509	13	1	13.2401667	77.7168118	0.04	2026-11-24 00:42:23.639
510	13	1	13.2401671	77.7168118	0.04	2026-11-24 00:42:29.655
511	13	1	13.2401676	77.7168120	0.03	2026-11-24 00:42:35.673
512	13	1	13.2401678	77.7168128	0.04	2026-11-24 00:42:41.577
513	13	1	13.2401684	77.7168133	0.06	2026-11-24 00:42:46.666
514	13	1	13.2401692	77.7168133	0.06	2026-11-24 00:42:52.45
515	13	1	13.2401696	77.7168138	0.04	2026-11-24 00:42:57.658
516	13	1	13.2401694	77.7168136	0.06	2026-11-24 00:43:02.749
517	13	1	13.2401696	77.7168134	0.07	2026-11-24 00:43:08.651
518	13	1	13.2401692	77.7168134	0.05	2026-11-24 00:43:13.627
519	13	1	13.2401685	77.7168145	0.07	2026-11-24 00:43:18.601
520	13	1	13.2401679	77.7168149	0.06	2026-11-24 00:43:24.619
521	13	1	13.2401684	77.7168143	0.06	2026-11-24 00:43:29.595
522	13	1	13.2401687	77.7168129	0.06	2026-11-24 00:43:35.611
523	13	1	13.2401693	77.7168110	0.06	2026-11-24 00:43:41.629
524	13	1	13.2401692	77.7168108	0.07	2026-11-24 00:43:47.645
525	13	1	13.2401677	77.7168104	0.07	2026-11-24 00:43:53.662
526	13	1	13.2401679	77.7168106	0.06	2026-11-24 00:43:58.638
527	13	1	13.2401673	77.7168117	0.07	2026-11-24 00:44:04.572
528	13	1	13.2401671	77.7168112	0.07	2026-11-24 00:44:09.631
529	13	1	13.2401660	77.7168116	0.06	2026-11-24 00:44:14.605
530	13	1	13.2401652	77.7168131	0.05	2026-11-24 00:44:20.623
531	13	1	13.2401652	77.7168143	0.06	2026-11-24 00:44:25.599
532	13	1	13.2401655	77.7168142	0.06	2026-11-24 00:44:31.616
533	13	1	13.2401654	77.7168145	0.06	2026-11-24 00:44:36.59
534	13	1	13.2401660	77.7168143	0.07	2026-11-24 00:44:41.575
535	13	1	13.2401660	77.7168136	0.06	2026-11-24 00:44:47.584
536	13	1	13.2401673	77.7168137	0.07	2026-11-24 00:44:53.6
537	13	1	13.2401681	77.7168134	0.07	2026-11-24 00:44:59.617
538	13	1	13.2401682	77.7168140	0.06	2026-11-24 00:45:04.593
539	13	1	13.2401679	77.7168137	0.06	2026-11-24 00:45:10.609
540	13	1	13.2401680	77.7168136	0.06	2026-11-24 00:45:16.627
541	13	1	13.2401685	77.7168135	0.06	2026-11-24 00:45:22.644
542	13	1	13.2401686	77.7168144	0.04	2026-11-24 00:45:27.619
543	13	1	13.2401689	77.7168133	0.03	2026-11-24 00:45:32.595
544	13	1	13.2401686	77.7168127	0.04	2026-11-24 00:45:38.612
545	13	1	13.2401677	77.7168127	0.04	2026-11-24 00:45:44.629
546	13	1	13.2401683	77.7168123	0.03	2026-11-24 00:45:50.645
547	13	1	13.2401684	77.7168122	0.04	2026-11-24 00:45:56.663
548	13	1	13.2401688	77.7168125	0.06	2026-11-24 00:46:02.679
549	13	1	13.2401684	77.7168130	0.06	2026-11-24 00:46:07.656
550	13	1	13.2401678	77.7168133	0.06	2026-11-24 00:46:12.63
551	13	1	13.2401680	77.7168136	0.07	2026-11-24 00:46:18.647
552	13	1	13.2401679	77.7168144	0.06	2026-11-24 00:46:23.623
553	13	1	13.2401673	77.7168149	0.06	2026-11-24 00:46:28.598
554	13	1	13.2401664	77.7168153	0.07	2026-11-24 00:46:34.615
555	13	1	13.2401656	77.7168146	0.06	2026-11-24 00:46:39.591
556	13	1	13.2401647	77.7168143	0.07	2026-11-24 00:46:44.683
557	13	1	13.2401641	77.7168141	0.06	2026-11-24 00:46:50.583
558	13	1	13.2401631	77.7168142	0.06	2026-11-24 00:46:55.675
559	13	1	13.2401623	77.7168134	0.06	2026-11-24 00:47:01.577
560	13	1	13.2401623	77.7168127	0.06	2026-11-24 00:47:06.668
561	13	1	13.2401627	77.7168131	0.07	2026-11-24 00:47:11.642
562	13	1	13.2401640	77.7168118	0.06	2026-11-24 00:47:16.619
563	13	1	13.2401636	77.7168107	0.08	2026-11-24 00:47:22.636
564	13	1	13.2401634	77.7168111	0.07	2026-11-24 00:47:27.612
565	13	1	13.2401639	77.7168116	0.06	2026-11-24 00:47:32.587
566	13	1	13.2401645	77.7168116	0.06	2026-11-24 00:47:37.679
567	13	1	13.2401655	77.7168109	0.06	2026-11-24 00:47:43.579
568	13	1	13.2401670	77.7168121	0.07	2026-11-24 00:47:48.67
569	13	1	13.2401675	77.7168141	0.07	2026-11-24 00:47:54.581
570	13	1	13.2401686	77.7168146	0.06	2026-11-24 00:48:00.59
571	13	1	13.2401687	77.7168148	0.06	2026-11-24 00:48:05.576
572	13	1	13.2401687	77.7168149	0.06	2026-11-24 00:48:10.657
573	13	1	13.2401667	77.7168146	0.06	2026-11-24 00:48:15.631
574	13	1	13.2401658	77.7168142	0.07	2026-11-24 00:48:21.649
575	13	1	13.2401657	77.7168139	0.06	2026-11-24 00:48:27.665
576	13	1	13.2401662	77.7168143	0.07	2026-11-24 00:48:33.578
577	13	1	13.2401673	77.7168143	0.07	2026-11-24 00:48:39.585
578	13	1	13.2401667	77.7168140	0.06	2026-11-24 00:48:44.676
579	13	1	13.2401665	77.7168139	0.06	2026-11-24 00:48:50.579
580	13	1	13.2401657	77.7168146	0.07	2026-11-24 00:48:56.594
581	13	1	13.2401656	77.7168150	0.06	2026-11-24 00:49:01.579
582	13	1	13.2401653	77.7168152	0.06	2026-11-24 00:49:07.587
583	13	1	13.2401650	77.7168140	0.07	2026-11-24 00:49:12.678
584	13	1	13.2401652	77.7168139	0.07	2026-11-24 00:49:18.58
585	13	1	13.2401656	77.7168140	0.06	2026-11-24 00:49:23.902
586	13	1	13.2401654	77.7168141	0.07	2026-11-24 00:49:29.687
587	13	1	13.2401658	77.7168138	0.06	2026-11-24 00:49:35.588
588	13	1	13.2401659	77.7168136	0.06	2026-11-24 00:49:40.68
589	13	1	13.2401662	77.7168136	0.06	2026-11-24 00:49:46.581
590	13	1	13.2401678	77.7168133	0.05	2026-11-24 00:49:52.599
591	13	1	13.2401678	77.7168127	0.06	2026-11-24 00:49:57.576
592	13	1	13.2401675	77.7168120	0.07	2026-11-24 00:50:03.59
593	13	1	13.2401676	77.7168117	0.06	2026-11-24 00:50:08.682
594	13	1	13.2401679	77.7168122	0.07	2026-11-24 00:50:14.351
595	13	1	13.2401681	77.7168118	0.05	2026-11-24 00:50:19.578
596	13	1	13.2401681	77.7168114	0.07	2026-11-24 00:50:24.65
597	13	1	13.2401672	77.7168114	0.06	2026-11-24 00:50:30.668
598	13	1	13.2401660	77.7168114	0.06	2026-11-24 00:50:35.642
599	13	1	13.2401655	77.7168113	0.06	2026-11-24 00:50:41.66
600	13	1	13.2401657	77.7168111	0.06	2026-11-24 00:50:46.636
601	13	1	13.2401659	77.7168110	0.06	2026-11-24 00:50:52.652
602	13	1	13.2401661	77.7168123	0.07	2026-11-24 00:50:57.628
603	13	1	13.2401660	77.7168115	0.06	2026-11-24 00:51:03.645
604	13	1	13.2401656	77.7168108	0.06	2026-11-24 00:51:08.621
605	13	1	13.2401656	77.7168109	0.06	2026-11-24 00:51:13.596
606	13	1	13.2401657	77.7168099	0.07	2026-11-24 00:51:18.577
607	13	1	13.2401668	77.7168102	0.06	2026-11-24 00:51:24.403
608	13	1	13.2401672	77.7168107	0.06	2026-11-24 00:51:29.68
609	13	1	13.2401673	77.7168121	0.07	2026-11-24 00:51:34.655
610	13	1	13.2401677	77.7168135	0.07	2026-11-24 00:51:40.672
611	13	1	13.2401679	77.7168139	0.07	2026-11-24 00:51:45.647
612	13	1	13.2401680	77.7168141	0.07	2026-11-24 00:51:50.622
613	13	1	13.2401684	77.7168144	0.06	2026-11-24 00:51:56.64
614	13	1	13.2401686	77.7168144	0.06	2026-11-24 00:52:02.656
615	13	1	13.2401684	77.7168146	0.06	2026-11-24 00:52:08.572
616	13	1	13.2401686	77.7168142	0.04	2026-11-24 00:52:14.576
617	13	1	13.2401691	77.7168147	0.07	2026-11-24 00:52:20.593
618	13	1	13.2401686	77.7168149	0.06	2026-11-24 00:52:25.578
619	13	1	13.2401684	77.7168148	0.06	2026-11-24 00:52:30.66
620	13	1	13.2401681	77.7168150	0.07	2026-11-24 00:52:36.677
621	14	2	13.2401667	77.7168133	\N	2026-11-24 00:53:56.402
622	14	2	13.2401215	77.7168696	0.00	2026-11-24 00:54:01.577
623	14	2	13.2401218	77.7168709	0.59	2026-11-24 00:54:06.617
624	14	2	13.2401211	77.7168696	0.09	2026-11-24 00:54:12.634
625	14	2	13.2401215	77.7168329	0.09	2026-11-24 00:54:18.536
626	14	2	13.2401343	77.7168199	0.09	2026-11-24 00:54:23.627
627	14	2	13.2401382	77.7168142	0.09	2026-11-24 00:54:28.603
628	14	2	13.2401444	77.7168105	0.06	2026-11-24 00:54:33.579
629	14	2	13.2401499	77.7168074	0.07	2026-11-24 00:54:38.701
630	14	2	13.2401535	77.7168059	0.08	2026-11-24 00:54:44.686
631	14	2	13.2401561	77.7168048	0.06	2026-11-24 00:54:50.588
632	14	2	13.2401573	77.7168042	0.07	2026-11-24 00:54:56.605
633	14	2	13.2401580	77.7168036	0.05	2026-11-24 00:55:02.622
634	14	2	13.2401591	77.7168037	0.07	2026-11-24 00:55:08.407
635	14	2	13.2401589	77.7168034	0.07	2026-11-24 00:55:13.615
636	14	2	13.2401587	77.7168030	0.07	2026-11-24 00:55:18.591
637	14	2	13.2401583	77.7168023	0.08	2026-11-24 00:55:24.608
\.


--
-- Data for Name: buses; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.buses (bus_id, bus_number, bus_type, capacity, registration_number, driver_id, front_photo, side_photo, route_id) FROM stdin;
9	BUS-02	SHUTTLE_BUS	50	DEMO-REG-009	\N	\N	\N	12
2	BUS-01	SHUTTLE_BUS	55	KA 53 AC 0634	3	/uploads/buses/2_front_photo_ccad50e444f84f268ea3cc51e970ec77.png	/uploads/buses/2_side_photo_58f176a684d749eb80a042b98bcd84fa.png	11
10	BUS-03	SHUTTLE_BUS	55	DEMO-REG-010	\N	\N	\N	12
1	BUS-001	ROUTE_BUS	55	KA 53 AC 4053	1	/uploads/buses/1_front_photo_77162a8eb45f46029ac5e4db5b97950e.png	/uploads/buses/1_side_photo_e0879af916eb4a1abf48d2d9fadd9519.png	1
3	BUS-002	ROUTE_BUS	55	DEMO-REG-003	\N	/uploads/buses/3_front_photo_bf1dabbf78494248a31786e89c88be68.png	/uploads/buses/3_side_photo_5c50161fee874bef8d0aaa32f2134ee8.png	5
4	BUS-003	ROUTE_BUS	55	DEMO-REG-004	\N	\N	\N	6
5	BUS-004	ROUTE_BUS	55	DEMO-REG-005	\N	\N	\N	7
6	BUS-005	ROUTE_BUS	55	DEMO-REG-006	\N	\N	\N	9
7	BUS-006	ROUTE_BUS	55	DEMO-REG-007	\N	\N	\N	10
8	BUS-007	ROUTE_BUS	55	DEMO-REG-008	\N	\N	\N	\N
\.


--
-- Data for Name: driver_registration_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.driver_registration_requests (request_id, user_id, license_number, phone, status, reviewed_by, reviewed_at, rejection_reason, created_at) FROM stdin;
1	13	JH2026001234	9879904356	APPROVED	2	2026-11-08 11:03:58.653357	\N	2026-11-08 11:01:38.974046
2	17	JH202611001	9876543210	APPROVED	2	2026-11-10 15:27:50.159981	\N	2026-11-10 15:17:14.803278
4	19	KA05BM8963	0987654321	APPROVED	2	2026-11-10 16:34:49.374529	\N	2026-11-10 16:00:07.664915
3	18	KA02M9087	1234567890	APPROVED	2	2026-11-10 16:34:50.962475	\N	2026-11-10 15:57:14.089902
5	20	KA 05 BN 8976	0987653283	PENDING	\N	\N	\N	2026-11-10 16:37:55.855819
\.


--
-- Data for Name: drivers; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.drivers (driver_id, user_id, license_number, phone) FROM stdin;
2	12	S001	1234567890
1	5	DL 04K 0321	9876543211
3	13	JH2026001234	9879904356
4	17	JH202611001	9876543210
5	19	KA05BM8963	0987654321
6	18	KA02M9087	1234567890
7	22	KA1213243212	9876543210
\.


--
-- Data for Name: faculty; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.faculty (faculty_id, user_id, employee_id, department) FROM stdin;
2	9	101	SOE
3	11	102	SOE
4	14	1001	LAW
5	15	10011	Engineering
1	6	FAC001	Computer Science
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.notifications (notification_id, user_id, title, message, notification_type, is_read, created_at) FROM stdin;
206	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-21 19:21:28.693569
211	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-21 22:59:15.401592
215	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-21 23:07:14.909557
75	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 17:59:29.045675
77	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 18:01:09.973436
79	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 18:07:22.351164
217	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 13:20:08.780741
4	13	Driver Registration Approved	Your driver registration has been approved. You can now login.	DRIVER_APPROVED	t	2026-11-08 11:03:58.653357
221	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 13:37:42.428009
225	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 14:53:53.592639
230	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 17:01:17.708503
232	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 19:32:07.476884
235	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 20:25:57.678543
239	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-23 21:44:17.881664
243	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-23 22:59:25.51319
248	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 00:08:15.191835
258	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 02:49:22.85288
262	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 03:33:28.224096
266	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 03:42:30.493553
270	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 04:02:22.371996
274	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 14:09:55.150044
279	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 15:33:14.72459
283	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 16:51:48.692319
286	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-24 23:50:45.950399
290	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-25 01:58:25.982065
291	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-26 18:31:10.772633
293	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-26 19:53:35.355192
294	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-26 21:52:24.042556
298	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-26 23:21:43.351423
254	13	Bus Trip Started	Bus BUS-01: trip #14 has started.	TRIP_STARTED	t	2026-11-24 00:53:56.870323
300	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 01:24:20.236562
304	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 01:57:47.158393
306	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-27 02:55:44.832882
307	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-27 07:41:42.202358
310	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-27 08:46:40.334004
313	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-27 09:51:57.537684
316	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	f	2026-11-27 10:08:41.256262
319	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-27 11:33:04.795465
44	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 12:52:43.239369
1	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-08 10:45:11.10223
2	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-08 10:58:12.242021
3	2	New Driver Registration	Vikram V has submitted a driver registration request.	DRIVER_REQUEST	t	2026-11-08 11:01:38.974046
5	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-08 11:04:52.763904
6	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-08 11:08:19.383441
7	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-08 11:16:07.977498
8	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-08 11:22:52.97671
9	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-08 11:23:06.235993
10	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-08 11:23:28.08043
11	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-08 11:26:12.972478
12	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-09 14:29:24.036099
13	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	t	2026-11-09 14:33:28.59405
14	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	t	2026-11-09 14:34:05.325852
15	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-09 15:19:06.95813
16	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-09 15:52:38.469044
17	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-09 16:19:51.341979
18	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-09 17:16:19.493699
19	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-09 17:16:43.924651
20	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	t	2026-11-09 17:17:53.446996
21	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-09 17:18:29.411561
22	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-09 17:19:02.513605
23	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-09 17:19:25.078308
24	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-09 17:27:27.397662
25	2	User Login	Babu (STUDENT) successfully logged in.	LOGIN	t	2026-11-09 17:28:10.267525
26	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-09 17:28:56.584229
27	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-09 17:31:07.935164
28	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-09 17:54:31.302769
29	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-09 17:57:29.434828
30	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-09 18:37:42.993543
81	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-11 13:44:25.102728
83	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-11 14:22:35.890896
85	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-11 16:58:58.743328
31	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 10:16:36.85398
32	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-10 10:30:32.537929
33	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-10 10:53:37.780804
34	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-10 11:13:39.297824
35	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 11:44:42.034993
36	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 11:45:52.851627
37	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 11:46:06.259531
38	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 11:46:27.43195
39	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 11:47:28.340634
40	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 11:47:49.592729
41	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 12:15:04.564188
42	2	User Login	Babu (STUDENT) successfully logged in.	LOGIN	t	2026-11-10 12:30:01.73038
43	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 12:32:40.994849
207	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	f	2026-11-21 19:39:29.102617
45	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 13:09:21.915783
212	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-21 22:59:33.181768
46	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 13:24:43.245206
216	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 00:00:34.745908
76	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 17:59:50.653604
49	17	Driver Registration Approved	Your driver registration has been approved. You can now login.	DRIVER_APPROVED	f	2026-11-10 15:27:50.159981
78	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 18:01:29.752843
80	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 18:12:54.468415
218	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 13:21:43.396742
222	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 13:38:16.920052
226	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 15:14:26.970884
53	2	New Driver Registration	Raju bhai has submitted a driver registration request.	DRIVER_REQUEST	t	2026-11-10 16:00:07.664915
54	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 16:00:49.416994
52	2	New Driver Registration	Raju has submitted a driver registration request.	DRIVER_REQUEST	t	2026-11-10 15:57:14.089902
55	19	Driver Registration Approved	Your driver registration has been approved. You can now login.	DRIVER_APPROVED	f	2026-11-10 16:34:49.374529
56	18	Driver Registration Approved	Your driver registration has been approved. You can now login.	DRIVER_APPROVED	f	2026-11-10 16:34:50.962475
233	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 19:32:37.715343
236	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-23 20:39:38.48388
240	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 21:50:24.472277
244	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-23 23:07:42.229019
249	16	Bus GPS Disconnected	Bus BUS-001: trip #12 was automatically completed because GPS updates stopped for 30 seconds.	GPS_TIMEOUT	f	2026-11-24 00:22:49.588632
250	5	Bus GPS Disconnected	Bus BUS-001: trip #12 was automatically completed because GPS updates stopped for 30 seconds.	GPS_TIMEOUT	f	2026-11-24 00:22:49.588632
255	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 01:29:49.247347
259	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 02:53:40.360254
263	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 03:39:39.504034
267	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 03:46:27.092352
271	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 04:58:56.263068
275	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 14:18:16.288063
280	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 15:49:40.874413
284	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 17:24:35.015781
287	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 23:53:06.143504
292	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-26 18:31:56.485202
295	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-26 23:09:21.804929
299	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-26 23:31:04.561148
47	2	New Driver Registration	Ravi Driver has submitted a driver registration request.	DRIVER_REQUEST	t	2026-11-10 15:17:14.803278
48	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 15:27:15.965521
50	2	User Login	Ravi Driver (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 15:30:02.340378
51	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 15:52:19.459492
57	2	User Login	Raju (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 16:35:17.474764
58	2	New Driver Registration	Sunny BM has submitted a driver registration request.	DRIVER_REQUEST	t	2026-11-10 16:37:55.855819
59	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 16:38:11.953592
60	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 16:41:06.242655
61	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 16:42:29.811322
62	2	User Login	Babu (STUDENT) successfully logged in.	LOGIN	t	2026-11-10 16:44:53.945342
63	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 16:47:13.280225
64	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 16:54:36.224889
65	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 16:55:43.436146
66	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 16:56:29.585299
67	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 17:05:00.362211
68	2	User Login	Raju (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 17:06:40.941409
69	2	User Login	Raju (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 17:06:58.380979
70	2	User Login	Raju (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 17:07:24.982412
71	2	User Login	Raju (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 17:08:02.752942
72	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 17:08:22.013795
73	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-10 17:09:49.045951
74	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-10 17:13:33.632398
301	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-27 01:25:25.039291
305	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-27 02:53:26.316726
208	10	Bus GPS Disconnected	Bus BUS-01: trip #9 was automatically completed because GPS updates stopped for 30 seconds.	GPS_TIMEOUT	f	2026-11-21 20:31:00.770142
213	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-21 23:00:01.509784
219	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 13:24:30.324515
209	13	Bus GPS Disconnected	Bus BUS-01: trip #9 was automatically completed because GPS updates stopped for 30 seconds.	GPS_TIMEOUT	t	2026-11-21 20:31:00.770142
223	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 13:41:24.17522
227	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 16:45:06.505048
228	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 16:45:06.076173
231	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 19:32:08.228719
237	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 21:19:00.080007
241	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 22:50:52.527765
245	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 23:52:36.511367
251	16	Bus Trip Started	Bus BUS-001: trip #13 has started.	TRIP_STARTED	f	2026-11-24 00:23:11.964501
252	5	Bus Trip Started	Bus BUS-001: trip #13 has started.	TRIP_STARTED	f	2026-11-24 00:23:11.964501
256	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 01:35:38.290545
260	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 02:55:57.960852
264	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 03:41:27.880522
268	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 03:57:35.198342
272	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 05:07:27.072056
276	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 14:40:48.087289
277	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 14:40:44.261346
281	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 16:22:21.626548
285	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 17:38:55.795984
288	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-25 00:57:47.221371
296	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-26 23:10:04.200615
303	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 01:53:21.754824
308	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-27 07:42:04.878999
311	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 08:49:58.33302
314	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 10:03:00.883723
317	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-27 10:44:57.247488
320	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-27 12:41:15.76297
87	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-11 18:33:52.235043
89	2	User Login	Viraj Babu (STUDENT) successfully logged in.	LOGIN	t	2026-11-11 19:09:25.891275
91	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-11 19:12:06.954337
93	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-11 19:15:53.272844
95	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 06:44:48.187297
97	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 06:56:52.461029
99	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-12 08:48:46.075841
101	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:36:10.043581
103	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-12 09:36:42.70917
105	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:37:51.480865
107	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:38:59.748107
109	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:40:00.073134
111	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-12 09:45:46.425528
113	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:46:52.636579
115	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-12 09:54:30.140717
117	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-14 09:55:39.598172
119	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-14 14:37:46.380973
121	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-14 16:44:12.534864
123	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-14 18:29:38.270524
125	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-14 20:16:56.118608
127	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-14 20:52:06.3426
129	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-14 20:52:42.536212
131	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-15 08:10:47.978558
133	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-15 08:26:33.672622
135	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-15 08:41:00.657047
136	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-15 08:45:02.782207
137	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 08:47:47.697496
138	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 08:48:09.422364
139	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 08:48:30.196464
140	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 08:51:14.996785
141	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 08:53:23.798194
142	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 08:54:33.34091
143	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 08:55:15.835928
144	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 08:58:45.69669
82	2	User Login	Babu (STUDENT) successfully logged in.	LOGIN	t	2026-11-11 14:20:10.576158
84	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-11 16:30:19.461508
86	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-11 18:33:32.34277
88	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-11 18:35:37.259441
90	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-11 19:11:13.470266
92	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-11 19:14:11.186053
94	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 06:44:27.782677
96	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-12 06:47:58.151634
98	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 08:48:15.65644
100	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 08:49:19.855271
102	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:36:24.51492
104	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:37:18.335337
106	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-12 09:38:25.809653
108	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:39:39.296053
110	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:40:27.682072
112	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:46:29.219104
114	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-12 09:47:19.574829
116	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-12 10:33:44.580694
118	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-14 13:35:08.876079
120	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-14 14:59:19.675189
122	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-14 17:06:08.493784
124	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-14 19:31:07.331617
126	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-14 20:30:21.323431
128	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-14 20:52:24.5725
130	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-15 07:41:11.691065
132	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-15 08:15:39.03352
134	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-15 08:27:24.935581
145	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 08:59:51.080902
146	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 09:08:31.506449
147	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 09:15:27.61732
148	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 09:15:46.278109
149	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-15 11:47:46.786974
150	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-15 13:12:36.636084
151	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-15 13:15:21.733058
152	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-16 18:58:43.069019
153	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-16 19:01:46.186099
154	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-16 19:02:01.643173
155	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-16 19:04:41.603787
156	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-16 19:41:08.564548
157	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-17 01:44:31.746309
158	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-17 01:55:50.048232
159	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-17 03:06:36.753565
160	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-17 03:07:02.653376
161	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-17 21:53:06.61738
162	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-17 22:30:29.234894
163	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	t	2026-11-17 22:31:06.703085
164	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	t	2026-11-17 22:34:56.255529
165	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-17 23:04:06.147635
166	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 00:22:35.628068
167	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 00:24:56.521168
168	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-18 00:32:47.424378
169	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 00:51:54.393818
170	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 00:55:59.880658
171	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 01:28:29.429319
172	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-18 01:33:42.305264
173	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-18 11:33:57.113147
174	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-18 11:41:09.566393
175	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 11:56:26.392927
176	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-18 11:59:19.075279
177	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-18 12:26:45.557176
178	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 22:07:08.799502
179	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 22:09:34.101941
180	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 22:45:48.719128
181	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 22:47:59.386596
182	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 23:14:27.909643
183	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-18 23:58:41.356265
184	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-19 01:15:55.528259
185	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-19 01:16:50.2965
186	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	t	2026-11-19 01:17:13.346991
187	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	t	2026-11-19 01:21:41.938671
188	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-20 20:48:09.990899
189	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-20 22:58:49.818725
190	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	t	2026-11-20 23:00:07.987525
191	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	t	2026-11-20 23:53:12.427253
192	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	t	2026-11-20 23:54:25.823547
193	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-20 23:58:48.79794
194	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-21 01:05:12.608253
195	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-21 01:13:49.807024
196	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	t	2026-11-21 01:15:37.057561
197	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-21 01:25:14.244908
198	2	User Login	Bharat sir (FACULTY) successfully logged in.	LOGIN	t	2026-11-21 01:25:35.498065
199	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-21 01:57:47.178242
200	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-21 02:32:37.483223
201	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-21 02:35:29.477513
202	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-21 14:50:25.405278
203	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-21 16:32:40.246355
204	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	t	2026-11-21 19:05:59.237185
205	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	t	2026-11-21 19:07:05.816542
210	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-21 20:52:48.716944
214	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-21 23:01:06.501627
220	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 13:25:25.723943
224	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 13:50:49.706322
229	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-22 16:53:18.462988
234	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 19:33:22.917112
238	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-23 21:38:34.328287
242	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-23 22:51:58.765356
246	16	Bus Trip Started	Bus BUS-001: trip #12 has started.	TRIP_STARTED	f	2026-11-24 00:04:23.873577
247	5	Bus Trip Started	Bus BUS-001: trip #12 has started.	TRIP_STARTED	f	2026-11-24 00:04:23.873577
253	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 00:53:21.962555
257	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 02:37:09.884336
261	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 02:56:52.585083
265	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-24 03:41:55.754418
269	2	User Login	Aryan (FACULTY) successfully logged in.	LOGIN	f	2026-11-24 03:59:14.701754
273	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 05:11:16.90607
278	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-24 15:21:25.838245
282	2	User Login	Biru (STUDENT) successfully logged in.	LOGIN	f	2026-11-24 16:35:44.260354
289	2	User Login	System Admin (ADMIN) successfully logged in.	LOGIN	f	2026-11-25 01:29:10.070343
297	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-26 23:21:22.28551
302	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 01:53:16.680157
309	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 07:42:48.050769
312	2	User Login	Rahul Kumar (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 08:59:26.196089
315	2	New Driver Added	Rishav has been added by Admin.	DRIVER_ADDED	f	2026-11-27 10:04:06.845986
318	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 11:03:44.076077
321	2	User Login	Vikram V (DRIVER) successfully logged in.	LOGIN	f	2026-11-27 13:33:53.444198
\.


--
-- Data for Name: routes; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.routes (route_id, route_name, route_code, description, start_point, end_point, is_active) FROM stdin;
7	Route 4 - Sandal Soap Factory to Campus	R004	Bengaluru University Route - Route Bus Timings AY 2026-27	Sandal Soap Factory	Campus	t
9	Route 5 - KR Puram Metro Station to Global Campus	R005	Bengaluru University Route - Route Bus Timings AY 2026-27	KR Puram Metro Station	Global Campus	t
10	Route 6 - Hope Farm Metro Station to Chanakya University	R006	Bengaluru University Route - Route Bus Timings AY 2026-27	Hope Farm Metro Station	Chanakya University	t
5	Route 2 - Laggere Bridge to Campus	R002	Bengaluru University Route - Route Bus Timings AY 2026-27	Laggere Bridge	Campus	t
6	Route 3 - Chikkabalapur Court to Campus	R003	Bengaluru University Route - Route Bus Timings AY 2026-27	Chikkabalapur-Court	Campus	t
11	Shuttle BUS-009 - University Campus to Devanahalli	R007	BUS-07 Shuttle Service - AY 2026-27	University Campus	Devanahalli	t
12	Shuttle BUS-010 - University Campus to Devanahalli	R008	Shuttle service for BUS-010 as per AY 2026-27 timetable	University Campus	Devanahalli	t
1	Route 1 - Prajnanam to Campus	R001	Bengaluru University Route - Route Bus Timings AY 2026-27	Prajnanam	University Campus	t
\.


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.schedules (schedule_id, route_id, bus_id, departure_time, arrival_time, day_of_week, direction) FROM stdin;
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
1	11	2	07:30:00	\N	WORKING_DAYS	OUTBOUND
2	11	2	07:55:00	\N	WORKING_DAYS	OUTBOUND
3	11	2	08:25:00	\N	WORKING_DAYS	OUTBOUND
4	11	2	08:45:00	\N	WORKING_DAYS	OUTBOUND
5	11	2	14:00:00	\N	WORKING_DAYS	OUTBOUND
6	11	2	16:40:00	\N	WORKING_DAYS	OUTBOUND
7	11	2	17:20:00	\N	WORKING_DAYS	OUTBOUND
8	11	2	18:00:00	\N	WORKING_DAYS	OUTBOUND
9	11	2	07:45:00	\N	WORKING_DAYS	RETURN
10	11	2	08:10:00	\N	WORKING_DAYS	RETURN
11	11	2	08:35:00	\N	WORKING_DAYS	RETURN
12	11	2	08:55:00	\N	WORKING_DAYS	RETURN
13	11	2	14:30:00	\N	WORKING_DAYS	RETURN
14	11	2	17:00:00	\N	WORKING_DAYS	RETURN
15	11	2	17:40:00	\N	WORKING_DAYS	RETURN
16	11	2	18:30:00	\N	WORKING_DAYS	RETURN
30	1	1	16:40:00	18:50:00	WORKING_DAYS	RETURN
31	9	6	07:15:00	08:30:00	WORKING_DAYS	OUTBOUND
32	9	6	16:40:00	18:40:00	WORKING_DAYS	RETURN
33	5	3	07:15:00	08:30:00	WORKING_DAYS	OUTBOUND
34	5	3	16:40:00	18:10:00	WORKING_DAYS	RETURN
35	6	4	07:15:00	08:30:00	WORKING_DAYS	OUTBOUND
36	6	4	16:40:00	18:00:00	WORKING_DAYS	RETURN
37	7	5	07:30:00	08:40:00	WORKING_DAYS	OUTBOUND
38	7	5	16:40:00	18:05:00	WORKING_DAYS	RETURN
39	10	7	16:40:00	18:25:00	WORKING_DAYS	RETURN
40	10	7	07:00:00	08:40:00	WORKING_DAYS	OUTBOUND
29	1	1	07:15:00	08:45:00	WORKING_DAYS	OUTBOUND
\.


--
-- Data for Name: stops; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.stops (stop_id, route_id, stop_name, latitude, longitude, stop_order, pickup_time, drop_time) FROM stdin;
26	11	University Campus	13.2215000	77.7547050	1	\N	\N
27	11	Devanahalli	13.2445610	77.7136520	2	\N	\N
28	11	Devanahalli	13.2445610	77.7136520	3	\N	\N
29	11	University Campus	13.2215000	77.7547050	4	\N	\N
5	1	Prajnanam	12.9669711	77.5106840	1	07:15:00	\N
6	1	Attiguppe Metro Station	12.9621018	77.5337131	2	07:30:00	\N
7	1	Navarang	12.9979050	77.5528050	3	07:45:00	\N
8	1	University Campus	13.2215000	77.7547050	4	08:45:00	\N
10	1	University Campus	13.2215000	77.7547050	5	\N	16:40:00
11	1	Navarang	12.9979050	77.5528050	6	\N	18:00:00
12	1	Attiguppe Metro Station	12.9621018	77.5337131	7	\N	18:40:00
13	1	Prajnanam	12.9669711	77.5106840	8	\N	18:50:00
1	5	Laggere Bridge	13.0101340	77.5274210	1	07:15:00	\N
2	5	Peenya Metro Station / Platinum City	13.0331150	77.5338920	2	07:25:00	\N
3	5	MS Palya	13.0813220	77.5481720	3	07:40:00	\N
14	5	Campus	13.2215000	77.7547050	4	08:30:00	\N
15	5	Campus	13.2215000	77.7547050	5	\N	16:40:00
16	5	MS Palya	13.0813220	77.5481720	6	\N	17:35:00
17	5	Peenya Metro Station / Platinum City	13.0331150	77.5338920	7	\N	18:00:00
18	5	Laggere Bridge	13.0101340	77.5274210	8	\N	18:10:00
4	6	Chikkabalapur-Court	13.4359950	77.7289630	1	07:15:00	\N
19	6	Nagarjuna College	13.3507270	77.7273450	2	07:30:00	\N
20	6	Vijayapura	13.3014960	77.7937300	3	07:50:00	\N
21	6	University Campus	13.2215000	77.7547050	4	08:30:00	\N
22	6	University Campus	13.2215000	77.7547050	5	\N	16:40:00
23	6	Vijayapura	13.3014960	77.7937300	6	\N	17:15:00
24	6	Nagarjuna College	13.3507270	77.7273450	7	\N	17:40:00
25	6	Chikkabalapur-Court	13.4359950	77.7289630	8	\N	18:00:00
30	7	Sandal Soap Factory	0.0000000	0.0000000	1	07:30:00	18:05:00
31	7	Yeswanthpur Anjenaya Temple	0.0000000	0.0000000	2	07:32:00	18:00:00
32	7	IISC Campus	0.0000000	0.0000000	3	07:35:00	17:55:00
33	7	Mekri Circle Bus Stand	0.0000000	0.0000000	4	07:55:00	17:50:00
34	7	CBI Bus Stand	0.0000000	0.0000000	5	07:58:00	17:45:00
35	7	Hebbal Bus Stand	0.0000000	0.0000000	6	08:00:00	17:40:00
36	7	Esteem Mall Bus Stand	0.0000000	0.0000000	7	08:05:00	17:35:00
37	7	Yelahanka Café Day	0.0000000	0.0000000	8	08:10:00	17:30:00
38	7	Airforce Station Bus Stand	0.0000000	0.0000000	9	08:15:00	17:25:00
39	7	Hunasmaranahalli Bridge	0.0000000	0.0000000	10	08:20:00	17:20:00
40	7	Chikkajala / Sadahalli Signal	0.0000000	0.0000000	11	08:25:00	17:10:00
41	7	Kannamangala Gate	0.0000000	0.0000000	12	08:30:00	17:05:00
42	7	Chiksene Gate Bus Stand	0.0000000	0.0000000	13	08:35:00	17:00:00
43	7	Campus	0.0000000	0.0000000	14	08:40:00	16:40:00
48	9	Babusapalya Bus Stop	0.0000000	0.0000000	5	07:30:00	18:15:00
49	9	Horamavu / Kalyan Nagar Bus Stop	0.0000000	0.0000000	6	07:32:00	18:10:00
50	9	Hennur Bus Stop	0.0000000	0.0000000	7	07:34:00	18:05:00
51	9	H R B R Layout Bus Stand	0.0000000	0.0000000	8	07:36:00	18:00:00
54	9	Thannisandra Circle Bharath Petrol Bunk	0.0000000	0.0000000	11	07:42:00	17:45:00
55	9	Rastrothana School Junction	0.0000000	0.0000000	12	07:45:00	17:40:00
56	9	Bharathiya City Bus Stand	0.0000000	0.0000000	13	07:48:00	17:35:00
57	9	Bellahalli Cross Bus Stand	0.0000000	0.0000000	14	07:50:00	17:25:00
59	9	Bagaluru Cross	0.0000000	0.0000000	16	08:00:00	17:10:00
44	9	KR Puram Metro Station	13.0004310	77.6779130	1	07:15:00	18:40:00
45	9	Tinfactory Bus Stop	12.9973942	77.6696002	2	07:20:00	18:30:00
46	9	Ramamurthy Nagar Bridge Bus Stop	13.0099050	77.6613660	3	07:22:00	18:25:00
53	9	Element Mall Thannisandra Main Road	13.0449400	77.6268230	10	07:40:00	17:50:00
58	9	Reva University Circle Signal Junction	13.1221820	77.6304820	15	07:55:00	17:20:00
60	9	Global Campus	13.2213020	77.7547690	17	08:30:00	16:40:00
47	9	Banaswadi Bus Stop	13.0144450	77.6509010	4	07:24:00	18:20:00
52	9	Nagavara Signal Junction	13.0410700	77.6247240	9	07:38:00	17:55:00
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.students (student_id, user_id, enrollment_no, department, semester) FROM stdin;
2	7	001	MCA	3
3	8	00011	MCA	3
4	10	0022	MCA	1
5	16	0011	Cyber security	3
1	4	MCA001	Computer Science	1
6	21	0010	MBA	2
7	23	TEST-BULK-001	Computer Science	2
\.


--
-- Data for Name: subscriptions; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.subscriptions (subscription_id, student_id, route_id, subscribed_at, is_active) FROM stdin;
1	4	5	2026-09-29 09:10:13.305189	t
2	5	1	2026-11-10 11:14:39.643332	t
3	5	9	2026-11-14 16:55:32.625931	t
4	5	7	2026-11-27 02:52:27.450365	t
5	6	12	2026-11-27 02:52:27.450365	t
6	2	10	2026-11-27 02:52:27.450365	t
7	3	1	2026-11-27 02:52:27.450365	t
8	4	1	2026-11-27 02:52:27.450365	t
9	1	12	2026-11-27 02:52:27.450365	t
10	2	6	2026-11-27 02:52:27.450365	t
11	2	11	2026-11-27 02:52:27.450365	t
12	2	9	2026-11-27 02:52:27.450365	t
13	5	5	2026-11-27 02:52:27.450365	t
14	6	11	2026-11-27 02:52:27.450365	t
15	6	9	2026-11-27 02:52:27.450365	t
16	3	7	2026-11-27 02:52:27.450365	t
17	4	7	2026-11-27 02:52:27.450365	t
18	1	10	2026-11-27 02:52:27.450365	t
19	6	6	2026-11-27 02:52:27.450365	t
20	1	9	2026-11-27 02:52:27.450365	t
21	1	11	2026-11-27 02:52:27.450365	t
22	3	5	2026-11-27 02:52:27.450365	t
23	1	6	2026-11-27 02:52:27.450365	t
24	6	10	2026-11-27 02:52:27.450365	t
25	2	12	2026-11-27 02:52:27.450365	t
26	6	5	2026-11-27 02:52:27.450365	t
27	1	7	2026-11-27 02:52:27.450365	t
28	4	10	2026-11-27 02:52:27.450365	t
29	3	10	2026-11-27 02:52:27.450365	t
30	3	9	2026-11-27 02:52:27.450365	t
31	4	9	2026-11-27 02:52:27.450365	t
32	4	11	2026-11-27 02:52:27.450365	t
33	3	11	2026-11-27 02:52:27.450365	t
34	1	5	2026-11-27 02:52:27.450365	t
35	4	6	2026-11-27 02:52:27.450365	t
36	3	6	2026-11-27 02:52:27.450365	t
37	6	7	2026-11-27 02:52:27.450365	t
38	5	12	2026-11-27 02:52:27.450365	t
39	2	1	2026-11-27 02:52:27.450365	t
40	2	7	2026-11-27 02:52:27.450365	t
41	5	10	2026-11-27 02:52:27.450365	t
42	6	1	2026-11-27 02:52:27.450365	t
43	5	6	2026-11-27 02:52:27.450365	t
44	1	1	2026-11-27 02:52:27.450365	t
45	4	12	2026-11-27 02:52:27.450365	t
46	3	12	2026-11-27 02:52:27.450365	t
47	2	5	2026-11-27 02:52:27.450365	t
48	5	11	2026-11-27 02:52:27.450365	t
\.


--
-- Data for Name: trip_stop_events; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.trip_stop_events (event_id, trip_id, stop_id, arrival_time, departure_time, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: trips; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.trips (trip_id, bus_id, route_id, driver_id, trip_date, start_time, end_time, status, source) FROM stdin;
1	1	5	1	2026-09-29	\N	\N	COMPLETED	REAL
2	1	5	1	2026-10-07	\N	2026-10-18 10:23:08.313142	COMPLETED	REAL
3	1	5	1	2026-10-18	2026-10-18 10:51:13.732897	2026-10-18 11:02:14.130516	COMPLETED	REAL
4	1	5	1	2026-10-18	2026-10-18 12:06:46.588659	2026-10-18 12:10:55.688019	COMPLETED	REAL
5	1	1	1	2026-10-18	2026-10-18 12:40:52.080854	2026-10-25 09:29:00.862306	COMPLETED	REAL
7	2	5	3	2026-11-03	2026-11-10 18:01:55.975834	2026-11-10 18:03:52.017957	COMPLETED	REAL
6	1	1	1	2026-11-01	2026-11-01 09:30:03.968828	2026-11-16 18:39:08.659319	COMPLETED	REAL
8	2	5	3	2026-11-16	2026-11-16 19:01:46.585342	2026-11-16 19:04:41.989119	COMPLETED	REAL
10	1	1	1	2026-11-18	2026-11-18 01:47:52.667126	2026-11-18 01:49:38.513628	COMPLETED	SIMULATED
9	2	5	3	2026-11-17	2026-11-17 01:47:00.552896	2026-11-21 20:31:00.770142	COMPLETED	REAL
11	1	1	1	2026-11-18	2026-11-18 11:49:17.974014	2026-11-21 20:31:00.770142	COMPLETED	SIMULATED
12	1	1	1	2026-11-24	2026-11-24 00:04:23.873577	2026-11-24 00:22:49.588632	COMPLETED	REAL
13	1	1	1	2026-11-24	2026-11-24 00:23:11.964501	\N	ACTIVE	REAL
14	2	11	3	2026-11-24	2026-11-24 00:53:56.870323	\N	ACTIVE	REAL
\.


--
-- Data for Name: user_notification_preferences; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_notification_preferences (user_id, preferences, updated_at) FROM stdin;
14	{"gpsAlerts": true, "busArrival": true, "tripAlerts": true, "routeUpdates": true, "systemAlerts": true, "compactTables": false, "timetableReminders": true, "showRecentNotifications": true}	2026-11-24 05:26:14.837395
13	{"gpsAlerts": true, "busArrival": true, "tripAlerts": true, "routeUpdates": true, "systemAlerts": true, "compactTables": false, "timetableReminders": true, "showRecentNotifications": true}	2026-11-26 23:30:10.51421
16	{"gpsAlerts": true, "busArrival": true, "tripAlerts": true, "routeUpdates": true, "systemAlerts": true, "compactTables": false, "timetableReminders": true, "showRecentNotifications": true}	2026-11-21 19:39:12.283099
15	{"gpsAlerts": true, "busArrival": false, "tripAlerts": true, "routeUpdates": false, "systemAlerts": true, "compactTables": false, "timetableReminders": false, "showRecentNotifications": true}	2026-11-21 19:39:41.069441
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: bus_admin
--

COPY public.users (user_id, name, email, password_hash, role, created_at, is_active) FROM stdin;
2	System Admin	admin@university.com	$2b$12$DgUJYlY/7JWPXhS2NiZ9PO0IJLpjhmaUJJHY/Rqvd.1zZYTy9WRWa	ADMIN	2026-09-06 19:36:36.02318	t
8	ankit	ankit1234@university.com	$2b$12$nWv3Dqj9RO/b6.vo6ayg4OuKozGXaU8MnE2ewzxiqzcVAD9DcVW/q	STUDENT	2026-09-17 18:05:29.382999	t
9	Abhi	abhi123@gmail.com	$2b$12$IWu7eS/MqIW6rAECgkNCaeecKin7S4MoT3x6dQxP4IWV0J2Qo.8iW	FACULTY	2026-09-19 15:40:14.204869	t
10	Babu	babu1234@gmail.com	$2b$12$J5jgXw9Ww0OWoRufeR1dl.7hevpv1XrWF/tsdPfxK7OsGCw6NE47m	STUDENT	2026-09-19 15:54:45.992761	t
11	ankit	ankit123@university.com	$2b$12$DNELaG3vI99U3/jaYYU6vuhWMPP7DjrlrX7OzEQ06Koyy7Zs1ILQO	FACULTY	2026-10-03 08:35:34.643256	t
14	Aryan	aryan123@gmail.com	$2b$12$V8274qsYe72Xq2qFIOU3.Oc875wkbELhF8H.P57wFA4w/BWyn8NO6	FACULTY	2026-11-09 14:33:07.982683	t
15	Bharat sir	bharat123@gmail.com	$2b$12$f5hw8tes.UCQeUZPHL/Yu.KT6oBip6kQuEQ52aowefUGJOx5Gcs/m	FACULTY	2026-11-09 17:13:17.67824	t
16	Biru	biru123@gmail.com	$2b$12$1mTbmgZjnGV2jQLbfKKnDeOoNsMkDkk0vhhdQu6CJP5.OVPd/fDQC	STUDENT	2026-11-09 17:14:31.020245	t
7	Ram	ram01@university.com	$2b$12$qmPyvIvTWX7U3WO.n6RGr.haRnn5nZh6./BMQHqm7.DQtzxP/holu	STUDENT	2026-09-17 18:00:04.512824	f
3	Test Faculty	faculty@test.com	$2b$12$DDU6Q7Mhmmx/1f7AjKK3oeg6d44pu8Y4mLyBDgiHCYV/zdLrBYayS	FACULTY	2026-09-07 09:51:58.126358	f
4	Rahul Kumar	rahul@university.com	$2b$12$ZW1EpbCqvqebGyOnP.BI6eCFv/VGWRdirhpgbQr7avluk5Tn.441q	STUDENT	2026-09-07 18:49:17.700806	t
1	string	user@example.com	$2b$12$DrPqNa0Wmp/J7vSt0VZcvuJEy7jZcP1xPI5fxYPfTljc4A2R/JtfS	STUDENT	2026-09-06 18:03:26.281763	f
6	Priya Sharma	faculty@university.com	$2b$12$U0IF4wc5TksyEaWHS4JKnONtHFlnR1eokNPXzjWrijxshefghukFK	FACULTY	2026-09-11 09:04:26.242535	f
13	Vikram V	vikram123@gmail.com	$2b$12$caOrlFU0gBBpx2kwJZrtpO3UDfC.54M0NlD7sfiGZixDGUpRJ3Df.	DRIVER	2026-11-08 11:01:38.974046	t
12	abhay	abhay123@gmail.com	$2b$12$pEt9TOQxhMqtIR4HFOh7h.fcH1zhhaReDptY3QhSsnz7bkM1jxm5i	DRIVER	2026-10-25 13:35:23.509462	f
17	Ravi Driver	ravidriver123@gmail.com	$2b$12$nyG8WIm/YR01xEWv.V7G3O9VYl2HTAQAIHouFN8o6LSt7yff6Nfey	DRIVER	2026-11-10 15:17:14.803278	t
19	Raju bhai	raju1234@gmail.com	$2b$12$99FwJAwMZgR.VOngtLkFFuazXLgrOyQUEwAiGh09ULYnQ/JZcUad.	DRIVER	2026-11-10 16:00:07.664915	t
18	Raju	raju123@gmail.com	$2b$12$6dO0hpe9G43kEGb9DGTcWe0YfAWF0/wZKQAI//I3W.srmzffRDhl.	DRIVER	2026-11-10 15:57:14.089902	t
20	Sunny BM	sunny123@gmail.com	$2b$12$8uYQ.bay31OSpv/xySq68OxSiB5EvvNNQoGG.lKP3dtS7MZcpHK5u	DRIVER	2026-11-10 16:37:55.855819	f
21	Viraj Babu	viraj123@gmail.com	$2b$12$HzEYTIRrDEaE4X.Qz7IaOOo9PiHkSlJ0InYcMoR1GUf1ZgVbyj47q	STUDENT	2026-11-11 19:09:11.183641	t
5	Rahul Kumar	rahul123@gmail.com	$2b$12$DiEr5MHIcwraG.CX5wJmW.AYY5FKTXsMDL054IvuKIl0cfqNthZ32	DRIVER	2026-09-07 19:13:15.002917	t
22	Rishav	rishav123@gmail.com	$2b$12$nKzs.Gde1vY1p0CcG4gwyeF1K6aZr1ty26raUEO.uJCejuxka3pN.	DRIVER	2026-11-27 10:04:06.845986	t
23	Test Student	test.bulkimport@example.com	$2b$12$KM1q5TjYTZPVx3uID50NAevaAtCLic2CeXt6cVf7BiW31IYwmHFdm	STUDENT	2026-11-27 12:48:08.623661	t
\.


--
-- Name: bus_locations_location_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.bus_locations_location_id_seq', 4268, true);


--
-- Name: buses_bus_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.buses_bus_id_seq', 10, true);


--
-- Name: driver_registration_requests_request_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.driver_registration_requests_request_id_seq', 5, true);


--
-- Name: drivers_driver_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.drivers_driver_id_seq', 7, true);


--
-- Name: faculty_faculty_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.faculty_faculty_id_seq', 5, true);


--
-- Name: notifications_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.notifications_notification_id_seq', 321, true);


--
-- Name: routes_route_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.routes_route_id_seq', 12, true);


--
-- Name: schedules_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.schedules_schedule_id_seq', 40, true);


--
-- Name: stops_stop_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.stops_stop_id_seq', 60, true);


--
-- Name: students_student_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.students_student_id_seq', 7, true);


--
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.subscriptions_subscription_id_seq', 48, true);


--
-- Name: trip_stop_events_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.trip_stop_events_event_id_seq', 1, false);


--
-- Name: trips_trip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.trips_trip_id_seq', 14, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: bus_admin
--

SELECT pg_catalog.setval('public.users_user_id_seq', 23, true);


--
-- Name: bus_geofence_simulator_state bus_geofence_simulator_state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bus_geofence_simulator_state
    ADD CONSTRAINT bus_geofence_simulator_state_pkey PRIMARY KEY (bus_id);


--
-- Name: bus_geofence_state bus_geofence_state_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.bus_geofence_state
    ADD CONSTRAINT bus_geofence_state_pkey PRIMARY KEY (bus_id);


--
-- Name: bus_geofence_validation_state bus_geofence_validation_state_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.bus_geofence_validation_state
    ADD CONSTRAINT bus_geofence_validation_state_pkey PRIMARY KEY (bus_id, source);


--
-- Name: bus_locations bus_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.bus_locations
    ADD CONSTRAINT bus_locations_pkey PRIMARY KEY (location_id);


--
-- Name: buses buses_bus_number_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.buses
    ADD CONSTRAINT buses_bus_number_key UNIQUE (bus_number);


--
-- Name: buses buses_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.buses
    ADD CONSTRAINT buses_pkey PRIMARY KEY (bus_id);


--
-- Name: buses buses_registration_number_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.buses
    ADD CONSTRAINT buses_registration_number_key UNIQUE (registration_number);


--
-- Name: driver_registration_requests driver_registration_requests_license_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_registration_requests
    ADD CONSTRAINT driver_registration_requests_license_number_key UNIQUE (license_number);


--
-- Name: driver_registration_requests driver_registration_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_registration_requests
    ADD CONSTRAINT driver_registration_requests_pkey PRIMARY KEY (request_id);


--
-- Name: driver_registration_requests driver_registration_requests_user_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_registration_requests
    ADD CONSTRAINT driver_registration_requests_user_id_key UNIQUE (user_id);


--
-- Name: drivers drivers_license_number_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_license_number_key UNIQUE (license_number);


--
-- Name: drivers drivers_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_pkey PRIMARY KEY (driver_id);


--
-- Name: drivers drivers_user_id_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_user_id_key UNIQUE (user_id);


--
-- Name: faculty faculty_employee_id_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_employee_id_key UNIQUE (employee_id);


--
-- Name: faculty faculty_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_pkey PRIMARY KEY (faculty_id);


--
-- Name: faculty faculty_user_id_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_user_id_key UNIQUE (user_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (notification_id);


--
-- Name: routes routes_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_pkey PRIMARY KEY (route_id);


--
-- Name: routes routes_route_code_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.routes
    ADD CONSTRAINT routes_route_code_key UNIQUE (route_code);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (schedule_id);


--
-- Name: stops stops_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.stops
    ADD CONSTRAINT stops_pkey PRIMARY KEY (stop_id);


--
-- Name: students students_enrollment_no_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_enrollment_no_key UNIQUE (enrollment_no);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (student_id);


--
-- Name: students students_user_id_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_key UNIQUE (user_id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (subscription_id);


--
-- Name: trip_stop_events trip_stop_events_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trip_stop_events
    ADD CONSTRAINT trip_stop_events_pkey PRIMARY KEY (event_id);


--
-- Name: trips trips_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT trips_pkey PRIMARY KEY (trip_id);


--
-- Name: stops unique_route_stop_order; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.stops
    ADD CONSTRAINT unique_route_stop_order UNIQUE (route_id, stop_order);


--
-- Name: subscriptions unique_student_route; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT unique_student_route UNIQUE (student_id, route_id);


--
-- Name: trip_stop_events unique_trip_stop_event; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trip_stop_events
    ADD CONSTRAINT unique_trip_stop_event UNIQUE (trip_id, stop_id);


--
-- Name: user_notification_preferences user_notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_notification_preferences
    ADD CONSTRAINT user_notification_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: idx_bus_geofence_updated; Type: INDEX; Schema: public; Owner: bus_admin
--

CREATE INDEX idx_bus_geofence_updated ON public.bus_geofence_state USING btree (updated_at);


--
-- Name: idx_driver_requests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_driver_requests_status ON public.driver_registration_requests USING btree (status);


--
-- Name: idx_notifications_user_read; Type: INDEX; Schema: public; Owner: bus_admin
--

CREATE INDEX idx_notifications_user_read ON public.notifications USING btree (user_id, is_read);


--
-- Name: idx_trip_stop_events_stop; Type: INDEX; Schema: public; Owner: bus_admin
--

CREATE INDEX idx_trip_stop_events_stop ON public.trip_stop_events USING btree (stop_id);


--
-- Name: idx_trip_stop_events_trip; Type: INDEX; Schema: public; Owner: bus_admin
--

CREATE INDEX idx_trip_stop_events_trip ON public.trip_stop_events USING btree (trip_id);


--
-- Name: uq_buses_one_driver; Type: INDEX; Schema: public; Owner: bus_admin
--

CREATE UNIQUE INDEX uq_buses_one_driver ON public.buses USING btree (driver_id) WHERE (driver_id IS NOT NULL);


--
-- Name: uq_trips_one_active_bus; Type: INDEX; Schema: public; Owner: bus_admin
--

CREATE UNIQUE INDEX uq_trips_one_active_bus ON public.trips USING btree (bus_id) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: uq_trips_one_active_driver; Type: INDEX; Schema: public; Owner: bus_admin
--

CREATE UNIQUE INDEX uq_trips_one_active_driver ON public.trips USING btree (driver_id) WHERE (((status)::text = 'ACTIVE'::text) AND (driver_id IS NOT NULL));


--
-- Name: trips trg_validate_trip_assignment; Type: TRIGGER; Schema: public; Owner: bus_admin
--

CREATE TRIGGER trg_validate_trip_assignment BEFORE INSERT OR UPDATE OF bus_id, driver_id, route_id ON public.trips FOR EACH ROW EXECUTE FUNCTION public.validate_new_trip_assignment();


--
-- Name: bus_geofence_simulator_state bus_geofence_simulator_state_bus_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bus_geofence_simulator_state
    ADD CONSTRAINT bus_geofence_simulator_state_bus_id_fkey FOREIGN KEY (bus_id) REFERENCES public.buses(bus_id) ON DELETE CASCADE;


--
-- Name: bus_geofence_state bus_geofence_state_bus_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.bus_geofence_state
    ADD CONSTRAINT bus_geofence_state_bus_id_fkey FOREIGN KEY (bus_id) REFERENCES public.buses(bus_id) ON DELETE CASCADE;


--
-- Name: bus_geofence_validation_state bus_geofence_validation_state_bus_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.bus_geofence_validation_state
    ADD CONSTRAINT bus_geofence_validation_state_bus_id_fkey FOREIGN KEY (bus_id) REFERENCES public.buses(bus_id);


--
-- Name: buses buses_route_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.buses
    ADD CONSTRAINT buses_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.routes(route_id) ON DELETE SET NULL;


--
-- Name: buses fk_bus_driver; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.buses
    ADD CONSTRAINT fk_bus_driver FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id) ON DELETE SET NULL;


--
-- Name: driver_registration_requests fk_driver_request_admin; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_registration_requests
    ADD CONSTRAINT fk_driver_request_admin FOREIGN KEY (reviewed_by) REFERENCES public.users(user_id) ON DELETE SET NULL;


--
-- Name: driver_registration_requests fk_driver_request_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_registration_requests
    ADD CONSTRAINT fk_driver_request_user FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: drivers fk_driver_user; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT fk_driver_user FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: faculty fk_faculty_user; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT fk_faculty_user FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: bus_locations fk_location_bus; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.bus_locations
    ADD CONSTRAINT fk_location_bus FOREIGN KEY (bus_id) REFERENCES public.buses(bus_id) ON DELETE CASCADE;


--
-- Name: bus_locations fk_location_trip; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.bus_locations
    ADD CONSTRAINT fk_location_trip FOREIGN KEY (trip_id) REFERENCES public.trips(trip_id) ON DELETE CASCADE;


--
-- Name: notifications fk_notification_user; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


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
-- Name: stops fk_stop_route; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.stops
    ADD CONSTRAINT fk_stop_route FOREIGN KEY (route_id) REFERENCES public.routes(route_id) ON DELETE CASCADE;


--
-- Name: students fk_student_user; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT fk_student_user FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: subscriptions fk_subscription_route; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_subscription_route FOREIGN KEY (route_id) REFERENCES public.routes(route_id) ON DELETE CASCADE;


--
-- Name: subscriptions fk_subscription_student; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT fk_subscription_student FOREIGN KEY (student_id) REFERENCES public.students(student_id) ON DELETE CASCADE;


--
-- Name: trips fk_trip_bus; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT fk_trip_bus FOREIGN KEY (bus_id) REFERENCES public.buses(bus_id);


--
-- Name: trips fk_trip_driver; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT fk_trip_driver FOREIGN KEY (driver_id) REFERENCES public.drivers(driver_id) ON DELETE SET NULL;


--
-- Name: trips fk_trip_route; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trips
    ADD CONSTRAINT fk_trip_route FOREIGN KEY (route_id) REFERENCES public.routes(route_id);


--
-- Name: trip_stop_events trip_stop_events_stop_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trip_stop_events
    ADD CONSTRAINT trip_stop_events_stop_id_fkey FOREIGN KEY (stop_id) REFERENCES public.stops(stop_id) ON DELETE CASCADE;


--
-- Name: trip_stop_events trip_stop_events_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: bus_admin
--

ALTER TABLE ONLY public.trip_stop_events
    ADD CONSTRAINT trip_stop_events_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trips(trip_id) ON DELETE CASCADE;


--
-- Name: user_notification_preferences user_notification_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_notification_preferences
    ADD CONSTRAINT user_notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO bus_admin;
GRANT USAGE ON SCHEMA public TO asus;
GRANT USAGE ON SCHEMA public TO superset_reader;


--
-- Name: TABLE bus_geofence_simulator_state; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.bus_geofence_simulator_state TO asus;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.bus_geofence_simulator_state TO bus_admin;
GRANT SELECT ON TABLE public.bus_geofence_simulator_state TO superset_reader;


--
-- Name: TABLE bus_geofence_state; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.bus_geofence_state TO asus;
GRANT SELECT ON TABLE public.bus_geofence_state TO superset_reader;


--
-- Name: TABLE bus_geofence_validation_state; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.bus_geofence_validation_state TO superset_reader;


--
-- Name: TABLE bus_locations; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.bus_locations TO asus;
GRANT SELECT ON TABLE public.bus_locations TO superset_reader;


--
-- Name: SEQUENCE bus_locations_location_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.bus_locations_location_id_seq TO asus;


--
-- Name: TABLE bus_locations_timezone_backup_20261124; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.bus_locations_timezone_backup_20261124 TO asus;
GRANT SELECT ON TABLE public.bus_locations_timezone_backup_20261124 TO superset_reader;


--
-- Name: TABLE buses; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.buses TO asus;
GRANT SELECT ON TABLE public.buses TO superset_reader;


--
-- Name: SEQUENCE buses_bus_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.buses_bus_id_seq TO asus;


--
-- Name: TABLE driver_registration_requests; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.driver_registration_requests TO bus_admin;
GRANT SELECT ON TABLE public.driver_registration_requests TO asus;
GRANT SELECT ON TABLE public.driver_registration_requests TO superset_reader;


--
-- Name: SEQUENCE driver_registration_requests_request_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.driver_registration_requests_request_id_seq TO bus_admin;
GRANT SELECT,USAGE ON SEQUENCE public.driver_registration_requests_request_id_seq TO asus;


--
-- Name: TABLE drivers; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.drivers TO asus;
GRANT SELECT ON TABLE public.drivers TO superset_reader;


--
-- Name: SEQUENCE drivers_driver_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.drivers_driver_id_seq TO asus;


--
-- Name: TABLE faculty; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.faculty TO asus;
GRANT SELECT ON TABLE public.faculty TO superset_reader;


--
-- Name: SEQUENCE faculty_faculty_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.faculty_faculty_id_seq TO asus;


--
-- Name: TABLE notifications; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.notifications TO asus;
GRANT SELECT ON TABLE public.notifications TO superset_reader;


--
-- Name: SEQUENCE notifications_notification_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.notifications_notification_id_seq TO asus;


--
-- Name: TABLE routes; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.routes TO asus;
GRANT SELECT ON TABLE public.routes TO superset_reader;


--
-- Name: SEQUENCE routes_route_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.routes_route_id_seq TO asus;


--
-- Name: TABLE schedules; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.schedules TO asus;
GRANT SELECT ON TABLE public.schedules TO superset_reader;


--
-- Name: SEQUENCE schedules_schedule_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.schedules_schedule_id_seq TO asus;


--
-- Name: TABLE stops; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.stops TO asus;
GRANT SELECT ON TABLE public.stops TO superset_reader;


--
-- Name: SEQUENCE stops_stop_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.stops_stop_id_seq TO asus;


--
-- Name: TABLE students; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.students TO asus;
GRANT SELECT ON TABLE public.students TO superset_reader;


--
-- Name: SEQUENCE students_student_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.students_student_id_seq TO asus;


--
-- Name: TABLE subscriptions; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.subscriptions TO asus;
GRANT SELECT ON TABLE public.subscriptions TO superset_reader;


--
-- Name: SEQUENCE subscriptions_subscription_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.subscriptions_subscription_id_seq TO asus;


--
-- Name: TABLE trip_stop_events; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.trip_stop_events TO asus;
GRANT SELECT ON TABLE public.trip_stop_events TO superset_reader;


--
-- Name: TABLE trips; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.trips TO asus;
GRANT SELECT ON TABLE public.trips TO superset_reader;


--
-- Name: SEQUENCE trips_trip_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.trips_trip_id_seq TO asus;


--
-- Name: TABLE user_notification_preferences; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.user_notification_preferences TO bus_admin;
GRANT SELECT ON TABLE public.user_notification_preferences TO superset_reader;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT ON TABLE public.users TO asus;
GRANT SELECT ON TABLE public.users TO superset_reader;


--
-- Name: SEQUENCE users_user_id_seq; Type: ACL; Schema: public; Owner: bus_admin
--

GRANT SELECT,USAGE ON SEQUENCE public.users_user_id_seq TO asus;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: bus_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE bus_admin IN SCHEMA public GRANT SELECT ON TABLES TO superset_reader;


--
-- PostgreSQL database dump complete
--

\unrestrict 3U9hZDwy8FTLytCJZZ7W1eRafh0ZACiiKBPWfqUEUlw2zB8q7LXhUcIQhKQU4zK

