# Solitary Slate

A Twitter bot that retweets @slate the first time they post a link, but
ignores reposts.

I run this in production
[@SolitarySlate](https://twitter.com/SolitarySlate)

## How it works

The script runs as a demon, listening for @slate tweets (could be any
user account, however) and then retweets if:

* There are no links in the tweet
* The first link in the tweet has not been included in a @slate tweet
  before

The first link in every @slate tweet is stored in a redis set.

## Setup

Clone the repo and:

```
npm install
coffee index.coffee
```
