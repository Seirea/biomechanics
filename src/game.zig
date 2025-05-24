const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");

const types = @import("types.zig");
const gui = @import("gui.zig");
const utils = @import("utils.zig");
const assets = @import("assets.zig");
const consts = @import("consts.zig");

const fonts = @import("fonts.zig");

var selectedIndex: usize = 0;

const Direction = enum(u2) { Vertical, DiagonalUp, Horizontal, DiagonalDown };
var cursorState: Direction = .Vertical;

var Level: types.LevelData = undefined;
var level_loaded = false;

pub fn levelUnloaded() bool {
    return !level_loaded;
}

var won = false;

pub fn loadLevel(level: types.LevelData) void {
    level_loaded = true;
    Level = level;
}

pub fn unloadLevel() void {
    level_loaded = false;
    won = false;
}

fn isSameSizeAsTargetStateWire(typ: Direction, idx: usize) bool {
    switch (typ) {
        .Horizontal => {
            var count: u8 = 0;
            for (Level.state[idx]) |x| {
                if (x) |_| {
                    count += 1;
                }
            }
            var target_count: u8 = 0;
            for (Level.target_state[idx]) |x| {
                if (x) |_| {
                    target_count += 1;
                }
            }
            return count == target_count;
        },
        .Vertical => {
            var count: u8 = 0;
            for (Level.state) |x| {
                if (x[idx]) |_| {
                    count += 1;
                }
            }
            var target_count: u8 = 0;
            for (Level.target_state) |x| {
                if (x[idx]) |_| {
                    target_count += 1;
                }
            }
            return count == target_count;
        },
        .DiagonalUp => {
            const N = Level.state.len;
            const diag_len = @min(idx, 2 * N - idx);
            var xc: usize = @min(idx, N) - 1;
            var yc: usize = undefined;
            if (N >= idx) {
                yc = 0;
            } else {
                yc = idx - N;
            }

            var count: u8 = 0;
            const old_xc = xc;
            const old_yc = yc;

            for (0..diag_len) |_| {
                if (Level.state[xc][yc]) |_| {
                    count += 1;
                }
                xc -%= 1;
                yc +%= 1;
            }

            var target_count: u8 = 0;
            xc = old_xc;
            yc = old_yc;
            for (0..diag_len) |_| {
                if (Level.target_state[xc][yc]) |_| {
                    target_count += 1;
                }
                xc -%= 1;
                yc +%= 1;
            }

            return count == target_count;
        },
        .DiagonalDown => {
            const N = Level.state.len;
            const diag_len = @min(idx, 2 * N - idx);

            var yc: usize = N - (@min(idx, N));
            var xc: usize = undefined;
            if (N >= idx) {
                xc = 0;
            } else {
                xc = idx - N;
            }

            var count: u8 = 0;
            const old_xc = xc;
            const old_yc = yc;

            for (0..diag_len) |_| {
                if (Level.state[xc][yc]) |_| {
                    count += 1;
                }

                xc +%= 1;
                yc +%= 1;
            }

            var target_count: u8 = 0;
            xc = old_xc;
            yc = old_yc;
            for (0..diag_len) |_| {
                if (Level.target_state[xc][yc]) |_| {
                    target_count += 1;
                }
                xc +%= 1;
                yc +%= 1;
            }

            return count == target_count;
        },
    }
    unreachable;
}

