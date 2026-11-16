-- Apply explicitly only after the existing authentication and transport schemas
-- are installed in the SAME database. Never auto-assign privileges from email,
-- request headers, registration, or a client-selected role.
CREATE TABLE transport_account_roles (
  user_id bigint PRIMARY KEY REFERENCES users(id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (role IN ('driver', 'authority')),
  driver_id integer UNIQUE REFERENCES drivers(id) ON DELETE RESTRICT,
  CHECK ((role = 'driver' AND driver_id IS NOT NULL) OR
         (role = 'authority' AND driver_id IS NULL))
);
-- No row means Student. Provision grants only through a trusted administrator.
