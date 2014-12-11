Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
Form = require 'form'
Time = require 'time'
Social = require 'social'
Chess = require 'chess'
{tr} = require 'i18n'

exports.renderSettings = !->
	if Db.shared
		Dom.text tr("Game has started")

	else
		selectMember
			name: 'opponent'
			title: tr("Opponent")

dbg.rules = ->
	Chess.rules()

exports.render = !->
	whiteId = Db.shared.get('white')
	blackId = Db.shared.get('black')

	if challenge=Db.shared.get('challenge')
		Dom.div !->
			Dom.style
				padding: '8px'
				textAlign: 'center'
				fontSize: '120%'

			Dom.text tr("%1 (white) vs %2 (black), no time limit",
				Plugin.userName(whiteId), Plugin.userName(blackId))

			if challenge[Plugin.userId()]
				Dom.div tr("%1 challenged you for a game of Chess.", Plugin.userName(Plugin.ownerId()))

				Ui.bigButton tr("Accept"), !->
					Server.call 'accept'

			else
				break for id of challenge
				Dom.div tr("Waiting for %1 to accept...", Plugin.userName(id))

	else
		#Ui.bigButton "INIT", !->
		#	Server.call 'init'

		isBlack = Plugin.userId() is blackId and Plugin.userId() isnt whiteId

		renderSide = (side) !->
			Dom.div !->
				Dom.style
					textAlign: 'center'
					fontSize: '130%'
					padding: '8px 0'
					color: 'inherit'
					fontWeight: 'normal'
				id = Db.shared.get(side)
				if id is Plugin.userId()
					Dom.text tr("You")
				else
					Dom.text Plugin.userName(id)

				if result = Db.shared.get('result')
					Dom.style fontWeight: 'bold'
					if result is side
						Dom.text " - wins!"
					else if result is 'draw'
						Dom.text " - draw"
					else if result
						Dom.text " - lost"

				else if Db.shared.get('turn') is side
					if id is Plugin.userId()
						Dom.style color: Plugin.colors().highlight, fontWeight: 'bold'
					Dom.text " - to move"

		renderSide if isBlack then 'white' else 'black'
		
		Dom.div !->
			Dom.style
				display_: 'box'
				_boxAlign: 'center'
				_boxPack: 'center'
				margin: '4px 0'

		Dom.div !->
			Dom.style
				margin: '0 5%'

			selected = Obs.create false
			markers = Obs.create {}
				# chess field index indicating last-moved-piece, king-under-attack, selected, possible-move
		
			Obs.observe !->
				if last=Db.shared.get('last')
					markers.set last[0], 'last'
					markers.set last[1], 'last'

				if check = Chess.isCheck(Db.shared.get('board'), Db.shared.get('turn')?[0])
					markers.set check, 'check'

				if s = selected.get()
					markers.set s, 'selected'
					for square of Chess.find(s)
						markers.set square, 'move'

				Obs.onClean !->
					markers.set {}

			Dom.div !->
				Dom.style
					paddingTop: '161%'
					#background: "url(#{Plugin.resourceUri 'board.svg'})"
					background: 'url("data:image/svg+xml;utf8,<svg width=\'1080\' height=\'1740\' viewPort=\'0 0 1060 1720\' version=\'1.1\' xmlns=\'http://www.w3.org/2000/svg\'><clipPath id=\'aceg\'><rect x=\'135\' y=\'0\' width=\'135\' height=\'1740\'/><rect x=\'405\' y=\'0\' width=\'135\' height=\'1740\'/><rect x=\'675\' y=\'0\' width=\'135\' height=\'1740\'/><rect x=\'945\' y=\'0\' width=\'135\' height=\'1740\'/></clipPath><clipPath id=\'bdfh\'><rect x=\'0\' y=\'0\' width=\'135\' height=\'1740\'/><rect x=\'270\' y=\'0\' width=\'135\' height=\'1740\'/><rect x=\'540\' y=\'0\' width=\'135\' height=\'1740\'/><rect x=\'810\' y=\'0\' width=\'135\' height=\'1740\'/><rect x=\'1080\' y=\'0\' width=\'135\' height=\'1740\'/></clipPath><ellipse cx=\'540\' cy=\'870\' rx=\'810\' ry=\'870\' fill=\'#000\' /><ellipse cx=\'540\' cy=\'870\' rx=\'810\' ry=\'870\' fill=\'#fff\' clip-path=\'url(#aceg)\' /><ellipse cx=\'540\' cy=\'870\' rx=\'675\' ry=\'725\' fill=\'#000\' /><ellipse cx=\'540\' cy=\'870\' rx=\'675\' ry=\'725\' fill=\'#FFF\' clip-path=\'url(#bdfh)\' /><ellipse cx=\'540\' cy=\'870\' rx=\'540\' ry=\'580\' fill=\'#000\' /><ellipse cx=\'540\' cy=\'870\' rx=\'540\' ry=\'580\' fill=\'#FFF\' clip-path=\'url(#aceg)\' /><ellipse cx=\'540\' cy=\'870\' rx=\'405\' ry=\'435\' fill=\'#000\' /><ellipse cx=\'540\' cy=\'870\' rx=\'405\' ry=\'435\' fill=\'#FFF\' clip-path=\'url(#bdfh)\' /><ellipse cx=\'540\' cy=\'870\' rx=\'270\' ry=\'290\' fill=\'#000\' /><ellipse cx=\'540\' cy=\'870\' rx=\'270\' ry=\'290\' fill=\'#FFF\' clip-path=\'url(#aceg)\' /><ellipse cx=\'540\' cy=\'870\' rx=\'135\' ry=\'145\' fill=\'#000\' /><ellipse cx=\'540\' cy=\'870\' rx=\'135\' ry=\'145\' fill=\'#FFF\' clip-path=\'url(#bdfh)\' /></svg>")'
					backgroundSize: '100% 100%'
					position: 'relative'

				size = 50

				(if isBlack then 'hgfedcba' else 'abcdefgh').split('').forEach (x,xi) !->
					rows = if x in ['a','h']
							[1,2,45,7,8]
						else if x in ['b','g']
							[1,2,3,45,6,7,8]
						else if x in ['c','f']
							[1,2,3,4,45,5,6,7,8]
						else if x in ['d','e']
							[1,2,3,4,42,45,48,5,6,7,8]
					rows.forEach (y, yi) !->
						Dom.div !->
							offset = 0
							stride = 8.3
							height = 8
							if x in ['a','h']
								offset = 10
								stride = 12
								if y is 45
									height = 30
							else if x in ['b','g']
								offset = 5
								stride = 10
								if y is 45
									height = 25
							else if x in ['c','f']
								offset = 2
								stride = 8.7
								if y is 45
									height = 20
							else if y is 45
								height = 15

							top = if y is 45
									50
								else if y is 42
									38
								else if y is 48
									62
								else if y > 4
									96 - (8-y)*stride - offset
								else
									4 + (y-1)*stride + offset

							if !isBlack
								top = 100-top
							top -= height/2
							#Dom.cls 'square'
							Dom.style
								position: 'absolute'
								left: "#{xi*12.5}%"
								width: '12.5%'
								top: "#{top}%"
								height: "#{height}%"
							if 1
								Dom.cls if (xi%2)==(yi%2) then 'white' else 'black'

								piece = Db.shared.get('board', x+y)

								if marker = markers.get(x+y)
									Dom.div !->
										blue = marker in ['last', 'check']
										Dom.style
											position: 'absolute'
											width: if piece then '90%' else '50%'
											height: if piece then '90%' else '50%'
											left: if piece then '5%' else '25%'
											top: if piece then '5%' else '25%'
											background: if marker in ['last', 'check']
													Plugin.colors().bar
												else
													Plugin.colors().highlight
											opacity: if marker is 'last' then .6 else 1
											borderRadius: '999px'

								if piece
									Dom.div !->
										Dom.style
											position: 'absolute'
											left: 0
											top: 0
											width: '100%'
											height: '100%'
											background: "url(#{Plugin.resourceUri piece+'.png'}) no-repeat 50% 50%"
											backgroundSize: "#{0|size*.75}px"

								Dom.onTap !->
									turn = Db.shared.get('turn')
									if Db.shared.get(turn) is Plugin.userId()
										s = selected.get()
										if !s and piece and piece[0] is turn[0]
											selected.set x+y
											return

										if s and s isnt x+y and Db.shared.peek('board', x+y)?[0] isnt turn[0]
											log 'move', s, '>', x+y
											type = Chess.canMove(s, x+y)
											if type is 'promotion'
												t = turn[0]
												choosePiece [t+'q',t+'r',t+'b',t+'n'], (piece) ->
													Server.call 'move', s, x+y, piece[1] if piece
											else if type
												Server.call 'move', s, x+y
											else if markers.get(x+y) is 'move'
												# we had a move marker here, but cant move here because we are checked or will be in check
												require('toast').show tr("Invalid move - you are checked!")

									selected.set false

		renderSide if isBlack then 'black' else 'white'

	Social.renderComments()
	