fn isContiguous(typ: Direction, idx: usize) bool {
    switch (typ) {
        .Horizontal => {
            var tracking = false;
            var left = false;
            for (Level.state[idx]) |x| {
                if (x) |_| {
                    // not null
                    tracking = true;

                    // if we already tracked a contiguous array and now came across something not in that
                    if (left) {
                        return false;
                    }
                } else {
                    if (tracking) {
                        left = true;
                    }
                }
            }
            return true;
        },
        .Vertical => {
            var tracking = false;
            var left = false;
            for (Level.state) |x| {
                if (x[idx]) |_| {
                    tracking = true;
                    if (left) {
                        return false;
                    }
                } else {
                    if (tracking) {
                        left = true;
                    }
                }
            }
            return true;
        },
        .DiagonalUp => {
            const N = Level.state.len;
            const diag_len = @min(idx, 2 * N - idx);
            var xc: usize = @min(idx, N) - 1;
            var yc: usize = undefined;
            if (N >= idx) {
                yc = 0;
            } else {
                yc = idx - N;
            }
            var tracking = false;
            var left = false;

            for (0..diag_len - 1) |_| {
                if (Level.state[xc][yc]) |_| {
                    tracking = true;
                    if (left) {
                        return false;
                    }
                } else {
                    if (tracking) {
                        left = true;
                    }
                }

                xc -= 1;
                yc += 1;
            }
            return true;
        },
        .DiagonalDown => {
            const N = Level.state.len;
            const diag_len = @min(idx, 2 * N - idx);

            var yc: usize = N - (@min(idx, N));
            var xc: usize = undefined;
            if (N >= idx) {
                xc = 0;
            } else {
                xc = idx - N;
            }

            var tracking = false;
            var left = false;

            // std.debug.print("START: xc={}, yc={} for idx={}\n", .{ xc, yc, idx });
            for (0..diag_len - 1) |_| {
                if (Level.state[xc][yc]) |_| {
                    // std.debug.print("{} @ {},{}\n", .{ Level.state[xc][yc].?.marking, xc, yc });
                    tracking = true;
                    if (left) {
                        return false;
                    }
                } else {
                    // std.debug.print("null @ {},{}\n", .{ xc, yc });
                    if (tracking) {
                        left = true;
                    }
                }

                xc += 1;
                yc += 1;
            }
            return true;
        },
    }
    unreachable;
}

fn isShiftable(typ: Direction, idx: usize) bool {
    return isContiguous(typ, idx) and isSameSizeAsTargetStateWire(typ, idx);
}

fn shiftColumn(idx: usize, amount: i32) void {
    if (!isShiftable(.Vertical, idx)) {
        return;
    }

    if (amount >= 0) {
        var i = (Level.state[0].len - 2);
        if (Level.state[i + 1][idx] != null) {
            return;
        }
        while (i >= 0) : (i -= 1) {
            Level.state[@intCast(@as(i32, @intCast(i)) + amount)][idx] = Level.state[i][idx];
            Level.state[i][idx] = null;

            if (i == 0) {
                break;
            }
        }
    } else {
        if (Level.state[0][idx] != null) {
            return;
        }
        for (1..Level.state[0].len) |x| {
            Level.state[@intCast(@as(i32, @intCast(x)) + amount)][idx] = Level.state[x][idx];
            Level.state[x][idx] = null;
        }
    }

    assets.slide_sfx.getOrLoad().play();
}

fn shiftDiagDown(idx: usize, amount: i32) void {
    if (!isShiftable(.DiagonalDown, idx)) {
        return;
    }

    const N = Level.state.len;
    const diag_len = @min(idx, 2 * N - idx);

    var yc: usize = N - (@min(idx, N));
    var xc: usize = undefined;
    if (N >= idx) {
        xc = 0;
    } else {
        xc = idx - N;
    }

    if (amount < 0) {
        // var j = count;
        const tmp: usize = xc;
        xc = N - yc - 1;
        yc = N - tmp - 1;

        var firsty = true;
        for (0..diag_len - 1) |_| {
            // std.debug.print("SHIFT DIAGDOWN UP: {} {} for IDX={}\n", .{ xc, yc, idx });
            if (firsty and Level.state[xc][yc] != null) {
                return;
            } else {
                firsty = false;
            }

            Level.state[xc][yc] = Level.state[xc - 1][yc - 1];
            Level.state[xc - 1][yc - 1] = null;
            xc -= 1;
            yc -= 1;
        }
    } else {
        var firsty = true;
        for (0..diag_len - 1) |_| {
            // std.debug.print("SHIFT DIAGDOWn DOWN: {} {} for IDX={}\n", .{ xc, yc, idx });
            if (firsty and Level.state[xc][yc] != null) {
                return;
            } else {
                firsty = false;
            }
            Level.state[xc][yc] = Level.state[xc + 1][yc + 1];
            Level.state[xc + 1][yc + 1] = null;
            xc += 1;
            yc += 1;
        }
    }

    assets.slide_sfx.getOrLoad().play();
}

