bunyan = require('bunyan')
log = bunyan.createLogger(
  name: 'solitary_slate',
  streams: [
    stream: process.stdout
  ]
)

CONFIG = require('./config.json')
USER_ID = 15164565 #@slate
HEADERS = {
  "User-Agent": "SolitarySlate Bot (@solitaryslate)"
  "Referrer": "http://twitter.com"
}

request = require 'request'
url = require 'url'

redis = require 'redis'
redisClient = redis.createClient()
redisClient.on('error', (err) ->
  log.fatal {error: err}, "Redis error"
  throw new Error(err)
)

Twit = require 'twit'
T = new Twit(CONFIG.twitter_oauth)

retweet = (tweet) ->
  T.post("statuses/retweet/#{tweet.id_str}", (err) ->
    if err?
      log.error {error: err, tweet_id: tweet.id_str}, "Retweet failed"
  )

getFirstUrlFromTweet = (tweet) ->
  urlRegex = new RegExp("(https?):\/\/[a-zA-Z0-9+&@#\/%?=~_|!:,.;]*", "g")
  return tweet.text.match(urlRegex)?[0]

log.info "Starting up"

stream = T.stream('statuses/filter', follow: [USER_ID])
stream.on('tweet', (tweet) ->
  return unless tweet.user.id is USER_ID

  urlFromTweet = getFirstUrlFromTweet(tweet)
  if urlFromTweet?
    options = {
      url: urlFromTweet
      followAllRedirects: true
      headers: HEADERS
    }

    request(options, (err, res) ->
      return if err?

      expandedUrl = url.parse(res.request.uri.href).pathname
      log.info({url: urlFromTweet, path: expandedUrl, tweet_id: tweet.id_str}, "Received tweet")

      redisClient.sismember(CONFIG.redis.set_name, expandedUrl, (err, reply) ->
        throw new Error(err) if err?

        if reply is 1
          log.info({url: urlFromTweet, path: expandedUrl, tweet_id: tweet.id_str}, "Ignoring tweet")
        else
          log.info({url: urlFromTweet, path: expandedUrl, tweet_id: tweet.id_str}, "Retweeting tweet")
          retweet tweet
          redisClient.sadd(CONFIG.redis.set_name, expandedUrl)
      )
    )
  else
    # Always retweet if no links are present
    retweet tweet
)
