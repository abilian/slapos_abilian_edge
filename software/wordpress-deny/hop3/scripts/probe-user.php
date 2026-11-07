<?php
/**
 * Create Hop3's probe account: a WordPress SUBSCRIBER, never an administrator.
 *
 * The [admin] credential is handed to the operator, so it stops being Hop3's to
 * assert the moment they change the password. This account is Hop3's alone, so
 * a refused sign-in means the app broke.
 *
 * Uses WordPress's own wp_insert_user(), the routine `wp user create` calls, so
 * the stored credential cannot drift from what the login form verifies.
 * Idempotent, and silent when no [probe] is declared.
 */

$login = getenv('HOP3_PROBE_USER');
$password = getenv('HOP3_PROBE_PASSWORD');
if (!$login || !$password) {
    exit(0);
}

define('WP_USE_THEMES', false);
require_once __DIR__ . '/../wp-load.php';
require_once ABSPATH . 'wp-admin/includes/user.php';

if (username_exists($login)) {
    exit(0);
}

$email = getenv('HOP3_PROBE_EMAIL') ?: $login . '@hop3.invalid';
$id = wp_insert_user([
    'user_login' => $login,
    'user_pass' => $password,
    'user_email' => $email,
    // Subscriber: signing in is the entire diagnostic value, and it carries
    // none of an administrator's privilege.
    'role' => 'subscriber',
]);

if (is_wp_error($id)) {
    fwrite(STDERR, 'WordPress probe user could not be created: '
        . $id->get_error_message() . "\n");
    exit(1);
}

echo "WordPress probe user '{$login}' created.\n";