fn shiftDiagUp(idx: usize, amount: i32) void {
    if (!isShiftable(.DiagonalUp, idx)) {
        return;
    }

    const N = Level.state.len;
    const diag_len = @min(idx, 2 * N - idx);
    var xc: usize = @min(idx, N) - 1;
    var yc: usize = undefined;
    if (N >= idx) {
        yc = 0;
    } else {
        yc = idx - N;
    }
    if (amount >= 0) {
        // var j = count;
        const tmp: usize = xc;
        xc = yc;
        yc = tmp;

        var firsty = true;
        for (0..diag_len - 1) |_| {
            if (firsty and Level.state[xc][yc] != null) {
                return;
            } else {
                firsty = false;
            }

            Level.state[xc][yc] = Level.state[xc + 1][yc - 1];
            Level.state[xc + 1][yc - 1] = null;
            xc += 1;
            yc -= 1;
        }
    } else {
        var firsty = true;
        for (0..diag_len - 1) |_| {
            // std.debug.print("SHIFT DIAGUP DOWN: {} {} for IDX={}\n", .{ xc, yc, idx });
            if (firsty and Level.state[xc][yc] != null) {
                return;
            } else {
                firsty = false;
            }
            Level.state[xc][yc] = Level.state[xc - 1][yc + 1];
            Level.state[xc - 1][yc + 1] = null;
            xc -= 1;
            yc += 1;
        }
    }

    assets.slide_sfx.getOrLoad().play();
}

fn shiftRow(idx: usize, amount: i32) void {
    if (!isShiftable(.Horizontal, idx)) {
        return;
    }

    if (amount >= 0) {
        var i = (Level.state[0].len - 2);
        if (Level.state[idx][i + 1] != null) {
            return;
        }
        while (i >= 0) : (i -= 1) {
            Level.state[idx][@intCast(@as(i32, @intCast(i)) + amount)] = Level.state[idx][i];
            Level.state[idx][i] = null;

            if (i == 0) {
                break;
            }
        }
    } else {
        if (Level.state[idx][0] != null) {
            return;
        }
        for (1..Level.state[0].len) |x| {
            Level.state[idx][@intCast(@as(i32, @intCast(x)) + amount)] = Level.state[idx][x];
            Level.state[idx][x] = null;
        }
    }

    assets.slide_sfx.getOrLoad().play();
}

var block_size: i32 = 0;
var padding: i32 = 0;

fn indexToWorldPos(pos: u8) i32 {
    return pos * block_size + (block_size >> 1);
}

fn drawLineWithThickness(startPosX: i32, startPosY: i32, endPosX: i32, endPosY: i32, thickness: f32, color: rl.Color) void {
    rl.drawLineEx(
        rl.Vector2.init(@floatFromInt(startPosX), @floatFromInt(startPosY)),
        rl.Vector2.init(@floatFromInt(endPosX), @floatFromInt(endPosY)),
        thickness,
        color,
    );
}

