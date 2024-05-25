const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

pub const SudokuError = error{ UnsolvableBoard, InvalidBoardSize };
pub fn Board(comptime N: comptime_int) type {
    const SQRT_N: comptime_int = comptime @intCast(std.math.sqrt(N));

    if (N != SQRT_N * SQRT_N) {
        return SudokuError.InvalidBoardSize;
    }

    return struct {
        cells: [N][N]u8,

        var lastPrintTime: i64 = 0;
        const CLEAR = "\x1b[2J\x1b[H";
        const CHARSET = switch (N) {
            4 => [_]u8{ '1', '2', '3', '4' },
            9 => [_]u8{ '1', '2', '3', '4', '5', '6', '7', '8', '9' },
            16 => [_]u8{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' },
            25 => [_]u8{ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y' },
            else => unreachable,
        };
        const out = std.io.getStdOut();
        var buf = std.io.bufferedWriter(out.writer());
        var w = buf.writer();
        pub fn print(self: *const Board(N)) void {
            if (builtin.is_test) {
                return;
            }

            const now = std.time.milliTimestamp();
            if (now - lastPrintTime < 100) {
                return;
            }
            lastPrintTime = now;

            _ = w.write(CLEAR) catch unreachable;

            self.forcePrint();
        }

        pub fn forcePrint(self: *const Board(N)) void {
            for (self.cells) |row| {
                _ = w.write("|") catch unreachable;
                for (row) |cell| {
                    if (cell == 0) {
                        _ = w.write("   |") catch unreachable;
                    } else {
                        _ = w.writeByte(' ') catch unreachable;
                        _ = w.writeByte(CHARSET[cell - 1]) catch unreachable;
                        _ = w.write(" |") catch unreachable;
                    }
                }
                _ = w.writeByte('\n') catch unreachable;
            }

            _ = w.writeByte('\n') catch unreachable;

            buf.flush() catch unreachable;
        }

        pub fn solve(self: *Board(N)) SudokuError!*Board(N) {
            return self.solveCell(0, 0);
        }

        fn solveCell(self: *Board(N), x: usize, y: usize) SudokuError!*Board(N) {
            if (y > N - 1) {
                return self;
            }
            self.print();

            const next_x, const next_y = if (x < N - 1)
                .{ x + 1, y }
            else
                .{ 0, y + 1 };

            if (self.cells[y][x] != 0) {
                return self.solveCell(next_x, next_y);
            }

            for (1..N + 1) |val| {
                self.cells[y][x] = @intCast(val);
                if (self.boardValid(x, y)) {
                    if (self.solveCell(next_x, next_y)) |sol| {
                        return sol;
                    } else |_| {}
                }
            }
            self.cells[y][x] = 0;

            return SudokuError.UnsolvableBoard;
        }

        fn boardValid(self: *const Board(N), x: usize, y: usize) bool {
            return self.rowValid(x, y) and
                self.colValid(x, y) and
                self.squareValid(x, y);
        }

        fn rowValid(self: *const Board(N), _: usize, y: usize) bool {
            for (self.cells[y], 0..N) |cell0, i| {
                if (cell0 == 0) {
                    continue;
                }
                for (self.cells[y][i + 1 ..]) |cell| {
                    if (cell == cell0) {
                        return false;
                    }
                }
            }

            return true;
        }

        fn colValid(self: *const Board(N), x: usize, _: usize) bool {
            for (self.cells, 0..N) |row0, i| {
                if (row0[x] == 0) {
                    continue;
                }
                for (self.cells[i + 1 .. N]) |row| {
                    if (row[x] == row0[x]) {
                        return false;
                    }
                }
            }

            return true;
        }

        fn squareValid(self: *const Board(N), x: usize, y: usize) bool {
            const start_x = x - x % SQRT_N;
            const start_y = y - y % SQRT_N;

            for (start_y..start_y + SQRT_N) |y0| {
                for (start_x..start_x + SQRT_N) |x0| {
                    const cell0 = self.cells[y0][x0];

                    if (cell0 == 0) {
                        continue;
                    }

                    for (x0 + 1..start_x + SQRT_N) |x1| {
                        if (self.cells[y0][x1] == cell0) {
                            return false;
                        }
                    }

                    for (y0 + 1..start_y + SQRT_N) |y1| {
                        for (start_x..start_x + SQRT_N) |x1| {
                            if (self.cells[y1][x1] == cell0) {
                                return false;
                            }
                        }
                    }
                }
            }

            return true;
        }
    };
}

test "4x4 solve test" {
    var board = Board(4){
        .cells = [4][4]u8{
            [4]u8{ 0, 0, 0, 4 },
            [4]u8{ 0, 0, 0, 0 },
            [4]u8{ 2, 0, 0, 3 },
            [4]u8{ 4, 0, 1, 2 },
        },
    };

    const expected_board = Board(4){
        .cells = [4][4]u8{
            [4]u8{ 1, 2, 3, 4 },
            [4]u8{ 3, 4, 2, 1 },
            [4]u8{ 2, 1, 4, 3 },
            [4]u8{ 4, 3, 1, 2 },
        },
    };

    _ = try board.solve();

    try std.testing.expectEqualDeep(expected_board, board);
}

test "9x9 solve test" {
    var board = Board(9){
        .cells = [9][9]u8{
            [9]u8{ 0, 0, 1, 0, 0, 4, 0, 0, 0 },
            [9]u8{ 0, 0, 5, 0, 0, 0, 0, 1, 6 },
            [9]u8{ 2, 0, 0, 0, 3, 0, 7, 0, 5 },
            [9]u8{ 0, 0, 0, 0, 1, 7, 3, 0, 0 },
            [9]u8{ 0, 3, 0, 0, 0, 0, 9, 8, 0 },
            [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            [9]u8{ 6, 0, 7, 1, 0, 0, 0, 5, 0 },
            [9]u8{ 0, 0, 0, 0, 7, 0, 0, 0, 0 },
            [9]u8{ 0, 2, 0, 8, 0, 0, 6, 0, 0 },
        },
    };

    const expected_board = Board(9){
        .cells = [9][9]u8{
            [_]u8{ 9, 6, 1, 7, 5, 4, 2, 3, 8 },
            [_]u8{ 3, 7, 5, 2, 8, 9, 4, 1, 6 },
            [_]u8{ 2, 8, 4, 6, 3, 1, 7, 9, 5 },
            [_]u8{ 8, 5, 2, 9, 1, 7, 3, 6, 4 },
            [_]u8{ 7, 3, 6, 5, 4, 2, 9, 8, 1 },
            [_]u8{ 4, 1, 9, 3, 6, 8, 5, 7, 2 },
            [_]u8{ 6, 4, 7, 1, 2, 3, 8, 5, 9 },
            [_]u8{ 5, 9, 8, 4, 7, 6, 1, 2, 3 },
            [_]u8{ 1, 2, 3, 8, 9, 5, 6, 4, 7 },
        },
    };

    _ = try board.solve();

    try std.testing.expectEqualDeep(expected_board, board);
}

test "board valid test" {
    const board = Board(9){
        .cells = [9][9]u8{
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
        },
    };

    try std.testing.expect(!board.boardValid(0, 0));
    try std.testing.expect(!board.boardValid(4, 0));
    try std.testing.expect(!board.boardValid(5, 6));
}

test "row test" {
    const board = Board(9){
        .cells = [9][9]u8{
            [9]u8{ 0, 0, 1, 0, 1, 4, 0, 0, 0 }, // <-- 1
            [9]u8{ 0, 0, 5, 0, 0, 0, 0, 1, 6 },
            [9]u8{ 2, 0, 0, 0, 3, 0, 7, 0, 5 },
            [9]u8{ 0, 0, 0, 0, 1, 7, 3, 0, 0 },
            [9]u8{ 0, 3, 0, 0, 0, 0, 9, 8, 0 },
            [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            [9]u8{ 6, 0, 7, 1, 0, 5, 0, 5, 0 }, // <-- 5
            [9]u8{ 0, 0, 0, 0, 7, 0, 0, 0, 0 },
            [9]u8{ 0, 2, 0, 8, 0, 0, 6, 0, 0 },
        },
    };

    try std.testing.expect(board.rowValid(4, 1));
    try std.testing.expect(board.rowValid(2, 2));
    try std.testing.expect(board.rowValid(1, 3));
    try std.testing.expect(board.rowValid(0, 4));
    try std.testing.expect(board.rowValid(8, 5));
    try std.testing.expect(board.rowValid(9, 7));
    try std.testing.expect(board.rowValid(7, 8));

    try std.testing.expect(!board.rowValid(0, 0));
    try std.testing.expect(!board.rowValid(1, 0));
    try std.testing.expect(!board.rowValid(2, 0));
    try std.testing.expect(!board.rowValid(3, 0));
    try std.testing.expect(!board.rowValid(4, 0));
    try std.testing.expect(!board.rowValid(5, 0));
    try std.testing.expect(!board.rowValid(6, 0));
    try std.testing.expect(!board.rowValid(7, 0));
    try std.testing.expect(!board.rowValid(8, 0));

    try std.testing.expect(!board.rowValid(0, 6));
    try std.testing.expect(!board.rowValid(1, 6));
    try std.testing.expect(!board.rowValid(2, 6));
    try std.testing.expect(!board.rowValid(3, 6));
    try std.testing.expect(!board.rowValid(4, 6));
    try std.testing.expect(!board.rowValid(5, 6));
    try std.testing.expect(!board.rowValid(6, 6));
    try std.testing.expect(!board.rowValid(7, 6));
    try std.testing.expect(!board.rowValid(8, 6));
}

test "col test" {
    const board = Board(9){
        .cells = [9][9]u8{
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
        },
    };

    try std.testing.expect(board.colValid(0, 1));
    try std.testing.expect(board.colValid(2, 2));
    try std.testing.expect(board.colValid(3, 1));
    try std.testing.expect(board.colValid(4, 0));
    try std.testing.expect(board.colValid(5, 8));
    try std.testing.expect(board.colValid(7, 9));
    try std.testing.expect(board.colValid(8, 7));

    try std.testing.expect(!board.colValid(6, 0));
    try std.testing.expect(!board.colValid(6, 1));
    try std.testing.expect(!board.colValid(6, 2));
    try std.testing.expect(!board.colValid(6, 3));
    try std.testing.expect(!board.colValid(6, 4));
    try std.testing.expect(!board.colValid(6, 5));
    try std.testing.expect(!board.colValid(6, 6));
    try std.testing.expect(!board.colValid(6, 7));
    try std.testing.expect(!board.colValid(6, 8));

    try std.testing.expect(!board.colValid(1, 0));
    try std.testing.expect(!board.colValid(1, 1));
    try std.testing.expect(!board.colValid(1, 2));
    try std.testing.expect(!board.colValid(1, 3));
    try std.testing.expect(!board.colValid(1, 4));
    try std.testing.expect(!board.colValid(1, 5));
    try std.testing.expect(!board.colValid(1, 6));
    try std.testing.expect(!board.colValid(1, 7));
    try std.testing.expect(!board.colValid(1, 8));
}

test "square test" {
    const board = Board(9){
        .cells = [9][9]u8{
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
        },
    };

    try std.testing.expect(board.squareValid(0, 3));
    try std.testing.expect(board.squareValid(8, 8));
    try std.testing.expect(board.squareValid(5, 2));
    try std.testing.expect(board.squareValid(7, 7));

    try std.testing.expect(!board.squareValid(0, 0));
    try std.testing.expect(!board.squareValid(0, 1));
    try std.testing.expect(!board.squareValid(0, 2));
    try std.testing.expect(!board.squareValid(1, 0));
    try std.testing.expect(!board.squareValid(1, 1));
    try std.testing.expect(!board.squareValid(1, 2));
    try std.testing.expect(!board.squareValid(2, 0));
    try std.testing.expect(!board.squareValid(2, 1));
    try std.testing.expect(!board.squareValid(2, 2));

    try std.testing.expect(!board.squareValid(6, 3));
    try std.testing.expect(!board.squareValid(6, 4));
    try std.testing.expect(!board.squareValid(6, 5));
    try std.testing.expect(!board.squareValid(7, 3));
    try std.testing.expect(!board.squareValid(7, 4));
    try std.testing.expect(!board.squareValid(7, 5));
    try std.testing.expect(!board.squareValid(8, 3));
    try std.testing.expect(!board.squareValid(8, 4));
    try std.testing.expect(!board.squareValid(8, 5));
}
