const std = @import("std");
const testing = std.testing;

pub const SudokuError = error{UnsolvableBoard};
pub fn Board(comptime N: comptime_int) type {
    return struct {
        cells: [N][N]u8,

        pub fn print(self: *const Board(N)) !void {
            const out = std.io.getStdOut();
            var buf = std.io.bufferedWriter(out.writer());

            var w = buf.writer();

            for (self.cells) |row| {
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

        pub fn solve(self: *Board(N)) SudokuError!*Board(N) {
            return self.solveCell(0, 0);
        }

        fn solveCell(self: *Board(N), x: usize, y: usize) SudokuError!*Board(N) {
            if (y > 8) {
                return self;
            }

            const next_x, const next_y = if (x < 8) .{ x + 1, y } else .{ 0, y + 1 };
            if (self.cells[y][x] != 0) {
                return self.solveCell(next_x, next_y);
            }

            for (1..10) |val| {
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
            for (self.cells[y], 0..) |cell0, i| {
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
            for (self.cells, 0..) |row0, i| {
                if (row0[x] == 0) {
                    continue;
                }
                for (self.cells[i + 1 ..]) |row| {
                    if (row[x] == row0[x]) {
                        return false;
                    }
                }
            }

            return true;
        }

        fn squareValid(self: *const Board(N), x: usize, y: usize) bool {
            const start_x = x - x % 3;
            const start_y = y - y % 3;

            for (start_y..start_y + 3) |y0| {
                for (start_x..start_x + 3) |x0| {
                    const cell0 = self.cells[y0][x0];

                    if (cell0 == 0) {
                        continue;
                    }

                    for (x0 + 1..start_x + 3) |x1| {
                        if (self.cells[y0][x1] == cell0) {
                            return false;
                        }
                    }

                    for (y0 + 1..start_y + 3) |y1| {
                        for (start_x..start_x + 3) |x1| {
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

test "solve test" {
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
        }
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
        }
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
        }
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
