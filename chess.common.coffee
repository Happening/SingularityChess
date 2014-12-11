Db = require 'db'

exports.init = !->
	Db.shared.set 'board', do ->
		board = {}
		for color in ['w', 'b']
			for x,piece of {a:'r', b:'n', c:'b', d:'q', e:'k', f:'b', g:'n', h:'r'}
				board[x+(if color is 'w' then 1 else 8)] = color + piece
				board[x+(if color is 'w' then 2 else 7)] = color + 'p'
		board
	Db.shared.set 'turn', 'white'
	Db.shared.set 'moveId', 1
	Db.shared.set 'castling', {wk: true, wq: true, bk: true, bq: true}
		# indicates white/black king/queenside castling still possible

exports.move = (from, to, promotionPiece='q') ->
	boardRef = Db.shared.ref('board')
	return false if !boardRef

	type = canMove(from, to)
	return false if !type

	square = boardRef.get from
	[color,piece] = square

	capture = !!boardRef.peek(to)

	boardRef.set to, if type is 'promotion' then color+promotionPiece else square
	boardRef.remove from

	if type is 'enPassant' and lastTo = Db.shared.peek('last')?[1]
		boardRef.remove lastTo

	else if type is 'castle'
		boardRef.remove (if to[0] is 'g' then 'h' else 'a')+to[1]
		boardRef.set (if to[0] is 'g' then 'f' else 'd')+to[1], color+'r'

	if piece is 'k' or (piece is 'r' and from.charAt(0) is 'a')
		Db.shared.remove 'castling', color + 'q'
	if piece is 'k' or (piece is 'r' and from.charAt(0) is 'h')
		Db.shared.remove 'castling', color + 'k'

	Db.shared.set 'last', [from, to]

	color = Db.shared.modify 'turn', (t) -> if t is 'white' then 'black' else 'white'

	if mate = isMate(boardRef.get(), color[0])
		Db.shared.set 'result', if mate is 'stale' then 'draw' else if color is 'white' then 'black' else 'white'
	else if color is 'w'
		Db.shared.modify 'moveId', (m) -> m+1

	# return notation string:
	if type is 'castle' and to[0] is 'g'
		'0-0'
	else if type is 'castle'
		'0-0-0'
	else
		(if piece isnt 'p' then piece.toUpperCase() else '') + (if capture then 'x' else '') + to
	
exports.canMove = canMove = (from, to) ->
	square = Db.shared.get('board', from)
	return false if !square

	[color,piece] = square

	return false if color isnt Db.shared.get('turn')[0]

	board = Db.shared.get('board')
	isValid = false
	for move,type of findMoves(board, from)
		isValid = move is to
		break if isValid
	return false if !isValid

	board[to] = square
	delete board[from]
	return false if isCheck(board,color)

	type

exports.isCheck = isCheck = (board, forColor) ->
	attacked = {}
	kingLoc = false
	for loc,square of board when square?
		#log 'isCheck?', loc, square
		if square[0] isnt forColor
			for move of findMoves(board, loc)
				attacked[move] = true
		else if square is forColor + 'k'
			kingLoc = loc
	if attacked[kingLoc]
		kingLoc

isMate = (board, forColor) ->
	# check if stale or check mate on board
	# forColor: 'w' || 'b'
	
	for loc,square of board when square?[0] is forColor
		moves = findMoves(board,loc)
		delete board[loc]
		for move of moves
			prev = board[move]
			board[move] = square
			if not isCheck(board, forColor)
				#log 'no mate; move', loc, square, 'to', move
				board[move] = prev
				board[loc] = square
				return false
			board[move] = prev
		board[loc] = square

	#log 'looks like mate!', forColor
	# no moves? then it's either checkmate or stalemate
	if isCheck(board, forColor) then 'check' else 'stale'

exports.find = (base) ->
	findMoves Db.shared.get('board'), base

