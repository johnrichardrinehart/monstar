//! Vendored and adapted from ghostty (src/font/sprite/draw/block.zig), MIT licensed. Original copyright Mitchell Hashimoto and ghostty contributors.
//! Block Elements | U+2580...U+259F
//! https://en.wikipedia.org/wiki/Block_Elements
//!
//! ▀▁▂▃▄▅▆▇█▉▊▋▌▍▎▏
//! ▐░▒▓▔▕▖▗▘▙▚▛▜▝▞▟
//!

const std = @import("std");
const Allocator = std.mem.Allocator;

const common = @import("common.zig");
const Shade = common.Shade;
const Quads = common.Quads;
const Alignment = common.Alignment;
const fill = common.fill;

const font = @import("../metrics.zig");
const sprite = @import("../canvas.zig");

pub fn draw2580_259F(
    cp: u32,
    canvas: *sprite.Canvas,
    width: u32,
    height: u32,
    metrics: font.Metrics,
) !void {
    _ = width;
    _ = height;

    switch (cp) {
        // '▀' UPPER HALF BLOCK
        0x2580 => block(metrics, canvas, .upper, 1, common.half),
        // '▁' LOWER ONE EIGHTH BLOCK
        0x2581 => block(metrics, canvas, .lower, 1, common.one_eighth),
        // '▂' LOWER ONE QUARTER BLOCK
        0x2582 => block(metrics, canvas, .lower, 1, common.one_quarter),
        // '▃' LOWER THREE EIGHTHS BLOCK
        0x2583 => block(metrics, canvas, .lower, 1, common.three_eighths),
        // '▄' LOWER HALF BLOCK
        0x2584 => block(metrics, canvas, .lower, 1, common.half),
        // '▅' LOWER FIVE EIGHTHS BLOCK
        0x2585 => block(metrics, canvas, .lower, 1, common.five_eighths),
        // '▆' LOWER THREE QUARTERS BLOCK
        0x2586 => block(metrics, canvas, .lower, 1, common.three_quarters),
        // '▇' LOWER SEVEN EIGHTHS BLOCK
        0x2587 => block(metrics, canvas, .lower, 1, common.seven_eighths),
        // '█' FULL BLOCK
        0x2588 => fullBlockShade(metrics, canvas, .on),
        // '▉' LEFT SEVEN EIGHTHS BLOCK
        0x2589 => block(metrics, canvas, .left, common.seven_eighths, 1),
        // '▊' LEFT THREE QUARTERS BLOCK
        0x258a => block(metrics, canvas, .left, common.three_quarters, 1),
        // '▋' LEFT FIVE EIGHTHS BLOCK
        0x258b => block(metrics, canvas, .left, common.five_eighths, 1),
        // '▌' LEFT HALF BLOCK
        0x258c => block(metrics, canvas, .left, common.half, 1),
        // '▍' LEFT THREE EIGHTHS BLOCK
        0x258d => block(metrics, canvas, .left, common.three_eighths, 1),
        // '▎' LEFT ONE QUARTER BLOCK
        0x258e => block(metrics, canvas, .left, common.one_quarter, 1),
        // '▏' LEFT ONE EIGHTH BLOCK
        0x258f => block(metrics, canvas, .left, common.one_eighth, 1),

        // '▐' RIGHT HALF BLOCK
        0x2590 => block(metrics, canvas, .right, common.half, 1),
        // '░'
        0x2591 => fullBlockShade(metrics, canvas, .light),
        // '▒'
        0x2592 => fullBlockShade(metrics, canvas, .medium),
        // '▓'
        0x2593 => fullBlockShade(metrics, canvas, .dark),
        // '▔' UPPER ONE EIGHTH BLOCK
        0x2594 => block(metrics, canvas, .upper, 1, common.one_eighth),
        // '▕' RIGHT ONE EIGHTH BLOCK
        0x2595 => block(metrics, canvas, .right, common.one_eighth, 1),
        // '▖'
        0x2596 => quadrant(metrics, canvas, .{ .bl = true }),
        // '▗'
        0x2597 => quadrant(metrics, canvas, .{ .br = true }),
        // '▘'
        0x2598 => quadrant(metrics, canvas, .{ .tl = true }),
        // '▙'
        0x2599 => quadrant(metrics, canvas, .{ .tl = true, .bl = true, .br = true }),
        // '▚'
        0x259a => quadrant(metrics, canvas, .{ .tl = true, .br = true }),
        // '▛'
        0x259b => quadrant(metrics, canvas, .{ .tl = true, .tr = true, .bl = true }),
        // '▜'
        0x259c => quadrant(metrics, canvas, .{ .tl = true, .tr = true, .br = true }),
        // '▝'
        0x259d => quadrant(metrics, canvas, .{ .tr = true }),
        // '▞'
        0x259e => quadrant(metrics, canvas, .{ .tr = true, .bl = true }),
        // '▟'
        0x259f => quadrant(metrics, canvas, .{ .tr = true, .bl = true, .br = true }),

        else => unreachable,
    }
}

