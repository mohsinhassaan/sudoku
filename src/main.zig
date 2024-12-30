const std = @import("std");

const Board = [9][9]u8;
const SudokuError = error{UnsolvableBoard};

pub const std_options = .{ .log_level = .info };

pub fn main() !void {
    var board = Board{
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

    try print_board(&board);

    var timer = try std.time.Timer.start();

    _ = try solve(&board);

    std.log.info("Solved in {}ms", .{timer.read() / 1_000_000});

    try print_board(&board);
}

fn print_board(board: *const Board) !void {
    const out = std.io.getStdOut();
    var buf = std.io.bufferedWriter(out.writer());

    var w = buf.writer();

    for (board) |row| {
        _ = try w.write("|");
        for (row) |cell| {
            if (cell == 0) {
                _ = try w.write("   |");
            } else {
                _ = try w.writeByte(' ');
                _ = try w.writeByte('0' + cell);
                _ = try w.write(" |");
            }
        }
        _ = try w.write("\n");
    }

    try buf.flush();
}

pub fn solve(board: *Board) SudokuError!*Board {
    return solveCell(board, 0, 0);
}

fn solveCell(board: *Board, x: usize, y: usize) SudokuError!*Board {
    if (y > 8) {
        return board;
    }

    const next_x, const next_y = if (x < 8) .{ x + 1, y } else .{ 0, y + 1 };
    if (board[y][x] != 0) {
        return solveCell(board, next_x, next_y);
    }

    for (1..10) |val| {
        board[y][x] = @intCast(val);
        if (boardValid(board, x, y)) {
            if (solveCell(board, next_x, next_y)) |sol| {
                return sol;
            } else |_| {}
        }
    }
    board[y][x] = 0;

    return SudokuError.UnsolvableBoard;
}

fn boardValid(board: *const Board, x: usize, y: usize) bool {
    return rowValid(board, x, y) and
        colValid(board, x, y) and
        squareValid(board, x, y);
}

fn rowValid(board: *const Board, _: usize, y: usize) bool {
    for (board[y], 0..) |cell0, i| {
        if (cell0 == 0) {
            continue;
        }
        for (board[y][i + 1 ..]) |cell| {
            if (cell == cell0) {
                return false;
            }
        }
    }

    return true;
}

fn colValid(board: *const Board, x: usize, _: usize) bool {
    for (board, 0..) |row0, i| {
        if (row0[x] == 0) {
            continue;
        }
        for (board[i + 1 ..]) |row| {
            if (row[x] == row0[x]) {
                return false;
            }
        }
    }

    return true;
}

fn squareValid(board: *const Board, x: usize, y: usize) bool {
    const start_x = x - x % 3;
    const start_y = y - y % 3;

    for (start_y..start_y + 3) |y0| {
        for (start_x..start_x + 3) |x0| {
            const cell0 = board[y0][x0];

            if (cell0 == 0) {
                continue;
            }

            for (x0 + 1..start_x + 3) |x1| {
                if (board[y0][x1] == cell0) {
                    return false;
                }
            }

            for (y0 + 1..start_y + 3) |y1| {
                for (start_x..start_x + 3) |x1| {
                    if (board[y1][x1] == cell0) {
                        return false;
                    }
                }
            }
        }
    }

    return true;
}

test "solve test" {
    var board = Board{
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

    const expected_board = Board{
        [_]u8{ 9, 6, 1, 7, 5, 4, 2, 3, 8 },
        [_]u8{ 3, 7, 5, 2, 8, 9, 4, 1, 6 },
        [_]u8{ 2, 8, 4, 6, 3, 1, 7, 9, 5 },
        [_]u8{ 8, 5, 2, 9, 1, 7, 3, 6, 4 },
        [_]u8{ 7, 3, 6, 5, 4, 2, 9, 8, 1 },
        [_]u8{ 4, 1, 9, 3, 6, 8, 5, 7, 2 },
        [_]u8{ 6, 4, 7, 1, 2, 3, 8, 5, 9 },
        [_]u8{ 5, 9, 8, 4, 7, 6, 1, 2, 3 },
        [_]u8{ 1, 2, 3, 8, 9, 5, 6, 4, 7 },
    };

    _ = try solve(&board);

    try std.testing.expectEqualDeep(expected_board, board);
}

test "board valid test" {
    const board = Board{
        //        v 2      v 3
        [9]u8{ 0, 0, 1, 0, 0, 4, 0, 0, 0 },
        [9]u8{ 0, 2, 5, 0, 3, 0, 0, 1, 6 },
        [9]u8{ 2, 0, 0, 0, 3, 0, 7, 0, 5 },
        [9]u8{ 0, 0, 0, 0, 1, 7, 3, 0, 0 },
        [9]u8{ 0, 3, 0, 0, 0, 0, 9, 8, 0 },
        [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        [9]u8{ 6, 0, 7, 1, 0, 5, 0, 5, 0 }, // <-- 5
        [9]u8{ 0, 0, 0, 0, 7, 0, 0, 0, 0 },
        [9]u8{ 0, 2, 0, 8, 0, 0, 6, 0, 0 },
    };

    try std.testing.expect(!boardValid(&board, 0, 0));
    try std.testing.expect(!boardValid(&board, 4, 0));
    try std.testing.expect(!boardValid(&board, 5, 6));
}

test "row test" {
    const board = Board{
        [9]u8{ 0, 0, 1, 0, 1, 4, 0, 0, 0 }, // <-- 1
        [9]u8{ 0, 0, 5, 0, 0, 0, 0, 1, 6 },
        [9]u8{ 2, 0, 0, 0, 3, 0, 7, 0, 5 },
        [9]u8{ 0, 0, 0, 0, 1, 7, 3, 0, 0 },
        [9]u8{ 0, 3, 0, 0, 0, 0, 9, 8, 0 },
        [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        [9]u8{ 6, 0, 7, 1, 0, 5, 0, 5, 0 }, // <-- 5
        [9]u8{ 0, 0, 0, 0, 7, 0, 0, 0, 0 },
        [9]u8{ 0, 2, 0, 8, 0, 0, 6, 0, 0 },
    };

    try std.testing.expect(rowValid(&board, 4, 1));
    try std.testing.expect(rowValid(&board, 2, 2));
    try std.testing.expect(rowValid(&board, 1, 3));
    try std.testing.expect(rowValid(&board, 0, 4));
    try std.testing.expect(rowValid(&board, 8, 5));
    try std.testing.expect(rowValid(&board, 9, 7));
    try std.testing.expect(rowValid(&board, 7, 8));

    try std.testing.expect(!rowValid(&board, 0, 0));
    try std.testing.expect(!rowValid(&board, 1, 0));
    try std.testing.expect(!rowValid(&board, 2, 0));
    try std.testing.expect(!rowValid(&board, 3, 0));
    try std.testing.expect(!rowValid(&board, 4, 0));
    try std.testing.expect(!rowValid(&board, 5, 0));
    try std.testing.expect(!rowValid(&board, 6, 0));
    try std.testing.expect(!rowValid(&board, 7, 0));
    try std.testing.expect(!rowValid(&board, 8, 0));

    try std.testing.expect(!rowValid(&board, 0, 6));
    try std.testing.expect(!rowValid(&board, 1, 6));
    try std.testing.expect(!rowValid(&board, 2, 6));
    try std.testing.expect(!rowValid(&board, 3, 6));
    try std.testing.expect(!rowValid(&board, 4, 6));
    try std.testing.expect(!rowValid(&board, 5, 6));
    try std.testing.expect(!rowValid(&board, 6, 6));
    try std.testing.expect(!rowValid(&board, 7, 6));
    try std.testing.expect(!rowValid(&board, 8, 6));
}

test "col test" {
    const board = Board{
        [9]u8{ 0, 0, 1, 0, 0, 4, 0, 0, 0 },
        [9]u8{ 0, 2, 5, 0, 0, 0, 0, 1, 6 },
        [9]u8{ 2, 0, 0, 0, 3, 0, 7, 0, 5 },
        [9]u8{ 0, 0, 0, 0, 1, 7, 3, 0, 0 },
        [9]u8{ 0, 3, 0, 0, 0, 0, 9, 8, 0 },
        [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        [9]u8{ 6, 0, 7, 1, 0, 0, 9, 5, 0 },
        [9]u8{ 0, 0, 0, 0, 7, 0, 0, 0, 0 },
        [9]u8{ 0, 2, 0, 8, 0, 0, 6, 0, 0 },
        //        ^ 2            ^ 9
    };

    try std.testing.expect(colValid(&board, 0, 1));
    try std.testing.expect(colValid(&board, 2, 2));
    try std.testing.expect(colValid(&board, 3, 1));
    try std.testing.expect(colValid(&board, 4, 0));
    try std.testing.expect(colValid(&board, 5, 8));
    try std.testing.expect(colValid(&board, 7, 9));
    try std.testing.expect(colValid(&board, 8, 7));

    try std.testing.expect(!colValid(&board, 6, 0));
    try std.testing.expect(!colValid(&board, 6, 1));
    try std.testing.expect(!colValid(&board, 6, 2));
    try std.testing.expect(!colValid(&board, 6, 3));
    try std.testing.expect(!colValid(&board, 6, 4));
    try std.testing.expect(!colValid(&board, 6, 5));
    try std.testing.expect(!colValid(&board, 6, 6));
    try std.testing.expect(!colValid(&board, 6, 7));
    try std.testing.expect(!colValid(&board, 6, 8));

    try std.testing.expect(!colValid(&board, 1, 0));
    try std.testing.expect(!colValid(&board, 1, 1));
    try std.testing.expect(!colValid(&board, 1, 2));
    try std.testing.expect(!colValid(&board, 1, 3));
    try std.testing.expect(!colValid(&board, 1, 4));
    try std.testing.expect(!colValid(&board, 1, 5));
    try std.testing.expect(!colValid(&board, 1, 6));
    try std.testing.expect(!colValid(&board, 1, 7));
    try std.testing.expect(!colValid(&board, 1, 8));
}

test "square test" {
    const board = Board{
        //        v 5
        [9]u8{ 0, 0, 1, 0, 0, 4, 0, 0, 0 },
        [9]u8{ 0, 5, 5, 0, 0, 0, 0, 1, 6 },
        [9]u8{ 2, 0, 0, 0, 3, 0, 7, 0, 5 },
        [9]u8{ 0, 0, 0, 0, 1, 7, 3, 0, 0 },
        [9]u8{ 0, 3, 0, 0, 0, 0, 9, 8, 0 }, // <-- 3
        [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 3 },
        [9]u8{ 6, 0, 7, 1, 0, 0, 0, 5, 0 },
        [9]u8{ 0, 0, 0, 0, 7, 0, 0, 0, 0 },
        [9]u8{ 0, 2, 0, 8, 0, 0, 6, 0, 0 },
    };

    try std.testing.expect(squareValid(&board, 0, 3));
    try std.testing.expect(squareValid(&board, 8, 8));
    try std.testing.expect(squareValid(&board, 5, 2));
    try std.testing.expect(squareValid(&board, 7, 7));

    try std.testing.expect(!squareValid(&board, 0, 0));
    try std.testing.expect(!squareValid(&board, 0, 1));
    try std.testing.expect(!squareValid(&board, 0, 2));
    try std.testing.expect(!squareValid(&board, 1, 0));
    try std.testing.expect(!squareValid(&board, 1, 1));
    try std.testing.expect(!squareValid(&board, 1, 2));
    try std.testing.expect(!squareValid(&board, 2, 0));
    try std.testing.expect(!squareValid(&board, 2, 1));
    try std.testing.expect(!squareValid(&board, 2, 2));

    try std.testing.expect(!squareValid(&board, 6, 3));
    try std.testing.expect(!squareValid(&board, 6, 4));
    try std.testing.expect(!squareValid(&board, 6, 5));
    try std.testing.expect(!squareValid(&board, 7, 3));
    try std.testing.expect(!squareValid(&board, 7, 4));
    try std.testing.expect(!squareValid(&board, 7, 5));
    try std.testing.expect(!squareValid(&board, 8, 3));
    try std.testing.expect(!squareValid(&board, 8, 4));
    try std.testing.expect(!squareValid(&board, 8, 5));
}
