<!--
A fullscren video player that simulates background-cover for video
-->

<template lang='jade'>
.cover-video(:class='[trim, playable ? "playable" : ""]')

	//- Poster image loaded dynamically
	.bkgd(v-el:poster v-if="poster"
		v-media-loader
		:media="poster")

	//- Container for the <video> element
	.video(v-el:video)

</template>

<!-- ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– -->

<script lang='coffee'>
win = require 'window-event-mediator'
module.exports =
	components:	'media-loader': require 'vue-media-loader-directive'
	mixins: [ require 'vue-in-viewport-mixin' ]

	# Settings
	props:

		# Video HTML string
		video: default: null

		# Control the loading of video
		autoload:
			default: 'scroll'
			validator: (value) -> value in [
				'scroll' # Load the video when it is scrolled into viewport
				true     # Load the video immediately
				false    # Don't autoload
			]

		# Control the playing of video
		autoplay:
			default: 'scroll'
			validator: (value) -> value in [
				'scroll' # Play the video whnever it is scrolled into viewport
				true     # Play immediately, as soon as it is loaded
				false    # Don't autoplay
			]

		# Control the pausing of video
		autopause:
			default: 'scroll'
			validator: (value) -> value in [
				'scroll' # Pause the video whnever it is scrolled out of viewport
				false    # Don't do any auto pausing control
			]

		# Simple HTML5 video properties
		loop:      default: true
		mute:      default: true
		poster:    defaut: null

	data: ->
		vid:             null   # The video element
		playable:        false  # Is the video ready to play?
		playing:         false  # Playing state in easy var
		videoAspect:     null   # Aspect ratio of the video
		containerAspect: null   # Orientation of the container
		class:           null   # Cropping class to apply

	# We want to autopause using in-viewport
	created: -> @inViewportOnce = false

	# Init the video on ready
	ready: -> @initVideo() if @video

	# Destroy the video and it's listeners when removed
	destroyed: -> @destroyVideo() if @video

	methods:

		# Init HTML5 video, which may be absent during dev
		initVideo: ->
			if @autoload == 'scroll'
				@loadWhenVisible()
			else if @autoload || @autoplay
				@load()

		# Start loading once the video is in the viewport
		loadWhenVisible: ->
			unwatch = @$watch 'inViewport', (visible) ->
				return unless visible
				unwatch()
				@load()
			, immediate: true

		# Start the video loading.  Watching for it via `timeupdate` because it
		# reports playback earlier and more dependably than `canplaythrough`,
		# noticeably in Safari.  The video begins loading when the video is appended
		# because it is set to repload.
		load: ->
			@vid = @renderVideo(@video)
			@vid.addEventListener 'loadedmetadata', @onAspectData
			@vid.addEventListener 'timeupdate', @canPlay
			@$els.video.appendChild @vid
			@play() if @autoplay == true
			if @autoplay == 'scroll' || @autopause == 'scroll'
				@$watch 'inViewport', @toggleIfVisible, immediate: true

		# Take video tag HTML string and render DOM element
		renderVideo: (html) ->
			$html = $(@video)
			$html.attr 'loop', true if @loop
			$html.attr 'autoplay', true if @autoplay == 'now'
			$html.attr 'muted', true if @mute
			$html.attr 'preload', 'auto'
			return $html[0]

		# The video is ready for playing.  Doing a timeupdate check because
		# canplaythrough was firing too early and would pause for a tick in safari.
		canPlay: (e) ->

			# If autoplaying, make sure it's already advanced before showing
			return if @vid.currentTime < 0.2
			@vid.removeEventListener 'timeupdate', @canPlay

			# Listen to resizing to capture
			win.on 'resize', @onResize
			@onResize()

			# Recapture the aspect if it failed the first time.  Safari is guilty
			# of this.
			@captureAspect() if !@aspect

			# Shows the video
			@playable = true

		# The video has reported it is playable
		onAspectData: (e) ->
			@vid.removeEventListener 'loadedmetadata', @onAspectData
			@captureAspect()

		# Capture the aspect ratio
		captureAspect: (e) ->
			@videoAspect = @vid.videoWidth / @vid.videoHeight
			@onResize()

		# Center the video in it's container while maintaining aspect ratio
		onResize: (e) ->
			return unless @$el
			@containerAspect = @$el.clientWidth / @$el.clientHeight

		# Remove the video
		destroyVideo: ->
			win.off 'resize', @onResize
			@vid.removeEventListener 'loadedmetadata', @onAspectData
			@vid.removeEventListener 'timeupdate', @canPlay
			@vid.pause()
			@vid.src = ''
			@vid.load()

		###
		# Controlling video API
		###

		# Play the video if visible
		toggleIfVisible: (val) ->
			@play() if @inViewport && @autoplay == 'scroll'
			@pause() if not @inViewport && @autopause == 'scroll'

		# Toggle video playing state
		toggle: (play) -> if play then @play() else @pause()

		# Play the video from the beginning
		restart: ->
			@vid.currentTime = 0
			@play()

		# Play the video
		play: -> @playing = true

		# Pause the video
		pause: -> @playing = false

	watch:

		# Control the video by watching the play state
		playing: (playing) ->
			if playing
				@vid.play()
				@onResize() # Re-apply, just in case
			else
				@vid.pause()

	computed:

		# The aspect ratio of the video as a string
		trim: ->if @containerAspect > @videoAspect then 'letterbox' else 'pillarbox'

</script>

<!-- ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– -->

<style lang='stylus'>
.cover-video
	position absolute
	top 0
	left 0
	bottom 0
	right 0

	.video
		position absolute
		top 0
		left 0
		bottom 0
		right 0
		opacity 0
		transition opacity 300ms
	&.playable .video
		opacity 1

	video
		position absolute
		top 50%
		left 50%
		transform translate(-50%, -50%)

	&.pillarbox video
		width auto
		height calc(100% + 1px) // Cover rounding errors

	&.letterbox video
		width calc(100% + 1px) // Cover rounding errors
		height auto;

</style>
