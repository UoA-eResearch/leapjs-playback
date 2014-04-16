window.recorder.controller 'Controls', ['$scope', '$location', '$document', ($scope, $location, $document)->
  $scope.maxFrames = ->
#    console.log('max frames', window.controller.plugins.playback.player.maxFrames)
    Math.max(window.controller.plugins.playback.player.maxFrames - 1, 0)

  $scope.mode = ''
  $scope.leftHandlePosition
  $scope.rightHandlePosition
  $scope.paused = false
  $scope.inDigestLoop = false
  $scope.pinHandle = ''

  $scope.$watch 'leftHandlePosition', (newVal, oldVal) ->
    return if newVal == oldVal
    return unless $scope.mode == 'crop'
    player().setFrameIndex(parseInt(newVal, 10))
    player().leftCrop()

  $scope.$watch 'rightHandlePosition', (newVal, oldVal) ->
    return if newVal == oldVal  # prevents issue where newVal == 9999 on bootstrap
    return if $scope.inDigestLoop
    player().setFrameIndex(parseInt(newVal, 10))
    if $scope.mode == 'crop'
      player().rightCrop()

  $scope.record = ->
    $scope.paused = $scope.stopOnRecordButtonClick()
    if $scope.paused then player().finishRecording() else player().record()

  window.controller.on 'playback.record', (player)->
    $scope.mode = 'record'

  window.controller.on 'playback.play', (player)->
    $scope.pinHandle = 'min'
    $scope.mode = 'playback'
    $scope.pause = false

  window.controller.on 'playback.pause', (player)->
    $scope.pause = true


  $scope.crop = ->
    $scope.mode = 'crop'
    $scope.pinHandle = ''
    # in this particular hack, we prevent the frame from changing by having the $watch in a seperate, and flagged, digest loop.
    setTimeout ->
      $scope.inDigestLoop = true
      $scope.leftHandlePosition = player().leftCropPosition
      $scope.rightHandlePosition = player().rightCropPosition
      $scope.$apply()
      $scope.inDigestLoop = false
    , 0
    player().pause()
    # this hack previews the current hand position
    setTimeout(->
      player().sendFrame(player().currentFrame())
    , 0)

  $scope.stopOnRecordButtonClick = ->
    $scope.mode == 'record' && !$scope.paused

  $scope.pauseOnPlaybackButtonClick = ->
    $scope.mode == 'playback' && !$scope.paused

  $scope.canPlayBack = ->
    !player().loaded()

  window.controller.on 'playback.ajax:begin', (player)->
    $scope.playback()
    # note, this is an anti-pattern https://github.com/angular/angular.js/wiki/Anti-Patterns
    $scope.$apply() unless ($scope.$$phase)

  window.controller.on 'playback.recordingFinished', ->
    if player().loaded()
      $scope.crop()
    # remove depressed button state on record button -.-
    document.getElementById('record').blur()

  window.controller.on 'playback.playbackFinished', ->
    $scope.paused = true
    $scope.$apply()


  $scope.playback = ()->
    player().toggle()


  $document.bind 'keypress', (e)->
    switch e.which
      when 32
        # prevent spacebar from activating buttons
        e.originalEvent.target.blur()
        if $scope.mode == 'record'
          $scope.record()
        else
          $scope.playback()
      when 102
        if (document.body.requestFullscreen)
          document.body.requestFullscreen()
        else if (document.body.msRequestFullscreen)
          document.body.msRequestFullscreen()
        else if (document.body.mozRequestFullScreen)
          document.body.mozRequestFullScreen()
        else if (document.body.webkitRequestFullscreen)
          document.body.webkitRequestFullscreen()
      when 114
        $scope.record()
      when 99
        $scope.crop()
      when 112
        $scope.playback()
      when 115
        $scope.save()
      when 47, 63
        $('#helpModal').modal('show')
      when 27 # esc
        $('#helpModal').modal('hide')
        $('#metadata').modal('hide')
      when 109
        $('#metadata').modal('toggle')
      else
        console.log "unbound keycode: #{e.which}"


  window.controller.on 'frame', (frame)->
    $scope.inDigestLoop = true
    $scope.$apply ->
      if $scope.mode == 'playback'
        $scope.leftHandlePosition = player().leftCropPosition
        $scope.rightHandlePosition = player().frameIndex
    $scope.inDigestLoop = false


  $scope.save = (format)->
    filename = if player().metadata.title
      # assumes camelcase
      player().metadata.title.replace(/\s/g, '')
    else
      'leap-playback-recording'

    if player().metadata.frameRate
      filename += "-#{Math.round(player().metadata.frameRate)}fps"

    if format == 'json'
      saveAs(new Blob([player().export('json')], {type: "text/JSON;charset=utf-8"}), "#{filename}.json")
    else
      saveAs(new Blob([player().export('lz')], {type: "text/JSON;charset=utf-8"}), "#{filename}.json.lz")
]