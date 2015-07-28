
DROP SCHEMA IF EXISTS gps CASCADE;

CREATE SCHEMA gps

CREATE TABLE ee_species_limited (
  abbr varchar PRIMARY KEY,
  english_name varchar,
  latin_name varchar UNIQUE NOT NULL,
  species_id integer NOT NULL
)

CREATE TABLE ee_individual_limited (
  ring_number varchar PRIMARY KEY,
  species_latin_name varchar NOT NULL ,
  colour_ring varchar,
  mass numeric(5,0),
  remarks varchar,
  sex varchar NOT NULL ,
  start_date timestamp without time zone NOT NULL ,
  end_date timestamp without time zone NOT NULL ,
  individual_id integer NOT NULL,
  FOREIGN KEY (species_latin_name) REFERENCES ee_species_limited (latin_name)
)

CREATE TABLE ee_project_limited (
  key_name varchar PRIMARY KEY,
  station_name varchar NOT NULL,
  start_date timestamp without time zone NOT NULL,
  end_date timestamp without time zone NOT NULL,
  description varchar,
  project_id integer NOT NULL,
  parent_id integer
)

CREATE TABLE ee_tracker_limited (
  device_info_serial integer PRIMARY KEY,
  firmware_version varchar,
  mass numeric(4,2),
  start_date timestamp without time zone NOT NULL,
  end_date timestamp without time zone NOT NULL,
  x_o numeric(30,6),
  x_s numeric(30,6),
  y_o numeric(30,6),
  y_s numeric(30,6),
  z_o numeric(30,6),
  z_s numeric(30,6),
  tracker_id integer
)

CREATE TABLE ee_track_session_limited (
  key_name varchar NOT NULL,
  device_info_serial integer NOT NULL,
  ring_number varchar NOT NULL,
  start_date timestamp without time zone NOT NULL,
  end_date timestamp without time zone NOT NULL,
  start_latitude numeric(11,8) NOT NULL,
  start_longitude numeric(11,8) NOT NULL,
  remarks varchar,
  track_session_id integer NOT NULL,
  project_id integer NOT NULL,
  tracker_id integer NOT NULL,
  individual_id integer NOT NULL,
  FOREIGN KEY (device_info_serial) REFERENCES ee_tracker_limited,
  FOREIGN KEY (key_name) REFERENCES ee_project_limited,
  FOREIGN KEY (ring_number) REFERENCES ee_individual_limited
)

CREATE TABLE ee_tracking_speed_limited (
    cartodb_id SERIAL PRIMARY KEY,
    device_info_serial integer NOT NULL,
    date_time timestamp without time zone NOT NULL,
    latitude double precision,
    longitude double precision,
    altitude integer,
    pressure integer,
    temperature double precision,
    satellites_used smallint,
    gps_fixtime double precision,
    positiondop double precision,
    h_accuracy double precision,
    v_accuracy double precision,
    x_speed double precision,
    y_speed double precision,
    z_speed double precision,
    speed_accuracy double precision,
    the_geom geometry(Geometry,4326),
    the_geom_webmercator geometry(Geometry,3857),
    userflag integer DEFAULT 0,
    speed_2d double precision,
    speed_3d double precision,
    direction numeric,
    altitude_agl double precision,
    FOREIGN KEY (device_info_serial) REFERENCES ee_tracker_limited
)
CREATE INDEX  ee_tracking_speed_limited_the_geom_idx ON  ee_tracking_speed_limited USING gist (the_geom)
CREATE INDEX  ee_tracking_speed_limited_the_geom_webmercator_idx ON  ee_tracking_speed_limited USING gist (the_geom_webmercator)
CREATE UNIQUE INDEX ee_tracking_speed_limited_id_dt_idx ON ee_tracking_speed_limited (device_info_serial, date_time)

;

SELECT cartodb.cdb_organization_add_table_organization_read_permission('gps', 'ee_species_limited');
SELECT cartodb.cdb_organization_add_table_organization_read_permission('gps', 'ee_individual_limited');
SELECT cartodb.cdb_organization_add_table_organization_read_permission('gps', 'ee_project_limited');
SELECT cartodb.cdb_organization_add_table_organization_read_permission('gps', 'ee_tracker_limited');
SELECT cartodb.cdb_organization_add_table_organization_read_permission('gps', 'ee_track_session_limited');
SELECT cartodb.cdb_organization_add_table_organization_read_permission('gps', 'ee_tracking_speed_limited');
