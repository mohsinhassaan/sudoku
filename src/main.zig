const std = @import("std");
const sudoku = @import("root.zig");

pub const std_options = .{ .log_level = .info };

pub fn main() !void {
    var board = sudoku.Board{
        [9]u8{ 0, 0, 1, 0, 0, 4, 0, 0, 0 },
        [9]u8{ 0, 0, 5, 0, 0, 0, 0, 1, 6 },
        [9]u8{ 2, 0, 0, 0, 3, 0, 7, 0, 5 },
        [9]u8{ 0, 0, 0, 0, 1, 7, 3, 0, 0 },
        [9]u8{ 0, 3, 0, 0, 0, 0, 9, 8, 0 },
        [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        [9]u8{ 6, 0, 7, 1, 0, 0, 0, 5, 0 },
        [9]u8{ 0, 0, 0, 0, 7, 0, 0, 0, 0 },
        [9]u8{ 0, 2, 0, 8, 0, 0, 6, 0, 0 },
    };

    // var board = Board{
    //     [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    //     [9]u8{ 0, 0, 0, 1, 5, 8, 0, 0, 0 },
    //     [9]u8{ 0, 0, 0, 9, 0, 3, 0, 6, 1 },
    //     [9]u8{ 0, 0, 0, 3, 8, 1, 5, 9, 0 },
    //     [9]u8{ 2, 0, 0, 0, 0, 0, 3, 0, 0 },
    //     [9]u8{ 0, 0, 9, 0, 0, 0, 7, 0, 6 },
    //     [9]u8{ 0, 0, 7, 0, 0, 0, 0, 4, 0 },
    //     [9]u8{ 0, 3, 5, 0, 4, 0, 6, 0, 0 },
    //     [9]u8{ 0, 0, 0, 2, 0, 9, 0, 0, 0 },
    // };

    try sudoku.print_board(&board);

    var timer = try std.time.Timer.start();

    _ = try sudoku.solve(&board);

    std.log.info("Solved in {}ms", .{timer.read() / 1_000_000});

    try sudoku.print_board(&board);
}
