-- Additive transport domain. Existing bookings and their snapshots are retained.
CREATE TABLE transport_sources (
  id TEXT PRIMARY KEY, effective_from DATE NOT NULL, image_sha256 TEXT NOT NULL,
  extraction_complete BOOLEAN NOT NULL DEFAULT FALSE, issues JSONB NOT NULL DEFAULT '[]'
);
CREATE TABLE transport_routes (
  id BIGSERIAL PRIMARY KEY, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 150)
);
CREATE TABLE transport_variants (
  id BIGSERIAL PRIMARY KEY, route_id BIGINT NOT NULL REFERENCES transport_routes(id),
  code TEXT NOT NULL UNIQUE, name TEXT NOT NULL, source_id TEXT REFERENCES transport_sources(id),
  verified BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE transport_stops (
  id BIGSERIAL PRIMARY KEY, source_key TEXT NOT NULL UNIQUE, name TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 500),
  latitude DOUBLE PRECISION, longitude DOUBLE PRECISION, coordinate_reference TEXT,
  CHECK ((latitude IS NULL AND longitude IS NULL AND coordinate_reference IS NULL) OR
    (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180 AND coordinate_reference IS NOT NULL AND length(trim(coordinate_reference)) > 0 AND latitude IS NOT NULL AND longitude IS NOT NULL))
);
CREATE TABLE transport_patterns (
  id BIGSERIAL PRIMARY KEY, variant_id BIGINT NOT NULL REFERENCES transport_variants(id),
  direction TEXT NOT NULL CHECK (direction IN ('inbound','outbound')),
  sequence_verified BOOLEAN NOT NULL DEFAULT FALSE, UNIQUE(variant_id,direction)
);
CREATE TABLE transport_pattern_stops (
  id BIGSERIAL PRIMARY KEY, pattern_id BIGINT NOT NULL REFERENCES transport_patterns(id),
  stop_id BIGINT NOT NULL REFERENCES transport_stops(id), sequence INTEGER NOT NULL CHECK(sequence > 0),
  label TEXT NOT NULL, pickup_allowed BOOLEAN NOT NULL DEFAULT TRUE, dropoff_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE(pattern_id,sequence) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX transport_pattern_stops_stop_idx ON transport_pattern_stops(stop_id);
CREATE TABLE transport_gps_devices (
  id BIGSERIAL PRIMARY KEY, external_id TEXT NOT NULL UNIQUE, provider TEXT NOT NULL DEFAULT 'traccar', active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE transport_buses (
  id BIGSERIAL PRIMARY KEY, registration TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
  capacity INTEGER NOT NULL CHECK(capacity BETWEEN 1 AND 200), standing_capacity INTEGER NOT NULL DEFAULT 0 CHECK(standing_capacity BETWEEN 0 AND 200),
  gps_device_id BIGINT UNIQUE REFERENCES transport_gps_devices(id), active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE transport_drivers (
  id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL, staff_reference TEXT NOT NULL UNIQUE, active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE transport_schedules (
  id BIGSERIAL PRIMARY KEY, source_key TEXT NOT NULL UNIQUE, source_id TEXT REFERENCES transport_sources(id),
  pattern_id BIGINT NOT NULL REFERENCES transport_patterns(id), label TEXT NOT NULL,
  period TEXT NOT NULL CHECK(period IN ('morning_1','morning_2','afternoon','evening')),
  departure_time TIME NOT NULL, arrival_time TIME, effective_from DATE NOT NULL, effective_to DATE,
  service_days INTEGER[] NOT NULL DEFAULT ARRAY[0,1,2,3,4,6],
  bus_id BIGINT REFERENCES transport_buses(id), driver_id BIGINT REFERENCES transport_drivers(id),
  verified BOOLEAN NOT NULL DEFAULT FALSE, active BOOLEAN NOT NULL DEFAULT FALSE,
  admin_modified BOOLEAN NOT NULL DEFAULT FALSE,
  CHECK(effective_to IS NULL OR effective_to >= effective_from),
  CHECK(arrival_time IS NULL OR arrival_time > departure_time),
  CHECK(cardinality(service_days)>0 AND service_days <@ ARRAY[0,1,2,3,4,5,6]),
  CHECK(NOT active OR (verified AND bus_id IS NOT NULL AND driver_id IS NOT NULL))
);
CREATE INDEX transport_schedules_pattern_idx ON transport_schedules(pattern_id);
CREATE INDEX transport_schedules_availability_idx ON transport_schedules(active,effective_from,effective_to);
CREATE INDEX transport_schedules_bus_idx ON transport_schedules(bus_id);
CREATE INDEX transport_schedules_driver_idx ON transport_schedules(driver_id);
CREATE TABLE transport_stop_times (
  schedule_id BIGINT NOT NULL REFERENCES transport_schedules(id), pattern_stop_id BIGINT NOT NULL REFERENCES transport_pattern_stops(id),
  pickup_time TIME, arrival_time TIME,
  PRIMARY KEY(schedule_id,pattern_stop_id),
  CHECK((pickup_time IS NOT NULL AND arrival_time IS NULL) OR (pickup_time IS NULL AND arrival_time IS NOT NULL))
);
CREATE TABLE transport_service_exceptions (
  travel_date DATE PRIMARY KEY, reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 1 AND 500)
);
-- Explicit grants for the existing authenticated identity; no public role escalation.
CREATE TABLE transport_admins (user_id BIGINT PRIMARY KEY REFERENCES users(id), granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE TABLE transport_audit (
  id BIGSERIAL PRIMARY KEY, actor_id BIGINT NOT NULL REFERENCES users(id), action TEXT NOT NULL,
  entity_id TEXT, details JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX transport_audit_actor_created_idx ON transport_audit(actor_id,created_at DESC);
ALTER TABLE bookings ADD COLUMN schedule_id BIGINT REFERENCES transport_schedules(id);
ALTER TABLE bookings ADD COLUMN pickup_stop_id BIGINT REFERENCES transport_pattern_stops(id);
ALTER TABLE bookings ADD COLUMN dropoff_stop_id BIGINT REFERENCES transport_pattern_stops(id);
ALTER TABLE bookings ADD CONSTRAINT booking_transport_shape CHECK
  ((schedule_id IS NULL AND pickup_stop_id IS NULL AND dropoff_stop_id IS NULL) OR (schedule_id IS NOT NULL AND pickup_stop_id IS NOT NULL));
CREATE INDEX bookings_schedule_date_idx ON bookings(schedule_id,travel_date) WHERE status='confirmed';
