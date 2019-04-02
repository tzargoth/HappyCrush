extends Node2D

var level
#var swap
var cookiesLayer
var tilesLayer

var swipeFromColumn
var swipeFromRow

var selectionCookie
var userInteractionEnabled = false
var sounds = Dictionary()

var cookiesList = []
var cookiesHList = []

func _enter_tree():
	cookiesList.append(mainRes.Croissant)
	cookiesList.append(mainRes.Cupcake)
	cookiesList.append(mainRes.Danish)
	cookiesList.append(mainRes.Donut)
	cookiesList.append(mainRes.Macaroon)
	cookiesList.append(mainRes.SugarCookie)
	
	cookiesHList.append(mainRes.CroissantH)
	cookiesHList.append(mainRes.CupcakeH)
	cookiesHList.append(mainRes.DanishH)
	cookiesHList.append(mainRes.DonutH)
	cookiesHList.append(mainRes.MacaroonH)
	cookiesHList.append(mainRes.SugarCookieH)
	
	level = mainRes.gameLevel.new()
	
	add_child(level, true)
	
	tilesLayer = get_node("TilesLayer")
	tilesLayer.position = getLayerPos()
	
	cookiesLayer = get_node("CookiesLayer")
	cookiesLayer.position = getLayerPos()

func removeAllCookies():
	for child in cookiesLayer.get_children():
		if child.get_name() != "ScoreLabelNode": child.queue_free()

func getLayerPos():
	return Vector2(-global.TILE_WIDTH * global.NumColumns/2, -global.TILE_HEIGHT * global.NumRows/2)

func _ready():
	userInteractionEnabled = true
	
	swipeFromColumn = null
	swipeFromRow = null
	selectionCookie = null

	preloadResources()
	set_process_input(true)

func highlightSelectionIndicator():
	if selectionCookie != null:
		selectionCookie.sprite.set_texture(cookiesHList[selectionCookie.cookieType-1])

func hideSelectionIndicator():
	if selectionCookie != null:
		selectionCookie.sprite.set_texture(cookiesList[selectionCookie.cookieType-1])

func preloadResources():
	sounds["crush"]			= "Chomp"
	sounds["validSwap"]		= "Scrape"
	sounds["invalidSwap"]	= "Error"
	sounds["match"]			= "Ka-Ching"
	sounds["fallingCookies"]= "Drip"

func addTiles():
	#for row in range(-1, global.NumRows, 1):
	#	for column in range(global.NumColumns):
	#		if row >= 0 && level.tileAt(column, row) == null:
	#			level.createLighMaskAt(pointFor(column, row), tilesLayer)
	#		elif row == -1 && level.tileAt(column, row) != null:
	#			level.createLighMaskAt(pointFor(column, row), tilesLayer)
	#
	for row in range(global.NumRows, -1, -1):
		for column in range(global.NumColumns+1):
			var topLeft = (column > 0 && row < global.NumRows && level.tileAt(column-1, row))
			var bottomLeft = (column > 0 && row > 0 && level.tileAt(column-1, row-1))
			var topRight = (column < global.NumColumns && row < global.NumRows && level.tileAt(column,row))
			var bottomRight = (column < global.NumColumns && row > 0 && level.tileAt(column, row-1))
			
			var value = int(topLeft) | int(topRight) << 1 | int(bottomLeft) << 2 | int(bottomRight) << 3
			
			if value != 0 && value != 6 && value != 9:
				var path = "res://textures/grid/Tile_%d.png" % value
				var pos = pointFor(column, row)
				pos.x -= global.TILE_WIDTH / 2
				pos.y -= global.TILE_HEIGHT / 2
				var sprite = Sprite.new()
				var texture = ResourceLoader.load(path)
				sprite.set_texture(texture)
				sprite.position = pos
				tilesLayer.add_child(sprite)
			