fn renderWiresForDirectionWithSelectedIndex(direction: Direction, idx: usize, is_active: bool) void {
    const wires = directionToWires(direction);
    switch (direction) {
        .Vertical => {
            for (wires, 0..) |pos, loc| {
                const selected: bool = is_active and loc == idx;
                const shiftable: bool = isShiftable(direction, pos);

                const coord = indexToWorldPos(pos);
                drawLineWithThickness(
                    coord,
                    0,
                    coord,
                    rl.getScreenHeight(),
                    if (shiftable) consts.wire_thickness else (consts.wire_thickness / 6),
                    if (selected) (if (shiftable) consts.selected_wire_color else (rl.Color.red)) else rl.Color.gray,
                );
            }
        },
        .DiagonalUp => {
            for (wires, 0..) |pos, loc| {
                const selected: bool = is_active and loc == idx;
                const shiftable: bool = isShiftable(direction, pos + 1);

                const coord = indexToWorldPos(pos) + (block_size >> 1);
                drawLineWithThickness(
                    0,
                    coord,
                    coord,
                    0,
                    if (shiftable) consts.wire_thickness else (consts.wire_thickness / 6),
                    if (selected) (if (shiftable) consts.selected_wire_color else (rl.Color.red)) else rl.Color.gray,
                );
            }
        },
        .Horizontal => {
            for (wires, 0..) |pos, loc| {
                const selected: bool = is_active and loc == idx;
                const shiftable: bool = isShiftable(direction, pos);

                const coord = indexToWorldPos(pos);
                drawLineWithThickness(
                    0,
                    coord,
                    rl.getScreenWidth(),
                    coord,
                    if (shiftable) consts.wire_thickness else (consts.wire_thickness / 6),
                    if (selected) (if (shiftable) consts.selected_wire_color else (rl.Color.red)) else rl.Color.gray,
                );
            }
        },
        .DiagonalDown => {
            for (wires, 0..) |pos, loc| {
                const selected: bool = is_active and loc == idx;
                const shiftable: bool = isShiftable(direction, pos + 1);

                const coord = indexToWorldPos(pos) + (block_size >> 1);
                drawLineWithThickness(
                    rl.getScreenWidth() - coord,
                    0,
                    rl.getScreenWidth(),
                    coord,
                    if (shiftable) consts.wire_thickness else (consts.wire_thickness / 6),
                    if (selected) (if (shiftable) consts.selected_wire_color else (rl.Color.red)) else rl.Color.gray,
                );
            }
        },
    }
}

fn directionToWires(dir: Direction) []const u8 {
    return switch (dir) {
        .Vertical => Level.vertical_wires,
        .Horizontal => Level.horizontal_wires,
        .DiagonalDown => Level.diag_down_wires,
        .DiagonalUp => Level.diag_up_wires,
    };
}

fn markingToColor(mark: u8) rl.Color {
    return switch (mark) {
        0 => rl.Color.light_gray,
        1 => rl.Color.red,
        else => unreachable,
    };
}

fn markingToTexture(mark: u8) rl.Texture2D {
    return Level.markingPictures[mark].getOrLoad();
}

fn hasWon() bool {
    for (Level.target_state, 0..) |row, e| {
        for (row, 0..) |pieceMaybe, z| {
            if (pieceMaybe) |piece| {
                if (Level.state[e][z]) |otro| {
                    if (!std.meta.eql(piece, otro)) {
                        return false;
                    }
                } else {
                    return false;
                }
            } else {
                // this is null
                if (Level.state[e][z] != null) {
                    return false;
                }
            }
        }
    }
    return true;
}

