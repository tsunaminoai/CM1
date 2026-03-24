const std = @import("std");

const FortranSource = struct {
    name: []const u8,
    deps: []const []const u8 = &.{},
};

// The full source list with dependencies, transcribed from src/Makefile
const sources: []const FortranSource = &.{
    .{ .name = "constants" },
    .{ .name = "input" },
    .{ .name = "bc", .deps = &.{ "constants", "input" } },
    .{ .name = "comm", .deps = &.{ "input", "bc" } },
    .{ .name = "singleton" },
    .{ .name = "poiss", .deps = &.{ "input", "singleton" } },
    .{ .name = "cm1libs", .deps = &.{ "input", "constants" } },
    .{ .name = "misclibs", .deps = &.{ "constants", "input", "goddard", "lfoice" } },
    .{ .name = "adv_routines", .deps = &.{ "input", "constants", "pdef", "comm" } },
    .{ .name = "adv", .deps = &.{ "constants", "input", "pdef", "adv_routines", "ib_module" } },
    // ... transcribe the rest of the ~85 sources from the Makefile dependency section
    // Each entry maps directly to a line like:
    //   adv.o: constants.o input.o pdef.o adv_routines.o ib_module.o
};

pub fn build(b: *std.Build) void {
    // ---------------------------------------------------------------
    // Build Options (replaces make variable passing)
    // ---------------------------------------------------------------
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
        "Path to NetCDF installation (e.g., $CONDA_PREFIX)",
    );
    // const gpu_type = b.option(
    //     enum { a100, v100 },
    //     "gpu-type",
    //     "GPU architecture for OpenACC",
    // ) orelse .a100;

    // ---------------------------------------------------------------
    // Resolve compiler binary and flags
    // ---------------------------------------------------------------
    const fc: []const u8 = if (use_mpi) "mpifort" else switch (compiler) {
        .gfortran => "gfortran",
        .ifort => "ifort",
        .nvfortran => "nvfortran",
        .ftn => "ftn",
    };

    // Build the CPP preprocessor defines
    var cpp_defines = std.ArrayList([]const u8){};
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

    // Build the Fortran compiler flags
    var fc_flags = std.ArrayList([]const u8){};
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
                "-Mfree",           "-Ktrap=none", "-Mautoinline",
                "-Minline=reshape", "-Kieee",      "-Mnofma",
            }) catch unreachable;
            if (debug_mode) {
                fc_flags.appendSlice(b.allocator, &.{ "-g", "-O0" }) catch unreachable;
            } else {
                fc_flags.appendSlice(b.allocator, &.{ "-g", "-O2" }) catch unreachable;
            }
            if (use_double) fc_flags.append(b.allocator, "-r8") catch unreachable;
            if (use_openmp) fc_flags.append(b.allocator, "-mp") catch unreachable;
            // ... OpenACC flags based on gpu_type
        },
        .ftn => {
            fc_flags.appendSlice(b.allocator, &.{ "-O2", "-Ovector2", "-Oscalar2", "-Othread2" }) catch unreachable;
            if (use_openmp)
                fc_flags.append(b.allocator, "-h omp") catch unreachable
            else
                fc_flags.append(b.allocator, "-h noomp") catch unreachable;
        },
    }

    if (use_netcdf) {
        if (netcdf_base) |base| {
            const inc = b.fmt("-I{s}/include", .{base});
            fc_flags.append(b.allocator, inc) catch unreachable;
        }
    }

    // ---------------------------------------------------------------
    // Build each Fortran source as a step in the DAG
    // ---------------------------------------------------------------
    const src_dir = b.path("src");
    var object_steps = std.StringHashMap(*std.Build.Step.Run).init(b.allocator);
    var object_files = std.ArrayList([]const u8){};
    defer object_steps.deinit();
    defer object_files.deinit(b.allocator);

    for (sources) |src| {
        const f_file = b.fmt("src/{s}.F", .{src.name});
        const f90_file = b.fmt("src/{s}.f90", .{src.name});
        const o_file = b.fmt("src/{s}.o", .{src.name});

        // Step 1: CPP preprocessing (.F -> .f90)
        const cpp_step = b.addSystemCommand(&.{ "cpp", "-C", "-P", "-traditional", "-ffreestanding" });
        for (cpp_defines.items) |def| {
            cpp_step.addArg(def);
        }
        cpp_step.addFileArg(b.path(f_file));
        const preprocessed = cpp_step.captureStdOut();

        // Step 2: gfortran compile (.f90 -> .o)
        const compile_step = b.addSystemCommand(&.{fc});
        for (fc_flags.items) |flag| {
            compile_step.addArg(flag);
        }
        compile_step.addArg("-c");
        compile_step.addFileArg(preprocessed);
        compile_step.addArg("-o");
        const obj_output = compile_step.addOutputFileArg(o_file);
        compile_step.addFileArg(b.path(f90_file));

        // Wire up Fortran module dependencies
        for (src.deps) |dep_name| {
            if (object_steps.get(dep_name)) |dep_step| {
                compile_step.step.dependOn(&dep_step.step);
            }
        }

        object_steps.put(src.name, compile_step) catch unreachable;
        object_files.append(b.allocator, obj_output.) catch unreachable;
    }

    // ---------------------------------------------------------------
    // Link step: produce cm1.exe
    // ---------------------------------------------------------------
    const link_step = b.addSystemCommand(&.{fc});
    for (fc_flags.items) |flag| {
        link_step.addArg(flag);
    }
    if (use_netcdf) {
        if (netcdf_base) |base| {
            link_step.addArg(b.fmt("-L{s}/lib", .{base}));
        }
        link_step.addArgs(&.{ "-lnetcdf", "-lnetcdff" });
    }
    // Add all object files
    var it = object_steps.valueIterator();
    while (it.next()) |step_ptr| {
        link_step.step.dependOn(&step_ptr.*.step);
    }
    // ... add object file paths to link command
    link_step.addArg("-o");
    link_step.addArg("run/cm1.exe");

    // ---------------------------------------------------------------
    // Top-level build step
    // ---------------------------------------------------------------
    const build_step = b.step("cm1", "Build CM1 atmospheric model");
    build_step.dependOn(&link_step.step);
    b.default_step = build_step;

    // ---------------------------------------------------------------
    // Clean step
    // ---------------------------------------------------------------
    const clean_step = b.addSystemCommand(&.{ "rm", "-f" });
    clean_step.addArgs(&.{ "src/*.f90", "src/*.o", "src/*.a", "src/*.mod" });
    clean_step.setCwd(src_dir);
    const clean = b.step("clean", "Clean build artifacts");
    clean.dependOn(&clean_step.step);
}