func addSpritesFor(cookies):
	var tween = Tween.new()
	add_child(tween)
	
	for cookie in cookies:
		var sprite = Sprite.new()
		var tex = cookiesList[int(cookie.cookieType-1)]
		sprite.z_index = 10
		sprite.light_mask = 8
		sprite.texture = tex
		sprite.position = pointFor(cookie.column, cookie.row)
		cookiesLayer.add_child(sprite)
		cookie.sprite = sprite
		cookie.sprite.modulate.a = 1
		cookie.sprite.scale = Vector2(0.5, 0.5)
		
		var delay = rand_range(0.25, 0.5)
		
		tween.interpolate_property(cookie.sprite, "modulate:a", 0.0, 1.0, 0.25, Tween.TRANS_LINEAR, \
		Tween.EASE_OUT, delay)
		tween.interpolate_property(cookie.sprite, "scale", Vector2(0.5, 0.5), Vector2(1.0, 1.0), \
		0.25, Tween.TRANS_LINEAR, Tween.EASE_OUT, delay)

		# old 2.0 code
		#tween.interpolate_method(cookie.sprite, "set_opacity", 0.0, 1.0, 0.25, Tween.TRANS_LINEAR, \
		#Tween.EASE_OUT, delay)
		#tween.interpolate_method(cookie.sprite, "set_scale", Vector2(0.5, 0.5), Vector2(1.0, 1.0), \
		#0.25, Tween.TRANS_LINEAR, Tween.EASE_OUT, delay)
	
	tween.interpolate_callback(self, tween.get_runtime(), "removeNode", tween)
	tween.start()
	

func pointFor(column, row):
	return Vector2(column*global.TILE_WIDTH + global.TILE_WIDTH/2, \
					row*global.TILE_HEIGHT + global.TILE_HEIGHT/2)

func handleMatch():
	var chains = level.removeMatches()
	if chains.size() == 0: beginNextTurn()
	else: animateMatched(chains)

func beginNextTurn():
	level.resetcomboMultiplier()
	var swaps = level.detectPossibleSwaps()
	setUserInteraction(true)
	decrementMoves()
	
	if swaps.size() <= 0: get_parent().shuffle()

func decrementMoves():
	global.movesLeft -= 1;
	
	if global.score >= level.targetScore:
		#showGameOver()
		pass
	elif global.movesLeft <= 0:
		#showGameOver()
		pass

func showGameOver():
	animateBeginEndGame(true)
	setUserInteraction(false)

func swapHandler(swap):
	if level.isPossible(swap):
		setUserInteraction(false)
		level.performSwap(swap)
		animateSwap(swap)
	else:
		setUserInteraction(false)
		animateInvalidSwap(swap)

func completeSwap(t1, cookie, invalid = false):
	t1.queue_free()
	hideSelectionIndicator()
	
	if not invalid: handleMatch()
	else: setUserInteraction(true)

func completeMatch(tween, chains):
	removeNode(tween)
	
	for chain in chains:
		global.score += chain.score
	
	var columns = level.fillHoles()
	animateFallingCookies(columns)

func completeFalling(tween):
	removeNode(tween)
	
	var columns = level.topUpCookies()
	animateNewCookies(columns)

func completeAddCookie(tween):
	removeNode(tween)
	
	handleMatch()

func trySwap (horzDelta, vertDelta):
	var toColumn = swipeFromColumn + horzDelta
	var toRow = swipeFromRow + vertDelta
	
	if toColumn < 0 || toColumn >= global.NumColumns: return
	if toRow < 0 || toRow >= global.NumRows: return
	
	var toCookie = level.cookieAt(toColumn, toRow)
	if toCookie == null: return
	
	var fromCookie = level.cookieAt(swipeFromColumn, swipeFromRow)
	
	var swap = mainRes.gameSwap.new()
	swap.cookieA = fromCookie;
	swap.cookieB = toCookie;
	
	swapHandler(swap);

