import pg from 'pg';
export function createPool(config) { return new pg.Pool({ connectionString: config.databaseUrl }); }
