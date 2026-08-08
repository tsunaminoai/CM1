const std = @import("std");

const FortranSource = struct {
    name: []const u8,
    deps: []const []const u8 = &.{},
};

// Sources in topological order (dependencies before dependents).
// Derived from src/Makefile: SRC list (lines 208-298) and DEPENDENCIES (lines 347-423).
const sources: []const FortranSource = &.{
    // ── Level 0: leaf nodes (no dependencies) ────────────────────────────────
    .{ .name = "constants" },
    .{ .name = "input" },
    .{ .name = "singleton" },
    .{ .name = "getcape" },
    .{ .name = "radlib3d" },
    .{ .name = "sfclay" },
    .{ .name = "slab" },
    .{ .name = "oml" },
    .{ .name = "module_gfs_machine" },
    .{ .name = "module_ra_etc" },
    .{ .name = "module_mp_nssl_2mom" },
    .{ .name = "module_mp_p3" },
    .{ .name = "module_libmassv" },
    .{ .name = "module_sf_exchcoef" },
    .{ .name = "ccpp_kind_types" },
    .{ .name = "stopcm1" },
    // ── Level 1 ───────────────────────────────────────────────────────────────
    .{ .name = "bc", .deps = &.{ "constants", "input" } },
    .{ .name = "cm1libs", .deps = &.{ "input", "constants" } },
    .{ .name = "lfoice", .deps = &.{"input"} },
    .{ .name = "maxmin", .deps = &.{"input"} },
    .{ .name = "diff2", .deps = &.{ "constants", "input" } },
    .{ .name = "eddy_recycle", .deps = &.{ "constants", "input" } },
    .{ .name = "lsnudge", .deps = &.{ "constants", "input" } },
    .{ .name = "interp_routines", .deps = &.{ "constants", "input" } },
    .{ .name = "writeout_nc", .deps = &.{ "constants", "input" } },
    .{ .name = "testcase_simple_phys", .deps = &.{ "constants", "input" } },
    .{ .name = "morrison", .deps = &.{ "input", "constants" } },
    .{ .name = "kessler", .deps = &.{ "constants", "input" } },
    .{ .name = "irrad3d", .deps = &.{"radlib3d"} },
    .{ .name = "sorad3d", .deps = &.{"radlib3d"} },
    .{ .name = "module_gfs_physcons", .deps = &.{"module_gfs_machine"} },
    .{ .name = "module_ra_rrtmg_lw", .deps = &.{"module_ra_etc"} },
    .{ .name = "module_mp_radar", .deps = &.{"module_ra_etc"} },
    .{ .name = "module_sf_mynn", .deps = &.{"module_ra_etc"} },
    .{ .name = "module_bl_myjpbl", .deps = &.{"module_ra_etc"} },
    .{ .name = "module_sf_myjsfc", .deps = &.{"module_ra_etc"} },
    .{ .name = "mp_radar", .deps = &.{"ccpp_kind_types"} },
    .{ .name = "bl_ysu", .deps = &.{"ccpp_kind_types"} },
    .{ .name = "sf_sfclayrev", .deps = &.{"ccpp_kind_types"} },
    .{ .name = "cu_ntiedtke", .deps = &.{"ccpp_kind_types"} },
    // ── Level 2 ───────────────────────────────────────────────────────────────
    .{ .name = "comm", .deps = &.{ "input", "bc" } },
    .{ .name = "goddard", .deps = &.{ "constants", "input", "cm1libs" } },
    .{ .name = "turbtend", .deps = &.{ "constants", "input", "cm1libs" } },
    .{ .name = "sfcphys", .deps = &.{ "constants", "input", "cm1libs" } },
    .{ .name = "module_gfs_funcphys", .deps = &.{ "module_gfs_machine", "module_gfs_physcons" } },
    .{ .name = "module_bl_mynn_common", .deps = &.{ "module_ra_etc", "module_gfs_machine" } },
    .{ .name = "module_ra_rrtmg_sw", .deps = &.{ "module_ra_etc", "module_ra_rrtmg_lw" } },
    .{ .name = "mp_wsm6", .deps = &.{ "ccpp_kind_types", "module_libmassv", "mp_radar" } },
    .{ .name = "module_sf_gfdl", .deps = &.{ "module_gfs_machine", "module_gfs_physcons", "module_gfs_funcphys", "module_sf_exchcoef" } },
    // ── Level 3 ───────────────────────────────────────────────────────────────
    .{ .name = "poiss", .deps = &.{ "input", "singleton" } },
    .{ .name = "misclibs", .deps = &.{ "constants", "input", "goddard", "lfoice" } },
    .{ .name = "pdef", .deps = &.{ "input", "bc", "comm" } },
    .{ .name = "ib_module", .deps = &.{ "input", "constants", "bc", "comm" } },
    .{ .name = "turbnba", .deps = &.{ "constants", "input", "bc", "comm" } },
    .{ .name = "module_bl_mynn", .deps = &.{"module_bl_mynn_common"} },
    .{ .name = "mp_wsm6_effectRad", .deps = &.{ "ccpp_kind_types", "mp_wsm6" } },
    .{ .name = "module_bl_gfsedmf", .deps = &.{ "module_gfs_funcphys", "module_gfs_machine", "module_gfs_physcons", "module_sf_gfdl" } },
    .{ .name = "module_mp_jensen_ishmael", .deps = &.{ "input", "module_ra_etc" } },
    .{ .name = "thompson", .deps = &.{ "input", "module_mp_radar", "module_ra_etc" } },
    .{ .name = "mmm_physics_wrapper", .deps = &.{ "ccpp_kind_types", "bl_ysu", "mp_wsm6", "mp_wsm6_effectRad", "sf_sfclayrev", "cu_ntiedtke" } },
    // ── Level 4 ───────────────────────────────────────────────────────────────
    .{ .name = "adv_routines", .deps = &.{ "input", "constants", "pdef", "comm" } },
    .{ .name = "anelp", .deps = &.{ "constants", "input", "misclibs", "bc", "poiss" } },
    .{ .name = "parcel", .deps = &.{ "constants", "input", "cm1libs", "bc", "comm", "writeout_nc" } },
    .{ .name = "statpack", .deps = &.{ "constants", "input", "maxmin", "misclibs", "cm1libs", "writeout_nc" } },
    .{ .name = "module_bl_mynn_wrapper", .deps = &.{ "module_bl_mynn_common", "module_bl_mynn" } },
    .{ .name = "radtrns3d", .deps = &.{ "irrad3d", "sorad3d", "radlib3d" } },
    .{ .name = "restart_write", .deps = &.{ "constants", "input", "writeout_nc", "lsnudge" } },
    // ── Level 5 ───────────────────────────────────────────────────────────────
    .{ .name = "adv", .deps = &.{ "constants", "input", "pdef", "adv_routines", "ib_module" } },
    .{ .name = "sound", .deps = &.{ "constants", "input", "misclibs", "bc", "comm", "ib_module" } },
    .{ .name = "sounde", .deps = &.{ "constants", "input", "misclibs", "bc", "comm", "ib_module" } },
    .{ .name = "soundns", .deps = &.{ "constants", "input", "misclibs", "bc", "comm", "ib_module" } },
    .{ .name = "soundcb", .deps = &.{ "constants", "input", "misclibs", "bc", "comm", "ib_module" } },
    .{ .name = "init_terrain", .deps = &.{ "constants", "input", "bc", "comm", "adv_routines" } },
    .{ .name = "solve3", .deps = &.{ "constants", "input", "bc", "comm", "adv_routines", "misclibs", "parcel", "lsnudge" } },
    .{ .name = "azimavg", .deps = &.{ "input", "constants", "cm1libs", "writeout_nc", "comm", "bc" } },
    .{ .name = "base", .deps = &.{ "constants", "input", "bc", "comm", "goddard", "cm1libs", "getcape" } },
    .{ .name = "writeout", .deps = &.{ "constants", "input", "bc", "comm", "writeout_nc", "misclibs", "getcape", "ib_module", "cm1libs", "sfcphys", "eddy_recycle" } },
    .{ .name = "restart_read", .deps = &.{ "constants", "input", "writeout_nc", "lsnudge", "goddard", "lfoice", "restart_write" } },
    .{ .name = "mp_driver", .deps = &.{ "constants", "input", "misclibs", "kessler", "goddard", "thompson", "lfoice", "morrison", "module_mp_nssl_2mom", "module_mp_p3", "module_mp_jensen_ishmael", "mmm_physics_wrapper", "mp_wsm6" } },
    .{ .name = "radiation_driver", .deps = &.{ "constants", "input", "bc", "radtrns3d", "module_ra_etc", "module_ra_rrtmg_lw", "module_ra_rrtmg_sw" } },
    .{ .name = "init_physics", .deps = &.{ "constants", "input", "sfclay", "slab", "radtrns3d", "irrad3d", "goddard", "module_ra_rrtmg_lw", "module_ra_rrtmg_sw", "module_sf_gfdl", "module_sf_mynn", "module_sf_myjsfc", "sf_sfclayrev", "cu_ntiedtke" } },
    .{ .name = "init_surface", .deps = &.{ "constants", "input", "oml" } },
    .{ .name = "solve1", .deps = &.{ "constants", "input", "bc", "diff2", "turbtend", "misclibs", "testcase_simple_phys", "eddy_recycle", "lsnudge" } },
    // ── Level 6 ───────────────────────────────────────────────────────────────
    .{ .name = "hifrq", .deps = &.{ "input", "constants", "cm1libs", "adv", "bc", "ib_module", "writeout_nc", "comm" } },
    .{ .name = "pdcomp", .deps = &.{ "constants", "input", "adv", "poiss", "ib_module" } },
    .{ .name = "turb", .deps = &.{ "constants", "input", "bc", "comm", "sfcphys", "sfclay", "slab", "oml", "cm1libs", "module_sf_gfdl", "module_bl_gfsedmf", "module_sf_mynn", "module_bl_mynn_wrapper", "module_bl_myjpbl", "module_sf_myjsfc", "turbnba", "misclibs", "ib_module", "turbtend", "mmm_physics_wrapper" } },
    .{ .name = "param", .deps = &.{ "constants", "input", "init_terrain", "bc", "comm", "thompson", "morrison", "module_mp_nssl_2mom", "goddard", "lfoice", "module_mp_p3", "module_mp_jensen_ishmael", "ib_module", "eddy_recycle", "lsnudge", "mp_wsm6", "ccpp_kind_types" } },
    .{ .name = "solve2", .deps = &.{ "constants", "input", "bc", "comm", "adv", "sound", "sounde", "soundns", "soundcb", "anelp", "misclibs", "module_mp_nssl_2mom", "ib_module" } },
    // ── Level 7 ───────────────────────────────────────────────────────────────
    .{ .name = "domaindiag", .deps = &.{ "constants", "input", "interp_routines", "cm1libs", "getcape", "sfcphys", "turb", "lsnudge", "writeout_nc", "testcase_simple_phys" } },
    .{ .name = "init3d", .deps = &.{ "constants", "input", "misclibs", "cm1libs", "bc", "comm", "module_mp_nssl_2mom", "poiss", "parcel", "ib_module", "turb" } },
    // ── Level 8: main program ─────────────────────────────────────────────────
    .{ .name = "cm1", .deps = &.{ "constants", "input", "param", "base", "init3d", "misclibs", "solve1", "solve2", "solve3", "pdcomp", "diff2", "turb", "statpack", "writeout", "restart_write", "restart_read", "radiation_driver", "radtrns3d", "domaindiag", "azimavg", "hifrq", "parcel", "init_physics", "init_surface", "mp_driver", "ib_module", "eddy_recycle", "lsnudge" } },
};

