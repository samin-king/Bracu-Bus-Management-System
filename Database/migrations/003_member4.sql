-- User references are verified Member 1 account identifiers. Add users FKs on integration.
CREATE TABLE complaints (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 user_id text NOT NULL CHECK (length(btrim(user_id)) BETWEEN 1 AND 250),
 category text NOT NULL CHECK (category IN ('service','driver','safety','schedule','other')),
 description text NOT NULL CHECK (length(btrim(description)) BETWEEN 1 AND 5000),
 trip_id integer REFERENCES trips(id) ON DELETE RESTRICT,
 route_id integer REFERENCES routes(id) ON DELETE RESTRICT,
 status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_review','resolved','rejected')),
 response text CHECK (response IS NULL OR length(btrim(response)) BETWEEN 1 AND 5000),
 updated_by text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX complaints_owner_created_idx ON complaints(user_id,created_at DESC,id DESC);
CREATE INDEX complaints_status_created_idx ON complaints(status,created_at DESC,id DESC);
CREATE TRIGGER complaints_updated BEFORE UPDATE ON complaints FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TABLE feedback (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 user_id text NOT NULL CHECK (length(btrim(user_id)) BETWEEN 1 AND 250),
 target text NOT NULL CHECK (target IN ('service','bus','trip','route')),
 bus_id integer REFERENCES buses(id) ON DELETE RESTRICT,
 trip_id integer REFERENCES trips(id) ON DELETE RESTRICT,
 route_id integer REFERENCES routes(id) ON DELETE RESTRICT,
 rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
 comment text CHECK (comment IS NULL OR length(btrim(comment)) BETWEEN 1 AND 5000),
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK ((target='service' AND bus_id IS NULL AND trip_id IS NULL AND route_id IS NULL)
 OR (target='bus' AND bus_id IS NOT NULL AND trip_id IS NULL AND route_id IS NULL)
 OR (target='trip' AND trip_id IS NOT NULL AND bus_id IS NULL AND route_id IS NULL)
 OR (target='route' AND route_id IS NOT NULL AND bus_id IS NULL AND trip_id IS NULL))
);
CREATE INDEX feedback_owner_created_idx ON feedback(user_id,created_at DESC,id DESC);
CREATE TABLE notifications (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 user_id text NOT NULL CHECK (length(btrim(user_id)) BETWEEN 1 AND 250),
 type text NOT NULL CHECK (length(btrim(type)) BETWEEN 1 AND 100),
 title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 250),
 message text NOT NULL CHECK (length(btrim(message)) BETWEEN 1 AND 5000),
 reference_type text CHECK (reference_type IS NULL OR length(btrim(reference_type)) BETWEEN 1 AND 100),
 reference_id text CHECK (reference_id IS NULL OR length(btrim(reference_id)) BETWEEN 1 AND 250),
 read_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_owner_created_idx ON notifications(user_id,created_at DESC,id DESC);
CREATE INDEX notifications_unread_idx ON notifications(user_id,created_at DESC) WHERE read_at IS NULL;
