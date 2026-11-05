# LimeSurvey, with what its .htaccess files deny

The golden recipe with a `[proxy] deny` list. Under nginx, without one, anyone can read `tmp/runtime` and run `open-api-gen.php`, which writes to `docs/`.

A respondent's uploaded file stays readable by anyone who has its name, which has 15 random characters: `upload/surveys/.htaccess` denies these files by pattern, and `deny` takes prefixes.
