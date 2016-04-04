<!--
A fullscren video player that simulates background-cover for video
-->

<template lang='jade'>

.cover-video(:class='[trim, playable && trim ? "visible" : ""]')

	//- Allow markup to be prended
	slot(name='prepend')

	//- Poster image loaded dynamically
	.bkgd(v-if="poster"
		v-el:poster
		v-media-loader="poster")

	//- Container for the <video> element
	.video(v-el:video v-if="shouldLoadVideo")

	//- Allow markup to be appended
	slot

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
			default: 'visible'
			validator: (value) -> value in [
				'visible'  # Load the video when it is scrolled into viewport
				'revealed' # Load the video when entirely scrolled into viewport
				'hover'    # Load the video on mouseover
				true       # Load the video immediately
				false      # Don't autoload
			]

		# Control the playing of video
		autoplay:
			default: true
			validator: (value) -> value in [
				true     # Play as soon as it is loaded
				false    # Don't autoplay
			]

		# Control the pausing of video
		autopause:
			default: 'visible'
			validator: (value) -> value in [
				'visible'  # Toggle playback whenever it is scrolled out of viewport
				'revealed' # Toggle playback when video is no longer fully in viewport
				'hover'    # Pause on mouseout
				false      # Don't do any auto pausing control
			]

		# Don't create video tag on non-autoplaying devices
		requireAutoplay:
			default: true
			validator: (value) -> value in [
				true     # If a device can't autoplay vidoes, don't create video tag
				false    # Create video tag even if device can't autoplay
			]

		# Pass in the element who dispatches the mouse events for hovering
		hoverDispatcher: default: null

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
		mouseover:       null   # Currently in a hovered state

	# We want to autopause using in-viewport
	created: -> @inViewportOnce = false

	# Init the video on ready
	ready: ->
		@addHoverListeners() if 'hover' in [@autoload, @autopause]
		@initVideo() if @shouldLoadVideo

	# Destroy the video and it's listeners when removed
	destroyed: ->
		@removeHoverListeners() if 'hover' in [@autoload, @autopause]
		@destroyVideo() if @shouldLoadVideo

	methods:

		# Add hover listeners
		addHoverListeners: ->
			@mouseover = false
			dispatcher = @hoverDispatcher ? @$el
			dispatcher.addEventListener 'mouseenter', @onMouseenter
			dispatcher.addEventListener 'mouseleave', @onMouseleave

		# Init HTML5 video
		initVideo: ->
			if @inViewportProp('autoload')
				@loadWhenVisible()
			else if @autoload == true
				@load()

		###
		# Triggers
		###

		# Start loading once the video is in the viewport.  This only needs to run
		# once, thus the unwatch().  However, if it runs immediately, the unwatch
		# response from watch() isn't ready in time, thus the defer.
		loadWhenVisible: ->
			unwatch = @$watch @inViewportProp('autoload'), (visible) ->
				return unless visible
				if unwatch then unwatch() else _.defer -> unwatch()
				@load()
			, immediate: true

		# Triggering loading / playing on mouseover
		onMouseenter: -> @mouseover = true

		# Triggering pausing on mouseout
		onMouseleave: -> @mouseover = false

		###
		# Loading
		###

		# Start the video loading.  Watching for it via `timeupdate` because it
		# reports playback earlier and more dependably than `canplaythrough`,
		# noticeably in Safari.  The video begins loading when the video is appended
		# because it is set to repload.
		load: ->

			# Create the video element and add listeners
			return if @vid or !@video # Don't run multiple times
			@vid = @renderVideo(@video)
			@vid.addEventListener 'loadedmetadata', @onAspectData
			@vid.addEventListener 'timeupdate', @canPlay
			@$els.video.appendChild @vid

			# Trigger autoplaying
			@play() if @autoplay == true
			if prop = @inViewportProp('autopause')
				@$watch prop, @toggleOnViewport, immediate: true
			else if @autopause == 'hover'
				@play() if @mouseover

		# Take video tag HTML string and render DOM element
		renderVideo: (html) ->
			$html = $(html)
			$html.attr 'loop', true if @loop
			$html.attr 'autoplay', true if @autoplay == true
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

		###
		# Cover layout
		###

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

		###
		# Cleanup
		###

		# Remove hover listeners
		removeHoverListeners: ->
			dispatcher = @hoverDispatcher ? @$el
			dispatcher.removeEventListener 'mouseenter', @onMouseenter
			dispatcher.removeEventListener 'mouseleave', @onMouseleave

		# Remove the video
		destroyVideo: ->
			win.off 'resize', @onResize
			return unless @vid
			@vid.removeEventListener 'loadedmetadata', @onAspectData
			@vid.removeEventListener 'timeupdate', @canPlay
			@unloadVideo()

		# Unload a video once it is no longer in the DOM. This is needed beceause
		# the Vue `destroyed` hook fires before the video is actually removed.
		unloadVideo: ->
			return setTimeout @unloadVideo, 50 if document.body.contains @vid
			@vid.pause()
			@vid.src = ''
			@vid.load()

		###
		# Controlling video API
		###

		# Play the video if visible
		toggleOnViewport: (isIn) -> if isIn then @play() else @pause()

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

		# Get the in-viewport prop given a cover-video prop key
		inViewportProp: (prop) -> switch @[prop]
			when 'visible' then 'inViewport'
			when 'revealed' then 'inViewportEntirely'

	watch:

		# Control the video by watching the play state
		playing: (playing) ->
			return unless @vid
			if playing
				@vid.play()
				@onResize() # Re-apply, just in case
			else
				@vid.pause()

		# Toggle loading / playback based on hover
		mouseover: (hovered) ->
			if hovered
				@load() if @autoload == 'hover'
				@play() if @autopause == 'hover'
			else
				@pause() if @autopause == 'hover'

	computed:

		# The aspect ratio of the video as a string
		trim: ->
			return unless @videoAspect and @containerAspect
			return if @containerAspect > @videoAspect then 'letterbox' else 'pillarbox'

		# Boolean for whether a video should be loaded
		shouldLoadVideo: -> @video and (not @requireAutoplay or @supportsAutoplay)

		# Test whether the device supports autoplay
		supportsAutoplay: -> !navigator.userAgent.match /Mobile|Android|BlackBerry/i

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
	&.visible .video
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
