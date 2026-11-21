// Tests database.rules.json against the Realtime Database emulator, with the
// writes the app really makes (rooms, seats, profiles, leaderboard):
//
//   firebase emulators:exec --only database --project pastra-95bc5 "node tool/ci/rules_test.mjs"
//
// Never touches the live database: it talks to the emulator only.
const host = process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '127.0.0.1:9000';
// The namespace the rules are loaded into (the app's database, see firebase_options.dart).
const ns = 'pastra-95bc5-default-rtdb';
if (!/^(127\.0\.0\.1|localhost):/.test(host)) throw new Error(`not an emulator: ${host}`);

// Requests as the admin ("owner"), acting as a user through
// auth_variable_override, as the Admin SDK does: the rules see auth.uid.
async function req(method, uid, path, body) {
  let url = `http://${host}/${path}.json?ns=${ns}`;
  if (uid !== 'admin') {
    const auth = uid ? { uid, provider: 'anonymous', token: { sub: uid } } : null;
    url += `&auth_variable_override=${encodeURIComponent(JSON.stringify(auth))}`;
  }
  const headers = { 'Content-Type': 'application/json', Authorization: 'Bearer owner' };
  const r = await fetch(url, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return r.status;
}
const put = (uid, path, body) => req('PUT', uid, path, body);
const patch = (uid, path, body) => req('PATCH', uid, path, body);
const del = (uid, path) => req('DELETE', uid, path);
const now = { '.sv': 'timestamp' };

let failed = 0;
async function expect(what, status, ok) {
  const passed = ok ? status === 200 : status !== 200;
  if (!passed) failed++;
  console.log(`${passed ? 'ok  ' : 'FAIL'} ${ok ? 'allowed' : 'refused'}: ${what} (${status})`);
}

await del('admin', '');
const room = 'rooms/1234';
const me = { pic: 'boat', frame: 'gold', back: 'ruby' };

// Rooms and seats.
await expect('host creates the room', await put('host', `${room}/meta`, { host: 'host', players: 4, status: 'lobby' }), true);
await expect('host sits on seat 0', await put('host', `${room}/seats/s0`, { uid: 'host', name: 'Ali', online: true, ...me }), true);
await expect('guest takes a free seat', await put('g1', `${room}/seats/s1`, { uid: 'g1', name: 'Eleni', online: true, ...me }), true);
await expect('guest sets their online flag', await put('g1', `${room}/seats/s1/online`, false), true);
await expect('another player takes a taken seat', await put('g2', `${room}/seats/s1`, { uid: 'g2', name: 'X' }), false);
await expect('guest hands their seat to someone else', await put('g1', `${room}/seats/s1`, { uid: 'g2', name: 'X' }), false);
await expect('guest moves to a free seat', await put('g1', `${room}/seats/s2`, { uid: 'g1', name: 'Eleni', online: true, ...me }), true);
await expect('guest gives back the old seat', await del('g1', `${room}/seats/s1`), true);
await expect('host moves the guest to seat 3', await patch('host', `${room}/seats`, { s3: { uid: 'g1', name: 'Eleni', online: true, ...me }, s2: null }), true);
await expect('host puts a bot on seat 1', await put('host', `${room}/seats/s1`, { bot: true, name: '', online: true, botIndex: 4 }), true);
await expect('a 40-letter seat name', await put('g2', `${room}/seats/s2`, { uid: 'g2', name: 'x'.repeat(40) }), false);
await expect('a huge avatar name', await put('g2', `${room}/seats/s2`, { uid: 'g2', name: 'Nikos', pic: 'x'.repeat(500) }), false);
await expect('guest sends a move from their seat', await put('g1', `${room}/moves/s3`, { n: 1, card: 19 }), true);
await expect('guest sends a move for another seat', await put('g1', `${room}/moves/s1`, { n: 1, card: 19 }), false);
await expect('guest reads their own view', await req('GET', 'g1', `${room}/views/s3`), true);
await expect('guest reads another seat\'s view', await req('GET', 'g1', `${room}/views/s0`), false);

// Profiles.
await expect('own profile', await put('g1', 'users/g1', { name: 'Eleni', tag: '1234', frame: 'gold', pic: 'boat', lvl: 12 }), true);
await expect('online flag on the profile', await patch('g1', 'users/g1', { online: true, seen: now }), true);
await expect('someone else\'s profile', await put('g2', 'users/g1', { name: 'X', tag: '1111' }), false);
await expect('a huge frame name', await patch('g1', 'users/g1', { frame: 'x'.repeat(500) }), false);
await expect('a level that is text', await patch('g1', 'users/g1', { lvl: 'lots' }), false);

// Leaderboard and season.
const row = { name: 'Eleni', xp: 900, wins: 3, games: 5, frame: 'gold', pic: 'boat', tag: '1234', updated: now };
await expect('own leaderboard row', await put('g1', 'leaderboard/g1', row), true);
await expect('own season row', await put('g1', 'seasons/202611/g1', { ...row, lvl: 12 }), true);
await expect('a leaderboard tag that is not 4 digits', await put('g2', 'leaderboard/g2', { ...row, tag: 'abc' }), false);
await expect('xp out of reach', await put('g2', 'leaderboard/g2', { ...row, xp: 999999 }), false);

console.log(failed ? `${failed} rule check(s) failed` : 'all rule checks passed');
process.exit(failed ? 1 : 0);
