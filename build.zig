const std = @import("std");

const sources_ordered = [_][]const u8{
    "constants.F",
    "ccpp_kind_types.F",
    "getcape.F",
    "input.F",
    "module_gfs_machine.F",
    "module_libmassv.F",
    "module_mp_nssl_2mom.F",
    "module_mp_p3.F",
    "module_ra_etc.F",
    "module_sf_exchcoef.F",
    "oml.F",
    "radlib3d.F",
    "sfclay.F",
    "singleton.F",
    "slab.F",
    "stopcm1.F",

    "bc.F",
    "bl_ysu.F",
    "cm1libs.F",
    "cu_ntiedtke.F",
    "diff2.F",
    "eddy_recycle.F",
    "init_surface.F",
    "interp_routines.F",
    "irrad3d.F",
    "kessler.F",
    "lfoice.F",
    "lsnudge.F",
    "maxmin.F",
    "module_bl_myjpbl.F",
    "module_bl_mynn_common.F",
    "module_gfs_physcons.F",
    "module_mp_jensen_ishmael.F",
    "module_mp_radar.F",
    "module_ra_rrtmg_lw.F",
    "module_sf_myjsfc.F",
    "module_sf_mynn.F",
    "morrison.F",
    "mp_radar.F",
    "poiss.F",
    "sf_sfclayrev.F",
    "sorad3d.F",
    "testcase_simple_phys.F",
    "writeout_nc.F",

    "comm.F",
    "goddard.F",
    "module_bl_mynn.F",
    "module_gfs_funcphys.F",
    "module_ra_rrtmg_sw.F",
    "mp_wsm6.F",
    "radtrns3d.F",
    "restart_write.F",
    "sfcphys.F",
    "thompson.F",
    "turbtend.F",

    "azimavg.F",
    "base.F",
    "ib_module.F",
    "misclibs.F",
    "module_bl_mynn_wrapper.F",
    "module_sf_gfdl.F",
    "mp_wsm6_effectRad.F",
    "parcel.F",
    "pdef.F",
    "radiation_driver.F",
    "restart_read.F",
    "turbnba.F",

    "adv_routines.F",
    "anelp.F",
    "init_physics.F",
    "mmm_physics_wrapper.F",
    "module_bl_gfsedmf.F",
    "solve1.F",
    "sound.F",
    "soundcb.F",
    "sounde.F",
    "soundns.F",
    "statpack.F",
    "writeout.F",

    "adv.F",
    "init_terrain.F",
    "mp_driver.F",
    "solve3.F",
    "turb.F",

    "domaindiag.F",
    "hifrq.F",
    "init3d.F",
    "param.F",
    "pdcomp.F",
    "solve2.F",

    "cm1.F",
};

pub fn build(b: *std.Build) void {
    // const target = b.standardTargetOptions(.{}); // -Dtarget, -Dcpu.[web:19][web:21]
    // const optimize = b.standardOptimizeOption(.{}); // -Doptimize.[web:19][web:24]

    // Project‑specific toggles
    const use_mpi = b.option(bool, "use_mpi", "Enable MPI distributed memory") orelse false;
    // const use_openmp = b.option(bool, "use_openmp", "Enable OpenMP shared memory") orelse false;
    // const use_netcdf = b.option(bool, "use_netcdf", "Enable NetCDF output") orelse false;
    // const use_double = b.option(bool, "use_double", "Enable double precision (gfortran -fdefault-real-8)") orelse false;
    // const debug_mode = b.option(bool, "debug", "Enable debug build (-O0 -g)") orelse false;
    // const netcdf_base = b.option([]const u8, "netcdf_base", "Path to NetCDF installation prefix");
    const fortran_compiler: []const u8 = b.option([]const u8, "fc", "Fortran compiler to use") orelse
        (if (use_mpi) "mpifort" else "gfortran");

    // Layout: keep sources under src/, intermediates under cache_root, final exe in zig-out/bin
    const src_dir = "src";
    const work_dir = b.cache_root.join(b.allocator, &.{"cm1-work"}) catch @panic("OOM");
    const out_dir = b.getInstallPath(.bin, "");

    // Base flags reused in commands
    // const cpp_defs = makeCppDefs(b.allocator, use_mpi, use_openmp, use_netcdf, use_double, debug_mode);
    // const fflags = makeFFlags(b.allocator, use_openmp, use_double, use_netcdf, netcdf_base, debug_mode);
    // const link_flags = makeLinkFlags(b.allocator, use_openmp);
    // const link_libs = makeLinkLibs(b.allocator, use_netcdf, netcdf_base);

    // For each source, create two steps:
    //   1) cpp:  src/F -> work/F.f90
    //   2) fc:   work/F.f90 -> work/F.o
    var object_paths = std.ArrayList([]const u8){};

    for (sources_ordered) |src_name| {
        const base_name = stripSuffixF(b, src_name); // "foo.F" -> "foo"

        const src_path = b.pathJoin(&.{ src_dir, src_name });
        const f90_path = b.pathJoin(&.{ work_dir, b.fmt("{s}.f90", .{base_name}) });
        const obj_path = b.pathJoin(&.{ work_dir, b.fmt("{s}.o", .{base_name}) });

        // Step 1: cpp
        const cpp_cmd = b.addSystemCommand(&.{"zig"});
        cpp_cmd.addArg("cc");
        cpp_cmd.addArg("-C");
        cpp_cmd.addArg("-P");
        cpp_cmd.addArg("-traditional");
        cpp_cmd.addArg("-ffreestanding");
        // cpp_cmd.addArgs(std.mem.tokenizeAny(u8, cpp_defs, " "));
        cpp_cmd.addFileArg(b.path(src_path));
        cpp_cmd.addArg("-o");
        cpp_cmd.addArg(f90_path);

        // Step 2: Fortran compile
        const fc_cmd = b.addSystemCommand(&.{fortran_compiler});
        fc_cmd.step.dependOn(&cpp_cmd.step);
        // fc_cmd.addArgs(std.mem.tokenizeAny(u8, fflags, " "));
        fc_cmd.addFileArg(b.path(f90_path));
        fc_cmd.addArg("-c");
        fc_cmd.addArg("-o");
        fc_cmd.addArg(obj_path);

        object_paths.append(b.allocator, obj_path) catch @panic("OOM");
    }

    // Link step: cm1.exe
    const exe_name = "cm1.exe";
    const exe_path = b.pathJoin(&.{ out_dir, exe_name });

    const link_cmd = b.addSystemCommand(&.{fortran_compiler});
    for (object_paths.items) |obj| {
        link_cmd.addFileArg(b.path(obj));
    }
    // link_cmd.addArgs(std.mem.tokenizeAny(u8, link_flags, " "));
    // link_cmd.addArgs(std.mem.tokenizeAny(u8, link_libs, " "));
    link_cmd.addArg("-o");
    link_cmd.addArg(exe_path);

    const install_step = b.getInstallStep();
    install_step.dependOn(&link_cmd.step);

    // Clean step: remove Zig outputs and our work dir
    const clean_step = b.step("clean", "Remove build artifacts");
    const clean_cmd = b.addSystemCommand(&.{
        "sh",
        "-c",
        b.fmt("rm -rf {s} .zig-cache {s}", .{ out_dir, work_dir }),
    });
    clean_step.dependOn(&clean_cmd.step);
}