findMoves = (board, base) ->
	# get array of possible moves from a given start location
	square = board[base]
	[color,piece] = square

	moves = {}

	#log 'findMoves', base

	explore = (direction,recurse,ifEmpty,special,square,prev) ->
		square ?= base
		#log 'exploring', square, direction
		[a,b] = exploreRules[square][direction]
		for [loc,other] in [[a,b],[b,a]]
			if loc and (!prev or prev is other) and board[loc]?[0] isnt color
				if ifEmpty isnt null and (!ifEmpty? or (ifEmpty == !board[loc]))
					moves[loc] = special||true # add to possible moves
				if !board[loc] and recurse
					for d in [0,1,2,3]
						explore d, true, ifEmpty, special, loc, square

	if piece is 'p'
		###
		y = if color is 'w' then 1 else -1
		isPromotion = +base[1] is (if color is 'w' then 7 else 2)
		if findMove(0, y, true, (if isPromotion then 'promotion'))
			if +base[1] is (if color is 'w' then 2 else 7)
				findMove(0, y*2, true)
		last = Db.shared.peek('last')
		for x in [-1,1]
			enPassant = last and (last[1] is locDelta(base,x,0)) and board[last[1]][1] is 'p'
			findMove(x, y, (if enPassant then undefined else false), (if isPromotion then 'promotion' else if enPassant then 'enPassant'))
		###
		explore 1, false, true
		explore 2, false, false
		explore 3, false, false

		# discard all moves backward
		y = (s) ->
			p = +s.substr(1)
			p *= 10 if p<10
			p
		for s of moves
			#log 'color', color, y(s), y(base)
			if (color is 'w' and y(s) <= y(base)) or (color is 'b' and y(s) >= y(base))
				#log 'discard!'
				delete moves[s]

	else if piece is 'n'
		oldBoard = board
		board = {}
		explore 0
		explore 1
		board = oldBoard

		stage1 = {}
		stage1[s] = true for s of moves
		moves = {}
		for s of stage1
			explore 2, undefined, undefined, undefined, s
			explore 3, undefined, undefined, undefined, s

		for s of stage1
			delete moves[s]

	else if piece in ['k','q']
		explore d, (piece is 'q') for d in [0,1,2,3]

		###
		if piece is 'k'
			explore.single = true
			# check castling
			for side,x of {k:1, q:-1}
				if Db.shared?.peek('castling', color+side) and findMove(x,0,null)
					# todo: check for check
					findMove(x+x, 0, true, 'castle')
		###

	else if piece is 'r'
		explore 0, true
		explore 1, true

	else if piece is 'b'
		explore 2, true
		explore 3, true
	
	moves

exports.rules = -> exploreRules

exploreRules = {} # square -> [[hSquare0,hSquare1],[vSquare0,vSquare1],[d1Square0,d1Square1],[d2Square0,d2Square1]]
if dbg?
	dbg.e = exploreRules

squareDelta = (square, deltaRow, deltaCol) ->
	return if !square?

	col = square.charCodeAt(0) - 'a'.charCodeAt(0) + 1
	col = if typeof deltaCol is 'function' then deltaCol(col) else col + deltaCol
	col = String.fromCharCode(col + 'a'.charCodeAt(0) - 1)
	return if col<'a' or col>'h'

	row = parseInt(square[1..])
	row = if typeof deltaRow is 'function' then deltaRow(row) else row + deltaRow
	return if row<1 or (if row>10 then row/10 else row)>8

	col+row

rule = (square, horizontal, vertical, diagonal1, diagonal2) !->
	horizontal ?= [squareDelta(square,0,-1),squareDelta(square,0,1)]
	vertical ?= [squareDelta(square,-1,0),squareDelta(square,1,0)]
	diagonal1 ?= [squareDelta(square,-1,1),squareDelta(square,1,-1)]
	diagonal2 ?= [squareDelta(square,-1,-1),squareDelta(square,1,1)]

	mirrorCol = (col) -> 9-col
	mirrorRow = (row) -> (if row>10 then 90 else 9)-row

	[
		(s) -> s
		(s) -> squareDelta(s, 0, mirrorCol)
		(s) -> squareDelta(s, mirrorRow, 0)
		(s) -> squareDelta(s, mirrorRow, mirrorCol)
	].forEach (transform) !->
		exploreRules[transform(square)] = [
			horizontal?.map(transform),
			vertical?.map(transform),
			diagonal1?.map(transform),
			diagonal2?.map(transform)
		]

rule s for s in ['a1','b1','c1','d1','c2','d2','d3']
rule 'a2', undefined, ['a45','a1'], ['a7','b1']
rule 'b2', undefined, undefined, ['a45','c1']
rule 'b3', ['a45','c3'], ['b2','b45'], ['c2','b6']
rule 'c3', undefined, undefined, ['b45','d2']
rule 'c4', ['b45','d4'], ['c3','c45'], ['c5','d3'], ['b3','d42']
rule 'd4', undefined, ['d3','d42'], ['c45','e3'], ['c3','e42']
rule 'd42', ['c45','e42'], ['d4','d45'], ['d48','e4'], ['c4','e45']

rule 'a45', ['a2','b6'], ['a7','b3'], ['b2','b7'], ['b45']
rule 'b45', ['b3','c5'], ['b6','c4'], ['c3','c6'], ['a45','c45']
rule 'c45', ['c4','d48'], ['c5','d42'], ['d4','d5'], ['b45','d45']
rule 'd45', ['d42','d48'], [], ['e42','e48'], ['c45','e45']


