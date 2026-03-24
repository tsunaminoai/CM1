const std = @import("std");
const yazap = @import("yazap");
const Arg = yazap.Arg;
const log = std.log;
const argsParser = @import("args");

/// -------- Helper: parse unsigned integer --------
fn parseUInt(arg_iter: *std.mem.SplitIterator(u8, .any), comptime T: type) !T {
    const next = arg_iter.next() orelse
        return error.MissingValue;
    std.debug.print("{s}\n", .{next});
    return std.fmt.parseInt(T, next, 10) catch
        error.InvalidNumber;
}
fn parseFloat(arg_iter: *std.mem.SplitIterator(u8, .any), comptime T: type) !T {
    const next = arg_iter.next() orelse
        return error.MissingValue;
    std.debug.print("{s}\n", .{next});
    return std.fmt.parseFloat(T, next) catch
        error.InvalidNumber;
}

/// -------- Main entry point --------
pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const options = try argsParser.parseForCurrentProcess(struct {
        // This declares long options for double hyphen
        nx: usize = 0,
        ny: usize = 0,
        nz: usize = 0,
        dx: f64 = 0,
        dy: f64 = 0,
        dz: f64 = 0,
        dtl: f64 = 0,
        timax: f64 = 0,
        tapfrq: f64 = 0,
        rstfrq: f64 = 0,
        statfrq: f64 = 0,
        cm1setup: usize = 0,
        testcase: usize = 0,
        imoist: f64 = 0,
        ptype: usize = 0,
        ipbl: usize = 0,
        sgsmodel: usize = 0,
        psolver: usize = 0,
        isnd: usize = 0,
        iwnd: usize = 0,
        iinit: usize = 0,
        icor: usize = 0,
        fcor: f64 = 0,
        imove: usize = 0,
        umove: f64 = 0,
        vmove: f64 = 0,

        // This declares short-hand options for single hyphen
        pub const shorthands = .{};
    }, alloc, .print);
    defer options.deinit();

    std.debug.print("parsed options:\n", .{});
    inline for (std.meta.fields(@TypeOf(options.options))) |fld| {
        std.debug.print("\t{s} = {any}\n", .{
            fld.name,
            @field(options.options, fld.name),
        });
    }

    std.debug.print("parsed positionals:\n", .{});
    for (options.positionals) |arg| {
        std.debug.print("\t'{s}'\n", .{arg});
    }

    var cfg: @TypeOf(options.options) = .{};

    inline for (std.meta.fields(@TypeOf(options.options))) |fld| {
        @field(cfg, fld.name) = switch (@typeInfo(@TypeOf(fld))) {
            .int, .comptime_int => @intCast(fld.value),
            .float, .comptime_float => @floatCast(fld.value),
            else => @field(options.options, fld.name),
        };
    }

    // Ensure output directory exists
    const run_dir = "run";
    std.fs.cwd().makePath(run_dir) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => |err| return err,
    };

    // Open file for writing (truncate if exists)
    const file_path = "run/namelist.input";
    var file = try std.fs.cwd().createFile(file_path, .{
        .truncate = true,
        .read = false,
        .mode = 0o644,
    });
    defer file.close();

    // Write &param0 block — extend as needed
    try file.writer().print(
        \\&param0
        \\ nx            = {d},
        \\ ny            = {d},
        \\ nz            = {d},
        \\ dx            = {d:.1},
        \\ dy            = {d:.1},
        \\ dz            = {d:.1},
        \\ timax         = {d},
        \\ /
        \\
    , .{
        cfg.nx,    cfg.ny, cfg.nz,
        cfg.dx,    cfg.dy, cfg.dz,
        cfg.timax,
    });

    std.debug.print("Generated {s}\n", .{file_path});
}

/// -------- Error set for convenience --------
const Error = struct {
    InvalidFlag: error{},
    MissingValue: error{},
    InvalidNumber: error{},
};