fn stripSuffixF(_: *std.Build, src_name: []const u8) []const u8 {
    // naive but sufficient: assume ".F"
    if (std.mem.endsWith(u8, src_name, ".F")) {
        return src_name[0 .. src_name.len - 2];
    }
    return src_name;
}

fn makeCppDefs(
    allocator: std.mem.Allocator,
    use_mpi: bool,
    use_openmp: bool,
    use_netcdf: bool,
    use_double: bool,
    debug_mode: bool,
) []const u8 {
    var buf = std.ArrayList(u8){};
    if (use_mpi) _ = buf.appendSlice(allocator, " -DMPI") catch @panic("OOM");
    if (use_openmp) _ = buf.appendSlice(allocator, " -DOPENMP") catch @panic("OOM");
    if (use_double) _ = buf.appendSlice(allocator, " -DDP") catch @panic("OOM");
    if (use_netcdf) _ = buf.appendSlice(allocator, " -DNETCDF -DNCFPLUS") catch @panic("OOM");
    if (debug_mode) _ = buf.appendSlice(allocator, " -D_B4B") catch @panic("OOM");
    return buf.toOwnedSlice(allocator) catch @panic("OOM");
}

fn makeFFlags(
    allocator: std.mem.Allocator,
    use_openmp: bool,
    use_double: bool,
    use_netcdf: bool,
    netcdf_base: ?[]const u8,
    debug_mode: bool,
) []const u8 {
    var buf = std.ArrayList(u8){};
    _ = buf.appendSlice(allocator, "-ffree-form -ffree-line-length-none -fallow-argument-mismatch") catch @panic("OOM");

    if (debug_mode) {
        _ = buf.appendSlice(allocator, " -g -O0 -fcheck=all -fbacktrace") catch @panic("OOM");
    } else {
        _ = buf.appendSlice(allocator, " -O2 -finline-functions") catch @panic("OOM");
    }

    if (use_openmp) _ = buf.appendSlice(allocator, " -fopenmp") catch @panic("OOM");
    if (use_double) _ = buf.appendSlice(allocator, " -fdefault-real-8") catch @panic("OOM");

    if (use_netcdf) {
        if (netcdf_base) |base| {
            _ = buf.appendSlice(allocator, " -I") catch @panic("OOM");
            _ = buf.appendSlice(allocator, base) catch @panic("OOM");
            _ = buf.appendSlice(allocator, "/include") catch @panic("OOM");
        }
    }

    return buf.toOwnedSlice(allocator) catch @panic("OOM");
}

fn makeLinkFlags(allocator: std.mem.Allocator, use_openmp: bool) []const u8 {
    var buf = std.ArrayList(u8){};
    if (use_openmp) _ = buf.appendSlice(allocator, " -fopenmp") catch @panic("OOM");
    return buf.toOwnedSlice(allocator) catch @panic("OOM");
}

fn makeLinkLibs(
    allocator: std.mem.Allocator,
    use_netcdf: bool,
    netcdf_base: ?[]const u8,
) []const u8 {
    var buf = std.ArrayList(u8){};

    if (use_netcdf) {
        if (netcdf_base) |base| {
            _ = buf.appendSlice(allocator, " -L") catch @panic("OOM");
            _ = buf.appendSlice(allocator, base) catch @panic("OOM");
            _ = buf.appendSlice(allocator, "/lib") catch @panic("OOM");
        }
        _ = buf.appendSlice(allocator, " -lnetcdf -lnetcdff") catch @panic("OOM");
    }

    return buf.toOwnedSlice(allocator) catch @panic("OOM");
}
