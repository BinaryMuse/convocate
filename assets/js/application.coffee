$ = require('jquery')
angular = require 'angular'

app = angular.module 'convocate', []

app.controller 'TestController', ($scope) ->
  $scope.thing = 'stuff'