choosePiece = (pieces, cb) !->
	require('modal').show tr("Choose piece"), !->
		pieces.forEach (piece) !->
			Dom.div !->
				Dom.style
					display: 'inline-block'
					height: '40px'
					width: '40px'
					margin: '4px'
					background: "url(#{Plugin.resourceUri piece+'.png'}) no-repeat 50% 50%"
					backgroundSize: '32px'

				Dom.onTap !->
					require('modal').remove()
					cb(piece)
	, !->
		cb()
	, ['cancel', tr("Cancel")]


# input that handles selection of a member
selectMember = (opts) !->
	opts ||= {}
	[handleChange, initValue] = Form.makeInput opts, (v) -> 0|v

	value = Obs.create(initValue)
	Form.box !->
		Dom.style fontSize: '125%', paddingRight: '56px'
		Dom.text opts.title||tr("Selected member")
		v = value.get()
		Dom.div !->
			Dom.style color: (if v then 'inherit' else '#aaa')
			Dom.text (if v then Plugin.userName(v) else tr("Nobody"))
		if v
			Ui.avatar Plugin.userAvatar(v), !->
				Dom.style position: 'absolute', right: '6px', top: '50%', marginTop: '-20px'

		Dom.onTap !->
			Modal.show opts.selectTitle||tr("Select member"), !->
				Dom.style width: '80%'
				Dom.div !->
					Dom.style
						maxHeight: '40%'
						overflow: 'auto'
						_overflowScrolling: 'touch'
						backgroundColor: '#eee'
						margin: '-12px'

					Plugin.users.iterate (user) !->
						Ui.item !->
							Ui.avatar user.get('avatar')
							Dom.text user.get('name')

							if +user.key() is +value.get()
								Dom.style fontWeight: 'bold'

								Dom.div !->
									Dom.style
										Flex: 1
										padding: '0 10px'
										textAlign: 'right'
										fontSize: '150%'
										color: Plugin.colors().highlight
									Dom.text "✓"

							Dom.onTap !->
								handleChange user.key()
								value.set user.key()
								Modal.remove()
			, (choice) !->
				log 'choice', choice
				if choice is 'clear'
					handleChange ''
					value.set ''
			, ['cancel', tr("Cancel"), 'clear', tr("Clear")]

Dom.css
	'.board':
		XboxShadow: '0 0 8px #000'
	'.square':
		display: 'inline-block'
		width: '12.5%'
		padding: '12.5% 0 0' # use padding-top trick to maintain aspect ratio
		position: 'relative'
	'.square.white':
		backgroundColor: 'rgb(244,234,193)'
	'.square.black':
		backgroundColor: 'rgb(223,180,135)'

