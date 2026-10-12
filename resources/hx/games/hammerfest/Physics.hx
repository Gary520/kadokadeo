package hammerfest;

// hammer/entity/Physics.mt: gravity, frictions and the collisions with the level, by steps of at most one case
class Physics extends Animator {
	public var dx:Float;
	public var dy:Float;

	public var fallStart:Null<Float>; // used for the fall height

	public var gravityFactor:Float;
	public var fallFactor:Float;
	public var slideFriction:Null<Float>; // world value if null
	public var shockResistance:Float;

	public var fl_stable:Bool;
	public var fl_physics:Bool;
	public var fl_friction:Bool;
	public var fl_gravity:Bool;
	public var fl_strictGravity:Bool;
	public var fl_hitGround:Bool;
	public var fl_hitCeil:Bool;
	public var fl_hitWall:Bool;
	public var fl_hitBorder:Bool;
	public var fl_slide:Bool;
	public var fl_teleport:Bool;
	public var fl_portal:Bool;
	public var fl_wind:Bool;
	public var fl_moveable:Bool;
	public var fl_bump:Bool;

	public var lastTeleporter:World.TeleporterData;

	public var fl_stopStepping:Bool;
	public var fl_skipNextGravity:Bool;
	public var fl_skipNextGround:Bool;

	public function new(animBase:String) {
		super(animBase);
		dx = 0;
		dy = 0;
		fallStart = null;
		slideFriction = null;
		gravityFactor = 1.0;
		fallFactor = 1.0;
		shockResistance = 1.0;
		fl_stable = false;
		fl_physics = true;
		fl_friction = true;
		fl_gravity = true;
		fl_strictGravity = true;
		fl_hitGround = true;
		fl_hitCeil = false;
		fl_hitWall = true;
		fl_hitBorder = true;
		fl_slide = true;
		fl_teleport = false;
		fl_portal = false;
		fl_wind = false;
		fl_moveable = true;
		fl_bump = false;
		fl_stopStepping = false;
		fl_skipNextGravity = true;
		fl_skipNextGround = false;
	}

	override public function init(g:Game) {
		super.init(g);
		register(Data.PHYSICS);
	}

	public function enablePhysics() {
		fl_physics = true;
	}

	public function disablePhysics() {
		fl_physics = false;
	}

	// shock wave around this entity
	public function shockWave(e:Physics, radius:Float, power:Float) {
		if (!e.fl_moveable)
			return;
		power /= e.shockResistance;
		var dist = e.distance(x, y);
		var ratio = 1 - dist / radius;
		var ang = Math.atan2(e.y - y, e.x - x);
		e.dx = Cs.qt(Math.cos(ang)) * ratio * power;
		if (e.fl_stable) {
			e.dy = -5;
		} else {
			e.dy += Cs.qt(Math.sin(ang)) * ratio * power;
			e.dy = Math.max(e.dy, -10);
		}
		e.fl_stable = false;
	}

	// death with a jump
	public function killHit(dx:Null<Float>) {
		if (fl_kill)
			return;
		this.dx = dx == null ? 0 : dx;
		this.dy = -10;
		fl_hitGround = false;
		fl_hitWall = false;
		fl_kill = true;
		fallFactor = Data.FALL_FACTOR_DEAD;
		onKill();
	}

	public function resurrect() {
		fl_hitGround = true;
		fl_hitWall = true;
		fl_kill = false;
		fallFactor = 1.0;
		fl_stopStepping = true;
	}

	// MOVES
	public function moveToAng(angDeg:Float, speed:Float) {
		var rad = Math.PI * angDeg / 180;
		dx = Cs.qt(Math.cos(rad)) * speed;
		dy = Cs.qt(Math.sin(rad)) * speed;
	}

	public function moveToTarget(e:Entity, speed:Float) {
		var rad = Math.atan2(e.y - y, e.x - x);
		dx = Cs.qt(Math.cos(rad)) * speed;
		dy = Cs.qt(Math.sin(rad)) * speed;
	}

	public function moveToPoint(x:Float, y:Float, speed:Float) {
		var rad = Math.atan2(y - this.y, x - this.x);
		dx = Cs.qt(Math.cos(rad)) * speed;
		dy = Cs.qt(Math.sin(rad)) * speed;
	}

	public function moveUp(speed:Float) {
		moveToAng(-90, speed);
	}

	public function moveDown(speed:Float) {
		moveToAng(90, speed);
	}

	public function moveLeft(speed:Float) {
		moveToAng(180, speed);
	}

	public function moveRight(speed:Float) {
		moveToAng(0, speed);
	}

