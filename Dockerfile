ARG node_version=18.17
FROM node:${node_version} as intermediate

################ 
# Build Client
################ 
COPY ./ ./
WORKDIR ./central
RUN ./files/prebuild/write-version.sh
ARG OIDC_ENABLED
RUN OIDC_ENABLED="$OIDC_ENABLED" ./files/prebuild/build-frontend.sh

RUN mkdir /tmp/sentry-versions
RUN git describe --tags --dirty > /tmp/sentry-versions/central
WORKDIR server
RUN git describe --tags --dirty > /tmp/sentry-versions/server
WORKDIR ../client
RUN git describe --tags --dirty > /tmp/sentry-versions/client


################ 
# Build Server
################ 
FROM node:${node_version}

WORKDIR /usr/odk

RUN apt-get update && apt-get install wait-for-it && rm -rf /var/lib/apt/lists/*

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list && \
  curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg && \
  apt-get update && \
  apt-get install -y cron gettext postgresql-client-14 python3-pip default-jre nginx-extras lua-zlib

COPY central/files/service/crontab /etc/cron.d/odk

COPY central/server/package*.json ./

RUN npm clean-install --omit=dev --legacy-peer-deps --no-audit --fund=false --update-notifier=false

COPY central/server/ ./
COPY central/files/service/scripts/ ./

COPY config.json.template /usr/share/odk/
COPY central/files/service/odk-cmd /usr/bin/

COPY --from=intermediate /tmp/sentry-versions/ ./sentry-versions


################ 
# Pyxform
################ 

COPY pyxform-http/requirements.txt /tmp/ 
RUN rm /usr/lib/python3.11/EXTERNALLY-MANAGED && \
  pip install --requirement /tmp/requirements.txt

COPY pyxform-http/app /usr/odk/


################ 
# Nginx - for serving static client
################ 

COPY central/files/nginx/*.conf* /usr/share/odk/nginx/
COPY odk.conf.template /usr/share/odk/nginx/
RUN rm /etc/nginx/sites-enabled/default
COPY --from=intermediate central/client/dist/ /usr/share/nginx/html
COPY --from=intermediate /tmp/version.txt /usr/share/nginx/html

# SCRIPTS

COPY start-odk.sh /scripts/start-odk.sh
COPY src/ ./containerext/

CMD ["/scripts/start-odk.sh"]
