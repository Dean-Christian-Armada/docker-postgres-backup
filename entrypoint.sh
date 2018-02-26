#!/bin/bash
set -e

file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

file_env 'AWS_ACCESS_KEY_ID'
file_env 'AWS_SECRET_ACCESS_KEY'
file_env 'AWS_DEFAULT_REGION'
file_env 'BACKUP_FROM'
file_env 'CRON_SCHEDULE'
file_env 'POSTGRES_DB'
file_env 'POSTGRES_PASSWORD'
file_env 'POSTGRES_USER'
file_env 'S3_PATH'
file_env 'MAIL_TO'
file_env 'MAIL_FROM'
file_env 'WEBHOOK'
file_env 'WEBHOOK_METHOD'


if [ -z "$CRON_SCHEDULE" ]; then
    echo "WARNING: \$CRON_SCHEDULE not set!"
fi

# Write cron schedule
echo "#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

$CRON_SCHEDULE root . /backup/backup.sh >> /backup.log 2>&1
" > /etc/cron.d/postgresql-backup

# Env variables that can be imported from backup script,
# since cron jobs doesn't get the environment set
echo "#!/bin/bash

export BACKUP_DIR=$BACKUP_DIR
export TZ=$TZ
export S3_PATH=$S3_PATH
export DB_NAME=$POSTGRES_DB
export DB_PASS=$POSTGRES_PASSWORD
export DB_USER=$POSTGRES_USER
export DB_HOST=$BACKUP_FROM
export MAIL_TO=$MAIL_TO
export MAIL_FROM=$MAIL_FROM
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
export WEBHOOK=$WEBHOOK
export WEBHOOK_METHOD=$WEBHOOK_METHOD
" > /env.sh
chmod +x /env.sh

exec "$@"
