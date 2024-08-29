package qv

import "core:testing"

@(test)
test_parsing_multiple_commands :: proc(t: ^testing.T) {
    using testing

    src := " br10nu30r5 f30 "
    cmds, idx, err := parse_draw_commands(src, context.temp_allocator)

    expect_value(t, idx, len(src))
    expect_value(t, len(cmds), 4)
    expect_value(t, err, Draw_Error.None)
    if t.error_count == 0 {
        expect_value(t, cmds[0], Draw_Command{
            type=.One_Dimension,
            direction=.Right,
            param_1=10,
            pen_up=true,
        })
        expect_value(t, cmds[1], Draw_Command{
            type=.One_Dimension,
            direction=.Up,
            param_1=30,
            return_to_pos=true,
        })
        expect_value(t, cmds[2], Draw_Command{
            type=.One_Dimension,
            direction=.Right,
            param_1=5,
        })
        expect_value(t, cmds[3], Draw_Command{
            type=.One_Dimension,
            direction=.DownRight,
            param_1=30,
        })
    }

    src = "r10u30r5f30 u30r20d20l20f10r15 r20u15l20u15r20br5 nr20d15nr20d15r25 u30r5f30r5u30br5 nd30r5f30br5 nu30r20"
    cmds, idx, err = parse_draw_commands(src, context.temp_allocator)

    expect_value(t, idx, len(src))
    expect_value(t, len(cmds), 33)
}

@(test)
test_command_length_error :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("r", &idx)
    expect_value(t, err, Draw_Error.Command_Too_Short)
}

@(test)
test_unexpected_number_error :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("123r45", &idx)
    expect_value(t, idx, 0)
    expect_value(t, err, Draw_Error.Unexpected_Number)
}

@(test)
test_unrecognized_command_error :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("x203", &idx)
    expect_value(t, idx, 0)
    expect_value(t, err, Draw_Error.Unrecognized_Command)
}

@(test)
test_expected_number_error :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("ru203", &idx)
    expect_value(t, idx, 1)
    expect_value(t, err, Draw_Error.Expected_Number)
}

@(test)
test_number_too_big_error :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("r1000000", &idx)
    expect_value(t, idx, 8)
    expect_value(t, err, Draw_Error.Number_Too_Big)

    idx = 0
    cmd, err = parse_command("r999999", &idx)
    expect_value(t, idx, 7)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.Right,
        param_1=999999,
    })
}

@(test)
test_whitespace_parsing :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("r 20", &idx)
    expect_value(t, idx, 4)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.Right,
        param_1=20,
    })

    idx = 0
    cmd, err = parse_command("m 1080 ,  720", &idx)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, idx, 13)
    expect_value(t, cmd, Draw_Command{
        type=.Two_Dimensions,
        param_1=1080,
        param_2=720,
    })
}

@(test)
test_command_modifier_parsing :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("nr20", &idx)
    expect_value(t, idx, 4)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.Right,
        param_1=20,
        return_to_pos=true,
    })

    idx = 0
    cmd, err = parse_command("br20", &idx)
    expect_value(t, idx, 4)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.Right,
        param_1=20,
        pen_up=true,
    })

    idx = 0
    cmd, err = parse_command("nbr20", &idx)
    expect_value(t, idx, 5)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.Right,
        param_1=20,
        return_to_pos=true,
        pen_up=true,
    })
}

@(test)
test_directional_commands_parsing :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("r20", &idx)
    expect_value(t, idx, 3)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.Right,
        param_1=20,
    })

    idx = 0
    cmd, err = parse_command("l20", &idx)
    expect_value(t, idx, 3)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.Left,
        param_1=20,
    })

    idx = 0
    cmd, err = parse_command("u20", &idx)
    expect_value(t, idx, 3)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.Up,
        param_1=20,
    })

    idx = 0
    cmd, err = parse_command("d20", &idx)
    expect_value(t, idx, 3)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.Down,
        param_1=20,
    })

    idx = 0
    cmd, err = parse_command("e20", &idx)
    expect_value(t, idx, 3)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.UpRight,
        param_1=20,
    })

    idx = 0
    cmd, err = parse_command("f20", &idx)
    expect_value(t, idx, 3)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.DownRight,
        param_1=20,
    })

    idx = 0
    cmd, err = parse_command("g20", &idx)
    expect_value(t, idx, 3)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.DownLeft,
        param_1=20,
    })

    idx = 0
    cmd, err = parse_command("h20", &idx)
    expect_value(t, idx, 3)
    expect_value(t, cmd, Draw_Command{
        type=.One_Dimension,
        direction=.UpLeft,
        param_1=20,
    })
}

@(test)
test_movement_command_parsing :: proc(t: ^testing.T) {
    using testing

    idx := 0
    cmd, err := parse_command("m1080,720", &idx)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, idx, 9)
    expect_value(t, cmd, Draw_Command{
        type=.Two_Dimensions,
        param_1=1080,
        param_2=720,
    })
}

@(test)
test_invalid_movement_command_parsing :: proc(t: ^testing.T) {
    using testing

    idx := 0
    cmd, err := parse_command("m12r34", &idx)
    expect_value(t, err, Draw_Error.Expected_Comma)
    expect_value(t, idx, 3)

    idx = 0
    cmd, err = parse_command("m12,", &idx)
    expect_value(t, err, Draw_Error.Unexpected_End_Of_Command)
    expect_value(t, idx, 4)
}

@(test)
test_scale_command_parsing :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("s16", &idx)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, idx, 3)
    expect_value(t, cmd, Draw_Command{
        type=.Scale,
        param_1=16,
    })

    idx = 0
    cmd, err = parse_command("s  16", &idx)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, idx, 5)
    expect_value(t, cmd, Draw_Command{
        type=.Scale,
        param_1=16,
    })
}

@(test)
test_color_command_parsing :: proc(t: ^testing.T) {
    using testing

    idx: int
    cmd, err := parse_command("c8", &idx)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, idx, 2)
    expect_value(t, cmd, Draw_Command{
        type=.Color,
        param_1=8,
    })

    idx = 0
    cmd, err = parse_command("c 12", &idx)
    expect_value(t, err, Draw_Error.None)
    expect_value(t, idx, 4)
    expect_value(t, cmd, Draw_Command{
        type=.Color,
        param_1=12,
    })
}
