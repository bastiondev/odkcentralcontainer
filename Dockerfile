FROM node:14.17.6 as intermediate

# Build Client

COPY ./ ./
WORKDIR ./central
RUN ./files/prebuild/write-version.sh
RUN ./files/prebuild/build-frontend.sh


FROM node:14.17.6

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list; \
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -; \
  apt-get update; \
  apt-get install -y openssl cron gettext postgresql-client-9.6 python3-pip openjdk-8-jdk nginx-extras lua-zlib; 


# ODK Central

WORKDIR /usr/odk

COPY central/files/service/crontab /etc/cron.d/odk

COPY central/server/package*.json ./
RUN npm install --production
RUN npm install pm2 -g

COPY central/server/ ./
COPY central/files/service/scripts/ ./
COPY central/files/service/pm2.config.js ./

COPY config.json.template /usr/share/odk/config.json.template
COPY central/files/service/odk-cmd /usr/bin/odk-cmd


# Pyxform

COPY pyxform-http/requirements.txt /tmp/ 
RUN pip3 install --requirement /tmp/requirements.txt

COPY pyxform-http/app /usr/odk/


# Enketo

# FROM ghcr.io/enketo/enketo-express:3.1.0

# ENV ENKETO_SRC_DIR=/srv/src/enketo_express
# WORKDIR ${ENKETO_SRC_DIR}

# COPY central/files/enketo/config.json.template ${ENKETO_SRC_DIR}/config/config.json.template
# COPY central/files/enketo/config.json.template ${ENKETO_SRC_DIR}/config/config.json
# COPY central/files/enketo/start-enketo.sh ${ENKETO_SRC_DIR}/start-enketo.sh

# RUN apt-get update; apt-get install gettext-base


# Nginx - for serving static client
COPY odk.conf.template /usr/share/nginx/

COPY central/files/nginx/default /etc/nginx/sites-enabled/
COPY central/files/nginx/inflate_body.lua /usr/share/nginx/
COPY --from=intermediate central/client/dist/ /usr/share/nginx/html/
COPY --from=intermediate /tmp/version.txt /usr/share/nginx/html/


COPY start-odk.sh /scripts/start-odk.sh
COPY src/ ./containerext/


CMD ["/scripts/start-odk.sh"]
