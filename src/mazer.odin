package mazer

import "core:fmt"
import "core:mem"
import "core:path/filepath"
import "core:strings"
import "qv"
import rl "vendor:raylib"

// structs
Battle :: struct {
	wave: i64,
}

Game :: struct {
	sw, sh: f32,

	battle: Battle,
	player: Ship,
	rem_pop: i64, 		// The remaining population on the planet for this game
}

Ship :: struct {
	// movement
	accel: f32,
	vel: rl.Vector2,
	pos: rl.Vector2,
	friction: f32,
	max_speed: f32,

	// appearance and shape
	color: rl.Color,
	size: rl.Vector2,

	// game-play
	score: i64,
}

// variables
MAX_POP_DIGITS   :: 12
MAX_SCORE_DIGITS :: 8
hud_font: rl.Font
hud_font_size: i32 = 36

// procedures
do_battle :: proc(game: ^Game) {
	rl.ClearBackground(rl.BLACK)

	player_update(game)

	render_player(game)
	render_hud(game)
}

game_init :: proc(game: ^Game) {
	game.sw = f32(rl.GetScreenWidth())
	game.sh = f32(rl.GetScreenHeight())

	game.battle = Battle{}
	game.player = Ship{
		accel = 400,
		vel = rl.Vector2{ 0, 0 },
		pos = rl.Vector2{ 50, 200 },
		friction = 5,
		max_speed = 400,
		color = rl.BLUE,
		size = rl.Vector2{ 32, 16 }
	}
	game.rem_pop = 8_700_314_042
}

player_update :: proc(game: ^Game) {
	dt := rl.GetFrameTime()
	dir := rl.Vector2{ 0, 0 }
	if rl.IsKeyDown(rl.KeyboardKey.UP)    { dir.y -= 1 }
	if rl.IsKeyDown(rl.KeyboardKey.DOWN)  { dir.y += 1 }
	if rl.IsKeyDown(rl.KeyboardKey.LEFT)  { dir.x -= 1 }
	if rl.IsKeyDown(rl.KeyboardKey.RIGHT) { dir.x += 1 }
	if rl.Vector2Length(dir) > 0 {
		dir = rl.Vector2Normalize(dir)
	}

	accel_vec := (dir * game.player.accel)
	game.player.vel += (accel_vec * dt)
	if rl.Vector2Length(dir) == 0 {
		game.player.vel *= (1 - game.player.friction * dt)
	}
	if rl.Vector2Length(game.player.vel) > game.player.max_speed {
		game.player.vel = rl.Vector2Normalize(game.player.vel) * game.player.max_speed
	}

	game.player.pos += (game.player.vel * dt)
}

render_hud :: proc(game: ^Game) {
	segment_digit_height: f32 = 28
	segment_size: f32 = 3

	label      := "score"
	label_c    := strings.clone_to_cstring(label, context.temp_allocator)
	label_size := rl.MeasureTextEx(hud_font, label_c, f32(hud_font_size), 0)
	label_x    := (game.sw/2) - (label_size.x/2)
	rl.DrawTextEx(hud_font, label_c, rl.Vector2{label_x, segment_digit_height}, f32(hud_font_size), 0, rl.BLUE)
	qv.seven_segment_display(
		game.player.score, MAX_SCORE_DIGITS,
		rl.Vector2{ label_x+(label_size.x/2), (segment_digit_height/2)+segment_size },
		segment_digit_height,
		segment_size,
		rl.LIGHTGRAY
	)

	label      = "population"
	label_c    = strings.clone_to_cstring(label, context.temp_allocator)
	label_size = rl.MeasureTextEx(hud_font, label_c, f32(hud_font_size), 0)
	label_x    = 60
	rl.DrawTextEx(hud_font, label_c, rl.Vector2{label_x, segment_digit_height}, f32(hud_font_size), 0, rl.BLUE)
	qv.seven_segment_display(
		game.rem_pop, MAX_POP_DIGITS,
		rl.Vector2{ label_x+(label_size.x/2), (segment_digit_height/2)+segment_size },
		segment_digit_height,
		segment_size,
		rl.LIGHTGRAY
	)

	label      = "wave"
	label_c    = strings.clone_to_cstring(label, context.temp_allocator)
	label_size = rl.MeasureTextEx(hud_font, label_c, f32(hud_font_size), 0)
	label_x    = game.sw-label_size.x-60
	rl.DrawTextEx(hud_font, label_c, rl.Vector2{label_x, segment_digit_height}, f32(hud_font_size), 0, rl.BLUE)
	qv.seven_segment_display(
		game.battle.wave, 3,
		rl.Vector2{ label_x+(label_size.x/2), (segment_digit_height/2)+segment_size },
		segment_digit_height,
		segment_size,
		rl.LIGHTGRAY
	)
}

render_player :: proc(game: ^Game) {
	rl.DrawRectangleV(game.player.pos, game.player.size, game.player.color)
}

main :: proc() {
    when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("\n=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("\n=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	qv.create_window("Mazer", .Seven_Twenty_P)	

    src_dir := filepath.dir(#file, context.temp_allocator)
    hud_font_path := filepath.join([]string{src_dir, "resources", "fonts", "heavy_data.ttf"}, context.temp_allocator)
    hud_font = rl.LoadFontEx(strings.clone_to_cstring(hud_font_path, context.temp_allocator), hud_font_size, nil, 0)
    defer rl.UnloadFont(hud_font)

	game: Game
	game_init(&game)
    for !rl.WindowShouldClose() {
		qv.begin()
		defer qv.present()
		
		do_battle(&game)	
	}
}