# bluff/web

[![Netlify Status](https://api.netlify.com/api/v1/badges/bc06891f-46fd-411a-b063-f5cc5cd476bf/deploy-status)](https://app.netlify.com/sites/bluff/deploys)

This is an [Elm](https://elm-lang.org) app.

## Setup

This app was scaffolded with [create-elm-app](https://github.com/halfzebra/create-elm-app), and we use its CLI (`elm-app`) to run the app locally and build optimized builds for production.

## Running locally

```shell
PORT=3001 elm-app start
```

## Deploying

The front-end auto-deploys to [Netlify](https://www.netlify.com/).
They just notice when we push to master and they take care of it.
The build command and some other stuff are defined in the [netlify config file](../netlify.toml).

## Some links

- <https://bluff.netlify.app>
- <https://www.bluff.website>
