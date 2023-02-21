⚠️ This _was_ online at <https://www.bluff.website> but it was hosted on Heroku's free plan, and they don't offer that anymore, so it stopped working and I took it offline.

# Bluff

An online version of [Blind Man's Bluff](<https://en.wikipedia.org/wiki/Blind_man%27s_bluff_(poker)>).

A work in progress.
See the GH project for the current state: <https://github.com/maxjacobson/bluff/projects/1>

## Overview

- There's a Rails API-only backend: [api/](./api#readme)
- There's an Elm front-end: [web/](./web/#readme)

## Scripting

### bin/lint

Run this one to check that our linting/formatting tools are satisfied.

## Ops

### Pruning old records

```shell
heroku run -a bluff-api rails prune:abandoned_games
heroku run -a bluff-api rails prune:stale_humans
```
