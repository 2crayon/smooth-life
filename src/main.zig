const std = @import("std");

const WIDTH = 300;
const HEIGHT = 100;
const ra = 11;
const ri = ra / 3;
const alpha_n = 0.028;
const alpha_m = 0.147;
const b1 = 0.278;
const b2 = 0.365;
const d1 = 0.267;
const d2 = 0.445;
const dt = 0.5;

const GRADIENT = [_]u8{ ' ', '.', '-', '=', 'c', 'o', 'a', 'A', '@', '#' };

pub fn main() !void {
    const stdout_file = std.io.getStdOut();
    var bw = std.io.bufferedWriter(stdout_file.writer());
    const w = bw.writer();

    const rand = b: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        var prng = std.rand.DefaultPrng.init(seed);
        break :b prng.random();
    };

    var grid: [WIDTH * HEIGHT]f32 = std.mem.zeroes([WIDTH * HEIGHT]f32);
    var grid_diff: [WIDTH * HEIGHT]f32 = undefined;
    for (0..grid.len / 2) |i| {
        if (@mod(i, WIDTH) > WIDTH / 2) continue;
        grid[i] = rand.float(f32);
    }

    while (true) {
        computeGridDiff(&grid, &grid_diff);
        for (0..grid.len) |i| {
            grid[i] += dt * grid_diff[i];
            grid[i] = std.math.clamp(grid[i], 0.001, 0.999);
        }
        try w.writeAll("\x1b[H");
        try printGrid(&w, &grid);
        try bw.flush();
    }
}

fn computeGridDiff(grid: []const f32, grid_diff_out: []f32) void {
    var center_y: i32 = 0;
    while (center_y < HEIGHT) : (center_y += 1) {
        var center_x: i32 = 0;
        while (center_x < WIDTH) : (center_x += 1) {
            var m: f32 = 0;
            var n: f32 = 0;
            var M: f32 = 0;
            var N: f32 = 0;

            var dy: i32 = -(ra - 1);
            while (dy <= ra - 1) : (dy += 1) {
                var dx: i32 = -(ra - 1);
                while (dx <= (ra - 1)) : (dx += 1) {
                    const x = @mod(center_x + dx, WIDTH);
                    const y = @mod(center_y + dy, HEIGHT);
                    if (dx * dx + dy * dy <= ri * ri) {
                        m += grid[@intCast(y * WIDTH + x)];
                        M += 1;
                    } else if (dx * dx + dy * dy <= ra * ra) {
                        n += grid[@intCast(y * WIDTH + x)];
                        N += 1;
                    }
                }
            }
            m /= M;
            n /= N;
            const q = s(n, m);
            grid_diff_out[@intCast(center_y * WIDTH + center_x)] = 2 * q - 1;
        }
    }
}

fn sigma(x: f32, a: f32, alpha: f32) f32 {
    return 1 / (1 + @exp(-(x - a) * 4 / alpha));
}

fn sigmaN(x: f32, a: f32, b: f32) f32 {
    return sigma(x, a, alpha_n) * (1 - sigma(x, b, alpha_n));
}

fn sigmaM(x: f32, y: f32, m: f32) f32 {
    return x * (1 - sigma(m, 0.5, alpha_m)) + y * sigma(m, 0.5, alpha_m);
}

fn s(n: f32, m: f32) f32 {
    return sigmaN(n, sigmaM(b1, d1, m), sigmaM(b2, d2, m));
}

fn printGrid(w: anytype, grid: []const f32) !void {
    @setRuntimeSafety(false);

    for (0..grid.len) |i| {
        if (i % WIDTH == 0 and i != 0) {
            try w.writeByte('\n');
        }
        const grad_index: usize = @intFromFloat(grid[i] * GRADIENT.len - 1);
        try w.writeByte(GRADIENT[grad_index]);
    }
}
