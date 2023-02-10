#! /bin/bash

expect << END
        spawn createuser --username "$POSTGRES_USER" --echo --encrypted --pwprompt "$KC_DB_USERNAME"
        expect "Enter password for new role:"
        send "$KC_DB_PASSWORD\r"
        expect "Enter it again:"
        send "$KC_DB_PASSWORD\r"
        expect eof
        spawn createdb --username "$POSTGRES_USER" -O "$KC_DB_USERNAME" "$KC_DB_URL_DATABASE"
        expect eof
END