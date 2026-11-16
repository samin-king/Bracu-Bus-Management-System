import {AuthError} from '../../Bracu-Bus-Management-System/services/src/services/authService.js';

const selectAccount = `SELECT u.id, u.name, u.email,
  COALESCE(t.role, u.role) AS role, t.driver_id
  FROM users u LEFT JOIN transport_account_roles t ON t.user_id = u.id`;

function permittedAccount(row) {
  if (!row || !['student', 'driver', 'authority'].includes(row.role)) return null;
  if (row.role === 'driver' && row.driver_id == null) return null;
  return {id: row.id, name: row.name, email: row.email, role: row.role,
    ...(row.role === 'driver' ? {driver_id: row.driver_id} : {})};
}

// This is an account policy for the existing OAuth service, not another login
// implementation. It never inserts users, links by email alone, or grants roles.
export function authorizedAccounts(pool) {
  return {
    async authenticate(identity) {
      const result = await pool.query(`${selectAccount}
        WHERE u.google_subject = $1 AND u.email = $2`, [identity.subject, identity.email]);
      const account = permittedAccount(result.rows[0]);
      if (!account) throw new AuthError('account_not_authorized', 403);
      return account;
    },
    async findUser(id) {
      const result = await pool.query(`${selectAccount} WHERE u.id = $1`, [id]);
      return permittedAccount(result.rows[0]);
    }
  };
}
