echo "writing a new nginx configuration file.."

################ 
# ODK Central Service Startup - central/files/service/scripts/start-odk.sh
################

echo "generating local service configuration.."
ENKETO_API_KEY=$(cat /etc/secrets/enketo-api-key) \
BASE_URL=$( [ "${HTTPS_PORT}" = 443 ] && echo https://"${DOMAIN}" || echo https://"${DOMAIN}":"${HTTPS_PORT}" ) \
envsubst '$DOMAIN $BASE_URL $SYSADMIN_EMAIL $ENKETO_API_KEY $DB_HOST $DB_USER $DB_PASSWORD $DB_NAME $DB_SSL $EMAIL_FROM $EMAIL_HOST $EMAIL_PORT $EMAIL_SECURE $EMAIL_IGNORE_TLS $EMAIL_USER $EMAIL_PASSWORD $OIDC_ENABLED $OIDC_ISSUER_URL $OIDC_CLIENT_ID $OIDC_CLIENT_SECRET $SENTRY_ORG_SUBDOMAIN $SENTRY_KEY $SENTRY_PROJECT' \
    < /usr/share/odk/config.json.template \
    > /usr/odk/config/local.json

SENTRY_RELEASE="$(cat sentry-versions/server)"
export SENTRY_RELEASE
# shellcheck disable=SC2089
SENTRY_TAGS="{ \"version.central\": \"$(cat sentry-versions/central)\", \"version.client\": \"$(cat sentry-versions/client)\" }"
# shellcheck disable=SC2090
export SENTRY_TAGS

echo "running migrations.."
node ./lib/bin/run-migrations

echo "checking migration success.."
node ./lib/bin/check-migrations

if [ $? -eq 1 ]; then
  echo "*** Error starting ODK! ***"
  echo "After attempting to automatically migrate the database, we have detected unapplied migrations, which suggests a problem with the database migration step. Please look in the console above this message for any errors and post what you find in the forum: https://forum.getodk.org/"
  exit 1
fi

# If DEFAULT_ADMIN_EMAIL is set, we want to run the bootstrapAdmin script to get the first user set up 
if [ ! -z "${DEFAULT_ADMIN_EMAIL}" ]
then
  echo "found DEFAULT_ADMIN_EMAIL"
  node -e 'const { bootstrapAdmin } = require("./containerext/bootstrap.js"); bootstrapAdmin(require("config").get("default.database"), process.env.DEFAULT_ADMIN_EMAIL, process.env.DEFAULT_ADMIN_PASSWORD);'
  echo "done bootstrapping admin, remove DEFAULT_ADMIN_EMAIL and DEFAULT_ADMIN_PASSWORD from ENV for security"
fi


echo "starting cron.."
cron -f &

MEMTOT=$(vmstat -s | grep 'total memory' | awk '{ print $1 }')
if [ "$MEMTOT" -gt "1100000" ]
then
  export WORKER_COUNT=4
else
  export WORKER_COUNT=1
fi
echo "using $WORKER_COUNT worker(s) based on available memory ($MEMTOT).."

echo "starting nginx"
nginx

echo "starting pyxform"
gunicorn --bind 0.0.0.0:8080 --workers 5 --timeout 600 --max-requests 1 --max-requests-jitter 3 main:app &


echo "starting server."
pm2-runtime ./pm2.config.js --instances $WORKER_COUNT

