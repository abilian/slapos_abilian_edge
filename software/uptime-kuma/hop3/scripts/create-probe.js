/*
 * Create Hop3's probe account, on demand, for [probe].create.
 *
 * Separate from create-admin.js because Hop3 must be able to RUN this and watch
 * it exit: a [probe] section whose account Hop3 cannot create is a section Hop3
 * cannot trust, and the smoke test is then never given the credential. That was
 * the state this app was in — its probe was created only inside the branch that
 * also created the admin, so any instance with an existing user silently had
 * none, and nothing could tell.
 *
 * Deliberately does NOT run migrations: create-admin.js does that before the
 * server starts, and re-patching a database the running server holds open is
 * not something a diagnostic account is worth. Idempotent, and loud: exits
 * non-zero unless the account exists when it finishes.
 */
"use strict";

const bcrypt = require("bcryptjs");
const Database = require("../server/database");
const { R } = require("redbean-node");

const SALT_ROUNDS = 10; // must match server/password-hash.js

async function main() {
    const username = process.env.HOP3_PROBE_USER;
    const password = process.env.HOP3_PROBE_PASSWORD;
    if (!username || !password) {
        console.error(
            "Uptime Kuma probe: HOP3_PROBE_USER / HOP3_PROBE_PASSWORD not set " +
                "(they are injected for every app declaring [probe])."
        );
        process.exit(1);
    }

    Database.initDataDir({});
    await Database.connect(false, false, true);

    const existing = await R.knex("user").where({ username }).first();
    if (existing) {
        console.log(`Uptime Kuma probe user '${username}' already exists.`);
        return;
    }

    await R.knex("user").insert({
        username,
        password: await bcrypt.hash(password, SALT_ROUNDS),
        active: 1,
    });

    // Verify rather than assume. The whole point of this script is that Hop3
    // gets to observe the account exist; reporting success without looking
    // would put us back where we started.
    const created = await R.knex("user").where({ username }).first();
    if (!created) {
        throw new Error(`probe user '${username}' is absent after insert`);
    }
    console.log(`Uptime Kuma probe user '${username}' created.`);
}

main()
    .then(async () => {
        await Database.close();
        process.exit(0);
    })
    .catch(async (e) => {
        console.error(
            `Uptime Kuma probe: ${e && e.message ? e.message : String(e)}`
        );
        process.exit(1);
    });
