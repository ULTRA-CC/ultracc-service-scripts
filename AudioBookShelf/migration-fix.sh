#!/usr/bin/env bash
# Fixes a 502 / restart loop caused by an interrupted Audiobookshelf database migration.
# Run as user shell.

printf "\033[0;31mDisclaimer: This script is unofficial and Ultra.cc staff will not support any issues with it. It edits your Audiobookshelf database. A backup is taken first.\033[0m\n"
read -rp "Type confirm if you wish to continue: " input
if [ ! "$input" = "confirm" ]; then
    exit
fi

APP=audiobookshelf
DB="$HOME/.apps/$APP/config/absdatabase.sqlite"
SERVER="${HOSTNAME%%.*}"

say(){ printf '== %s\n' "$*"; }
health(){ curl -s -m 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/$APP/" 2>/dev/null || true; }

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
import sqlite3, sys, os

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

q = lambda s: s.replace('"', '""')
tables = lambda: {r[0] for r in cur.execute("select name from sqlite_master where type='table'")}
rows = lambda t: cur.execute('select count(*) from "%s"' % q(t)).fetchone()[0]
integrity = lambda: cur.execute("pragma integrity_check").fetchone()[0]

pre = integrity(); print("integrity (pre):", pre)
if pre != "ok":
    print("!! integrity not ok. Open a support ticket, do not auto-edit.")
    sys.exit(2)

if not any(x.endswith("_backup") for x in tables()):
    print("no *_backup tables. Different failure mode.")
    sys.exit(3)

bak = path + ".recover-bak"
b = sqlite3.connect(bak); con.backup(b); b.close(); print("snapshot:", bak)

try:
    con.execute("BEGIN IMMEDIATE")
except sqlite3.OperationalError as e:
    os.remove(bak)
    print("database is busy:", e)
    print("Something is still writing to it. Open a support ticket.")
    sys.exit(5)

# read and plan inside the lock, so the counts cannot go stale before we act
try:
    t = tables()
    orphans = sorted(x for x in t if x.endswith("_backup"))
    if not orphans:
        con.execute("ROLLBACK"); os.remove(bak)
        print("no *_backup tables. Different failure mode.")
        sys.exit(3)

    done = []
    for bk in orphans:
        base = bk[:-len("_backup")]
        # whichever of the pair still holds the rows is the real data, never drop that one
        if base not in t:
            con.execute('ALTER TABLE "%s" RENAME TO "%s"' % (q(bk), q(base)))
            done.append("RENAME  %s -> %s (base missing)" % (bk, base))
        else:
            n_bk, n_base = rows(bk), rows(base)
            if n_bk > n_base:
                con.execute('DROP TABLE "%s"' % q(base))
                con.execute('ALTER TABLE "%s" RENAME TO "%s"' % (q(bk), q(base)))
                done.append("RESTORE %s -> %s (copy back unfinished: %d rows vs %d)" % (bk, base, n_bk, n_base))
            else:
                con.execute('DROP TABLE "%s"' % q(bk))
                done.append("DROP    %s (duplicate: %d rows vs %d)" % (bk, n_bk, n_base))
    con.execute("COMMIT")
except SystemExit:
    raise
except Exception as e:
    try: con.execute("ROLLBACK")
    except Exception: pass
    print("error before commit:", e)
    print("NO changes were made to the database.")
    sys.exit(6)

for line in done:
    print(line)
print("remaining *_backup:", sorted(x for x in tables() if x.endswith("_backup")) or "none")
print("integrity (post):", integrity())
PY

case "$rc" in
  0) say "DB reconciled" ;;
  2) echo "integrity failed. DB untouched."; app-$APP start >/dev/null 2>&1 || true; exit 2 ;;
  3) echo "no orphan tables. Restarting unchanged."; app-$APP start >/dev/null 2>&1 || true; exit 3 ;;
  4) echo "DB unreadable here. Open a support ticket."; app-$APP start >/dev/null 2>&1 || true; exit 4 ;;
  5) echo "DB busy. Nothing changed."; app-$APP start >/dev/null 2>&1 || true; exit 5 ;;
  6) echo "DB edit failed and was rolled back. Nothing changed."; app-$APP start >/dev/null 2>&1 || true; exit 6 ;;
  *) echo "python step errored (rc=$rc)."; app-$APP start >/dev/null 2>&1 || true; exit "$rc" ;;
esac

say "starting $APP"
app-$APP start >/dev/null 2>&1 || true

say "waiting for Audiobookshelf on :$PORT"
up=0
for _ in $(seq 1 60); do
  sleep 5
  case "$(health)" in 200|301|302) up=1; echo "  UP"; break;; *) echo "  ...starting";; esac
done

echo
if [ "$up" = 1 ]; then
  echo "SUCCESS. Check your library at https://${APP}-${USER}.${SERVER}.usbx.me/"
  echo "Once you have confirmed your library is intact: rm -f '$DB.recover-bak'"
else
  echo "Audiobookshelf has not answered yet. This is not necessarily a failure."
  echo "It is most likely still re-running its database migration, and it does not answer"
  echo "HTTP while it does. On a large library that can take an hour or more. Leave it"
  echo "running and check again later:"
  echo
  echo "  https://${APP}-${USER}.${SERVER}.usbx.me/"
  echo
  echo "Your backup is kept at: $DB.recover-bak"
  echo "Only if it is still down after several hours, roll back with all four lines:"
  echo
  echo "  app-$APP stop"
  echo "  rm -f '$DB-journal' '$DB-wal' '$DB-shm'"
  echo "  cp -f '$DB.recover-bak' '$DB'"
  echo "  app-$APP start"
  echo
  echo "The rm line is required. Copying the backup over a database that still has a"
  echo "journal beside it will corrupt it. If unsure, open a support ticket instead."
fi
