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

        initial_board: [N][N]u8 = undefined,
        possibilities: [N][N]@Vector(N, bool) = undefined,
        changes: [N * N]struct { x: usize, y: usize, old_val: u8 } = undefined,
        change_index: usize = 0,
        tries: u64 = 0,

        const Self = @This();
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
        pub fn print(self: *Self) void {
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

            _ = w.print("Tried {} boards\n", .{self.tries}) catch unreachable;

            buf.flush() catch unreachable;
        }

        pub fn forcePrint(self: *Self) void {
            for (self.cells, 0..) |row, y| {
                _ = w.writeByte('|') catch unreachable;
                for (@as([N]u8, row), 0..) |cell, x| {
                    const sqrType = (x / SQRT_N + y / SQRT_N) % 2;
                    const nextSqrType = ((x + 1) / SQRT_N + y / SQRT_N) % 2;
                    _ = w.write(BG_COLORS[sqrType]) catch unreachable;
                    _ = w.write(FG_COLORS[@intFromBool(self.initial_board[y][x] == 0)]) catch unreachable;
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

        pub fn solve(self: *Self) SudokuError!*Self {
            _ = w.write(CLEAR ++ SAVE_CURSOR) catch unreachable;
            const res = try self.solveCell(0, 0);

            for (self.cells, 0..) |row, y| {
                for (@as([N]u8, row), 0..) |cell, x| {
                    self.setCell(x, y, cell);
                }
            }

            return res;
        }

        fn fillCellsWithOnePossibility(self: *Self) !usize {
            var filled: usize = 0;
            for (&self.possibilities, 0..) |*row_pos, y| {
                for (row_pos, 0..) |*cell_pos, x| {
                    if (self.getCell(x, y) != 0) {
                        continue;
                    }

                    switch (std.simd.countTrues(cell_pos.*)) {
                        0 => {
                            return SudokuError.UnsolvableBoard;
                        },
                        1 => {
                            self.setCell(x, y, @as(u8, std.simd.firstTrue(cell_pos.*).?) + 1);
                            filled += 1;
                        },
                        else => {},
                    }
                }
            }

            return filled;
        }

        fn fillValuesWithOneCell(self: *Self) !usize {
            var filled: usize = 0;

            for (0..N) |y| {
                n_loop: for (1..N + 1) |n| {
                    var row_index: ?usize = null;
                    for (0..N) |x| {
                        if (self.getCell(x, y) == n) {
                            row_index = null;
                            continue :n_loop;
                        }

                        if (self.possibilities[y][x][n - 1]) {
                            if (row_index) |_| {
                                row_index = null;
                                continue :n_loop;
                            } else {
                                row_index = x;
                            }
                        }
                    }
                    if (row_index) |x1| {
                        if (self.getCell(x1, y) != n) {
                            self.setCell(x1, y, @intCast(n));
                            filled += 1;
                        }
                    } else {
                        return SudokuError.UnsolvableBoard;
                    }
                }
            }

            for (0..N) |x| {
                n_loop: for (1..N + 1) |n| {
                    var col_index: ?usize = null;
                    for (0..N) |y| {
                        if (self.getCell(x, y) == n) {
                            col_index = null;
                            continue :n_loop;
                        }

                        if (self.possibilities[y][x][n - 1]) {
                            if (col_index) |_| {
                                col_index = null;
                                continue :n_loop;
                            } else {
                                col_index = y;
                            }
                        }
                    }
                    if (col_index) |y1| {
                        if (self.getCell(x, y1) != n) {
                            self.setCell(x, y1, @intCast(n));
                            filled += 1;
                        }
                    } else {
                        return SudokuError.UnsolvableBoard;
                    }
                }
            }

            for (0..N) |outer_index| {
                const start = .{
                    .x = (outer_index % SQRT_N) * SQRT_N,
                    .y = (outer_index / SQRT_N) * SQRT_N,
                };
                n_loop: for (1..N + 1) |n| {
                    var pos: ?struct { x: usize, y: usize } = null;
                    for (0..N) |inner_index| {
                        const offset = .{
                            .x = inner_index % SQRT_N,
                            .y = inner_index / SQRT_N,
                        };

                        const x = start.x + offset.x;
                        const y = start.y + offset.y;

                        if (self.getCell(x, y) == n) {
                            pos = null;
                            continue :n_loop;
                        }

                        if (self.possibilities[y][x][n - 1]) {
                            if (pos) |_| {
                                pos = null;
                                continue :n_loop;
                            } else {
                                pos = .{ .x = x, .y = y };
                            }
                        }
                    }
                    if (pos) |p| {
                        if (self.getCell(p.x, p.y) != n) {
                            self.setCell(p.x, p.y, @intCast(n));
                            filled += 1;
                        } else {
                            return SudokuError.UnsolvableBoard;
                        }
                    }
                }
            }

            return filled;
        }

        fn solveCell(self: *Self, x: usize, y: usize) !*Self {
            self.tries += 1;
            if (y > N - 1) {
                return self;
            }

            self.print();

            const saved_index = self.change_index;

            const next_x, const next_y = if (x < N - 1)
                .{ x + 1, y }
            else
                .{ 0, y + 1 };

            if (self.getCell(x, y) != 0) {
                return self.solveCell(next_x, next_y);
            }

            var filled: usize = 1;
            while (filled > 0) {
                filled = try self.fillCellsWithOnePossibility();
                filled += try self.fillValuesWithOneCell();
            }

            for (1..N + 1) |val| {
                if (self.possibilities[y][x][val - 1]) {
                    self.setCell(x, y, @intCast(val));
                    if (self.solveCell(next_x, next_y)) |sol| {
                        return sol;
                    } else |_| {
                        self.resetCells(saved_index);
                    }
                }
            }
            self.resetCells(saved_index);

            return SudokuError.UnsolvableBoard;
        }

        fn resetCells(self: *Self, saved_index: usize) void {
            while (self.change_index > saved_index) {
                self.change_index -= 1;
                const change = self.changes[self.change_index];
                self.cells[change.y][change.x] = change.old_val;
                self.updatePossibilities(change.x, change.y);
            }
        }

        fn setCell(self: *Self, x: usize, y: usize, value: u8) void {
            if (self.getCell(x, y) == value) {
                return;
            }

            self.changes[self.change_index] = .{
                .x = x,
                .y = y,
                .old_val = self.cells[y][x],
            };
            self.change_index += 1;
            self.cells[y][x] = value;
            self.updatePossibilities(x, y);
        }

        inline fn getCell(self: Self, x: usize, y: usize) u8 {
            return self.cells[y][x];
        }

        inline fn getPossibilities(self: Self, x: usize, y: usize) [N]bool {
            return self.possibilities[y][x];
        }

        inline fn boardValid(self: Self, x: usize, y: usize) bool {
            return self.rowValid(x, y) and
                self.colValid(x, y) and
                self.squareValid(x, y);
        }

        fn rowValid(self: Self, _: usize, y: usize) bool {
            for (1..N + 1) |n| {
                var seen = false;
                for (0..N) |x| {
                    if (self.getCell(x, y) == n) {
                        if (seen) {
                            return false;
                        } else {
                            seen = true;
                        }
                    }
                }
            }

            return true;
        }

        fn colValid(self: Self, x: usize, _: usize) bool {
            for (1..N + 1) |n| {
                var seen = false;
                for (0..N) |y| {
                    if (self.getCell(x, y) == n) {
                        if (seen) {
                            return false;
                        } else {
                            seen = true;
                        }
                    }
                }
            }

            return true;
        }

        fn squareValid(self: Self, x: usize, y: usize) bool {
            const square_start = .{
                .x = (x / SQRT_N) * SQRT_N,
                .y = (y / SQRT_N) * SQRT_N,
            };

            for (1..N + 1) |n| {
                var seen = false;
                for (0..N) |offset| {
                    const x1 = square_start.x + offset % SQRT_N;
                    const y1 = square_start.y + offset / SQRT_N;
                    if (self.getCell(x1, y1) == n) {
                        if (seen) {
                            return false;
                        } else {
                            seen = true;
                        }
                    }
                }
            }

            return true;
        }

        fn updatePossibilities(self: *Self, x: usize, y: usize) void {
            // for (0..N) |y1| {
            //     for (0..N) |x1| {
            //         self.calculatePossibilities(x1, y1);
            //     }
            // }
            const square_start = .{
                .x = (x / SQRT_N) * SQRT_N,
                .y = (y / SQRT_N) * SQRT_N,
            };

            for (0..N) |offset| {
                const sqr_x = square_start.x + offset % SQRT_N;
                const sqr_y = square_start.y + offset / SQRT_N;
                self.calculatePossibilities(offset, y);
                self.calculatePossibilities(x, offset);
                self.calculatePossibilities(sqr_x, sqr_y);
            }
        }

        fn calculatePossibilities(self: *Self, x: usize, y: usize) void {
            if (self.getCell(x, y) != 0) {
                self.possibilities[y][x] = @splat(false);
                self.possibilities[y][x][self.getCell(x, y) - 1] = true;
            } else {
                self.possibilities[y][x] = @splat(true);
                self.calculatePossibilitiesRow(x, y);
                self.calculatePossibilitiesCol(x, y);
                self.calculatePossibilitiesSquare(x, y);
            }
        }

        fn calculatePossibilitiesRow(self: *Self, x: usize, y: usize) void {
            for (0..N) |x1| {
                const val = self.getCell(x1, y);
                if (val != 0) {
                    self.possibilities[y][x][val - 1] = false;
                }
            }
        }

        fn calculatePossibilitiesCol(self: *Self, x: usize, y: usize) void {
            for (0..N) |y1| {
                const val = self.getCell(x, y1);
                if (val != 0) {
                    self.possibilities[y][x][val - 1] = false;
                }
            }
        }

        fn calculatePossibilitiesSquare(self: *Self, x: usize, y: usize) void {
            const square_start = .{
                .x = (x / SQRT_N) * SQRT_N,
                .y = (y / SQRT_N) * SQRT_N,
            };

            for (0..N) |offset| {
                const x1 = square_start.x + offset % SQRT_N;
                const y1 = square_start.y + offset / SQRT_N;
                const val = self.getCell(x1, y1);
                if (val != 0) {
                    self.possibilities[y][x][val - 1] = false;
                }
            }
        }

        pub fn init(cells: *const [N][N]u8) Self {
            var board = Self{
                .cells = cells.*,
                .initial_board = cells.*,
            };

            for (cells, 0..) |row, y| {
                for (row, 0..) |cell, x| {
                    board.setCell(x, y, cell);
                }
            }

            for (0..N) |y| {
                for (0..N) |x| {
                    board.calculatePossibilities(x, y);
                }
            }

            return board;
        }
    };
}

test "fill with one possibility test 4x4" {
    var board = Board(4).init(&[4][4]u8{
        [4]u8{ 0, 0, 0, 4 },
        [4]u8{ 0, 0, 0, 0 },
        [4]u8{ 2, 0, 0, 3 },
        [4]u8{ 4, 0, 1, 2 },
    });

    _ = try board.fillCellsWithOnePossibility();

    const expected_board = Board(4).init(&[4][4]u8{
        [4]u8{ 0, 0, 0, 4 },
        [4]u8{ 0, 0, 0, 1 },
        [4]u8{ 2, 1, 4, 3 },
        [4]u8{ 4, 3, 1, 2 },
    });

    try testing.expectEqualDeep(expected_board.cells, board.cells);
}

test "calculatePossibilities test" {
    var board = Board(4).init(&[4][4]u8{
        [4]u8{ 0, 0, 0, 4 },
        [4]u8{ 0, 0, 0, 0 },
        [4]u8{ 2, 0, 0, 3 },
        [4]u8{ 4, 0, 1, 2 },
    });

    board.calculatePossibilities(3, 0);
    try testing.expectEqualDeep(
        .{ false, false, false, true },
        board.getPossibilities(3, 0),
    );

    board.calculatePossibilities(0, 0);
    try testing.expectEqualDeep(
        .{ true, false, true, false },
        board.getPossibilities(0, 0),
    );

    board.calculatePossibilities(1, 1);
    try testing.expectEqualDeep(
        .{ true, true, true, true },
        board.getPossibilities(1, 1),
    );

    board.calculatePossibilities(1, 3);
    try testing.expectEqualDeep(
        .{ false, false, true, false },
        board.getPossibilities(1, 3),
    );

    board.calculatePossibilities(3, 1);
    try testing.expectEqualDeep(
        .{ true, false, false, false },
        board.getPossibilities(3, 1),
    );

    board.calculatePossibilities(2, 2);
    try testing.expectEqualDeep(
        .{ false, false, false, true },
        board.getPossibilities(2, 2),
    );

    board.calculatePossibilities(1, 2);
    try testing.expectEqualDeep(
        .{ true, false, false, false },
        board.getPossibilities(1, 2),
    );
}

test "4x4 solve test" {
    var board = Board(4).init(&[4][4]u8{
        [4]u8{ 0, 0, 0, 4 },
        [4]u8{ 0, 0, 0, 0 },
        [4]u8{ 2, 0, 0, 3 },
        [4]u8{ 4, 0, 1, 2 },
    });

    const expected_board = Board(4).init(&[4][4]u8{
        [4]u8{ 1, 2, 3, 4 },
        [4]u8{ 3, 4, 2, 1 },
        [4]u8{ 2, 1, 4, 3 },
        [4]u8{ 4, 3, 1, 2 },
    });

    _ = try board.solve();

    try std.testing.expectEqualDeep(expected_board.cells, board.cells);
}

test "9x9 solve test" {
    var board = Board(9).init(&[9][9]u8{
        [9]u8{ 0, 0, 1, 0, 0, 4, 0, 0, 0 },
        [9]u8{ 0, 0, 5, 0, 0, 0, 0, 1, 6 },
        [9]u8{ 2, 0, 0, 0, 3, 0, 7, 0, 5 },
        [9]u8{ 0, 0, 0, 0, 1, 7, 3, 0, 0 },
        [9]u8{ 0, 3, 0, 0, 0, 0, 9, 8, 0 },
        [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        [9]u8{ 6, 0, 7, 1, 0, 0, 0, 5, 0 },
        [9]u8{ 0, 0, 0, 0, 7, 0, 0, 0, 0 },
        [9]u8{ 0, 2, 0, 8, 0, 0, 6, 0, 0 },
    });

    const expected_board = Board(9).init(&[9][9]u8{
        [_]u8{ 9, 6, 1, 7, 5, 4, 2, 3, 8 },
        [_]u8{ 3, 7, 5, 2, 8, 9, 4, 1, 6 },
        [_]u8{ 2, 8, 4, 6, 3, 1, 7, 9, 5 },
        [_]u8{ 8, 5, 2, 9, 1, 7, 3, 6, 4 },
        [_]u8{ 7, 3, 6, 5, 4, 2, 9, 8, 1 },
        [_]u8{ 4, 1, 9, 3, 6, 8, 5, 7, 2 },
        [_]u8{ 6, 4, 7, 1, 2, 3, 8, 5, 9 },
        [_]u8{ 5, 9, 8, 4, 7, 6, 1, 2, 3 },
        [_]u8{ 1, 2, 3, 8, 9, 5, 6, 4, 7 },
    });

    _ = try board.solve();

    try std.testing.expectEqualDeep(expected_board.cells, board.cells);
}

test "board valid test" {
    var board = Board(9).init(&[9][9]u8{
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
    });

    try std.testing.expect(!board.boardValid(0, 0));
    try std.testing.expect(!board.boardValid(4, 0));
    try std.testing.expect(!board.boardValid(5, 6));
}

test "row test" {
    var board = Board(9).init(&[9][9]u8{
        [9]u8{ 0, 0, 1, 0, 1, 4, 0, 0, 0 }, // <-- 1
        [9]u8{ 0, 0, 5, 0, 0, 0, 0, 1, 6 },
        [9]u8{ 2, 0, 0, 0, 3, 0, 7, 0, 5 },
        [9]u8{ 0, 0, 0, 0, 1, 7, 3, 0, 0 },
        [9]u8{ 0, 3, 0, 0, 0, 0, 9, 8, 0 },
        [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        [9]u8{ 6, 0, 7, 1, 0, 5, 0, 5, 0 }, // <-- 5
        [9]u8{ 0, 0, 0, 0, 7, 0, 0, 0, 0 },
        [9]u8{ 0, 2, 0, 8, 0, 0, 6, 0, 0 },
    });

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
    var board = Board(9).init(&[9][9]u8{
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
    });

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
    var board = Board(9).init(&[9][9]u8{
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
    });

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