func animateInvalidSwap(swap):
	if swap.cookieA.sprite == null || swap.cookieB.sprite == null:
		setUserInteraction(true);
		return
	
	swap.cookieA.sprite.z_index = 100
	swap.cookieB.sprite.z_index = 90
	
	var tween = Tween.new()
	add_child(tween)
	
	#var cookieAPos = swap.cookieA.sprite.position
	#var cookieBPos = swap.cookieB.sprite.position
	
	var cookieAPos = pointFor(swap.cookieA.column, swap.cookieA.row)
	var cookieBPos = pointFor(swap.cookieB.column, swap.cookieB.row)
	
	var duration = 0.3
	#var property = "transform/pos"
	
	var bubbleA = Sprite.new()
	bubbleA.texture = mainRes.bubble
	bubbleA.scale = Vector2(1, 1)
	bubbleA.position = swap.cookieA.sprite.position
	var bubbleB = Sprite.new()
	bubbleB.texture = mainRes.bubble
	bubbleB.scale = Vector2(1, 1)
	bubbleB.position = swap.cookieB.sprite.position
	
	cookiesLayer.add_child(bubbleA)
	cookiesLayer.add_child(bubbleB)
	
	tween.interpolate_method(bubbleA, "set_scale", Vector2(1, 1), Vector2(0.4, 0.4), 0.2, \
	Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_method(bubbleB, "set_scale", Vector2(1, 1), Vector2(0.4, 0.4), 0.2, \
	Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_callback(self, tween.get_runtime(), "removeNode", bubbleA, bubbleB)
	
	tween.interpolate_method(swap.cookieA.sprite, "set_position", cookieAPos, cookieBPos, duration,\
	Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_method(swap.cookieB.sprite, "set_position", cookieBPos, cookieAPos, duration,\
	Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_method(swap.cookieA.sprite, "set_position", cookieBPos, cookieAPos, duration,\
	Tween.TRANS_LINEAR, Tween.EASE_OUT, duration)
	tween.interpolate_method(swap.cookieB.sprite, "set_position", cookieAPos, cookieBPos, duration,\
	Tween.TRANS_LINEAR, Tween.EASE_OUT, duration)
	tween.interpolate_callback(self, tween.get_runtime(), "completeSwap", tween, swap.cookieA.sprite, true)
	tween.start()
	pass

func animateSwap(swap):
	swap.cookieA.sprite.z_index = 100
	swap.cookieB.sprite.z_index = 90
	
	var cookieAPos = swap.cookieA.sprite.position
	var cookieBPos = swap.cookieB.sprite.position
	
	var tween = Tween.new()
	add_child(tween)
	
	var duration = 0.3	
	var bubbleA = Sprite.new()
	bubbleA.texture = mainRes.bubble
	bubbleA.scale = Vector2(1, 1)
	bubbleA.position = swap.cookieA.sprite.position
	var bubbleB = Sprite.new()
	bubbleB.texture = mainRes.bubble
	bubbleB.scale = Vector2(1, 1)
	bubbleB.position = swap.cookieB.sprite.position
	
	cookiesLayer.add_child(bubbleA)
	cookiesLayer.add_child(bubbleB)
	
	tween.interpolate_method(bubbleA, "set_scale", Vector2(1, 1), Vector2(0.4, 0.4), 0.2, \
	Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_method(bubbleB, "set_scale", Vector2(1, 1), Vector2(0.4, 0.4), 0.2, \
	Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_callback(self, tween.get_runtime(), "removeNode", bubbleA, bubbleB)
	
	var moveA = tween.interpolate_property(swap.cookieA.sprite, "position", cookieAPos, cookieBPos, \
	duration, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	var moveB = tween.interpolate_property(swap.cookieB.sprite, "position", cookieBPos, cookieAPos, \
	duration, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_callback(self, tween.get_runtime(), "completeSwap", tween, swap.cookieA)
	
	tween.start()
	pass

func animateMatched(chains):
	var tween = Tween.new()
	add_child(tween)
	
	for chain in chains:
		animateScoreForChain(chain)
		for cookie in  chain.getCookies():
			if cookie.sprite != null:
				var expTween = Tween.new()
				add_child(expTween)
				
				var expA = mainRes.starExp.instance()
				expA.lifetime = 1.0
				expA.emitting = true
				#expA.lifetime = 1
				expA.position = cookie.sprite.position
				
				var bubbleA = Sprite.new()
				bubbleA.texture = mainRes.bubble
				bubbleA.scale = Vector2(0.4, 0.4)
				bubbleA.position = cookie.sprite.position
				
				cookiesLayer.add_child(bubbleA)
				cookiesLayer.add_child(expA)
				
				tween.interpolate_method(bubbleA, "set_scale", bubbleA.get_scale(), Vector2(1.0, 1.0), \
				0.3, Tween.TRANS_LINEAR, Tween.EASE_OUT)
				
				tween.interpolate_property(cookie.sprite, "position", cookie.sprite.get_scale(), \
				Vector2(0.1, 0.1), 0.3, Tween.TRANS_LINEAR, Tween.EASE_OUT)
				tween.interpolate_property(cookie.sprite, "modulate:a", cookie.sprite.modulate.a, \
				0.3, 0.3, Tween.TRANS_LINEAR, Tween.EASE_OUT)

				# old 2.0 code
				#tween.interpolate_method(cookie.sprite, "set_opacity", cookie.sprite.get_opacity(), \
				#0.3, 0.3, Tween.TRANS_LINEAR, Tween.EASE_OUT)
				tween.interpolate_callback(self, tween.get_runtime(), "removeNode", cookie.sprite, bubbleA)
				
				expTween.interpolate_property(expA, "modulate:a", expA.modulate.a, \
				0.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.3)

				# old 2.0 code
				#expTween.interpolate_method(expA, "set_opacity", expA.get_opacity(), \
				#0.0, 0.5, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.3)
				expTween.interpolate_callback(self, expTween.get_runtime(), "removeNode", expA, expTween)
				expTween.start()
				
				cookie.sprite = null
	
	tween.interpolate_callback(self, tween.get_runtime(), "completeMatch", tween, chains)
	tween.start()
	pass

func animateFallingCookies(columns):
	var tween = Tween.new()
	add_child(tween)
	
	for array in columns:
		var idx = 0
		for cookie in array:
			var newPosition = pointFor(cookie.column, cookie.row)
			var newPosition1 = Vector2(newPosition.x, newPosition.y - 3)
			
			var delay = (0.05 + idx / 10.0) * 0.1
			var duration = ((newPosition.y - cookie.sprite.position.y) / global.TILE_HEIGHT) * 0.1
			
			tween.interpolate_property(cookie.sprite, "position", cookie.sprite.position, \
			newPosition, duration, Tween.TRANS_LINEAR, Tween.EASE_OUT, delay)
			tween.interpolate_property(cookie.sprite, "position", newPosition, newPosition1, \
			0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT, duration + delay)
			tween.interpolate_property(cookie.sprite, "position", newPosition1, newPosition, \
			0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT, duration + delay + 0.1)
			
			idx += 1
	tween.interpolate_callback(self, tween.get_runtime(), "completeFalling", tween)
	tween.start()

func animateNewCookies(columns):
	var tween = Tween.new()
	add_child(tween)
	
	for array in columns:
		var startRow = array[0].row - 1
		var idx = 0
		array.invert()
		for cookie in array:
			var sprite = Sprite.new()
			sprite.texture = cookiesList[cookie.cookieType-1]
			sprite.position = pointFor(cookie.column, startRow)
			sprite.light_mask = global.TILE_MASK
			cookiesLayer.add_child(sprite)
			cookie.sprite = sprite
			
			var newPosition = pointFor(cookie.column, cookie.row)
			var newPosition1 = Vector2(newPosition.x, newPosition.y-3)
			var delay = (0.05 + (idx/10.0))
			var duration = ((cookie.row - startRow) * 0.1)
			
			tween.interpolate_property(cookie.sprite, "position", cookie.sprite.position, \
			newPosition, duration, Tween.TRANS_LINEAR, Tween.EASE_OUT, delay)
			tween.interpolate_property(cookie.sprite, "position", newPosition, newPosition1, \
			0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT, duration+delay)
			tween.interpolate_property(cookie.sprite, "position", newPosition1, newPosition, \
			0.1, Tween.TRANS_LINEAR, Tween.EASE_OUT, duration + delay + 0.1)
			
			idx += 1
	tween.interpolate_callback(self, tween.get_runtime(), "completeAddCookie", tween)
	tween.start()

func animateScoreForChain(chain):
	var tween = Tween.new()
	add_child(tween)
	
	var Cookies = chain.getCookies()
	var column
	var row
	
	if chain.chainType == mainRes.gameChain.ChainTShape || chain.chainType == mainRes.gameChain.ChainLShape:
		column = chain.matchColumn
		row = chain.matchRow
	else:
		column = (Cookies[0].column + Cookies[-1].column)/2.0
		row = (Cookies[0].row + Cookies[-1].row)/2.0
	
	var cPos = pointFor(column, row)
	var node = Node2D.new()
	node.name = "ScoreLabelNode"
	node.position = cPos
	node.z_index = 300
	
	var scoreLabel = Label.new()
	scoreLabel.set("custom_fonts/font", preload("res://Fonts/foo_shadow_34.fnt"))
	scoreLabel.set("custom_colors/font_color", Color8(225, 80.68, 80.68))
	scoreLabel.text = str(chain.score)
	
	var size = scoreLabel.get_combined_minimum_size()
	scoreLabel.rect_position = Vector2(0.0 - size.x / 2, 0.0 - size.y / 2)
	
	node.scale = Vector2(0.8, 0.8)
	node.add_child(scoreLabel)
	cookiesLayer.add_child(node)
	
	tween.interpolate_method(node, "set_scale", Vector2(0.8, 0.8), Vector2(1.0, 1.0), 0.2, \
	Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_method(node, "set_position", cPos, Vector2(cPos.x, cPos.y-6), 0.7, \
	Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_method(node, "set_opacity", 1.0, 0.3, 0.3, Tween.TRANS_LINEAR, Tween.EASE_OUT, \
	tween.get_runtime())
	tween.interpolate_callback(self, tween.get_runtime(), "removeNode", node, tween)
	tween.start()

func animateBeginEndGame(end = false):
	var tween = Tween.new()
	add_child(tween)
	
	var cPos = position
	var pos = Vector2(position.x + (global.NumColumns*global.TILE_WIDTH)*2, position.y)
	
	if end:
		cPos = pos
		pos = position
	else: position = pos
	
	tween.interpolate_method(self, "set_position", pos, cPos, 1.0, Tween.TRANS_BACK, \
	(Tween.EASE_OUT if not end else Tween.EASE_IN))
	tween.interpolate_callback(self, tween.get_runtime(), "removeNode", tween)
	tween.start()

func setUserInteraction(value):
	userInteractionEnabled = value

func removeNode(node1, node2 = null, node3 = null, node4 = null):
	node1.queue_free()
	if node2 != null: node2.queue_free()
	if node3 != null: node3.queue_free()
	if node4 != null: node4.queue_free()

var touchStared
var touchStartPos
var touchCurrentPos

func _input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.is_pressed():
		touchStared = true
		touchBegin(event)
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.is_pressed():
		touchStared = false
		touchEnded(event)
	if event is InputEventMouseMotion:
		if touchStared: touchMoved(event)
	
	if event is InputEventScreenTouch and event.is_pressed():
		touchStared = true
		touchBegin(event)
	if event is InputEventScreenTouch and not event.is_pressed():
		touchStared = false
		touchEnded(event)
	if event is InputEventScreenDrag and event.is_pressed():
		if touchStared: touchMoved(event)

var touchInColumn1
var touchInRow1

func touchBegin(event):
	if not userInteractionEnabled: return
	var location = event.position - cookiesLayer.global_position
	
	if convertPoint(location):
		var cookie = level.cookieAt(touchInColumn1, touchInRow1)
		if cookie != null and not cookie.isnull:
			selectionCookie = cookie
			highlightSelectionIndicator()
			swipeFromColumn = touchInColumn1
			swipeFromRow = touchInRow1

			print(touchInColumn1)

func convertPoint(point, from = true):
	if (point.x >= 0 && point.x < global.NumColumns * global.TILE_WIDTH && \
	point.y >= 0 && point.y < global.NumRows * global.TILE_HEIGHT ):
		if from:
			touchInColumn1 = point.x / global.TILE_WIDTH
			touchInRow1 = point.y / global.TILE_HEIGHT
		else:
			touchInColumn2 = point.x / global.TILE_WIDTH
			touchInRow2 = point.y / global.TILE_HEIGHT
		
		return true
	else: return false

var touchInColumn2
var touchInRow2

func touchMoved(event):
	if not userInteractionEnabled: return
	if swipeFromColumn == null: return
	
	var location = event.position - cookiesLayer.global_position
	
	if convertPoint(location, false):
		var horzDelte = 0
		var vertDelta = 0
		
		if touchInColumn2 < swipeFromColumn: horzDelte = -1
		elif touchInColumn2 > swipeFromColumn: horzDelte = 1
		elif touchInRow2 < swipeFromRow: vertDelta = -1
		elif touchInRow2 > swipeFromRow: vertDelta = 1
		
		if horzDelte != 0 || vertDelta != 0:
			trySwap(horzDelte, vertDelta)
			if selectionCookie != null: hideSelectionIndicator()
			
			swipeFromColumn = null

func touchEnded(event):
	if selectionCookie != null and selectionCookie.sprite != null:
		selectionCookie.sprite.set_texture(cookiesList[selectionCookie.cookieType-1])
		selectionCookie = null
	
	swipeFromColumn = null
	swipeFromRow = null
