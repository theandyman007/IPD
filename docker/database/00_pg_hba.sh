#!/bin/bash
# Update database access to trust all

echo "host all all 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf"