CONFIG = require('./config.json')
USER_ID = 15164565 #@slate
HEADERS = {
  "User-Agent": "SolitarySlate Bot (@solitaryslate)"
  "Referrer": "http://twitter.com"
}

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

stream = T.stream('statuses/filter', follow: [USER_ID])
stream.on('tweet', (tweet) ->
  return unless tweet.user.id is USER_ID

  url = getFirstUrlFromTweet(tweet)
  if url?
    options = {
      url: url
      followAllRedirects: true
      headers: headers
    }

    request(url, (err, res) ->
      return if err?

      expandedUrl = res.request.uri.href
      console.log "Got a Slate tweet with this URL: #{expandedUrl}..."

      redisClient.sismember(CONFIG.redis.set_name, expandedUrl, (err, reply) ->
        throw new Error(err) if err?

        if reply is 1
          console.log "...got that one previously, ignoring!"
        else
          console.log "...never seen that one before, retweeting"
          retweet tweet
          redisClient.sadd(CONFIG.redis.set_name, expandedUrl)
      )
    )
  else
    # Always retweet if no links are present
    retweet tweet
)
