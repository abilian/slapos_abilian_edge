/*
 * Prepare Uptime Kuma's database and first admin account, headlessly (ADR 056).
 *
 * Runs BEFORE the server starts, and that ordering is the point. Uptime Kuma
 * decides once at startup whether it needs setup, by counting rows in `user`;
 * the flag then lives in memory. Creating the account while the server is
 * already running leaves that flag stale, so the browser keeps serving the
 * first-run setup wizard even though the account exists — an app you cannot log
 * into, with credentials that look fine. Creating it first means the server
 * boots straight to a login form.
 *
 * Upstream offers no CLI and no HTTP endpoint for this: its setup is a
 * socket.io event driven by that wizard, which a deploy cannot click through.
 * So this runs the app's own migrations (Database.patch) and then mirrors the
 * setup handler — refuse an already-initialised instance, otherwise insert one
 * `user` row hashed with the app's own bcrypt parameters (saltRounds 10, see
 * server/password-hash.js). Using the app's own modules means the schema and
 * the hash cannot drift from what the running server expects.
 *
 * Idempotent: an existing user means setup already happened, so leave it alone
 * (a redeploy must never reset an operator's password). Anything else fails
 * loud and non-zero — a running app nobody can log into is not a successful
 * deploy.
 */
"use strict";

const bcrypt = require("bcryptjs");
// Paths are relative to THIS file (scripts/), not the working directory.
const Database = require("../server/database");
const { R } = require("redbean-node");

const SALT_ROUNDS = 10; // must match server/password-hash.js

function required(name) {
    const value = process.env[name];
    if (!value) {
        console.error(
            `Uptime Kuma admin bootstrap: ${name} not set ` +
                "(declare it under [admin] in hop3.toml)"
        );
        process.exit(1);
    }
    return value;
}

async function main() {
    const username = required("HOP3_ADMIN_USER");
    const password = required("HOP3_ADMIN_PASSWORD");

    // Create/upgrade the schema exactly as the server would on its own first
    // start, so `user` exists to write to.
    Database.initDataDir({});
    await Database.connect(false, false, true);
    await Database.patch();

    const existing = await R.knex("user").count("id as count").first();
    if (existing.count > 0) {
        // NAME them. "already has a user" left the next question unanswerable:
        // if the admin Hop3 advertised is not among these, the operator has
        // been handed a password that cannot work, and the smoke test's
        // "the credential Hop3 generated was refused" is the truth about the
        // account rather than about the application.
        const users = await R.knex("user").select("username");
        const names = users.map((u) => u.username);
        console.log(
            `Uptime Kuma already has ${names.length} user(s): ${names.join(", ")}; ` +
                "leaving them untouched."
        );
        if (!names.includes(username)) {
            console.warn(
                `WARNING: the admin account Hop3 reports ('${username}') does NOT ` +
                    "exist in this database. The password shown after deploy will " +
                    "not sign in."
            );
        }
    } else {
        await R.knex("user").insert({
            username,
            password: await bcrypt.hash(password, SALT_ROUNDS),
            active: 1,
        });
        console.log(`Uptime Kuma admin '${username}' created.`);
    }

    // OUTSIDE the branch above, deliberately. This used to sit after the admin
    // insert, so an instance that already had any user returned first and the
    // probe was never created — while Hop3, seeing a [probe] with no `create`
    // command, told the smoke test a probe existed. The check then signed in as
    // an account nobody had made and reported the APPLICATION broken. The two
    // accounts have independent lifecycles: the admin is created once and is
    // then the operator's, the probe is Hop3's and must exist on every deploy.
    await createProbeUser();
}

/**
 * Create Hop3's own probe account, if [probe] declares one.
 *
 * The [admin] credential is handed to the operator, so it stops being Hop3's to
 * assert once they change the password. This account is Hop3's alone, so a
 * refused sign-in means the app broke.
 *
 * Uptime Kuma has no roles — every user is equivalent — so the probe carries the
 * same rights as the admin. That is the app's model, not a choice made here.
 */
async function createProbeUser() {
    const username = process.env.HOP3_PROBE_USER;
    const password = process.env.HOP3_PROBE_PASSWORD;
    if (!username || !password) {
        return;
    }

    const existing = await R.knex("user").where({ username }).first();
    if (existing) {
        return;
    }

    await R.knex("user").insert({
        username,
        password: await bcrypt.hash(password, SALT_ROUNDS),
        active: 1,
    });
    console.log(`Uptime Kuma probe user '${username}' created.`);
}

main()
    .then(async () => {
        await Database.close();
        process.exit(0);
    })
    .catch(async (e) => {
        console.error(
            `Uptime Kuma admin bootstrap: ${e && e.message ? e.message : String(e)}`
        );
        process.exit(1);
    });
