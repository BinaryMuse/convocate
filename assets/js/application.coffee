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
  $scope.scroller = {
    needsScroll: false
    enabled: true
    scrolling: false
  }

  $scope.$watch 'unreadCount', (value) ->
    Tinycon.setBubble(value) if angular.isNumber(value)
    if window.fluid
      if !value? || value == 0
        window.fluid.dockBadge = ""
      else
        window.fluid.dockBadge = "#{value}"
        window.fluid.requestUserAttention(false)

  Visibility.change ->
    if !Visibility.hidden()
      $scope.unreadCount = 0
      $scope.$apply()

  notify = ->
    $scope.chats.shift() if $scope.chats.length > 1000
    $scope.scroller.needsScroll = true
    if Visibility.hidden() || !$scope.scroller.enabled
      $scope.unreadCount++

  $scope.$watch 'scroller.enabled', (value) ->
    resetScrolling() if value == true && !Visibility.hidden()

  resetScrolling = ->
    $scope.scroller.needsScroll = true
    $scope.unreadCount = 0

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
    return if $scope.message.trim() == ""
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
    setNeedsScrolling = $parse(attrs.scrollToBottom).assign
    setScrollingEnabled = $parse(attrs.scrollingEnabled).assign
    setScrolling = $parse(attrs.scrolling).assign

    needsScrolling = false
    scrollingEnabled = false
    timeout = null

    go = ->
      if needsScrolling && scrollingEnabled
        $timeout (->
          pos = elem[0].scrollHeight
          setScrolling(scope, true)
          $timeout.cancel(timeout) if timeout?
          elem.stop().animate({scrollTop: pos}, 250)
          setNeedsScrolling(scope, false)
          timeout = $timeout (-> setScrolling(scope, false)), 250
        ), 0

    scope.$watch attrs.scrollToBottom, (value) ->
      needsScrolling = !!value
      go()

    scope.$watch attrs.scrollingEnabled, (value) ->
      scrollingEnabled = !!value
      go()

    elem.on 'scroll', (evt) ->
      scroll = elem.scrollTop() + elem.height()
      height = elem[0].scrollHeight
      if Math.abs(height - scroll) < 10
        setScrollingEnabled(scope, true)
      else
        setScrollingEnabled(scope, false)
      scope.$apply()

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

app.directive 'specialMessage', ($parse, $timeout) ->
  link: (scope, elem, attrs) ->
    message = scope.$eval attrs.specialMessage
    scroller = $parse(attrs.scroller).assign
    scroll = ->
      scroller(scope, true)
      scope.$apply()

    # Tweet
    if matches = message.match /^https?:\/\/(www.)?twitter\.com\/[^\/]+\/status\/(\d+)/
      tweetId = matches[2]
      quote = angular.element('<blockquote>').addClass('twitter-tweet')
      angular.element('<p>').html('&nbsp;').appendTo(quote)
      angular.element('<a>').prop('href', "https://twitter.com/twitterapi/status/#{tweetId}").appendTo(quote)
      quote.appendTo(elem)
      twttr.widgets.load()
      scroll()

    # Image
    if message.match /^https?:\/\/.*$/
      img = angular.element('<img>')
      img.load ->
        link = angular.element('<a>').prop('href', message).prop('target', '_blank').append(img)
        elem.append link
        scroll()
      img.attr 'src', message
