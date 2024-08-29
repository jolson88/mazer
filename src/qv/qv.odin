package qv

import "core:fmt"
import "core:math"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

// structures
Screen_Mode :: enum {
    Ten_Eighty_P = 0,
    Seven_Twenty_P = 1,
}

Text_Point :: struct {
    col: int,
    row: int,
}

@(private)
Pen_State :: struct {
    pos:    rl.Vector2,
    col:    int,
    scale:  f32
}

@(private)
Qv_State :: struct {
    // drawing
    drawing_cps: int,

    // screen
    screen_width, screen_height: int,
    screen_mode: Screen_Mode,
    frame_dur: f32,

    // text
    text_font: rl.Font,
    text_char_width: int,
    text_char_spacing: int,
    text_line_height: int,
    text_line_spacing: int,
    text_rows: int,
    text_cols: int,
    
    // timing
    completed_timers: map[string]bool,

    // typing
    typing_has_started_on_frame: bool,
    is_typing: bool,
    typing_cps: int,
    typing_entries: map[string]Typing_Entry,
    typing_text: string,
}

@(private)
Typing_Entry :: struct {
    is_done: bool,
    start: f64,
    text: string,
}

// variables
@(private) cyan := rl.ColorFromHSV(182, 0.73, 1.0)
@(private) default_palette := [16]rl.Color{
    rl.BLACK,
    rl.ColorBrightness(rl.BLUE, -0.5),
    rl.ColorBrightness(rl.GREEN, -0.5),
    rl.ColorBrightness(cyan, -0.5),
    rl.ColorFromHSV(28, 0.77, 0.65),
    rl.ColorBrightness(rl.MAGENTA, -0.5),
    rl.ColorBrightness(rl.YELLOW, -0.5),
    rl.LIGHTGRAY,
    rl.GRAY,
    rl.BLUE,
    rl.GREEN,
    cyan,
    rl.RED,
    rl.MAGENTA,
    rl.YELLOW,
    rl.WHITE,
}
@(private) segment_lookup := map[rune][7]u8{
	'0' = [7]u8{ 1, 1, 1, 1, 1, 1, 0 },
	'1' = [7]u8{ 0, 1, 1, 0, 0, 0, 0 },
	'2' = [7]u8{ 1, 1, 0, 1, 1, 0, 1 },
	'3' = [7]u8{ 1, 1, 1, 1, 0, 0, 1 },
	'4' = [7]u8{ 0, 1, 1, 0, 0, 1, 1 },
	'5' = [7]u8{ 1, 0, 1, 1, 0, 1, 1 },
	'6' = [7]u8{ 1, 0, 1, 1, 1, 1, 1 },
	'7' = [7]u8{ 1, 1, 1, 0, 0, 0, 0 },
	'8' = [7]u8{ 1, 1, 1, 1, 1, 1, 1 },
	'9' = [7]u8{ 1, 1, 1, 1, 0, 1, 1 },
}
@(private) state: Qv_State
@(private) pen_state: Pen_State

// procedures
begin :: proc() {
    state.typing_has_started_on_frame = false
    rl.BeginDrawing()
}

circle :: proc(center_x, center_y: f32, radius: f32, color: rl.Color) {
    rl.DrawCircle(i32(center_x), i32(center_y), radius, color)
}

circle_outline :: proc(center_x, center_y: f32, radius: f32, color: rl.Color) {
    rl.DrawCircleLines(i32(center_x), i32(center_y), radius, color)
}

clear_screen :: proc(color: rl.Color) {
    rl.ClearBackground(color)
}

close :: proc() {
    delete(state.typing_entries)
    delete(state.completed_timers)
    rl.CloseWindow()
}

concat :: proc(args: ..string) -> string {
    return strings.concatenate(args, context.temp_allocator)
}

create_window :: proc(title: string, screen_mode: Screen_Mode) {
    if (screen_mode == .Ten_Eighty_P) {
        state.screen_width  = 1920
        state.screen_height = 1080
    } else if (screen_mode == .Seven_Twenty_P) {
        state.screen_width  = 1280
        state.screen_height = 720
    }
    rl.InitWindow(i32(state.screen_width), i32(state.screen_height), strings.clone_to_cstring(title, context.temp_allocator))
    rl.SetTargetFPS(60)
    state.drawing_cps = 1000
    state.frame_dur = 60 / 1000
}