pub fn loop() bool {
    block_size = @divTrunc(rl.getScreenHeight(), @as(i32, @intCast(Level.state.len)));
    padding = block_size >> 3;
    // rl.drawRectangle(0, 0, 128, 128, rl.Color.red);

    if (rl.isKeyPressed(.space) or directionToWires(cursorState).len == 0) {
        var val = @intFromEnum(cursorState) +% 1;
        while (true) : (val +%= 1) {
            cursorState = @enumFromInt(val);
            if (directionToWires(cursorState).len != 0) {
                break;
            }
        }

        selectedIndex = 0;
    }

    switch (cursorState) {
        .Vertical => {
            if (rl.isKeyPressed(.right)) {
                selectedIndex +%= 1;
            }
            if (rl.isKeyPressed(.left)) {
                selectedIndex -%= 1;
            }
            selectedIndex = @mod(selectedIndex, directionToWires(cursorState).len);

            if (rl.isKeyPressed(.up)) {
                shiftColumn(Level.vertical_wires[selectedIndex], -1);
            }
            if (rl.isKeyPressed(.down)) {
                shiftColumn(Level.vertical_wires[selectedIndex], 1);
            }
        },
        .DiagonalUp => {
            if (rl.isKeyPressed(.down)) {
                selectedIndex +%= 1;
            }
            if (rl.isKeyPressed(.up)) {
                selectedIndex -%= 1;
            }

            selectedIndex = @mod(selectedIndex, directionToWires(cursorState).len);

            if (rl.isKeyPressed(.right)) {
                shiftDiagUp(Level.diag_up_wires[selectedIndex] + 1, 1);
            }
            if (rl.isKeyPressed(.left)) {
                shiftDiagUp(Level.diag_up_wires[selectedIndex] + 1, -1);
            }
        },
        .Horizontal => {
            if (rl.isKeyPressed(.down)) {
                selectedIndex +%= 1;
            }
            if (rl.isKeyPressed(.up)) {
                selectedIndex -%= 1;
            }

            selectedIndex = @mod(selectedIndex, directionToWires(cursorState).len);

            if (rl.isKeyPressed(.right)) {
                shiftRow(Level.horizontal_wires[selectedIndex], 1);
            }
            if (rl.isKeyPressed(.left)) {
                shiftRow(Level.horizontal_wires[selectedIndex], -1);
            }
        },
        .DiagonalDown => {
            if (rl.isKeyPressed(.down)) {
                selectedIndex +%= 1;
            }
            if (rl.isKeyPressed(.up)) {
                selectedIndex -%= 1;
            }

            selectedIndex = @mod(selectedIndex, directionToWires(cursorState).len);

            if (rl.isKeyPressed(.right)) {
                shiftDiagDown(Level.diag_down_wires[selectedIndex] + 1, -1);
            }
            if (rl.isKeyPressed(.left)) {
                shiftDiagDown(Level.diag_down_wires[selectedIndex] + 1, 1);
            }
        },
    }
    renderWiresForDirectionWithSelectedIndex(.Vertical, selectedIndex, cursorState == .Vertical);
    renderWiresForDirectionWithSelectedIndex(.Horizontal, selectedIndex, cursorState == .Horizontal);
    renderWiresForDirectionWithSelectedIndex(.DiagonalUp, selectedIndex, cursorState == .DiagonalUp);
    renderWiresForDirectionWithSelectedIndex(.DiagonalDown, selectedIndex, cursorState == .DiagonalDown);

    const rendering_target: bool = rl.isKeyDown(.q);

    // render pieces
    for (if (rendering_target) Level.target_state else Level.state, 0..) |row, e| {
        for (row, 0..) |pieceMaybe, z| {
            if (pieceMaybe) |piece| {
                const block_size_f: f32 = @floatFromInt(block_size);
                gui.drawTextureCenteredAtPoint(
                    2.0,
                    0.0,
                    rl.Vector2.init(
                        @as(f32, @floatFromInt(z)) * block_size_f + block_size_f / 2,
                        @as(f32, @floatFromInt(e)) * block_size_f + block_size_f / 2,
                    ),
                    markingToTexture(piece.marking),
                );
            }
        }
    }

    if (rendering_target) {
        rl.drawTextEx(
            fonts.main_font,
            "Target State",
            rl.Vector2.init(10, 64),
            fonts.Size.Large,
            0,
            rl.Color.white,
        );
    }

    if (rl.isKeyDown(.right_bracket) or hasWon()) {
        if (!won) {
            won = true;
            assets.win_sfx.getOrLoad().play();
        }

        rl.drawTextEx(
            fonts.main_font,
            "Click to continue...",
            rl.Vector2.init(10, @floatFromInt(rl.getScreenHeight() - 64)),
            fonts.Size.Medium,
            0,
            rl.Color.white,
        );

        if (gui.imgBtn(
            0.6,
            utils.renderSize().scale(0.5),
            assets.completedComponent.getOrLoad(),
            null,
            null,
            rl.getMousePosition(),
        ) or rl.isMouseButtonPressed(.left)) {
            won = false;
            return true;
        }
    } else {
        won = false;
    }
    return false;
}
