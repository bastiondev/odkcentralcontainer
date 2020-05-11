# ODK Central Configurable Single Image Build

This repository builds a single Docker image for ODK Central with its configuration driven from environment variables, appropriate for serverless environments.  It is also configured without SSL, to allow using an external load balancer that handles HTTPS termination and certificate management.

It does not include a Postgres Instance, and assumes an external database will be used to allow ODK Central to operate in a multi-node configuration.

The target environment is Amazon Web Services' [Elastic Container Service](https://aws.amazon.com/ecs/) and [Heroku](https://www.heroku.com). 

## Environment variables

All variables are required, string values can be left empty.

| Variable                            | Description                                     |
| ----------------------------------- | ----------------------------------------------- |
| `DOMAIN`                            | Domain the server is hosted on                  |
| `PORT`                              | Port to expose for the ODK API & client bundle  |
| `DATABASE__HOST`                    | Hostname of the PostgreSQL server               |
| `DATABASE__USER`                    | Username to log into the PostgreSQL server      |
| `DATABASE__PASSWORD`                | Password for the PostgreSQL server              |
| `DATABASE__DATABASE`                | Database to connect to on PostgreSQL server     |
| `EMAIL__SERVICE_ACCOUNT`            | Email address sent from for system mails        |
| `EMAIL__TRANSPORT`                  | Sendmail type (only SMTP configured for now)    |
| `EMAIL__TRANSPORT_OPTS__HOST`       | Host of email server                            |
| `EMAIL__TRANSPORT_OPTS__PORT`       | Port of email server                            |
| `EMAIL__TRANSPORT_OPTS__SECURE`     | Use TLS                                         |
| `EMAIL__TRANSPORT_OPTS__AUTH__USER` | Email server username                           |
| `EMAIL__TRANSPORT_OPTS__AUTH__PASS` | Email server password                           |

### Optional variables

| Variable                            | Description                                             |
| ----------------------------------- | ------------------------------------------------------- |
| `DATABASE_URL`                      | To be used instead of the DATABASE__* set (for Heroku)  |
| `DEFAULT_ADMIN_EMAIL`               | Email address of bootstrapped admin                     |
| `DEFAULT_ADMIN_PASSWORD`            | Password of bootstrapped admin                          |

If you use the `DEFAULT_ADMIN` settings to bootstrap the first admin user, it is recommended to use a temporary password via the ENV and set the real password via the built-in mechanism so the actual password is not saved unencrypted anywhere.  Additionally, the configuration should be removed after the first run.

## Build and run

Check out the ODK Central (including its submodules) and pyxform-http submodules:

```sh
$ git submodule update --init --recursive
```

Build the image and tag

```sh
$ docker build -t odkcentralcontainer:latest .
```

Using the `example.env` and `docker-compose.example.yml`, create your own `.env` and `docker-compose.local.yml` files, referencing your database and email systems.  Run docker-compose on the image:

```sh
$ docker-compose -f docker-compose.local.yml up
```

Your ODK system should be listening on the port specified.  You'll still need to bootstrap the first user by running `odk-cmd` within the container.  A feature to define injecting a default admin user is coming soon.

See directions for that here: https://docs.getodk.org/central-command-line/

You can shell into the container by finding the name of it and running `docker exec`

```sh
$ docker ps
CONTAINER ID...

$ docker exec -it <container_id_or_name> bash

```

## Heroku deployment

*Experimental: This deployment method is not tested and ODK Central is not designed to run in an environment like this. Experience with Heroku is recommended to run Central on it.*  

This build of ODK Central can be deployed on Heroku via their Docker Container Registry deploy: https://devcenter.heroku.com/articles/container-registry-and-runtime#getting-started.  Follow the instructions on the Heroku documentation, replaceing the `alpinehelloworld.git` with `odkcentralcontainer.git`.  You'll need to set up a Postgres addon for the application and set the environment variables.  

The PostgreSQL addon will set the `DATABASE_URL` environment variable, which will be used instead of the `DATABASE__*` variables.

1. Log into Heroku on the CLI

```sh
$ heroku container:login
```

2. Check out the ODK Central Container

```sh
$ git clone https://bastiondev/odkcentralcontainer.git
```

3. Create the application on Heroku.  The application will be available at https://&lt;appname&gt;.herokuapp.com once deployed.

```sh
$ heroku create <appname>
```

4. Build and push the application to the container registry

```sh
$ heroku container:push web
```

5. (Optional) Provision a PostgreSQL add on database for the application.  hobby-dev is the free tier, which is limited to 10,000 rows.  You will probably need a paid tier for a production application:

```sh
$ heroku addons:create heroku-postgresql:hobby-dev
```

6. Set the environment variables.  This can be done on https://dashboard.heroku.com or on the command line, see https://devcenter.heroku.com/articles/config-vars#managing-config-vars.  The required variables for Heroku are:

  - `DOMAIN` - Either custom domain or <appname>.herokuapp.com
  - `EMAIL__*` - Variables must be configured to enable system emails
  - `DATABASE_URL` - Will be set by the PostgreSQL addon (you don't have to set it if you use the addon)
  - `DEFAULT_ADMIN_*` - **Optional** - To set the default admin email & password.  Alternatively, you can `heroku run` to bash into a one-off dyno to run `odk-cmd`.

```sh
$ heroku config:set DOMAIN=... EMAIL__SERVICE_ACCOUNT=...
```

7. Run the application.  It will be default deploy on the free tier of dynos, which will idle out after inactivity.  For persistent application availability upgrade to a paid tier.

```sh
$ heroku container:release web
```