	public function moveFrom(e:Entity, speed:Float) {
		var ang = -Cs.rnd(Math.round(100 * Math.PI)) / 100;
		x = e.x + Cs.qt(Math.cos(ang)) * Data.CASE_WIDTH * 2;
		y = e.y + Cs.qt(Math.sin(ang)) * Data.CASE_HEIGHT * 2;
		moveToTarget(e, speed);
		dx = -dx;
		dy = -dy;
	}

	public function moveToGround() {
		if (fl_stable)
			return;
		var pt = world.getGround(cx, cy);
		moveToCase(pt.x, pt.y);
	}

	// STEPPING
	public function checkHits() {
		var l = getByType(Data.ENTITY);
		for (e in l) {
			if (!e.fl_kill && !fl_kill && this.hitBound(e) && e.uniqId != this.uniqId) {
				this.hit(e);
				e.hit(this);
			}
		}
	}

	public function prefix() {}

	// change of case
	public function infix() {
		checkHits();

		var cid = world.getCase(cx, cy);
		// teleportation
		if (fl_teleport && !fl_kill) {
			if (cid == Data.FIELD_TELEPORT) {
				var start = world.getTeleporter(this, cx, cy);
				if (start != null) {
					var target = world.getNextTeleporter(start);
					if (target != null) {
						game.fxMan.attachFx(x, y - Data.CASE_HEIGHT, "fxPop");
						if (target.td.dir == Data.HORIZONTAL) {
							if (target.fl_rand)
								moveTo(target.td.centerX - Data.CASE_WIDTH * 0.5, target.td.centerY);
							else
								moveTo(target.td.centerX + Entity.x_ctr(cx) - start.centerX, target.td.centerY);
						} else {
							if (target.fl_rand)
								moveTo(target.td.centerX, target.td.centerY);
							else
								moveTo(target.td.centerX, target.td.centerY + Entity.y_ctr(cy) - start.centerY);
						}
						game.fxMan.attachFx(x, y - Data.CASE_HEIGHT, "fxShine");
						Snd.play("sound_teleport", Snd.CHAN_FIELD);
						fl_stopStepping = true;
						lastTeleporter = target.td;
						onTeleport();
					}
				}
			} else {
				lastTeleporter = null;
			}
		}

		// bumpers
		if (fl_bump && !fl_kill && cid == Data.FIELD_BUMPER) {
			var horiz = world.getCase(cx - 1, cy) == cid || world.getCase(cx + 1, cy) == cid;
			if (horiz && Math.abs(dy) < 20) {
				dx = 0;
				dy *= 5;
			}
			if (!horiz && Math.abs(dx) < 20) {
				dx *= 7;
				dy = 0;
			}
			onBump();
		}
	}

	public function onTeleport() {}

	public function postfix() {}

	public function recal() {
		y = Entity.y_ctr(Entity.y_rtc(y));
		updateCoords();
		while (world.getCase(cx, cy) == Data.GROUND) {
			y -= Data.CASE_HEIGHT;
			updateCoords();
		}
	}

	public function needsPatch():Bool {
		return false;
	}

	// EVENTS
	public function onKill() {}

	public function onDeathLine() {}

	public function onHitWall() {
		dx = 0;
	}

	public function onHitGround(height:Float) {
		fl_stable = true;
		dy = 0;
		recal();
	}

	public function onHitCeil() {
		dy = 0;
	}

	public function onBump() {}

	override public function endUpdate() {
		if (fl_hitBorder) { // against the exits on the sides
			if (x < Data.BORDER_MARGIN)
				x = Data.BORDER_MARGIN;
			if (x >= Data.GAME_WIDTH - Data.BORDER_MARGIN)
				x = Data.GAME_WIDTH - Data.BORDER_MARGIN - 1;
		}
		super.endUpdate();
	}

