// Tests of ../firestore.rules against the Firebase emulator.
// Run with `npm test` in this folder (starts and stops the emulator itself).
const { readFileSync } = require('node:fs');
const path = require('node:path');
const { before, after, beforeEach, describe, it } = require('node:test');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  arrayUnion,
} = require('firebase/firestore');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-foodsaver',
    firestore: {
      rules: readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await env.cleanup();
});

const request = (id) => ({
  id,
  beneficiary: { id: 'rest1', name: 'Le Jardin' },
  status: 'pending',
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/donor1'), { role: 'user', email: 'd@x.com' });
    await setDoc(doc(db, 'users/other1'), { role: 'user' });
    // Created by another module before the profile: no role field at all.
    await setDoc(doc(db, 'users/legacy1'), { fridgeSeeded: true });
    await setDoc(doc(db, 'users/rest1'), { role: 'restaurant' });
    await setDoc(doc(db, 'users/admin1'), { role: 'admin' });
    await setDoc(doc(db, 'donations/don1'), {
      donorId: 'donor1',
      foodName: 'Bread',
      status: 'available',
      requests: [],
    });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('profile document users/{uid}', () => {
  it('lets a new user create their own profile as user', async () => {
    await assertSucceeds(setDoc(doc(as('new1'), 'users/new1'), { role: 'user' }));
  });

  it('lets a new user create their own profile as restaurant', async () => {
    await assertSucceeds(
      setDoc(doc(as('new1'), 'users/new1'), {
        role: 'restaurant',
        businessName: 'Le Jardin',
      }),
    );
  });

  it('accepts a profile written without a role (other modules merge fields)', async () => {
    await assertSucceeds(setDoc(doc(as('new1'), 'users/new1'), { fridgeSeeded: true }));
  });

  it('refuses creating a profile as admin', async () => {
    await assertFails(setDoc(doc(as('new1'), 'users/new1'), { role: 'admin' }));
  });

  it("refuses creating someone else's profile", async () => {
    await assertFails(setDoc(doc(as('new1'), 'users/new2'), { role: 'user' }));
  });

  it('lets users read only their own profile', async () => {
    await assertSucceeds(getDoc(doc(as('donor1'), 'users/donor1')));
    await assertFails(getDoc(doc(as('donor1'), 'users/other1')));
    await assertFails(getDoc(doc(anon(), 'users/donor1')));
  });

  it('lets users update other fields of their profile', async () => {
    await assertSucceeds(
      updateDoc(doc(as('donor1'), 'users/donor1'), { displayName: 'Maya' }),
    );
    await assertSucceeds(
      setDoc(doc(as('donor1'), 'users/donor1'), { photo: 'abc' }, { merge: true }),
    );
  });

  it('refuses a user making themselves admin or restaurant', async () => {
    await assertFails(updateDoc(doc(as('donor1'), 'users/donor1'), { role: 'admin' }));
    await assertFails(
      updateDoc(doc(as('donor1'), 'users/donor1'), { role: 'restaurant' }),
    );
    // Also when the profile had no role yet.
    await assertFails(
      setDoc(doc(as('legacy1'), 'users/legacy1'), { role: 'admin' }, { merge: true }),
    );
  });

  it('refuses a restaurant or admin changing their role', async () => {
    await assertFails(updateDoc(doc(as('rest1'), 'users/rest1'), { role: 'user' }));
    await assertFails(updateDoc(doc(as('admin1'), 'users/admin1'), { role: 'user' }));
  });

  it('lets an admin keep editing their own profile', async () => {
    await assertSucceeds(
      updateDoc(doc(as('admin1'), 'users/admin1'), { displayName: 'Root' }),
    );
  });

  it('lets users delete only their own profile', async () => {
    await assertFails(deleteDoc(doc(as('other1'), 'users/donor1')));
    await assertSucceeds(deleteDoc(doc(as('donor1'), 'users/donor1')));
  });
});

describe('private data users/{uid}/...', () => {
  it('lets the owner read and write their fridge', async () => {
    const ref = doc(as('donor1'), 'users/donor1/fridge_items/f1');
    await assertSucceeds(setDoc(ref, { name: 'Milk' }));
    await assertSucceeds(getDoc(ref));
  });

  it('refuses other users and signed-out requests', async () => {
    await assertFails(setDoc(doc(as('other1'), 'users/donor1/fridge_items/f1'), { name: 'x' }));
    await assertFails(getDoc(doc(as('other1'), 'users/donor1/shopping_lists/l1')));
    await assertFails(getDoc(doc(anon(), 'users/donor1/fridge_items/f1')));
  });

  it('refuses even a restaurant or admin reading a fridge', async () => {
    await assertFails(getDoc(doc(as('rest1'), 'users/donor1/fridge_items/f1')));
    await assertFails(getDoc(doc(as('admin1'), 'users/donor1/fridge_items/f1')));
  });
});

describe('donation events users/{uid}/notifications', () => {
  const event = { type: 'request', title: 'New request' };

  it('lets a restaurant or the admin notify a donor', async () => {
    await assertSucceeds(setDoc(doc(as('rest1'), 'users/donor1/notifications/e1'), event));
    await assertSucceeds(setDoc(doc(as('admin1'), 'users/donor1/notifications/e2'), event));
  });

  it('refuses a normal user writing into another user notifications', async () => {
    await assertFails(setDoc(doc(as('other1'), 'users/donor1/notifications/e1'), event));
    await assertFails(setDoc(doc(anon(), 'users/donor1/notifications/e1'), event));
  });

  it('lets the owner manage their own events', async () => {
    await assertSucceeds(setDoc(doc(as('donor1'), 'users/donor1/notifications/e1'), event));
  });

  it('does not let a restaurant read a donor notifications', async () => {
    await assertFails(getDoc(doc(as('rest1'), 'users/donor1/notifications/e1')));
  });
});

describe('donations/{id}', () => {
  it('can be read by any signed-in user, not by signed-out requests', async () => {
    await assertSucceeds(getDoc(doc(as('other1'), 'donations/don1')));
    await assertSucceeds(getDoc(doc(as('rest1'), 'donations/don1')));
    await assertSucceeds(getDoc(doc(as('admin1'), 'donations/don1')));
    await assertFails(getDoc(doc(anon(), 'donations/don1')));
  });

  it('lets a user create a donation in their own name only', async () => {
    const donation = { foodName: 'Rice', status: 'available', requests: [] };
    await assertSucceeds(
      setDoc(doc(as('donor1'), 'donations/new1'), { ...donation, donorId: 'donor1' }),
    );
    await assertFails(
      setDoc(doc(as('donor1'), 'donations/new2'), { ...donation, donorId: 'other1' }),
    );
  });

  it('refuses restaurants and admins creating donations', async () => {
    const donation = { foodName: 'Rice', status: 'available', requests: [] };
    await assertFails(
      setDoc(doc(as('rest1'), 'donations/new1'), { ...donation, donorId: 'rest1' }),
    );
    await assertFails(
      setDoc(doc(as('admin1'), 'donations/new2'), { ...donation, donorId: 'admin1' }),
    );
  });

  it('lets a restaurant add exactly one request', async () => {
    const ref = doc(as('rest1'), 'donations/don1');
    await assertSucceeds(updateDoc(ref, { requests: arrayUnion(request('r1')) }));
  });

  it('refuses a restaurant adding two requests at once, or touching the status', async () => {
    const ref = doc(as('rest1'), 'donations/don1');
    await assertFails(updateDoc(ref, { requests: [request('r1'), request('r2')] }));
    await assertFails(
      updateDoc(ref, { requests: [request('r1')], status: 'reserved' }),
    );
    await assertFails(updateDoc(ref, { status: 'reserved' }));
  });

  it('refuses a normal user who is not the donor adding a request', async () => {
    await assertFails(
      updateDoc(doc(as('other1'), 'donations/don1'), { requests: [request('r1')] }),
    );
  });

  it('lets the admin accept or refuse requests', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'donations/don1'), {
        requests: [request('r1')],
      });
    });
    const ref = doc(as('admin1'), 'donations/don1');
    await assertSucceeds(
      updateDoc(ref, {
        status: 'reserved',
        requests: [{ ...request('r1'), status: 'accepted' }],
      }),
    );
  });

  it('lets the donor mark it collected but not decide on requests', async () => {
    const ref = doc(as('donor1'), 'donations/don1');
    await assertSucceeds(
      updateDoc(ref, { status: 'collected', collectedAt: new Date() }),
    );
    await assertFails(
      updateDoc(ref, { requests: [{ ...request('r1'), status: 'accepted' }] }),
    );
    await assertFails(updateDoc(ref, { foodName: 'Cake' }));
  });

  it('lets only the donor delete a donation', async () => {
    await assertFails(deleteDoc(doc(as('other1'), 'donations/don1')));
    await assertFails(deleteDoc(doc(as('rest1'), 'donations/don1')));
    await assertFails(deleteDoc(doc(as('admin1'), 'donations/don1')));
    await assertSucceeds(deleteDoc(doc(as('donor1'), 'donations/don1')));
  });
});
