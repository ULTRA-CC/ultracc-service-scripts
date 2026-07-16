#!/usr/bin/env bash
# Fixes a 502 / restart loop caused by an interrupted Audiobookshelf database migration.
# Run as your own user. Do not use sudo.

printf "\033[0;31mDisclaimer: This script is unofficial and Ultra.cc staff will not support any issues with it. It edits your Audiobookshelf database. A backup is taken first.\033[0m\n"
read -rp "Type confirm if you wish to continue: " input
if [ ! "$input" = "confirm" ]; then
    exit
fi

APP=audiobookshelf
DB="$HOME/.apps/$APP/config/absdatabase.sqlite"

say(){ printf '== %s\n' "$*"; }
health(){ curl -s -m 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/$APP/" 2>/dev/null || echo 000; }

command -v "app-$APP" >/dev/null 2>&1 || { echo "app-$APP not found. Wrong service?"; exit 1; }
[ -f "$DB" ] || { echo "no DB at $DB. Audiobookshelf not installed here?"; exit 1; }
[ -e "$DB.recover-bak" ] && { echo "$DB.recover-bak already exists from an earlier run. Move or remove it first."; exit 1; }

PORT="$(app-ports show 2>/dev/null | awk 'tolower($2) ~ /^audiobookshelf$/{print $1; exit}')"
[ -n "$PORT" ] || { echo "could not read the Audiobookshelf port from app-ports show."; exit 1; }

case "$(health)" in 200|301|302) echo "Audiobookshelf already up on :$PORT. Nothing to do."; exit 0;; esac

say "stopping $APP"
app-$APP stop >/dev/null 2>&1 || true
sleep 2

rc=0
python3 - "$DB" <<'PY' || rc=$?
import sqlite3, sys

path = sys.argv[1]
try:
    con = sqlite3.connect(path, timeout=10)
    con.isolation_level = None
    cur = con.cursor()
    cur.execute("select count(*) from sqlite_master")
except sqlite3.DatabaseError as e:
    print("cannot read this database:", e)
    print("Its schema is newer than the SQLite available on your service.")
    sys.exit(4)

integrity = lambda: cur.execute("pragma integrity_check").fetchone()[0]
tables = lambda: {r[0] for r in cur.execute("select name from sqlite_master where type='table'")}
rows = lambda t: cur.execute('select count(*) from "%s"' % t).fetchone()[0]

pre = integrity(); print("integrity (pre):", pre)
if pre != "ok":
    print("!! integrity not ok. Open a support ticket, do not auto-edit.")
    sys.exit(2)

t = tables()
orphans = sorted(x for x in t if x.endswith("_backup"))
if not orphans:
    print("no *_backup tables. Different failure mode.")
    sys.exit(3)

bak = path + ".recover-bak"
b = sqlite3.connect(bak); con.backup(b); b.close(); print("snapshot:", bak)

# whichever of the pair still holds the rows is the real data, never drop that one
plan = []
for bk in orphans:
    base = bk[:-len("_backup")]
    if base not in t:
        plan.append(("rename", bk, base, "base missing"))
    else:
        n_bk, n_base = rows(bk), rows(base)
        if n_bk > n_base:
            plan.append(("restore", bk, base, "copy back unfinished: %d rows vs %d" % (n_bk, n_base)))
        else:
            plan.append(("drop", bk, base, "duplicate: %d rows vs %d" % (n_bk, n_base)))

try:
    con.execute("BEGIN IMMEDIATE")
except sqlite3.OperationalError as e:
    print("database is busy:", e)
    print("Something is still writing to it. Open a support ticket.")
    sys.exit(5)

for action, bk, base, why in plan:
    if action == "rename":
        con.execute('ALTER TABLE "%s" RENAME TO "%s"' % (bk, base))
        print("RENAME  %s -> %s (%s)" % (bk, base, why))
    elif action == "restore":
        con.execute('DROP TABLE "%s"' % base)
        con.execute('ALTER TABLE "%s" RENAME TO "%s"' % (bk, base))
        print("RESTORE %s -> %s (%s)" % (bk, base, why))
    else:
        con.execute('DROP TABLE "%s"' % bk)
        print("DROP    %s (%s)" % (bk, why))
con.execute("COMMIT")

print("remaining *_backup:", sorted(x for x in tables() if x.endswith("_backup")) or "none")
print("integrity (post):", integrity())
PY

case "$rc" in
  0) say "DB reconciled" ;;
  2) echo "integrity failed. DB untouched."; app-$APP start >/dev/null 2>&1 || true; exit 2 ;;
  3) echo "no orphan tables. Restarting unchanged."; app-$APP start >/dev/null 2>&1 || true; exit 3 ;;
  4) echo "DB unreadable here. Open a support ticket."; app-$APP start >/dev/null 2>&1 || true; exit 4 ;;
  5) echo "DB busy. Nothing changed."; app-$APP start >/dev/null 2>&1 || true; exit 5 ;;
  *) echo "python step errored (rc=$rc)."; app-$APP start >/dev/null 2>&1 || true; exit "$rc" ;;
esac

say "starting $APP"
app-$APP start >/dev/null 2>&1 || true

say "waiting for Audiobookshelf on :$PORT"
up=0
for _ in $(seq 1 24); do
  sleep 5
  case "$(health)" in 200|301|302) up=1; echo "  UP"; break;; *) echo "  ...starting";; esac
done

echo
if [ "$up" = 1 ]; then
  echo "SUCCESS. Check your library at https://${APP}-${USER}.${HOSTNAME}.usbx.me/"
  echo "Once you have confirmed your library is intact: rm -f '$DB.recover-bak'"
else
  echo "DID NOT come up. Open a support ticket and paste this output."
  echo "Rollback:  app-$APP stop; cp -f '$DB.recover-bak' '$DB'; app-$APP start"
fi
