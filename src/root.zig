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

        var initialBoard: [N][N]u8 = undefined;
        var rows: [N * N][N]@Vector(N, u8) = undefined;
        var cols: [N * N][N]@Vector(N, u8) = undefined;
        var sqrs: [N * N][N]@Vector(N, u8) = undefined;
        var depth: usize = 0;

        var tries: u64 = 0;

        const INITIAL_POSSIBILITIES: @Vector(N, bool) = @splat(true);

        // const CONST_VECS: [N]@Vector(N, u8) = init: {
        //     var initial_value: [N]@Vector(N, u8) = undefined;
        //     for (&initial_value, 0..) |*vec, i| {
        //         vec.* = @splat(i + 1);
        //     }
        //
        //     break :init initial_value;
        // };

        var lastPrintTime: i64 = 0;
        const CLEAR = "\x1b[2J\x1b[H\n";
        const RESET_CURSOR = "\x1b[H";
        const SAVE_CURSOR = "\x1b[s";
        const RESTORE_CURSOR = "\x1b[u\x1b[0J";
        const RESET_COLOR = "\x1b[0m";
        const BG_COLORS = [2][]const u8{ "\x1b[48;2;24;25;38m", "\x1b[48;2;54;58;79m" };
        const FG_COLORS = [2][]const u8{ "\x1b[38;2;237;135;150m", "\x1b[38;2;138;173;244m" };
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
        pub fn print(self: *Board(N)) void {
            if (builtin.is_test) {
                return;
            }

            const now = std.time.milliTimestamp();
            if (now - lastPrintTime < 500) {
                return;
            }
            lastPrintTime = now;

            _ = w.write(RESTORE_CURSOR) catch unreachable;

            self.forcePrint();

            _ = w.print("Tried {} boards\n", .{tries}) catch unreachable;

            buf.flush() catch unreachable;
        }

        pub fn forcePrint(self: *Board(N)) void {
            _ = self; // autofix
            for (rows[depth], 0..) |row, y| {
                _ = w.writeByte('|') catch unreachable;
                for (@as([N]u8, row), 0..) |cell, x| {
                    const sqrType = (x / SQRT_N + y / SQRT_N) % 2;
                    const nextSqrType = ((x + 1) / SQRT_N + y / SQRT_N) % 2;
                    _ = w.write(BG_COLORS[sqrType]) catch unreachable;
                    _ = w.write(FG_COLORS[@intFromBool(initialBoard[y][x] == 0)]) catch unreachable;
                    _ = w.writeByte(' ') catch unreachable;
                    if (cell == 0) {
                        _ = w.write(" ") catch unreachable;
                    } else {
                        _ = w.writeByte(CHARSET[cell - 1]) catch unreachable;
                    }
                    _ = w.writeByte(' ') catch unreachable;
                    _ = w.write(RESET_COLOR) catch unreachable;

                    if (nextSqrType == sqrType) {
                        _ = w.write(BG_COLORS[sqrType]) catch unreachable;
                    }
                    _ = w.writeByte('|') catch unreachable;
                }
                _ = w.writeByte('\n') catch unreachable;
            }

            _ = w.writeByte('\n') catch unreachable;

            buf.flush() catch unreachable;

            lastPrintTime = std.time.milliTimestamp();
        }

        pub fn solve(self: *Board(N)) SudokuError!*Board(N) {
            _ = w.write(CLEAR ++ SAVE_CURSOR) catch unreachable;
            const res = try self.solveCell(0, 0);

            for (rows[depth], 0..) |row, y| {
                for (@as([N]u8, row), 0..) |cell, x| {
                    self.cells[y][x] = cell;
                }
            }

            return res;
        }

        fn fillCellsWithOnePossibility(self: *Board(N)) SudokuError!void {
            var filled: bool = true;
            while (filled) {
                filled = false;
                for (0..N) |y| {
                    var possibilites: [N]@Vector(N, bool) = undefined;
                    for (0..N) |x| {
                        if (self.getCell(x, y) != 0) {
                            continue;
                        }

                        const outer_index = x / SQRT_N + SQRT_N * (y / SQRT_N);

                        const row = rows[depth][y];
                        const col = cols[depth][x];
                        const sqr = sqrs[depth][outer_index];

                        for (1..N + 1) |n| {
                            const ns: @Vector(N, u8) = @splat(@intCast(n));
                            possibilites[x][n - 1] = @reduce(.And, row != ns) and
                                @reduce(.And, col != ns) and
                                @reduce(.And, sqr != ns);
                        }

                        const trues = std.simd.countTrues(possibilites[x]);
                        switch (trues) {
                            0 => {
                                return SudokuError.UnsolvableBoard;
                            },
                            1 => {
                                const index: u8 = std.simd.firstTrue(possibilites[x]) orelse unreachable;
                                self.setCell(x, y, index + 1);
                                filled = true;
                            },
                            else => {},
                        }
                    }
                }
            }
        }

        fn solveCell(self: *Board(N), x: usize, y: usize) SudokuError!*Board(N) {
            tries += 1;
            if (y > N - 1) {
                return self;
            }

            try self.fillCellsWithOnePossibility();
            self.print();

            const next_x, const next_y = if (x < N - 1)
                .{ x + 1, y }
            else
                .{ 0, y + 1 };

            if (self.getCell(x, y) != 0) {
                return self.solveCell(next_x, next_y);
            }

            self.increaseDepth();
            for (1..N + 1) |val| {
                self.setCell(x, y, @intCast(val));
                if (self.boardValid(x, y)) {
                    if (self.solveCell(next_x, next_y)) |sol| {
                        return sol;
                    } else |_| {
                        self.resetDepth();
                    }
                }
            }
            self.decreaseDepth();
            self.setCell(x, y, 0);

            return SudokuError.UnsolvableBoard;
        }

        fn resetDepth(self: *Board(N)) void {
            _ = self; // autofix
            rows[depth] = rows[depth - 1];
            cols[depth] = cols[depth - 1];
            sqrs[depth] = sqrs[depth - 1];
        }

        fn increaseDepth(self: *Board(N)) void {
            _ = self; // autofix
            rows[depth + 1] = rows[depth];
            cols[depth + 1] = cols[depth];
            sqrs[depth + 1] = sqrs[depth];
            depth += 1;
        }

        fn decreaseDepth(self: *Board(N)) void {
            _ = self; // autofix
            depth -= 1;
        }

        fn setCell(self: *Board(N), x: usize, y: usize, value: u8) void {
            _ = self; // autofix
            const outer_index = x / SQRT_N + SQRT_N * (y / SQRT_N);
            const inner_index = x % SQRT_N + SQRT_N * (y % SQRT_N);

            rows[depth][y][x] = value;
            cols[depth][x][y] = value;
            sqrs[depth][outer_index][inner_index] = value;
        }

        fn getCell(self: *Board(N), x: usize, y: usize) u8 {
            _ = self; // autofix
            return rows[depth][y][x];
        }

        fn boardValid(self: *const Board(N), x: usize, y: usize) bool {
            return self.rowValid(x, y) and
                self.colValid(x, y) and
                self.squareValid(x, y);
        }

        fn rowValid(self: *const Board(N), _: usize, y: usize) bool {
            _ = self; // autofix
            var n: u8 = 1;
            while (n <= N) : (n += 1) {
                if (std.simd.countElementsWithValue(rows[depth][y], n) > 1) {
                    return false;
                }
            }

            return true;
        }

        fn colValid(self: *const Board(N), x: usize, _: usize) bool {
            _ = self; // autofix
            var n: u8 = 1;
            while (n <= N) : (n += 1) {
                if (std.simd.countElementsWithValue(cols[depth][x], n) > 1) {
                    return false;
                }
            }

            return true;
        }

        fn squareValid(self: *const Board(N), x: usize, y: usize) bool {
            _ = self; // autofix
            const outer_index = x / SQRT_N + SQRT_N * (y / SQRT_N);
            var n: u8 = 1;
            while (n <= N) : (n += 1) {
                if (std.simd.countElementsWithValue(sqrs[depth][outer_index], n) > 1) {
                    return false;
                }
            }

            return true;
        }

        pub fn initBoard(self: *Board(N)) void {
            initialBoard = self.cells;
            for (self.cells, 0..) |row, y| {
                for (row, 0..) |cell, x| {
                    self.setCell(x, y, cell);
                }
            }
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
    board.initBoard();

    var expected_board = Board(4){
        .cells = [4][4]u8{
            [4]u8{ 1, 2, 3, 4 },
            [4]u8{ 3, 4, 2, 1 },
            [4]u8{ 2, 1, 4, 3 },
            [4]u8{ 4, 3, 1, 2 },
        },
    };
    expected_board.initBoard();

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
    board.initBoard();

    var expected_board = Board(9){
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
    expected_board.initBoard();

    _ = try board.solve();

    try std.testing.expectEqualDeep(expected_board, board);
}

test "board valid test" {
    var board = Board(9){
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
    board.initBoard();

    try std.testing.expect(!board.boardValid(0, 0));
    try std.testing.expect(!board.boardValid(4, 0));
    try std.testing.expect(!board.boardValid(5, 6));
}

test "row test" {
    var board = Board(9){
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
    board.initBoard();

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
    var board = Board(9){
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
    board.initBoard();

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
    var board = Board(9){
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
    board.initBoard();

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
