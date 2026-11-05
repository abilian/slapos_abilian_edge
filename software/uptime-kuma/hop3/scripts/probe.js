/*
 * Drive Uptime Kuma's socket.io sign-in, using the app's OWN bundled client.
 *
 * Uptime Kuma authenticates over socket.io, not HTTP — there is no form to
 * post. `npm ci` puts socket.io-client in this tree, and it is the same library
 * the app's frontend uses, so the exchange is the real one.
 *
 * A FILE, not a string inside check.py. It lived there as an embedded Python
 * literal until a `\'` in the Python source arrived at node as a bare quote and
 * the whole probe died with a SyntaxError — after a full deploy. A .js file is
 * what node runs, is what `node --check` reads, and has no second layer of
 * escaping to get wrong.
 *
 * Usage: PROBE_PASSWORD=... node scripts/probe.js <url> <host> <username>
 * The password is read from the environment, never from argv, where any local
 * user reads it in /proc/<pid>/cmdline.
 * Prints one JSON object on stdout; exits non-zero with a reason on any failure.
 */
const io = require('socket.io-client');
const [url, host, username] = process.argv.slice(2);
const goodPassword = process.env.PROBE_PASSWORD;
if (!goodPassword) {
  console.error('PROBE_PASSWORD is not set');
  process.exit(1);
}

const CONNECT_MS = 20000;
const OFFER_MS = 8000;
const LOGIN_MS = 20000;

function connect() {
  // `url` is a loopback origin, not the app's name: this process resolves its
  // own DNS, and the app's hostname does not exist anywhere but nginx's vhost
  // table. The Python client is addressed by name and has its socket rewritten
  // underneath (LoopbackTransport); a subprocess gets no such help, so it
  // connects to loopback and carries the name in the two places that select the
  // vhost — `servername` for TLS SNI, and the `Host` header.
  return io(url, { extraHeaders: { Host: host }, rejectUnauthorized: false,
                   servername: host, transports: ['websocket'] });
}

// Every wait below REJECTS when nothing arrives. They used to resolve on their
// own timeout, which meant a probe that never reached the server reported the
// same shape as one that did: `offered` stayed null, the check asked only
// whether it was 'setup', and null is not 'setup' — so "the server offers a
// login, not its setup wizard" passed without a socket ever being opened. The
// login then timed out and was reported as a refused credential. Three silent
// fallbacks stacked into an accusation against a working app.
function settle(sock, what, ms, arm) {
  return new Promise((resolve, reject) => {
    let done = false;
    const finish = (fn, v) => { if (!done) { done = true; clearTimeout(t); fn(v); } };
    const t = setTimeout(
      () => finish(reject, new Error(what + ': nothing within ' + ms + 'ms')), ms);
    sock.on('connect_error', (e) =>
      finish(reject, new Error(what + ': connect_error: ' + (e && e.message || e))));
    arm((v) => finish(resolve, v));
  });
}

function connected(sock) {
  return settle(sock, 'socket.io connection', CONNECT_MS,
                (ok) => sock.on('connect', () => ok(true)));
}

function login(sock, password) {
  // A refusal is an ANSWER and must reach the caller as one; only silence is an
  // error. The two need opposite fixes, and collapsing them into `false` is
  // what made a working account look rejected.
  return settle(sock, "the socket.io 'login' event", LOGIN_MS, (ok) => {
    sock.emit('login', { username, password, token: '' }, (res) => ok({
      ok: !!(res && res.ok),
      msg: (res && (res.msg || res.message)) || '',
      answered: true,
    }));
  }).catch((e) => ({ ok: false, msg: String(e.message || e), answered: false }));
}

(async () => {
  const result = { offered: null, good: null, bad: null };

  const first = connect();
  await connected(first);
  result.offered = await settle(first, "the server\'s first message", OFFER_MS, (ok) => {
    first.on('setup', () => ok('setup'));
    first.on('loginRequired', () => ok('loginRequired'));
  });
  result.good = await login(first, goodPassword);
  first.close();

  const second = connect();
  await connected(second);
  result.bad = await login(second, 'not-the-password');
  second.close();

  console.log(JSON.stringify(result));
  process.exit(0);
})().catch((e) => { console.error(String(e && e.message || e)); process.exit(1); });
