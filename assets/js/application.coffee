$ = require('jquery')
angular = require 'angular'

app = angular.module 'convocate', []

app.controller 'TestController', ($scope) ->
  $scope.data = []
  socket = io.connect()
  socket.on 'error', (reason) ->
    console.log "Error! #{reason}"
  socket.on 'data', (data) ->
    $scope.data.push data
    if $scope.data.length > 5
      $scope.data.shift()
    $scope.$apply()
