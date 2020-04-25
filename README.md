# Bluff

An online version of [Blind Man's Bluff](<https://en.wikipedia.org/wiki/Blind_man%27s_bluff_(poker)>).

A work in progress.
See <https://github.com/maxjacobson/bluff/projects/1>

## Architecture overview

### ./api

The backend is a Rails API.

Setup:

```
cd api
bundle install
rails db:setup
```

Boot:

```
rails s
```

Deploy:

```
git remote add heroku https://git.heroku.com/bluff-api.git
bin/deploy-api
```

URL:

<https://bluff-api.herokuapp.com>

### ./web

The frontend is an Elm app.

Setup:

```
npm install -g create-elm-app
```

Boot:

```
cd web
PORT=3001 elm-app start
```

Deploy:

Just push to GitHub, and Netlify will take care of it.

URLs:

- <https://bluff.netlify.app>
- <https://www.bluff.website>

## Scripting

### bin/lint

Run this one to check that our linting/formatting tools are satisfied.

## Ops

### Pruning old records

```shell
heroku run -a bluff-api rails prune:abandoned_games
heroku run -a bluff-api rails prune:stale_humans
```
