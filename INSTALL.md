# External Dependencies

## Debian
`apt install elixir npm postgres libmagic-dev`

Make sure to run `ln -s /usr/bin/nodejs /usr/bin/node` afterwards 

# Dependency setup

## PostgreSQL

To setup for development:
1. `sudo -u postgres psql`
2. `create user athel password 'athel';`
3. `create database athel_dev owner athel`
4. `create database athel_test owner athel`

## Elixir

1. `mix deps.get` - pull in dependencies
2. Setup emagic
3. `mix ecto.migrate` - initialize database
4. `mix test` - run automated tests

## Node.js

Node is only being used as a build system for the (currently non-existent) frontend.
This is optional if you only care about NNTP
- `npm -g install npm` - update npm to the latest version
- `npm install` - pull local dependencies
- `npm install -g brunch` - will put `brunch` into the path, can be skipped by using =node_modules/brunch/bin/brunch= directly

# Running

`mix phoenix.server` should get you going, the NNTP server will be running on port 8119

`mix test` to run tests. The error output is expected for a few tests for the time being.

# Deployment

## Configuration

Create `config/prod.secret.exs` and fill out/copy over the Athel.Nntp
and Athel.Repo configs. Ideally this will be pulled in at runtime
instead of compiletime in the future.

## Assets

`./node_modules/brunch/bin/brunch b -p` builds static assets, and
`MIX_ENV=prod mix phoenix.digest` sets them up for caching

## Packaging

[Distillery](https://hexdocs.pm/distillery/) is used to create the release package.
`MIX_ENV=prod mix release --env=prod` will generate the release, with `--upgrade`
added for generating an upgrade release. Make sure that the system
you deploy on is binary compatible with the system that you build on.

## TODO Deployment


