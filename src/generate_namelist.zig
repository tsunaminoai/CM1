/// generate_namelist — write a CM1 namelist.input from command-line arguments.
///
/// Usage:
///   generate_namelist [--key value | --key=value] ...
///   generate_namelist --help
///
/// Unspecified parameters keep the default values shown below.
/// Output is written to run/namelist.input (relative to cwd).
const std = @import("std");

// ── Parameter struct with CM1 defaults ───────────────────────────────────────

const Params = struct {
    // &param0 — grid dimensions and global options
    nx: usize = 128,
    ny: usize = 128,
    nz: usize = 50,
    ppnode: usize = 1,
    timeformat: usize = 1,
    terrain_flag: usize = 0,
    outunits: usize = 0,

    // &param1 — physical grid and time stepping
    dx: f64 = 1000.0,
    dy: f64 = 1000.0,
    dz: f64 = 500.0,
    dtl: f64 = 6.0,
    timax: f64 = 3600.0,
    tapfrq: f64 = 900.0,
    rstfrq: f64 = 86400.0,
    statfrq: f64 = 300.0,

    // &param2 — physics options
    imoist: usize = 1,
    ptype: usize = 2,
    ipbl: usize = 0,
    sgsmodel: usize = 1,
    psolver: usize = 3,
    isnd: usize = 3,
    iwnd: usize = 0,
    iinit: usize = 1,
    icor: usize = 1,
    fcor: f64 = 1.0e-4,
    imove: usize = 0,
    umove: f64 = 0.0,
    vmove: f64 = 0.0,
};

// ── Argument parsing ──────────────────────────────────────────────────────────

fn parseArgs(io: std.Io, args: []const [:0]const u8, p: *Params) !void {
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            const out = std.Io.File.stdout();
            var buf: [4096]u8 = undefined;
            var w = out.writer(io, &buf);
            try w.interface.writeAll(
                \\Usage: generate_namelist [--key value | --key=value] ...
                \\
                \\Grid:
                \\  --nx --ny --nz      grid points (default 128 128 50)
                \\  --dx --dy --dz      grid spacing in metres (default 1000 1000 500)
                \\  --ppnode            processors per node (default 1)
                \\
                \\Time:
                \\  --dtl               large time step in seconds (default 6)
                \\  --timax             simulation length in seconds (default 3600)
                \\  --tapfrq            output frequency in seconds (default 900)
                \\  --rstfrq            restart frequency in seconds (default 86400)
                \\  --statfrq           statistics frequency in seconds (default 300)
                \\
                \\Physics:
                \\  --imoist            moisture flag 0/1 (default 1)
                \\  --ptype             microphysics type (default 2)
                \\  --ipbl              PBL scheme (default 0)
                \\  --sgsmodel          SGS turbulence model (default 1)
                \\  --psolver           pressure solver (default 3)
                \\  --isnd --iwnd       sounding/wind profile indices (default 3 0)
                \\  --iinit --icor      initialisation / Coriolis flags (default 1 1)
                \\  --fcor              Coriolis parameter (default 1e-4)
                \\  --imove --umove --vmove  moving frame (default 0 0.0 0.0)
                \\
            );
            try w.interface.flush();
            return;
        }

        // Accept --key=value or --key value
        var key: []const u8 = undefined;
        var val: []const u8 = undefined;

        if (std.mem.startsWith(u8, arg, "--")) {
            if (std.mem.indexOfScalar(u8, arg, '=')) |eq| {
                key = arg[2..eq];
                val = arg[eq + 1 ..];
            } else {
                key = arg[2..];
                i += 1;
                if (i >= args.len) {
                    std.debug.print("error: missing value for --{s}\n", .{key});
                    return error.MissingValue;
                }
                val = args[i];
            }
        } else {
            std.debug.print("error: unexpected argument '{s}'\n", .{arg});
            return error.UnknownArgument;
        }

        // Map key → field
        if (false) {} // dummy to start the if-else chain
        // usize fields
        else if (std.mem.eql(u8, key, "nx")) p.nx = try parseUInt(val)
        else if (std.mem.eql(u8, key, "ny")) p.ny = try parseUInt(val)
        else if (std.mem.eql(u8, key, "nz")) p.nz = try parseUInt(val)
        else if (std.mem.eql(u8, key, "ppnode")) p.ppnode = try parseUInt(val)
        else if (std.mem.eql(u8, key, "timeformat")) p.timeformat = try parseUInt(val)
        else if (std.mem.eql(u8, key, "terrain_flag")) p.terrain_flag = try parseUInt(val)
        else if (std.mem.eql(u8, key, "outunits")) p.outunits = try parseUInt(val)
        else if (std.mem.eql(u8, key, "imoist")) p.imoist = try parseUInt(val)
        else if (std.mem.eql(u8, key, "ptype")) p.ptype = try parseUInt(val)
        else if (std.mem.eql(u8, key, "ipbl")) p.ipbl = try parseUInt(val)
        else if (std.mem.eql(u8, key, "sgsmodel")) p.sgsmodel = try parseUInt(val)
        else if (std.mem.eql(u8, key, "psolver")) p.psolver = try parseUInt(val)
        else if (std.mem.eql(u8, key, "isnd")) p.isnd = try parseUInt(val)
        else if (std.mem.eql(u8, key, "iwnd")) p.iwnd = try parseUInt(val)
        else if (std.mem.eql(u8, key, "iinit")) p.iinit = try parseUInt(val)
        else if (std.mem.eql(u8, key, "icor")) p.icor = try parseUInt(val)
        else if (std.mem.eql(u8, key, "imove")) p.imove = try parseUInt(val)
        // f64 fields
        else if (std.mem.eql(u8, key, "dx")) p.dx = try parseFloat(val)
        else if (std.mem.eql(u8, key, "dy")) p.dy = try parseFloat(val)
        else if (std.mem.eql(u8, key, "dz")) p.dz = try parseFloat(val)
        else if (std.mem.eql(u8, key, "dtl")) p.dtl = try parseFloat(val)
        else if (std.mem.eql(u8, key, "timax")) p.timax = try parseFloat(val)
        else if (std.mem.eql(u8, key, "tapfrq")) p.tapfrq = try parseFloat(val)
        else if (std.mem.eql(u8, key, "rstfrq")) p.rstfrq = try parseFloat(val)
        else if (std.mem.eql(u8, key, "statfrq")) p.statfrq = try parseFloat(val)
        else if (std.mem.eql(u8, key, "fcor")) p.fcor = try parseFloat(val)
        else if (std.mem.eql(u8, key, "umove")) p.umove = try parseFloat(val)
        else if (std.mem.eql(u8, key, "vmove")) p.vmove = try parseFloat(val)
        else {
            std.debug.print("error: unknown option --{s}\n", .{key});
            return error.UnknownArgument;
        }
    }
}

