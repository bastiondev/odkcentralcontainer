# ODK Central Configurable Single Image Build

This repository builds a single Docker image for ODK Central with its configuration driven from environment variables, appropriate for serverless environments.  It is also configured without SSL, to allow using an external load balancer that handles HTTPS termination and certificate management.

It does not include a Postgres Instance, and assumes an external database will be used to allow ODK Central to operate in a multi-node configuration.

The target environment is Amazon Web Services' [Elastic Container Service](https://aws.amazon.com/ecs/). 

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