draw :: proc(src: string) {
    text_started := src in state.typing_entries
    if (state.is_typing && state.typing_text != src) {
        text_already_finished := state.typing_entries[src].is_done
        if !text_already_finished {
            return
        }
    }

    cmds, idx, err := parse_draw_commands(src, context.temp_allocator)
    if err != .None {
        fmt.eprintf("Invalid draw command (%v): %s. Failed at %i", err, src, idx)
        return
    }

    if !text_started {
        state.is_typing = true
        state.typing_text = src
        state.typing_entries[src] = Typing_Entry{
            start=rl.GetTime(),
            text=src,
        }
    }
    entry := state.typing_entries[src]
    if entry.is_done {
        draw_commands(cmds[:])
        return
    }

    elapsed_secs := rl.GetTime()-entry.start
    typed_cmds   := int(f32(state.drawing_cps) * f32(elapsed_secs))
    if (typed_cmds >= len(cmds)) {
        typed_cmds = len(cmds)
        entry.is_done = true
        state.typing_entries[src] = entry
        state.is_typing = false
        state.typing_text = ""
    }
    state.typing_has_started_on_frame = true

    draw_commands(cmds[:typed_cmds])
}

@(private)
draw_commands :: proc(cmds: []Draw_Command) {
    for cmd in cmds {
        switch cmd.type {
        case .One_Dimension:
            begin_pos := pen_state.pos
            dest_pos  := begin_pos
            switch cmd.direction {
            case .Up:        dest_pos.y=dest_pos.y-(f32(cmd.param_1)*pen_state.scale)
            case .UpRight:   dest_pos.y=dest_pos.y-(f32(cmd.param_1)*pen_state.scale); dest_pos.x=dest_pos.x+(f32(cmd.param_1)*pen_state.scale)
            case .Right:     dest_pos.x=dest_pos.x+(f32(cmd.param_1)*pen_state.scale)
            case .DownRight: dest_pos.x=dest_pos.x+(f32(cmd.param_1)*pen_state.scale); dest_pos.y=dest_pos.y+(f32(cmd.param_1)*pen_state.scale)
            case .Down:      dest_pos.y=dest_pos.y+(f32(cmd.param_1)*pen_state.scale)
            case .DownLeft:  dest_pos.y=dest_pos.y+(f32(cmd.param_1)*pen_state.scale); dest_pos.x=dest_pos.x-(f32(cmd.param_1)*pen_state.scale)
            case .Left:      dest_pos.x=dest_pos.x-(f32(cmd.param_1)*pen_state.scale)
            case .UpLeft:    dest_pos.x=dest_pos.x-(f32(cmd.param_1)*pen_state.scale); dest_pos.y=dest_pos.y-(f32(cmd.param_1)*pen_state.scale)
            case .Unknown:   // Do Nothing
            }
            if !cmd.pen_up {
                col := get_color_from_int(pen_state.col)
                line_impl(begin_pos, dest_pos, pen_state.scale, col)
            }
            if !cmd.return_to_pos {
                pen_state.pos = dest_pos
            }
        case .Two_Dimensions:
            begin_pos := rl.Vector2{}
            dest_pos  := rl.Vector2{f32(cmd.param_1), f32(cmd.param_2)}
            if !cmd.pen_up {
                col := get_color_from_int(pen_state.col)
                line_impl(begin_pos, dest_pos, pen_state.scale, col)
            }
            if !cmd.return_to_pos {
                pen_state.pos = dest_pos
            }
        case .Color:
            pen_state.col = cmd.param_1
        case .Scale:
            // Similar to QBasic 1.1, a scale of 4 means 1 pixel
            pen_state.scale = f32(cmd.param_1) / 4
        case .Unknown:
            // Do nothing
        }
    }
}

get_screen_width :: proc() -> int {
    return state.screen_width
}

get_screen_height :: proc() -> int {
    return state.screen_height
}

get_text_char_width :: proc() -> int {
    return state.text_char_width
}

get_text_columns :: proc() -> int {
    return state.text_cols
}

get_text_line_height :: proc() -> int {
    return state.text_line_height
}

get_text_rows :: proc() -> int {
    return state.text_rows
}

