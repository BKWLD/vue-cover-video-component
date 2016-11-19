autoprefixerBrowsers = [
	'last 2 versions'
	'ie >= 9'
]

autoprefixer = require 'autoprefixer'

module.exports =

	entry:
		index: './index.vue'

	resolve: extensions: ['', '.js', '.coffee', '.vue']

	module: loaders: [
		{ test: /\.jade$/, loader: 'apply-loader!jade-loader' }
		{ test: /\.coffee$/, loader: 'coffee-loader' }
		{ test: /\.vue$/, loader: 'vue-loader' }
		{ test: /\.styl$/, loader: 'css-loader?-autoprefixer!postcss-loader!stylus-loader' }
	]

	output:
		filename: if '-p' in process.argv then '[name].min.js' else '[name].js'
		libraryTarget: 'umd'
		umdNamedDefine: true
		library: 'vueCoverVideoComponent'

	postcss: -> [ autoprefixer( browsers: autoprefixerBrowsers ) ]

	vue:
		autoprefixer: browsers: autoprefixerBrowsers
		loaders:
			stylus: 'css-loader?-autoprefixer!stylus-loader'
