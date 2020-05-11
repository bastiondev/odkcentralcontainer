echo "writing a new nginx configuration file.."
/bin/bash -c "envsubst '\$PORT' < /usr/share/nginx/odk.conf.template > /etc/nginx/conf.d/odk.conf"

CONFIG_PATH=/usr/odk/config/local.json
if [ ! -e "$CONFIG_PATH" ]
then
  echo "generating local service configuration.."
  /bin/bash -c "envsubst < /usr/share/odk/config.json.template > $CONFIG_PATH"
fi

echo "running migrations.."
node -e 'const { withDatabase, migrate } = require("./lib/model/database"); withDatabase(require("config").get("default.database"))(migrate);'

if [ ! -e "$DEFAULT_ADMIN_EMAIL" ]
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
  WORKER_COUNT=4
else
  WORKER_COUNT=1
fi
echo "using $WORKER_COUNT worker(s) based on available memory ($MEMTOT).."

echo "starting nginx"
nginx

echo "starting pyxform"
waitress-serve --port=8080 --call main:app &

echo "starting server"
mkdir -p /var/log/odk
node node_modules/naught/lib/main.js start --remove-old-ipc true --worker-count $WORKER_COUNT --daemon-mode false --log /var/log/odk/naught.log --stdout /proc/1/fd/1 --stderr /proc/1/fd/2 lib/bin/run-server.js
