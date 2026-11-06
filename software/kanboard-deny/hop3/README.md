# Kanboard, with its `.htaccess` rules as a deny list

The golden recipe, plus a `[proxy] deny` list. nginx ignores `.htaccess`, so under the golden recipe anyone can download a task's attachment from `/data/files/` without signing in, once they have its path. Copy the list into the golden recipe if a Hop3 host's nginx behaves the same way, as it should.