pub fn block(
    metrics: font.Metrics,
    canvas: *sprite.Canvas,
    comptime alignment: Alignment,
    comptime width: f64,
    comptime height: f64,
) void {
    blockShade(metrics, canvas, alignment, width, height, .on);
}

pub fn blockShade(
    metrics: font.Metrics,
    canvas: *sprite.Canvas,
    comptime alignment: Alignment,
    comptime width: f64,
    comptime height: f64,
    comptime shade: Shade,
) void {
    const float_width: f64 = @floatFromInt(metrics.cell_width);
    const float_height: f64 = @floatFromInt(metrics.cell_height);

    const w: u32 = @intFromFloat(@round(float_width * width));
    const h: u32 = @intFromFloat(@round(float_height * height));

    const x = switch (alignment.horizontal) {
        .left => 0,
        .right => metrics.cell_width - w,
        .center => (metrics.cell_width - w) / 2,
    };
    const y = switch (alignment.vertical) {
        .top => 0,
        .bottom => metrics.cell_height - h,
        .middle => (metrics.cell_height - h) / 2,
    };

    canvas.rect(.{
        .x = @intCast(x),
        .y = @intCast(y),
        .width = @intCast(w),
        .height = @intCast(h),
    }, @as(sprite.Color, @enumFromInt(@intFromEnum(shade))));
}

pub fn fullBlockShade(
    metrics: font.Metrics,
    canvas: *sprite.Canvas,
    shade: Shade,
) void {
    canvas.box(
        0,
        0,
        @intCast(metrics.cell_width),
        @intCast(metrics.cell_height),
        @as(sprite.Color, @enumFromInt(@intFromEnum(shade))),
    );
}
/// Draw U+2591..U+2593 with KiTTY's spatial shade masks.
pub fn kittyShade(
    cp: u32,
    canvas: *sprite.Canvas,
    width: u32,
    height: u32,
    metrics: font.Metrics,
) !void {
    _ = metrics;
    std.debug.assert(cp >= 0x2591 and cp <= 0x2593);

    const light = cp != 0x2592;
    const invert = cp == 0x2593;
    const xnum: u32 = 12;
    const square_width = @max(1, width / xnum);
    const square_height = square_width;
    var columns = width / square_width;
    var rows = height / square_height;
    if (columns > 1 and columns % 2 != xnum % 2) columns -= 1;
    if (rows > 1 and rows % 2 != 0) rows -= 1;

    const excess_columns = width - square_width * columns;
    const excess_rows = height - square_height * rows;
    var previous_extra_y: u32 = 0;
    for (0..rows) |row_usize| {
        const row: u32 = @intCast(row_usize);
        const extra_y = ceilRatio(row * excess_rows, rows);
        const has_extra_row = extra_y != previous_extra_y;
        var previous_extra_x: u32 = 0;

        for (0..columns) |column_usize| {
            const column: u32 = @intCast(column_usize);
            const extra_x = ceilRatio(column * excess_columns, columns);
            const has_extra_column = extra_x != previous_extra_x;

            if (has_extra_row) {
                const alpha: u8 = if (light)
                    if (invert)
                        if (column % 2 == 1) 255 else 70
                    else if (column % 2 == 1) 0 else 70
                else if ((column % 2 == 1) == invert) 120 else 30;
                for (0..square_width) |dx|
                    canvas.pixel(@intCast(column * square_width + @as(u32, @intCast(dx)) + extra_x), @intCast(row * square_height + previous_extra_y), @enumFromInt(alpha));
            }

            if (has_extra_column) {
                const alpha: u8 = if (light)
                    if (invert)
                        if (row % 2 == 1) 255 else 70
                    else if (row % 2 == 1) 0 else 70
                else if ((row % 2 == 1) == invert) 120 else 30;
                for (0..square_height) |dy|
                    canvas.pixel(@intCast(column * square_width + previous_extra_x), @intCast(row * square_height + @as(u32, @intCast(dy)) + extra_y), @enumFromInt(alpha));
            }

            if (has_extra_row and has_extra_column)
                canvas.pixel(@intCast(column * square_width + previous_extra_x), @intCast(row * square_height + previous_extra_y), @enumFromInt(50));

            const blank = invert != ((row % 2 != column % 2) or (light and row % 2 == 1));
            if (!blank) canvas.box(
                @intCast(column * square_width + extra_x),
                @intCast(row * square_height + extra_y),
                @intCast((column + 1) * square_width + extra_x),
                @intCast((row + 1) * square_height + extra_y),
                .on,
            );
            previous_extra_x = extra_x;
        }
        previous_extra_y = extra_y;
    }
}

fn ceilRatio(numerator: u32, denominator: u32) u32 {
    return (numerator + denominator - 1) / denominator;
}

fn quadrant(
    metrics: font.Metrics,
    canvas: *sprite.Canvas,
    comptime quads: Quads,
) void {
    if (quads.tl) fill(metrics, canvas, .zero, .half, .zero, .half);
    if (quads.tr) fill(metrics, canvas, .half, .full, .zero, .half);
    if (quads.bl) fill(metrics, canvas, .zero, .half, .half, .full);
    if (quads.br) fill(metrics, canvas, .half, .full, .half, .full);
}
