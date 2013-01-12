http = require 'http'
sio = require 'socket.io'
redis = require 'redis'
cookie = require 'cookie'
connect = require 'connect'
express = require 'express'
webpack = require 'webpack'
webpackDev = require 'webpack-dev-middleware'
MemoryStore = express.session.MemoryStore

process.env.NODE_ENV ?= 'development'

app = express()
server = http.createServer(app)
io = sio.listen(server)
sessionStore = new MemoryStore()

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

usernames = {}

app.get '/', (req, res) ->
  res.render 'index'

app.get '/login', (req, res) ->
  if req.session.authenticated
    res.redirect '/'
  else
    res.render 'login'

app.post '/login', (req, res) ->
  if req.body.username && req.body.username not in Object.keys(usernames)
    req.session.authenticated = true
    req.session.username = req.body.username
    res.redirect '/'

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

io.sockets.on 'connection', (socket) ->
  session = socket.handshake.session
  username = session.username
  usernames[username] = true

  socket.broadcast.emit 'room:join', username
  socket.emit 'room:people',
    identity: username
    users: Object.keys(usernames)

  socket.on 'room:chat', (chat) ->
    socket.broadcast.emit 'room:chat',
      username: username
      message: chat

  socket.on 'disconnect', ->
    delete usernames[username]
    io.sockets.emit 'room:leave', username
