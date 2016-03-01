<!--
A fullscren video player that simulates background-cover for video
-->

<template lang='jade'>
.cover-video(:class='class')

	//- Poster image loaded dynamically
	.bkgd(v-el:poster v-if="poster"
		v-media-loader
		:media="poster")

	//- Container for the <video> element
	.video(v-el:video
		:style='{opacity: 1}')

</template>

<!-- ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– -->

<script lang='coffee'>
win = require 'window-event-mediator'
module.exports =

	components:
		'media-loader': require 'vue-media-loader-directive'

	mixins: [ require 'vue-in-viewport-mixin' ]

	data: ->
		vid: null
		class: null
		aspect: null
		landscape: null
		visible: null
		playable: false

	props:
		autoplay: default: 'now'
		loop: default: true
		mute: default: true
		video: defaut: null
		poster: defaut: null


	# We want to autopause using in-viewport
	created: -> @inViewportOnce = false

	ready: ->

		# Init special video handling
		@initVideo() if @video

		# Listen for resizing
		win.on 'resize', _.bind(@onResize,@)
		@onResize()
		@checkVisible()

	destroyed: ->
		# Remove non-Vue listeners
		win.off 'resize', _.bind(@onResize,@)
		win.off 'scroll', _.bind(@onScroll,@)
		# Cancel loading of the video.  Call it with a delay because "destroyed"
		# gets called immediately when a transition begins and I want to wait
		# till the transition is done.
		if @vid
			setTimeout @destroyVideo, 600
		return

	# Pause video if off screen
	watch: inViewport: -> @checkVisible()

	methods:
		checkVisible: ->
			if @vid and @$el
				@vid.play() if @inViewport
				@vid.pause() if not @inViewport

		# The video has reported it is playable
		onAspectData: (e) ->
			@vid.removeEventListener 'loadedmetadata', @onAspectData
			@captureAspect()

		# Remove the video
		destroyVideo: ->
			@vid.removeEventListener 'loadedmetadata', @onAspectData
			@vid.pause()
			@vid.src = ''
			@vid.load()

		# Capture the aspect ratio
		captureAspect: (e) ->
			@aspect = @vid.videoWidth / @vid.videoHeight
			@onResize()

		# Center the video in it's container while maintaining aspect ratio
		onResize: (e) ->

			# If we're mid remove, don't fire
			return unless @$el

			# Store the orientation
			ratio = @$el.clientWidth / @$el.clientHeight
			@landscape = ratio > 1

			# Store how to crop it
			if @aspect and ratio > @aspect
				@class = 'trim-vertical'
			else
				@class = 'trim-horizontal'

		# Update whether the player is currently visible or not
		onScroll: (e) ->
			viewport = document.documentElement.clientHeight
			pos = @$el.getBoundingClientRect()
			@visible = pos.top < viewport and pos.bottom > 0

		# Init HTML5 video, which may be absent during dev
		initVideo: ->

			# Wait till it's scrolled into visiblity to load and play
			if @autoplay == 'scroll'
				window.addEventListener 'scroll', @onScroll
				stopLoadWatch = @$watch('visible', (visible) ->
					return unless visible
					stopLoadWatch()
					@load()
					@play()
					@$watch 'visible', @toggle
				)

			# Start loading (and possibly playing) now
			else
				@load()

		# Start the video loading.
		load: ->

			# Make the element
			@vid = @videoEl

			# Listen for being able to play differntly based on what kinda autoplay
			if @autoplay == 'now'
				@vid.addEventListener 'timeupdate', @canPlayVideo
			else
				@vid.addEventListener 'canplaythrough', @canPlayVideo

			# Listen for when the aspect ratio can be set
			@vid.addEventListener 'loadedmetadata', @onAspectData

			# Insert the html via JS when ready to play.  Using the v-html directive to
			# set the video content was triggering multiple video loads.
			# loader.load()
			@$els.video.appendChild @vid

		# The video is ready for playing.  Doing a timeupdate check because
		# canplaythrough was firing too early and would pause for a tick in safari.
		canPlayVideo: (e) ->

			# If autoplaying, make sure it's already advanced before showing
			if @autoplay == 'now'
				return if @vid.currentTime < 0.2
				$(@$els.poster).velocity { opacity: 0 },{ display: 'none', duration: 100 }
				@vid.removeEventListener 'timeupdate', @canPlayVideo

			# If not autoplaying, trust the canplaythrough
			else
				@vid.addEventListener 'canplaythrough', @canPlayVideo

			# Recapture the aspect if it failed the first time.  Safari is guilty
			# of this.
			@captureAspect() if !@aspect

			# Show video
			@playable = true

		# Toggle video playing state
		toggle: (play) -> if play then @play() else @pause()

		# Play the video from the beginning
		restart: ->
			@vid.currentTime = 0
			@play()

		# Play the video
		play: ->
			@vid.play()
			@onResize()

		# Pause the video
		pause: -> @vid.pause()

	computed:
		# Customize the video HTML tag
		videoEl: ->
			$html = $(@video)
			$html.attr 'loop', true if @loop
			$html.attr 'autoplay', true if @autoplay == 'now'
			$html.attr 'muted', true if @mute

			$html.attr 'preload', 'auto'
			$html[0]

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

	video
		position absolute
		top 50%
		left 50%
		transform translate(-50%, -50%)

	&.trim-horizontal video
		// Default is to pillarbox
		width auto
		height calc(100% + 1px) // Cover rounding errors

	// Letterbox
	&.trim-vertical video
		width calc(100% + 1px) // Cover rounding errors
		height auto;

</style>