line :: proc(start_x, start_y, end_x, end_y: f32, color: rl.Color) {
    if should_return() {
        return
    }

    sizeable_line(start_x, start_y, end_x, end_y, color, 1)
}

present :: proc() {
    rl.EndDrawing()
}

print :: proc(text: string, pos: Text_Point, color: rl.Color) {
    if should_return() {
        return
    }

    rl.DrawTextEx(state.text_font,
        strings.clone_to_cstring(text, context.temp_allocator),
        get_vector_from_text_point(pos),
        f32(state.text_font.baseSize),
        f32(state.text_char_spacing),
        color
    )
}

print_centered :: proc(text: string, row: int, color: rl.Color) {
	print(text, Text_Point{(get_text_columns()-len(text)) / 2, row}, color)
}

ready_to_continue :: proc(wait_for_keypress: bool) -> bool {
    if !wait_for_keypress || rl.WindowShouldClose() {
        return true
    }
    if state.is_typing {
        return false
    }

    should_continue := rl.GetKeyPressed() != .KEY_NULL;
    for rl.GetKeyPressed() != .KEY_NULL {} // Clear remaining key presses for a fresh start
    return should_continue
}

rectangle :: proc(top_left_x, top_left_y, bottom_right_x, bottom_right_y: f32, color: rl.Color) {
    rl.DrawRectangle(
        i32(top_left_x), i32(top_left_y),
        i32(bottom_right_x - top_left_x), i32(bottom_right_y - top_left_y),
        color
    )
}

reset_frame_memory :: proc() {
    clear(&state.completed_timers)
    clear(&state.typing_entries)
}

set_drawing_speed :: proc(commands_per_sec: int) {
    state.drawing_cps = commands_per_sec
}