pub fn build(b: *std.Build) void {
    // ── Build options (replaces make variable passing) ────────────────────────
    const use_openmp = b.option(bool, "openmp", "Enable OpenMP parallelism") orelse false;
    const use_mpi = b.option(bool, "mpi", "Enable MPI distributed memory") orelse false;
    const use_netcdf = b.option(bool, "netcdf", "Enable NetCDF output") orelse false;
    const use_double = b.option(bool, "double", "Enable double precision (NVHPC only)") orelse false;
    const use_openacc = b.option(bool, "openacc", "Enable OpenACC GPU offloading") orelse false;
    const debug_mode = b.option(bool, "debug", "Build in debug mode") orelse false;
    const compiler = b.option(
        enum { gfortran, ifort, nvfortran, ftn },
        "fc",
        "Fortran compiler to use",
    ) orelse .gfortran;
    const netcdf_base = b.option(
        []const u8,
        "netcdf-base",
        "Path to NetCDF installation (e.g. $NETCDFBASE)",
    );
    // ── Resolve Fortran compiler binary ───────────────────────────────────────
    const fc: []const u8 = if (use_mpi) "mpifort" else switch (compiler) {
        .gfortran => "gfortran",
        .ifort => "ifort",
        .nvfortran => "nvfortran",
        .ftn => "ftn",
    };

    // Fortran .mod files are compiler-version-locked, so a toolchain swap under
    // an otherwise identical argv must invalidate cached objects. The version
    // is written to a stamp file that each compile/link step declares as an
    // input, putting its content into the cache manifest. (An environment
    // variable won't do: setting one clones the whole ambient environment into
    // the manifest, and any transient variable then defeats caching.)
    const fc_version: []const u8 = blk: {
        var exit_code: u8 = undefined;
        const stdout = b.runAllowFail(
            &.{ fc, "--version" },
            &exit_code,
            .ignore,
        ) catch break :blk "unknown";
        break :blk stdout[0 .. std.mem.indexOfScalar(u8, stdout, '\n') orelse stdout.len];
    };
    const fc_stamp = b.addWriteFiles().add("fc-version.txt", fc_version);

    // ── CPP preprocessor defines ──────────────────────────────────────────────
    // In Zig 0.15, ArrayList is unmanaged: allocator passed to every call.
    var cpp_defines: std.ArrayList([]const u8) = .empty;
    defer cpp_defines.deinit(b.allocator);
    if (use_mpi) cpp_defines.append(b.allocator, "-DMPI") catch unreachable;
    if (use_double) cpp_defines.append(b.allocator, "-DDP") catch unreachable;
    if (use_openmp) cpp_defines.append(b.allocator, "-DOPENMP") catch unreachable;
    if (use_openacc) cpp_defines.append(b.allocator, "-D_OPENACC") catch unreachable;
    if (debug_mode) cpp_defines.append(b.allocator, "-D_B4B") catch unreachable;
    if (use_netcdf) {
        cpp_defines.append(b.allocator, "-DNETCDF") catch unreachable;
        cpp_defines.append(b.allocator, "-DNCFPLUS") catch unreachable;
    }

    // ── Fortran compiler flags ────────────────────────────────────────────────
    var fc_flags: std.ArrayList([]const u8) = .empty;
    defer fc_flags.deinit(b.allocator);
    switch (compiler) {
        .gfortran => {
            fc_flags.appendSlice(b.allocator, &.{
                "-ffree-form",
                "-ffree-line-length-none",
                "-O2",
                "-finline-functions",
                "-fallow-argument-mismatch",
            }) catch unreachable;
            if (use_openmp) fc_flags.append(b.allocator, "-fopenmp") catch unreachable;
        },
        .ifort => {
            fc_flags.appendSlice(b.allocator, &.{
                "-O1",
                "-assume",
                "byterecl",
                "-fp-model",
                "precise",
                "-ftz",
                "-no-fma",
                "-diag-disable=10448",
            }) catch unreachable;
            if (use_openmp) fc_flags.append(b.allocator, "-qopenmp") catch unreachable;
        },
        .nvfortran => {
            fc_flags.appendSlice(b.allocator, &.{
                "-Mfree", "-Ktrap=none", "-Mautoinline", "-Minline=reshape", "-Kieee", "-Mnofma",
            }) catch unreachable;
            if (debug_mode) {
                fc_flags.appendSlice(b.allocator, &.{ "-g", "-O0" }) catch unreachable;
            } else {
                fc_flags.appendSlice(b.allocator, &.{ "-g", "-O2" }) catch unreachable;
            }
            if (use_double) fc_flags.append(b.allocator, "-r8") catch unreachable;
            if (use_openmp) fc_flags.append(b.allocator, "-mp") catch unreachable;
        },
        .ftn => {
            fc_flags.appendSlice(b.allocator, &.{ "-O2", "-Ovector2", "-Oscalar2", "-Othread2" }) catch unreachable;
            if (use_openmp) {
                fc_flags.append(b.allocator, "-h omp") catch unreachable;
            } else {
                fc_flags.append(b.allocator, "-h noomp") catch unreachable;
            }
        },
    }
    if (use_netcdf) {
        if (netcdf_base) |base| {
            fc_flags.append(b.allocator, b.fmt("-I{s}/include", .{base})) catch unreachable;
        }
    }

    // ── Module dependency closure ─────────────────────────────────────────────
    // Each compile step writes its .mod files to its own declared output
    // directory and reads dependencies' .mod files via -I. gfortran needs the
    // .mod of every module a file USEs directly, but the Makefile-derived edge
    // list was written under a shared module directory where under-declared
    // transitive edges were masked — so wire the transitive closure. `sources`
    // is topologically ordered, so one forward pass suffices.
    var closures = std.StringHashMap([]const []const u8).init(b.allocator);
    for (sources) |src| {
        var set: std.StringArrayHashMapUnmanaged(void) = .empty;
        for (src.deps) |dep| {
            set.put(b.allocator, dep, {}) catch unreachable;
            for (closures.get(dep).?) |transitive| {
                set.put(b.allocator, transitive, {}) catch unreachable;
            }
        }
        closures.put(src.name, set.keys()) catch unreachable;
    }

    // ── Per-source build steps ────────────────────────────────────────────────
    var mod_dirs = std.StringHashMap(std.Build.LazyPath).init(b.allocator);
    defer mod_dirs.deinit();

    var object_files: std.ArrayList(std.Build.LazyPath) = .empty;
    defer object_files.deinit(b.allocator);

    for (sources) |src| {
        const f_file = b.fmt("src/{s}.F", .{src.name});

        // Step 1: CPP preprocessing (.F → .f90) using zig cc (bundled clang).
        // Using zig cc means no separate cpp tool required.
        const cpp_step = b.addSystemCommand(&.{
            b.graph.zig_exe, "cc",
            "-x",   "c",
            "-E",   "-P",
            "-ffreestanding",
            "-traditional-cpp",
            "-Wno-invalid-pp-token",
        });
        for (cpp_defines.items) |def| cpp_step.addArg(def);
        cpp_step.addFileArg(b.path(f_file));
        cpp_step.addArg("-o");
        const f90_lp = cpp_step.addOutputFileArg(b.fmt("{s}.f90", .{src.name}));

        // Step 2: Fortran compilation (.f90 → .o)
        const compile_step = b.addSystemCommand(&.{fc});
        compile_step.addFileInput(fc_stamp);
        for (fc_flags.items) |flag| compile_step.addArg(flag);

        // Emitted .mod files land in this step's own declared output directory
        // so the cache tracks them alongside the .o.
        const mods_lp = switch (compiler) {
            .gfortran, .ftn => compile_step.addPrefixedOutputDirectoryArg("-J", "mods"),
            .ifort, .nvfortran => blk: {
                compile_step.addArg("-module");
                break :blk compile_step.addOutputDirectoryArg("mods");
            },
        };

        // Search every (transitive) dependency's module directory. These are
        // content-addressed paths, so this also hashes the dependency chain
        // into this step's cache manifest and wires the step dependencies.
        for (closures.get(src.name).?) |dep_name| {
            compile_step.addPrefixedDirectoryArg("-I", mod_dirs.get(dep_name).?);
        }

        compile_step.addArg("-c");
        compile_step.addFileArg(f90_lp);
        compile_step.addArg("-o");
        const obj_lp = compile_step.addOutputFileArg(b.fmt("{s}.o", .{src.name}));

        mod_dirs.put(src.name, mods_lp) catch unreachable;
        object_files.append(b.allocator, obj_lp) catch unreachable;
    }

    // ── Link step ─────────────────────────────────────────────────────────────
    // Always link with the Fortran driver: it knows its own runtime libraries
    // (libgfortran, libgomp via -fopenmp, ...), and mpifort adds MPI's.
    const link_step = b.addSystemCommand(&.{fc});
    link_step.addFileInput(fc_stamp);
    for (fc_flags.items) |flag| link_step.addArg(flag);

    // Add all object files (also wires the step dependencies automatically).
    for (object_files.items) |obj| link_step.addFileArg(obj);

    if (use_netcdf) {
        if (netcdf_base) |base| {
            link_step.addArg(b.fmt("-L{s}/lib", .{base}));
        }
        // Objects precede libs here, so the Fortran wrapper lib must come
        // before the C lib it depends on.
        link_step.addArgs(&.{ "-lnetcdff", "-lnetcdf" });
    }

    link_step.addArg("-o");
    const exe_lp = link_step.addOutputFileArg("cm1.exe");

    // ── Install ───────────────────────────────────────────────────────────────
    // `zig build` installs to zig-out/bin/cm1.exe.
    // `zig build -p "$out"` (Nix) installs to $out/bin/cm1.exe.
    b.getInstallStep().dependOn(&b.addInstallBinFile(exe_lp, "cm1.exe").step);
    b.default_step = b.getInstallStep();

    const cm1_step = b.step("cm1", "Build CM1 atmospheric model");
    cm1_step.dependOn(b.getInstallStep());

    // ── Clean ─────────────────────────────────────────────────────────────────
    const clean_step = b.addSystemCommand(&.{
        "sh", "-c",
        "rm -f src/*.f90 src/*.o src/*.a src/*.mod",
    });
    const clean = b.step("clean", "Remove build artifacts from src/");
    clean.dependOn(&clean_step.step);

    // ── Bench-make: original Makefile build for timing comparison ─────────────
    // Usage:
    //   time zig build clean && time zig build           # Zig build
    //   time zig build bench-make                        # Make build (serial, gfortran)
    //   time zig build bench-make -- -j$(nproc)          # Make build (parallel)
    //
    // Note: bench-make always starts from a clean src/ so times are comparable.
    const fc_str = switch (compiler) {
        .gfortran => "gfortran",
        .ifort => "ifort",
        .nvfortran => "nvfortran",
        .ftn => "ftn",
    };
    const make_cmd = b.fmt(
        "cd src && make clean && make FC={s}{s}{s}{s}{s}",
        .{
            fc_str,
            if (use_mpi) " USE_MPI=true" else "",
            if (use_netcdf) " USE_NETCDF=true" else "",
            if (use_openmp) " USE_OPENMP=true" else "",
            if (use_netcdf and netcdf_base != null)
                b.fmt(" NETCDFBASE={s}", .{netcdf_base.?})
            else
                "",
        },
    );
    const bench_make_step = b.addSystemCommand(&.{ "sh", "-c", make_cmd });
    const bench_make = b.step("bench-make", "Build via original Makefile for timing comparison");
    bench_make.dependOn(&bench_make_step.step);

    // ── Namelist generator (Zig utility) ──────────────────────────────────────
    const namelist_exe = b.addExecutable(.{
        .name = "generate_namelist",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/generate_namelist.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(namelist_exe);
}
