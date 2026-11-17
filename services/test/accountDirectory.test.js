import test from 'node:test';
import assert from 'node:assert/strict';
import { createAuthService } from '../src/services/authService.js';

const identity = {
  sub: 'verified-subject', email: 'alpha.beta@g.bracu.ac.bd',
  name: 'Alpha Beta', email_verified: true, hd: 'g.bracu.ac.bd',
};

function setup(overrides = {}) {
  const calls = [];
  const user = { id: 42, role: 'driver' };
  const service = createAuthService({
    config: { domain: 'g.bracu.ac.bd' },
    pool: { query() { assert.fail('Delegated authentication must not use the fallback database'); } },
    provider: {
      authorizationUrl: () => 'https://accounts.google.com/',
      verify: async () => ({ ...identity, nonce: flow.nonce, ...overrides }),
    },
    accountDirectory: {
      authenticate: async verified => { calls.push(verified); return user; },
      findUser: async id => ({ ...user, id }),
    },
  });
  const { flow } = service.begin();
  return { service, flow, calls, user };
}

test('account directory receives only verified Google identity', async () => {
  const { service, flow, calls, user } = setup();
  assert.equal(await service.authenticate({ state: flow.state, code: 'authorization-code', role: 'authority' }, flow), user);
  assert.deepEqual(calls, [{ subject: identity.sub, email: identity.email, name: identity.name }]);
});

test('account lookup delegates to the configured directory', async () => {
  const { service } = setup();
  assert.deepEqual(await service.findUser(42), { id: 42, role: 'driver' });
});

test('invalid nonce is rejected before account directory authentication', async () => {
  const { service, flow, calls } = setup({ nonce: 'invalid-nonce' });
  await assert.rejects(service.authenticate({ state: flow.state, code: 'authorization-code' }, flow), /invalid_callback/);
  assert.deepEqual(calls, []);
});

test('ineligible Google identity is rejected before account directory authentication', async () => {
  const { service, flow, calls } = setup({ email: 'alpha.beta@example.com' });
  await assert.rejects(service.authenticate({ state: flow.state, code: 'authorization-code' }, flow), /invalid_institution/);
  assert.deepEqual(calls, []);
});
