async = require 'async'

class Chatroom
  constructor: (@redis, @io) ->
    @members = []
    io.sockets.on 'connection', @join

  join: (socket) =>
    session = socket.handshake.session
    username = session.username
    @members.push username unless username in @members
    socket.broadcast.emit 'room:join', username
    socket.emit 'room:people',
      identity: username
      users: @members

    socket.on 'room:chat', @chat.bind(this, socket)
    socket.on 'disconnect', @leave.bind(this, socket)

  chat: (socket, message) =>
    socket.broadcast.emit 'room:chat',
      username: socket.handshake.session.username
      message: message

  leave: (socket, message) =>
    index = @members.indexOf socket.handshake.session.username
    @members.splice(index, 1) unless index == -1
    @io.sockets.emit 'room:leave', socket.handshake.session.username

module.exports = Chatroom
