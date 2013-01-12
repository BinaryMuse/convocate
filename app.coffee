http = require 'http'
sio = require 'socket.io'
redis = require 'redis'
express = require 'express'
webpack = require 'webpack'
webpackDev = require 'webpack-dev-middleware'

process.env.NODE_ENV ?= 'development'

app = express()
server = http.createServer(app)
io = sio.listen(server)

app.configure ->
  app.set 'port', process.env.PORT || '3000'
  app.set 'views', "#{__dirname}/views"
  app.set 'view engine', 'jade'
  app.use express.favicon()
  app.use express.logger()
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser('secret')
  app.use express.session()
  app.use express.static("#{__dirname}/public")

app.configure 'development', ->
  app.use webpackDev "#{__dirname}/assets/index.js",
    webpack:
      watch: true
      publicPrefix: 'http://localhost:3000/assets/'
      output: 'bundle.js'
  app.use express.errorHandler()

app.get '/', (req, res) ->
  res.render 'index'

server.listen app.get('port'), ->
  console.log "Server running on port #{app.get('port')}"
