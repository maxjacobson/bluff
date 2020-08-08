# bluff/api

The backend is a Rails API.

## Setup

```
bundle install
rails db:setup
```

## Running locally

```
rails s
```

## Deploying

To deploy, run this from the root of the repository:

```
git remote add heroku https://git.heroku.com/bluff-api.git
bin/deploy-api
```

# URL

<https://bluff-api.herokuapp.com>
