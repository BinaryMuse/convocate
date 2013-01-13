http = require 'http'
sio = require 'socket.io'
redis = require 'redis'
cookie = require 'cookie'
connect = require 'connect'
express = require 'express'
webpack = require 'webpack'
webpackDev = require 'webpack-dev-middleware'
MemoryStore = express.session.MemoryStore
redisConfig = require './config/redis'
Chatroom = require './lib/chatroom'

process.env.NODE_ENV ?= 'development'

app = express()
server = http.createServer(app)
io = sio.listen(server)
sessionStore = new MemoryStore()
redisClient = redis.createClient(redisConfig.port, redisConfig.host)
redisClient.select(redisConfig.database) if redisConfig.database?
redisClient.on 'error', (err) ->
  console.error "Error in redisClient:"
  console.error err
chatroom = new Chatroom(redisClient, io)

app.configure ->
  app.set 'port', process.env.PORT || '3000'
  app.set 'views', "#{__dirname}/views"
  app.set 'view engine', 'jade'
  app.use express.favicon()
  app.use express.logger()
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser()
  app.use express.session(secret: 'convocateisawesome', key: 'convocate.sid', store: sessionStore)
  app.use express.static("#{__dirname}/public")

app.configure 'development', ->
  app.use webpackDev "#{__dirname}/assets/index.js",
    webpack:
      watch: true
      publicPrefix: 'http://localhost:3000/assets/'
      output: 'bundle.js'
  app.use express.errorHandler()

app.get '/', (req, res) ->
  if req.session.authenticated
    res.render 'index'
  else
    res.redirect '/login'

app.get '/login', (req, res) ->
  if req.session.authenticated
    res.redirect '/'
  else
    res.render 'login'

app.post '/login', (req, res) ->
  if req.body.username && req.body.username not in chatroom.members
    req.session.authenticated = true
    req.session.username = req.body.username
    res.redirect '/'
  else
    res.redirect '/login'

app.get '/logout', (req, res) ->
  req.session.destroy ->
    res.redirect '/'

server.listen app.get('port'), ->
  console.log "Server running on port #{app.get('port')}"

io.set 'authorization', (handshakeData, accept) ->
  try
    if handshakeData.headers.cookie
      handshakeCookie = cookie.parse(handshakeData.headers.cookie)
      sessionId = connect.utils.parseSignedCookie(handshakeCookie['convocate.sid'], 'convocateisawesome')

      sessionStore.get sessionId, (err, session) ->
        if err? || !session
          accept 'Could not get session from session ID', false
        else
          if session.authenticated
            handshakeData.session = session
            accept null, true
          else
            accept 'Not authenticated', false
    else
      accept 'No cookie transmitted', false
  catch e
    accept 'Uncaught exception while authorizing', false