set_text_style :: proc(size: int, char_spacing: int, line_spacing: int) {
    // MEM: Cache previously loaded fonts so continued use doesn't result in resource exhaustion
    src_dir := filepath.dir(#file, context.temp_allocator)
    font_path := filepath.join([]string{src_dir, "resources", "DroidSansMono.ttf"}, context.temp_allocator)
    state.text_font = rl.LoadFontEx(strings.clone_to_cstring(font_path, context.temp_allocator), i32(size), nil, 0)

    char_count, line_count: int
    cur_x, cur_y: int
    measured_string := rl.MeasureTextEx(state.text_font, "T", f32(size), 0)
    state.text_char_width   = int(measured_string.x)+char_spacing
    state.text_line_height  = int(measured_string.y)+line_spacing
    state.text_char_spacing = char_spacing
    state.text_line_spacing = line_spacing
    for cur_x < state.screen_width {
        char_count = char_count+1
        cur_x = cur_x+state.text_char_width
    }
    for cur_y < state.screen_height {
        line_count = line_count+1
        cur_y = cur_y+state.text_line_height
    }
    state.text_rows = line_count
    state.text_cols = char_count
}

set_typing_speed :: proc(chars_per_sec: int) {
    state.typing_cps = chars_per_sec
}

seven_segment_display :: proc(val: i64, digits: i8, center: rl.Vector2, digit_height: f32, segment_size: f32, color: rl.Color) {
	digit_width    := digit_height / 2
	display_width  := digit_width*f32(digits) + segment_size*f32(digits)
	display_height := digit_height
	seg_width: f32  = (digit_width-(segment_size*2))
	seg_height: f32 = (digit_height-segment_size*3)/2

	// Generate a string of length `digits`, padded left with 0s, of the value `val`
	num_buf := make_slice([]u8, digits*2, context.temp_allocator)
	for i in 0..<len(num_buf) {
		num_buf[i] = '0'
	}
	if val > 0 {
		num_raw := fmt.tprintf("%i", val)
		for i := 0; i < math.min(int(digits), len(num_raw)); i=i+1 {
			num_buf[len(num_buf)-1-i] = num_raw[len(num_raw)-1-i]
		}
	}
	num := string(num_buf[digits:digits*2])

	seg_x: f32 = center.x-(display_width /2)
	seg_y: f32 = center.y-(display_height/2)
	for r in num {
		segments := segment_lookup[r]
		for seg_pat, seg in segments {
			if seg_pat <= 0 {
				continue
			}
			switch seg {
			case 0: rl.DrawRectangleV(rl.Vector2{ seg_x+segment_size,           seg_y },                             rl.Vector2{ seg_width, segment_size },   color)
			case 1: rl.DrawRectangleV(rl.Vector2{ seg_x+seg_width+segment_size, seg_y+segment_size },                rl.Vector2{ segment_size,  seg_height }, color)
			case 2: rl.DrawRectangleV(rl.Vector2{ seg_x+seg_width+segment_size, seg_y+segment_size*2+seg_height },   rl.Vector2{ segment_size,  seg_height }, color)
			case 3: rl.DrawRectangleV(rl.Vector2{ seg_x+segment_size,           seg_y+segment_size*2+seg_height*2 }, rl.Vector2{ seg_width, segment_size },   color)
			case 4: rl.DrawRectangleV(rl.Vector2{ seg_x,                        seg_y+seg_height+segment_size*2 },   rl.Vector2{ segment_size,  seg_height }, color)
			case 5: rl.DrawRectangleV(rl.Vector2{ seg_x,                        seg_y+segment_size },                rl.Vector2{ segment_size,  seg_height }, color)
			case 6: rl.DrawRectangleV(rl.Vector2{ seg_x+segment_size,           seg_y+segment_size+seg_height },     rl.Vector2{ seg_width, segment_size },   color)
			}
		}
		seg_x = seg_x+digit_width+segment_size
	}
}

sizeable_line :: proc(start_x, start_y, end_x, end_y: f32, color: rl.Color, thickness: f32) {
    line_impl(rl.Vector2{start_x, start_y}, rl.Vector2{end_x, end_y}, thickness, color)
}

type :: proc(text: string, pos: Text_Point, color: rl.Color) {
    text_started := text in state.typing_entries
    if (state.is_typing && state.typing_text != text) {
        text_already_finished := state.typing_entries[text].is_done
        if !text_already_finished {
            return
        }
    }

    if !text_started {
        state.is_typing = true
        state.typing_text = text
        state.typing_entries[text] = Typing_Entry{
            start=rl.GetTime(),
            text=text,
        }
    }
    entry := state.typing_entries[text]
    if entry.is_done {
        print(text, pos, color)
        return
    }

    elapsed_secs := rl.GetTime() - entry.start
    typed_chars  := int(f32(state.typing_cps) * f32(elapsed_secs))
    if (typed_chars >= len(text)) {
        typed_chars = len(text)
        entry.is_done = true
        state.typing_entries[text] = entry
        state.is_typing = false
        state.typing_text = ""
    }
    state.typing_has_started_on_frame = true
    rl.DrawTextEx(state.text_font,
        strings.clone_to_cstring(text[:typed_chars], context.temp_allocator),
        get_vector_from_text_point(pos),
        f32(state.text_font.baseSize),
        f32(state.text_char_spacing),
        color,
    )
}

wait :: proc(ms: int, loc := #caller_location) {
    if should_return() {
        return
    }
    key := strings.concatenate({loc.file_path, loc.procedure, fmt.tprintf("%i", loc.column), fmt.tprintf("%i", loc.line)}, context.temp_allocator)
    if key in state.completed_timers {
        return
    }

    rl.EndDrawing()
    rl.WaitTime(f64(ms / 1000))
    state.completed_timers[key] = true
    rl.BeginDrawing()
}

@(private)
get_color_from_int :: proc(palette_entry: int) -> rl.Color {
    if palette_entry <= 0 {
        return rl.BLACK
    }
    if palette_entry >= 15 {
        return rl.WHITE
    }
    return default_palette[palette_entry]
}

@(private)
get_vector_from_text_point :: proc(pos: Text_Point) -> rl.Vector2 {
    x := (pos.col-1)*state.text_char_width
    y := (pos.row-1)*state.text_line_height
    return rl.Vector2{f32(x+state.text_char_spacing), f32(y)}
}

@(private)
line_impl :: proc(start: rl.Vector2, end: rl.Vector2, thickness: f32, color: rl.Color) {
    rl.DrawLineEx(start, end, thickness, color)
}

@(private)
should_return :: proc() -> bool {
    typing_in_progress := state.typing_has_started_on_frame && state.is_typing
    return rl.WindowShouldClose() || typing_in_progress
}