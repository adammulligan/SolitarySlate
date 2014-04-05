CONFIG = require('./config.json')

request = require 'request'

redis = require 'redis'
redisClient = redis.createClient()
redisClient.on('error', (err) -> throw new Error(err))

Twit = require 'twit'
T = new Twit(CONFIG.twitter_oauth)

retweet = (tweet) ->
  T.post("statuses/retweet/#{tweet.id_str}", (err) ->
    if err?
      console.error "Could not retweet #{tweet.id_str}"
      console.error err
  )

getFirstUrlFromTweet = (tweet) ->
  urlRegex = new RegExp("(https?):\/\/[a-zA-Z0-9+&@#\/%?=~_|!:,.;]*", "g")
  return tweet.text.match(urlRegex)?[0]

# @slate
userId = 15164565

stream = T.stream('statuses/filter', follow: [userId])
stream.on('tweet', (tweet) ->
  return unless tweet.user.id is userId

  url = getFirstUrlFromTweet(tweet)
  if url?
    request(url, (err, res) ->
      return if err?

      expandedUrl = res.request.uri.href
      redisClient.sismember(CONFIG.redis.set_name, expandedUrl, (err, reply) ->
        throw new Error(err) if err?

        unless reply is 1
          retweet tweet
          redisClient.sadd(CONFIG.redis.set_name, expandedUrl)
      )
    )
  else
    # Always retweet if no links are present
    retweet tweet
)