	override public function update() {
		super.update();

		if (!fl_physics)
			return;

		updateCoords();

		// wind
		if (fl_wind) {
			if (fl_stable && game.fl_wind)
				dx += game.windSpeed * Game.tmod;
		}

		// fall
		if (fl_stable) {
			if (dy != 0 || world.getCase(fcx, fcy) != Data.GROUND)
				fl_stable = false;
		}

		if (dx != 0 || dy != 0 || !fl_stable) {
			// gravity
			if (!fl_skipNextGravity && !fl_stable && fl_gravity) {
				if (dy < 0) {
					dy += gravityFactor * Data.GRAVITY * Game.tmod;
				} else {
					if (fallStart == null)
						fallStart = y;
					dy += fallFactor * Data.FALL_SPEED * Game.tmod;
				}
			}
			fl_skipNextGravity = false;

			prefix();

			// steps of at most one case (calcSteps: the move of a picture, tmod of a cycle)
			var dxTotal = dx * Game.tmod;
			var dyTotal = dy * Game.tmod;
			var total = Math.ceil(Math.abs(dxTotal) / Data.STEP_MAX);
			total = Std.int(Math.max(total, Math.ceil(Math.abs(dyTotal) / Data.STEP_MAX)));
			var sdx = dxTotal / total;
			var sdy = dyTotal / total;
			var step = 0;

			while (!fl_stopStepping && step < total) {
				var ocx = cx;
				var ocy = cy;
				var ox = x;
				var oy = y;
				oldX = x;
				oldY = y;

				x += sdx;
				y += sdy;
				updateCoords();

				// against the walls
				if (fl_hitWall) {
					var fl_hasHitWall = false;
					if (dx > 0 && world.getCase(Entity.x_rtc(ox + Data.CASE_WIDTH * 0.5), Entity.y_rtc(oy)) > 0)
						fl_hasHitWall = true;
					if (dx < 0 && world.getCase(Entity.x_rtc(ox - Data.CASE_WIDTH * 0.5), Entity.y_rtc(oy)) > 0)
						fl_hasHitWall = true;
					if (fl_hasHitWall) {
						x = ox;
						sdx = 0;
						updateCoords();
						onHitWall();
					}
				}

				// horizontal collision
				if ((fl_hitBorder && (x < Data.BORDER_MARGIN || x >= Data.GAME_WIDTH - Data.BORDER_MARGIN))
					|| (fl_hitWall && world.getCase(cx, Entity.y_rtc(oy)) > 0)) {
					x = ox;
					sdx = 0;
					updateCoords();
					onHitWall();
				}

				// walls crossed from above
				if (fl_hitWall && sdy > 0 && !fl_kill) {
					if (world.getCase(Entity.x_rtc(ox), Entity.y_rtc(oy + Math.floor(Data.CASE_HEIGHT / 2))) != Data.WALL
						&& world.getCase(fcx, fcy) == Data.WALL) {
						x = ox;
						sdx = 0;
						updateCoords();
						onHitWall();
					}
				}

				// landing
				if (fl_hitGround && sdy >= 0) {
					if (world.getCase(Entity.x_rtc(ox), Entity.y_rtc(oy + Math.floor(Data.CASE_HEIGHT / 2))) != Data.GROUND
						&& world.getCase(fcx, fcy) == Data.GROUND) {
						if (world.checkFlag(fcx, fcy, Data.IA_TILE)) {
							if (fl_skipNextGround) {
								fl_skipNextGround = false;
							} else {
								sdy = 0;
								onHitGround(y - (fallStart == null ? Math.NaN : fallStart));
								fallStart = null;
								updateCoords();
							}
						}
					}
				}

				// ceiling
				if (fl_hitCeil && sdy <= 0) {
					if (world.getCase(Entity.x_rtc(ox), Entity.y_rtc(oy - Math.floor(Data.CASE_HEIGHT / 2))) <= 0
						&& world.getCase(Entity.x_rtc(x), Entity.y_rtc(y - Math.floor(Data.CASE_HEIGHT / 2))) > 0) {
						sdy = 0;
						onHitCeil();
						updateCoords();
					}
				}

				// change of case
				if (ocx != cx || ocy != cy) {
					var fl_patch = false;

					// entering a ground with an air jump
					if (fl_hitGround && ocy < cy) {
						if (needsPatch()) {
							if (world.getCase(ocx, ocy) <= 0 && dy > 0 && world.getCase(cx, cy) > 0 && cy < Data.LEVEL_HEIGHT) {
								x = Entity.x_ctr(ocx);
								y = Entity.y_ctr(ocy);
								sdy = 0;
								updateCoords();
								onHitGround(y - (fallStart == null ? Math.NaN : fallStart));
								fl_patch = true;
							}
						}
					}

					// entering a ground (diagonal corners)
					if (fl_hitGround && dy >= 0 && ocx != cx && ocy != cy) {
						if (world.getCase(ocx, ocy) <= 0 && world.getCase(cx, cy) == Data.GROUND) {
							x = Entity.x_ctr(ocx);
							y = Entity.y_ctr(ocy);
							sdx = 0;
							updateCoords();
							onHitWall();
							fl_patch = true;
						}
					}
					if (!fl_patch) {
						tRem(ocx, ocy);
						infix();
						updateCoords();
						tAdd(cx, cy);
					}
				}

				step++;
			}
		}

		fl_stopStepping = false;
		postfix();

		// frictions
		if (fl_friction) {
			if ((game.fl_ice || fl_slide) && fl_stable) {
				if (slideFriction == null)
					dx *= game.sFriction;
				else
					dx *= Math.pow(slideFriction, Game.tmod);
			} else {
				dx *= game.xFriction;
				dy *= game.yFriction;
			}
		}
		if (Math.abs(dx) <= 0.2)
			dx = 0;
		if (Math.abs(dy) <= 0.2)
			dy = 0;

		// death
		if (y >= Data.DEATH_LINE)
			onDeathLine();
	}
}