fn parseUInt(s: []const u8) !usize {
    return std.fmt.parseInt(usize, s, 10) catch {
        std.debug.print("error: expected integer, got '{s}'\n", .{s});
        return error.InvalidValue;
    };
}

fn parseFloat(s: []const u8) !f64 {
    return std.fmt.parseFloat(f64, s) catch {
        std.debug.print("error: expected float, got '{s}'\n", .{s});
        return error.InvalidValue;
    };
}

// ── Namelist output ───────────────────────────────────────────────────────────

fn writeNamelist(io: std.Io, file: std.Io.File, p: Params) !void {
    var buf: [65536]u8 = undefined;
    var w = file.writer(io, &buf);
    const iw = &w.interface;

    try iw.print(
        \\
        \\ &param0
        \\  nx            = {d},
        \\  ny            = {d},
        \\  nz            = {d},
        \\  ppnode        = {d},
        \\  timeformat    = {d},
        \\  terrain_flag  = {d},
        \\  outunits      = {d},
        \\ /
        \\
    , .{ p.nx, p.ny, p.nz, p.ppnode, p.timeformat, p.terrain_flag, p.outunits });

    try iw.print(
        \\ &param1
        \\  dx            = {d:.1},
        \\  dy            = {d:.1},
        \\  dz            = {d:.1},
        \\  dtl           = {d:.1},
        \\  timax         = {d:.1},
        \\  tapfrq        = {d:.1},
        \\  rstfrq        = {d:.1},
        \\  statfrq       = {d:.1},
        \\ /
        \\
    , .{ p.dx, p.dy, p.dz, p.dtl, p.timax, p.tapfrq, p.rstfrq, p.statfrq });

    try iw.print(
        \\ &param2
        \\  imoist        = {d},
        \\  ptype         = {d},
        \\  ipbl          = {d},
        \\  sgsmodel      = {d},
        \\  psolver       = {d},
        \\  isnd          = {d},
        \\  iwnd          = {d},
        \\  iinit         = {d},
        \\  icor          = {d},
        \\  fcor          = {e},
        \\  imove         = {d},
        \\  umove         = {d:.1},
        \\  vmove         = {d:.1},
        \\ /
        \\
    , .{ p.imoist, p.ptype, p.ipbl, p.sgsmodel, p.psolver, p.isnd, p.iwnd, p.iinit, p.icor, p.fcor, p.imove, p.umove, p.vmove });

    try w.interface.flush();
}

// ── Entry point ───────────────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;

    var args: std.ArrayList([:0]const u8) = .empty;
    defer args.deinit(alloc);
    var it: std.process.Args.Iterator = .init(init.minimal.args);
    defer it.deinit();
    while (it.next()) |arg| try args.append(alloc, arg);

    var params = Params{};
    try parseArgs(init.io, args.items, &params);

    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(init.io, "run");

    const file = try cwd.createFile(init.io, "run/namelist.input", .{
        .truncate = true,
    });
    defer file.close(init.io);

    try writeNamelist(init.io, file, params);

    const stdout = std.Io.File.stdout();
    var buf: [256]u8 = undefined;
    var w = stdout.writer(init.io, &buf);
    try w.interface.writeAll("Generated run/namelist.input\n");
    try w.interface.flush();
}
