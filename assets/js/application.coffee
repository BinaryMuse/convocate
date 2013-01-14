$ = require('jquery')
angular = require 'angular'
tinycon = require 'tinycon'

app = angular.module 'convocate', []

app.controller 'ChatController', ['$scope', 'Visibility', 'Tinycon', ($scope, Visibility, Tinycon) ->
  $scope.connected = false
  $scope.unauthenticated = false

  $scope.username = null
  $scope.users = []
  $scope.chats = []
  $scope.unreadCount = 0
  $scope.needsScroll = false

  $scope.$watch 'unreadCount', (value) ->
    Tinycon.setBubble(value) if angular.isNumber(value)

  Visibility.change ->
    if !Visibility.hidden()
      $scope.unreadCount = 0
      $scope.$apply()

  notify = ->
    $scope.chats.shift() if $scope.chats.length > 1000
    $scope.needsScroll = true
    if Visibility.hidden()
      $scope.unreadCount++

  socket = io.connect()

  socket.on 'error', (reason) ->
    $scope.unauthenticated = true
    $scope.$apply()

  socket.on 'connect', ->
    $scope.connected = true
    $scope.$apply()

  socket.on 'room:join', (username) ->
    $scope.users.push username
    $scope.chats.push type: 'entrance', username: username
    notify()
    $scope.$apply()

  socket.on 'room:leave', (username) ->
    index = $scope.users.indexOf(username)
    $scope.users.splice(index, 1) if index != -1
    $scope.chats.push type: 'exit', username: username
    notify()
    $scope.$apply()

  socket.on 'room:chat', (chat) ->
    $scope.chats.push chat
    notify()
    $scope.$apply()

  socket.on 'room:people', (data) ->
    $scope.username = data.identity
    $scope.users = data.users
    $scope.$apply()

  $scope.submitMessage = ->
    socket.emit 'room:chat', $scope.message
    $scope.chats.push
      username: $scope.username
      message: $scope.message
    notify()
    $scope.message = ''
]

app.directive 'editbox', ->
  link: (scope, elem, attrs) ->
    elem.on 'keydown', (evt) ->
      if evt.which == 13 && !evt.shiftKey
        evt.preventDefault()
        scope.$apply attrs.editboxEnter

app.filter 'sanitize', ->
  (str) ->
    return "" unless str?
    str.replace(/</g, '&lt;')

app.filter 'nl2br', ->
  (str) ->
    return "" unless str?
    str.replace(/(\n)|(&#10;)/g, "<br>\n")

app.directive 'scrollToBottom', ($parse, $timeout) ->
  link: (scope, elem, attrs) ->
    getter = $parse attrs.scrollToBottom
    setter = getter.assign

    scope.$watch attrs.scrollToBottom, (value) ->
      if !!value
        $timeout (->
          pos = elem[0].scrollHeight
          elem.animate({scrollTop: pos}, 250)
          setter(scope, false)
        ), 0

app.factory 'Visibility', ->
  visible = true
  callbacks = []
  doChange = (e) ->
    state = if visible then 'visible' else 'hidden'
    fn(e, state) for fn in callbacks

  api = {
    hidden: -> !visible
    change: (fn) -> callbacks.push fn
  }

  $(window).blur (evt) ->
    return unless visible
    visible = false
    doChange(evt)
  $(window).focus (evt) ->
    return if visible
    visible = true
    doChange(evt)
  api

app.factory 'Tinycon', ->
  tinycon
