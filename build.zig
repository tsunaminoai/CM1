const std = @import("std");

// ============================================================================
// CM1 Numerical Model — Zig Build Pipeline
//
// This build.zig replaces the traditional Makefile for compiling CM1.
// It drives the C preprocessor (cpp) and a Fortran compiler (gfortran)
// through zig's build system, respecting the module dependency order.
//
// Usage:
//   zig build                          # basic single-processor build
//   zig build -Duse_mpi=true           # MPI distributed memory
//   zig build -Duse_netcdf=true        # with NetCDF output
//   zig build -Duse_openmp=true        # OpenMP shared memory
//   zig build -Ddebug=true             # debug build
//   zig build clean                    # remove build artifacts
//
// The resulting binary is placed in zig-out/bin/cm1.exe
// ============================================================================

/// Source files in dependency-safe (topologically sorted) compilation order.
/// Derived from the Makefile dependency graph. Files providing Fortran modules
/// must be compiled before files that USE those modules.
const sources_ordered = [_][]const u8{
    // ── Tier 0: No module dependencies ──
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

    // ── Tier 1: Depend only on Tier 0 ──
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

    // ── Tier 2: Depend on Tier 0–1 ──
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

    // ── Tier 3: Depend on Tier 0–2 ──
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

    // ── Tier 4: Depend on Tier 0–3 ──
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

    // ── Tier 5: Depend on Tier 0–4 ──
    "adv.F",
    "init_terrain.F",
    "mp_driver.F",
    "solve3.F",
    "turb.F",

    // ── Tier 6: Depend on Tier 0–5 ──
    "domaindiag.F",
    "hifrq.F",
    "init3d.F",
    "param.F",
    "pdcomp.F",
    "solve2.F",

    // ── Tier 7: Main program ──
    "cm1.F",
};

pub fn build(b: *std.Build) void {
    // ── User-configurable options ──────────────────────────────────────
    const use_mpi = b.option(bool, "use_mpi", "Enable MPI distributed memory") orelse false;
    const use_openmp = b.option(bool, "use_openmp", "Enable OpenMP shared memory") orelse false;
    const use_netcdf = b.option(bool, "use_netcdf", "Enable NetCDF output") orelse false;
    const use_double = b.option(bool, "use_double", "Enable double precision (gfortran -fdefault-real-8)") orelse false;
    const debug_mode = b.option(bool, "debug", "Enable debug build (-O0 -g)") orelse false;
    const netcdf_base: ?[]const u8 = b.option([]const u8, "netcdf_base", "Path to NetCDF installation prefix (or set NETCDFBASE env var)");
    const fortran_compiler: []const u8 = b.option([]const u8, "fc", "Fortran compiler to use") orelse
        (if (use_mpi) "mpifort" else "gfortran");

    // ── Generate build shell script ────────────────────────────────────
    // Fortran modules (.mod) are side-effects of compilation and must live
    // in a single shared directory. We generate a self-contained sh script
    // that preprocesses and compiles each source in topological order,
    // then links the final binary — matching the original Makefile behavior.

    const wf = b.addWriteFiles();
    const script_content = generateBuildScript(
        b.allocator,
        fortran_compiler,
        use_mpi,
        use_openmp,
        use_netcdf,
        use_double,
        debug_mode,
        netcdf_base,
    );
    _ = wf.add("build_cm1.sh", script_content);

    // ── Run the build script ───────────────────────────────────────────
    const build_run = b.addSystemCommand(&.{"sh"});
    build_run.addFileArg(wf.getDirectory().path(b, "build_cm1.sh"));

    // Positional args: SRC_DIR, OUT_DIR, WORK_DIR
    build_run.addArg(b.pathFromRoot("src"));
    build_run.addArg(b.getInstallPath(.bin, ""));
    // Use a stable work directory under the zig cache for .mod/.o intermediates
    build_run.addArg(b.pathJoin(&.{ b.cache_root.path orelse ".", "cm1-work" }));

    b.getInstallStep().dependOn(&build_run.step);

    // ── "clean" step ───────────────────────────────────────────────────
    const clean_step = b.step("clean", "Remove build artifacts");
    const clean_cmd = b.addSystemCommand(&.{
        "sh",                                             "-c",
        "rm -rf zig-out .zig-cache && rm -f run/cm1.exe",
    });
    clean_step.dependOn(&clean_cmd.step);
}

/// Generates a self-contained POSIX shell script that builds CM1.
fn generateBuildScript(
    allocator: std.mem.Allocator,
    fc: []const u8,
    use_mpi: bool,
    use_openmp: bool,
    use_netcdf: bool,
    use_double: bool,
    debug_mode: bool,
    netcdf_base: ?[]const u8,
) []const u8 {
    var buf = std.ArrayListUnmanaged(u8){};

    emit(allocator, &buf, "#!/bin/sh\nset -e\n\n");
    emit(allocator, &buf, "# CM1 Build Script (generated by build.zig)\n\n");
    emit(allocator, &buf, "SRC_DIR=\"$1\"\nOUT_DIR=\"$2\"\nWORK_DIR=\"$3\"\n\n");
    emit(allocator, &buf, "if [ -z \"$SRC_DIR\" ] || [ -z \"$OUT_DIR\" ] || [ -z \"$WORK_DIR\" ]; then\n");
    emit(allocator, &buf, "    echo \"Usage: $0 <src_dir> <out_dir> <work_dir>\"\n    exit 1\nfi\n\n");
    emit(allocator, &buf, "mkdir -p \"$WORK_DIR\" \"$OUT_DIR\"\ncd \"$WORK_DIR\"\n\n");

    // Compiler
    emitFmt(allocator, &buf, "FC=\"{s}\"\n", .{fc});

    // CPP defines
    emit(allocator, &buf, "CPP_DEFS=\"");
    if (use_mpi) emit(allocator, &buf, " -DMPI");
    if (use_openmp) emit(allocator, &buf, " -DOPENMP");
    if (use_double) emit(allocator, &buf, " -DDP");
    if (use_netcdf) emit(allocator, &buf, " -DNETCDF -DNCFPLUS");
    if (debug_mode) emit(allocator, &buf, " -D_B4B");
    emit(allocator, &buf, "\"\n");

    // Fortran flags
    emit(allocator, &buf, "FFLAGS=\"-ffree-form -ffree-line-length-none -fallow-argument-mismatch");
    if (debug_mode) {
        emit(allocator, &buf, " -g -O0 -fcheck=all -fbacktrace");
    } else {
        emit(allocator, &buf, " -O2 -finline-functions");
    }
    if (use_openmp) emit(allocator, &buf, " -fopenmp");
    if (use_double) emit(allocator, &buf, " -fdefault-real-8");
    if (use_netcdf) {
        if (netcdf_base) |base| {
            emitFmt(allocator, &buf, " -I{s}/include", .{base});
        }
    }
    emit(allocator, &buf, "\"\n\n");

    // Link flags
    emit(allocator, &buf, "LINK_FLAGS=\"");
    if (use_openmp) emit(allocator, &buf, " -fopenmp");
    emit(allocator, &buf, "\"\n");

    emit(allocator, &buf, "LINK_LIBS=\"");
    if (use_netcdf) {
        if (netcdf_base) |base| {
            emitFmt(allocator, &buf, " -L{s}/lib", .{base});
        }
        emit(allocator, &buf, " -lnetcdf -lnetcdff");
    }
    emit(allocator, &buf, "\"\n\n");

    // Compile function + progress counter
    emitFmt(allocator, &buf, "TOTAL={d}\n", .{sources_ordered.len});
    emit(allocator, &buf, "COUNT=0\n\n");
    emit(allocator, &buf, "compile_source() {\n");
    emit(allocator, &buf, "    src=\"$1\"\n");
    emit(allocator, &buf, "    base=\"${src%.F}\"\n");
    emit(allocator, &buf, "    COUNT=$((COUNT + 1))\n");
    emit(allocator, &buf, "    printf \"  [%2d/%d] cpp   %s\\n\" \"$COUNT\" \"$TOTAL\" \"$src\"\n");
    emit(allocator, &buf, "    cpp -C -P -traditional -ffreestanding $CPP_DEFS \"$SRC_DIR/$src\" > \"${base}.f90\"\n");
    emit(allocator, &buf, "    printf \"  [%2d/%d] fc    %s.f90\\n\" \"$COUNT\" \"$TOTAL\" \"$base\"\n");
    emit(allocator, &buf, "    $FC $FFLAGS -c \"${base}.f90\"\n");
    emit(allocator, &buf, "}\n\n");

    emit(allocator, &buf, "echo \"=== CM1 Build ===\"\n");
    emit(allocator, &buf, "echo \"Compiler : $FC\"\n");
    emit(allocator, &buf, "echo \"Flags    : $FFLAGS\"\n");
    emit(allocator, &buf, "echo \"CPP defs : $CPP_DEFS\"\n");
    emit(allocator, &buf, "echo \"\"\n\n");

    // Compile each source in topological order
    for (sources_ordered) |src| {
        emitFmt(allocator, &buf, "compile_source \"{s}\"\n", .{src});
    }

    // Link
    emit(allocator, &buf, "\necho \"\"\nprintf \"  [link] cm1.exe\\n\"\n");
    emit(allocator, &buf, "$FC $LINK_FLAGS");
    for (sources_ordered) |src| {
        const base = src[0 .. src.len - 2];
        emitFmt(allocator, &buf, " \"{s}.o\"", .{base});
    }
    emit(allocator, &buf, " $LINK_LIBS -o \"$OUT_DIR/cm1.exe\"\n\n");
    emit(allocator, &buf, "echo \"\"\necho \"=== Build complete: $OUT_DIR/cm1.exe ===\"\n");

    return buf.toOwnedSlice(allocator) catch @panic("OOM");
}

/// Append a literal string to the script buffer.
fn emit(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), str: []const u8) void {
    buf.appendSlice(allocator, str) catch @panic("OOM");
}

/// Append a formatted string to the script buffer.
fn emitFmt(allocator: std.mem.Allocator, buf: *std.ArrayListUnmanaged(u8), comptime fmt: []const u8, args: anytype) void {
    buf.print(allocator, fmt, args) catch @panic("OOM");
}
