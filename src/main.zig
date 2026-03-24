//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("CM1_lib");

pub const Param0 = struct {
    //nx - Total number of grid points in x direction
    nx: usize = 60,

    // ny - Total number of grid points in y direction
    ny: usize = 60,

    // nz - Total number of grid points in z direction
    nz: usize = 40,

    // ppnode - MPI processes per node
    //  NOTEs:  - ppnode is used for input/output purposes only.
    //          - This is hardware dependent, so check the documentation
    //            for your supercomputer.
    //          - For NCAR's yellowstone, use ppnode=16.
    //          - For NCAR's cheyenne, use ppnode=36.
    //          - If you're not certain what to use, just take a guess;
    //            this doesn't affect model performance, but it can make
    //            parallel I/O a little faster and cleaner (i.e., fewer
    //            restart files, for example).
    ppnode: usize = 128,
    // timeformat - Format for text printout of model integration time: 1 = seconds 2 = minutes 3 = hours 4 = days
    timeformat: enum(u4) { seconds = 1, minutes, hours, days } = .minutes,
    // 0 = Do not provide provide timing statistics 1 = Provide timing statistics at end of simulation 2 = The same as 1, but include time required to complete each time step
    timestats: enum(u4) { no_stats = 0, timing_at_end_of_sim_2, include_time_steps } = .timing_at_end_of_sim_2,
    // terrain_flag - .true. = With terrain .false. = No terrain (flat lower boundary)
    terrain_flag: bool = false,

    //procfiles - .true. = Text printout/config files for every MPI process .false. = Only one text printout/config file (Default)
    procfiles: bool = false,
    // outunits - units of x,y,z (ie, space dimensions) in output files 1 = km (default for most cases) 2 = meters
    outunits: enum(u4) { km = 1, meters } = .km,
};

pub const Param1 = struct {
    //  dx - Horizontal grid spacing in x direction (m).
    dx: f32 = 2000.0,

    // dy - Horizontal grid spacing in y direction (m).
    dy: f32 = 2000.0,

    // dz - Vertical grid spacing (m).
    dz: f32 = 500.0,

    // NOTE:
    //    The variables dx,dy,dz are only used when stretch_* = 0.  When
    //    stretch_* >= 1, these variables should be set to an approximately
    //    average value (to minimize roundoff errors).  See README.stretch
    //    for more information.

    // dtl - Large time step (s).
    dtl: f32 = 7.500,

    //    For psolver = 2,3,4,5,6 this time step is limited by the fastest
    //    nonacoustic speed.  For thunderstorm simulations, this is usually
    //    the maximum vertical velocity.  Otherwise, this would be the
    //    propagation speed of gravity waves.  The following is a rough
    //    estimate that usually works well for convective storm simulations:
    //        dtl = min(dx,dy,dz)/67  (rounded to an appropriate value, of course)

    //    For psolver=1, this time step is limited by the propagation speed of
    //    sound waves.  dtl of about min(dx,dy,dz)/700 is recommended.

    //   When using adaptive time-stepping, set dtl to a reasonable
    //   "target" value (i.e., a value you think would probably be best for your
    //   simulation).  This will be used as the initial timestep.

    // timax - Maximum integration time (s).
    timax: f32 = 7200.0,

    // run_time - Integration time (s) to run model from current time. NOTE: Ignored if value is less than zero. NOTE: Overrides timax. (Useful for restarts. For example, just integrate model "run_time" seconds forward from current time.)
    run_time: f32 = -999.9,

    // tapfrq - Frequency of three-dimensional model output (s). Output is in cm1out files.
    tapfrq: f32 = 900.0,
    // rstfrq - Frequency to save model restart files (s). Set to a negative number if restart files are not desired.
    rstfrq: f32 = -3600.0,

    // statfrq - Frequency for calculating some interesting output. (seconds) Set to negative number to output stats every timestep. Output is in cm1out_stats.dat file. See param10 section below for the information that can be requested.
    statfrq: f32 = 60.0,

    // prclfrq - Frequency to output parcel data (s). Note ... this does not affect the parcel calculations themselves, which are always updated every timestep; it merely tells the model how frequently to output the information. Set to a negative number to output parcel data every time step.
    prclfrq: f32 = 60.0,
};

pub const Param2 = struct {
    // cm1setup - Overall CM1 setup, base on how turbulence is handled:
    cm1setup: enum(u4) {
        //           0 = no subgrid turbulence model & no explicit diffusion
        //         - essentially integrates the Euler equations
        //           (adiabatic and inviscid flow)
        //           (although, diffusion can still occur via numerical methods)
        //         - NOTE:  ignores sgsmodel, param7 section, etc
        no_subgrid = 0,
        //   1 = large-eddy simulation (LES)
        //         - integrates filtered Navier-Stokes equations (ie, LES equations)
        //         - NOTE:  user must set "sgsmodel" (and related parameters) below
        large_eddy,
        //   2 = mesoscale modeling with planetary boundary layer (PBL) parameterization
        //         - essentially uses Reynolds-averaged Navier-Stokes (RANS) equations
        //         - NOTE:  user must set "ipbl" below
        mesoscale,
        //   3 = direct numerical simulation (DNS)
        //         - integrates Navier-Stokes equations with explicit diffusion and
        //           diffusivity terms
        //         - NOTE:  user must set the parameters in "param7" section below
        direct_numerical,
        //            --- NEW ---
        //   4 = LES within mesoscale model
        //         - runs LES model within an inner fine mesh; runs mesoscale model
        //           with PBL parameterization beyond.  See param17 section for
        //           settings.
        les_within_mesoscale,
    } = .large_eddy,
    testcase: enum(u8) {
        //         0  =  Default.  (no special physics, forcings, or configutation)
        //       - Most users will use testcase=0.
        default = 0,

        // 1  =  Convective Boundary Layer (CBL) using Large Eddy Simulation (LES)
        //       - Based on Sullivan and Patton (2011, JAS, pg 2395)
        //       - See namelist.input in directory run/config_files/les_ConvBoundLayer
        cbl_using_les,
        // 2  =  Sheared Boundary Layer (SBL) using Large Eddy Simulation (LES)
        //       - Based on Moeng and Sullivan (1994, JAS, pg 999)
        //       - See namelist.input in directory run/config_files/les_ShearBoundLayer
        sheared_boundary_using_les,
        // 3  =  Shallow cumulus clouds using Large Eddy Simulation (LES)
        //       - Based on Siebesma et al (2003, JAS, pg 1201)
        //       - See namelist.input in directory run/config_files/les_ShallowCu
        shallow_cumulus_using_les,
        // 4  =  Nonprecipitating stratocumulus clouds using Large Eddy Simulation (LES)
        //       - Based on Stevens et al (2005, MWR, pg 1443)
        //       - See namelist.input in directory run/config_files/les_StratoCuNoPrecip
        nonprecip_stratro_using_les,
        // 5  =  Drizzling stratocumulus clouds using Large Eddy Simulation (LES)
        //       - Based on Ackerman et al (2009, MWR, pg 1083)
        //       - See namelist.input in directory run/config_files/les_StratoCuDrizzle
        drizzling_strato_using_les,
        // 6  =  Hurricane Boundary Layer (HBL) using Large Eddy Simulation (LES)
        //       - Based on Bryan et al (2017, BLM, pg 475)
        //       - See namelist.input in directory run/config_files/les_HurrBoundLayer
        //       Also: a single-column model (SCM) version using a PBL scheme is
        //       available.
        //       - See namelist.input in directory run/config_files/scm_HurrBoundLayer
        hbl_using_les,

        // 7  =  Precipitating shallow cumulus clouds using Large Eddy Simulation (LES)
        //       - Based on RICO shallow Cu case (VanZanten et al 2011, JAMES)
        //       - See namelist.input in run/config_files/les_ShallowCuPrecip
        precip_shallow_cumulus_using_les,
        // 8  =  Convection Permitting Model (CPM) simulation of Radiative Convective
        //       Equilibrium (RCE)
        //       - Based on Bretherton et al (2005, JAS)
        //       - NOTE: No diurnal cycle.  (Solar constant is fixed at 650.83 W/m2)
        //       - See namelist.input in run/config_files/cpm_RadConvEquil
        cpm_of_rce,
        // 9  =  Stable boundary layer using Large Eddy Simulation (LES)
        //       - Based on Beare et al. (2006, BLM)
        //       - See namelist.input in run/config_files/les_StableBoundLayer
        stable_boundry_using_les,
        // 10 =   Hurricane boundary layer with LES or single-column modeling
        //        with heat and moisture stratification.  Experimental:  uses
        //        nudging to help maintain original temperature and moisture
        //        profiles.  See "tqnudge" in solve.F for more information and
        //        settings.
        hbl_using_les_single_column,
        // 11 =  Convective boundary layer with moisture (but without clouds).
        //       - Based on NCAR LES intercomparison case.
        //       - See namelist.input in run/config_files/les_ConvPBL_moisture
        cbl_without_clouds,
        // 12 =  LES, wind tunnel with immersed cube.
        //       - Based on Martinuzzi and Tropea (1993, JFE).
        //       - See run/config_files/les_ib_windtunnel
        les_wind_tunnel,
        // 14 =  Shallow cumulus convection over land with diurnal cycle.
        //       - Based on Brown et al. (2002, QJRMS, 128, p 1075).
        //       - See namelist.input in run/config_files/les_ShallowCuLand
        shallow_cumulus_diurnal,
        // 15 =  LES, hurricane winds at a coast.
        //       - See run/config_files/les_HurrCoast
        les_hurr_coast,
    },
    // adapt_dt - Use adaptive timestep? (0=no, 1=yes) Model automatically adjusts timestep to maintain stability. NOTE: - a reasonable value must still be assigned to dtl (above), which will be used as the initial timestep
    adapt_dt: bool = false,
    // irst - Is this a restart? (0=no, 1=yes)
    irst: bool = false,
    // rstnum - If this is a restart, this variable specifies the number of the restart file. For example, for file cm1out_0000_0002_rst.dat, rstnum is 2.
    rstnum: usize = 1,
    // iconly - Setup initial conditions only? 1 = creates initial conditions, but does not run model. 0 = creates initial conditions, and proceeds with integration.
    iconly: bool = false,

    // hadvordrs - Order of horizontal advection scheme for scalars. vadvordrs - Order of vertical advection scheme for scalars. hadvordrv - Order of horizontal advection scheme for velocities. vadvordrv - Order of vertical advection scheme for velocities. [Valid options are 2,3,4,5,6,7,8,9,10]

    //    Odd-ordered schemes have implicit diffusion.  If an odd-ordered
    //    scheme is used (3,5,7,9) then idiff can be set to 0 (i.e., no
    //    additional artifical diffusion is typically necessary).

    //    Even-ordered schemes (2,4,6,8,10) usually require additional artifical
    //    diffusion for stability (i.e., idiff=1 is recommended).  Users can use
    //    idiff=1 with difforder=6 and a value of kdiff6 between about 0.02-0.24
    hadvordrs: usize = 5,
    vadvordrs: usize = 5,
    hadvordrv: usize = 5,
    vadvordrv: usize = 5,

    // advwenos - Advect scalars (except pressure) with WENO scheme? advwenov - Advect velocities with WENO scheme? 0 = no 1 = yes, apply on every Runge-Kutta step 2 = yes, apply on final Runge-Kutta step only (default)
    advwenos: usize = 2,
    advwenov: usize = 0,

    // weno_order - Formulation for the WENO scheme. Valid options are 3, 5, 7, 9

    // References:
    // original 3rd and 5th order weno:  Jiang and Shu, 1996,
    // J. Comput. Phys., 126, pg 202

    // original 7th and 9th order weno:  Balsara and Shu, 2000,
    // J. Comput. Phys., 160, pg 405

    //       *** CM1 default formulation ***
    // 5th order with improved smoothness indicators:
    // Borges et al, 2008, J. Comput. Phys., 227, pg 3191
    weno_order: usize = 5,

    // apmasscon - Adjust average pressure perturbation to ensure conservation of dry-air mass? 0 = no 1 = yes

    //      Note:  This option checks the total dry-air mass
    //             in the domain and adjusts the domain-average
    //             pressure perturbation to ensure conservation.
    //             In general, this option is only needed for long
    //             (several days or more) simulations.

    apmasscon: usize = 1,

    // idiff - Include additional artificial diffusion? (0=no, 1=yes) (in addition to any diffusion associated with cm1setup setting)

    //    For idiff=1, diffusion of all variables.
    //    For idiff=2, diffusion only applied to winds (u,v,w).

    //  User must also set difforder and kdiff2 or kdiff6.
    idiff: usize = 0,

    // mdiff - When idiff=1 and difforder=6, apply monotonic version of artificial diffusion?

    //    (0=no, 1=yes)

    //    Reference:  Xue, 2000, MWR, p 2853.

    mdiff: usize = 0,

    // difforder - Order of diffusion scheme. 2=second order, 6=sixth order.

    //    Second order diffusion is not generally recommended.  It is
    //    only used for certain idealized cases.  kdiff2 must be set
    //    appropriately when difforder=2.

    //    Sixth order diffusion is recommended for general use when
    //    diffusion of small scales (2-6 delta) is needed.  User must
    //    also set kdiff6 when difforder=6.

    //    (not available for axisymmetric simulations)
    difforder: usize = 6,
    // imoist - Include moisture? (0=no, 1=yes)
    imoist: usize = 1,
    // pbl - Use a planetary boundary layer (PBL) parameterization?

    //      0 = no

    //      1 = Yonsei University (YSU) PBL parameterization
    //            Reference:  Hong et al, 2006, MWR, p 2318
    //            ("bl_pbl_physics = 1" in WRF)

    //      2 = simple PBL parameterization (Louis-type scheme)
    //          Reference:  Bryan and Rotunno (2009, MWR, pg 1773)

    //      3 = GFS-EDMF  (as configured in HWRF_v4.0a)
    //           Reference:  Hong and Pan, 1996, MWR, pg 2322

    //      4 = MYNN (Mellor-Yamada-Nakanishi-Niino) level 2.5
    //           Reference:  Nakanishi and Niino (2006, BLM)

    //      5 = MYNN (Mellor-Yamada-Nakanishi-Niino) level 3
    //           Reference:  Nakanishi and Niino (2006, BLM)

    //      6 = MYJ (Mellor-Yamada-Janjic)

    // Note:  ipbl >= 1 requires cm1setup = 2
    ipbl: usize = 0,
    // sgsmodel - Subgrid-scale turbulence model for Large Eddy Simulation (LES) Note: only used for cm1setup = 1

    //       1 = TKE scheme (eg, Deardorff, 1980, BLM)
    //           (previously, this was iturb=1)
    //       2 = Smagorinsky scheme (eg, Stevens et al, 1999, JAS, see
    //           Appendix B, section b, "Equilibrium models")
    //           (previously, this was iturb=2)
    //       3 = sgsmodel=1 (TKE scheme) + Sullivan et al (1994, BLM)
    //           version of two-part model
    //           (see tunable parameters in param.F ...
    //            search for "2-part turbulence model")
    //       4 = sgsmodel=1 (TKE scheme) + Bryan (2020, in prep)
    //           version of two-part model
    //           (see tunable parameters in param.F ...
    //            search for "2-part turbulence model")
    //       5 = Nonlinear Backscatter and Anisotropy (NBA) model,
    //           Deardorff-type TKE version (Mirocha et al. 2010, MWR)
    //       6 = Nonlinear Backscatter and Anisotropy (NBA) model,
    //           Smagorinsky-type version (Mirocha et al. 2010, MWR)
    sgsmodel: usize = 1,
    // tconfig - Calculation of turbulence coefficients for sgsmodel = 1 or 2 1 = horizontal and vertical turbulence coefficients are the same; use this if dx,dy are about equal to dz (default) 2 = horizontal turbulence coefficient is different from vertical turbulence coefficient; use this if dx,dy are much greater than dz.
    tconfig: usize = 1,
    // bcturbs - Lower/upper boundary condition for vertical diffusion of all scalars. (Applies only to sgsmodel=1,2 and ipbl=2) 1 = zero flux (default) 2 = zero gradient
    bcturbs: usize = 1,
    // horizturb - Horizontal turbulence parameterization (i.e., horizontal Smagorinsky scheme) Reference: Bryan and Rotunno (2009, MWR, pg 1773) (note: previously, this was part of iturb=3)

    //              0 = no
    //              1 = yes

    //     Note:  horizturb = 1 requires cm1setup = 2

    horizturb: usize = 0,
    // doimpl - Vertically implicit calculation for vertical turbulence tendencies
    //           0 = no   (use vertically explicit scheme)
    //          1 = YES  (use vertically implicit scheme)
    //             (note:  doimpl=1 was required in cm1r18)

    //   Default formulation (doimpl=1) is a Crank-Nicholson scheme, which is
    //   absolutely stable (i.e., numerically stable regardless of time step).

    //   For doimpl=0, an explicit scheme is used for vertical turbulence
    //   tendencies, which can severely limit the time step for simulations
    //   with small vertical grid spacing.
    doimpl: usize = 1,

    // irdamp - Use upper-level Rayleigh damping zone? (acts on u,v,w, and theta only) (User must set rdalpha and zd below)

    //               0 = no
    //               1 = yes, damp towards base state
    //               2 = yes, damp towards horizontal average
    //                     (useful for very long simulations, eg, > 10 days)
    irdamp: usize = 1,

    // hrdamp - Use Rayleigh damping near lateral boundaries (0=NO, 1=yes) (acts on u,v,w only) (User must set rdalpha and xhd below)
    hrdamp: usize = 0,

    // psolver - Option for pressure solver.

    // CM1 DEFAULT:  depends on model grid
    //     - when dx,dy,dz are approximately equal, use psolver=2
    //     - when dz is much smaller than dx,dy, use psolver=3

    //    1 = Compressible equations, integrated explicitly:
    //        No time-splitting, no small time steps, no implicit numerics.
    //        (note: very expensive for weak wind speeds, < 10 m/s)
    //        (recommended only use when max wind speed is order 100 m/s)

    //    2 = Compressible equations, Klemp-Wilhelmson time-splitting, explicit:
    //        Uses K-W split time steps for acoustic modes; uses explicit
    //        calculations of acoustic terms in both vertical and horizontal
    //        directions.
    //        (use if dx,dy,dz are approximately equal)

    //    3 = Compressible, Klemp-Wilhelmson time-splitting, vertically implicit:
    //        Uses K-W split time steps for acoustic modes, with a vetically
    //        implicit solver, and horizontally explicit calculations.
    //        (as in MM5, ARPS, WRF, MPAS)
    //        (use if dz is much smaller than dx,dy)

    //    4 = Anelastic solver:
    //        Uses the anelastic mass continuity equation.  Pressure is retrieved
    //        diagnostically.
    //        (Note: OpenMP parallelization only; no MPI parallelization, for now.)

    //    5 = Incompressible solver:
    //        Uses the incompressible mass continuity equation.  Pressure is
    //        retrieved diagnostically.
    //        (Note: OpenMP parallelization only; no MPI parallelization, for now.)

    //    6 = Compressible-Boussinesq:
    //        Compressible equation set, using KW time splitting, fully explicit
    //        (like psolver=2), but Boussinesq approx made for pressure-gradient
    //        terms in velocity equations.  Useful for certain types of idealized
    //        modeling.  (see, eg, Bryan and Rotunno, 2014, JAS, pg 1126)
    //        Note: user must set value for "csound" in param.F (otherwise, default
    //        value of 300 m/s will be used)

    //    7 = Modified compressible equations:
    //        Equation set from Klemp and Wilhelmson (1978) but with modified value
    //        of sound propagation speed.  Useful for certain simulations with low
    //        wind speeds (<10 m/s).
    //        Note: user must set value for "csound" in param.F (otherwise, default
    //        value of 300 m/s will be used)

    //    NOTE:  since cm1r19, users no longer need to set the "nsound" parameter
    //           for psolver=2,3,6,7
    //           (It is now determined adaptively during simulations)
    psolver: usize = 3,
    // ptype - Explicit moisture scheme:

    //          0 = no microphysics (vapor only)

    //          1 = Kessler scheme (water only)

    //          2 = NASA-Goddard version of LFO scheme

    //          3 = Thompson scheme

    //          4 = Gilmore/Straka/Rasmussen version of LFO scheme
    // (default) 5 = Morrison double-moment scheme

    //      6 = Rotunno-Emanuel (1987) simple water-only scheme

    //      7 = WSM6        --- NEW ---

    //     (Note: options 26,27,28 use namelist nssl2mom_params, see below and
    //            README.NSSLmp
    //            3-moment option can be activated with nssl_3moment = .true.)
    //      26 = NSSL 2-moment scheme (graupel-only, no hail);
    //           graupel density predicted
    //      27 = NSSL 2-moment scheme (graupel and hail);
    //           graupel and hail densities predicted
    //      28 = NSSL single-moment scheme (graupel-only, similar to ptype=4);
    //           fixed graupel density (rho_qh)
    //      Ice density prediction can be turned off with nssl_density_on  (logical flag, default .true.)
    //          (ptype 26 or 27)

    //     (Note: P3 = Predicted Particle Property bulk microphysics scheme)
    //      50 = P3 1-ice category, 1-moment cloud water
    //      51 = P3 1-ice category plus double-moment cloud water
    //      52 = P3 2-ice categories plus double-moment cloud water
    //      53 = P3 1-ice category, 3-moment ice, plus double-moment cloud water

    //      55 = Jensen's ISHMAEL (Ice-Spheroids Habit Model with Aspect-ratio Evolution)
    // nssl_3moment - logical (default = .false.) Works with ptype 26 and 27 to turn on the reflectivity moments for rain and graupel (ptype=26/27) and for hail (ptype=27) Includes option for bin-emulating melting (Mansell et al. 2020; see README.NSSLmp)
    // nssl_density_on - logical flag (default .true.) to toggle graupel/hail density prediction (ptype 26 or 27)
    ptype: usize = 5,

    // ihail - Use hail or graupel for large ice category when ptype=2,5. (Goddard-LFO and Morrison schemes only) 1 = hail 0 = graupel
    ihail: usize = 1,
    // iautoc - Include autoconversion of qc to qr when ptype = 2? (0=no, 1=yes) (Goddard-LFO scheme only)
    iautoc: usize = 1,
    // cuparam - Convection parameterization: 0 = no convection parameterization (default) 1 = new Tiedtke convection parameterization
    cuparam: usize = 0,
    // icor - Include Coriolis acceleration? (0=no, 1=yes) (If user chooses 1, then fcor must be set below) f-plane is assumed.

    // NOTE: if icor=1, consider including a large-scale pressure gradient
    //       acceleration term (see lspgrad below)

    icor: usize = 0,
    // betaplane - Use beta plane (i.e., Coriolis term is a function of y)?
    // (0=no, 1=yes) Caution: not well tested. May not work with some lateral boundary condition options.
    betaplane: usize = 0,
    // lspgrad - Apply large-scale pressure gradient acceleration to u and v components of velocity. 0 = no 1 = yes, based on geostropic balance using base-state wind profiles (note: lspgrad = 1 was called "pertcor" in earlier versions of cm1) 2 = yes, based on geostropic balance using ug,vg arrays 3 = yes, based on gradient-wind balance (Bryan et al 2017, BLM) 4 = yes, specified values (set ulspg, vlspg in base.F)
    lspgrad: usize = 0,
    // eqtset - equation set for moist microphysics: 1 = a traditional (approximate) equation set for cloud models 2 = an energy-conserving equation set that accounts for the heat capacity of hydrometeors (Bryan and Fritsch 2002) that also conserves mass
    //     (note:  value is ignored if imoist = 0, because the
    //     equations are equivalent in a dry environment)

    //    (not available with ptype=4)

    eqtset: usize = 2,
    // idiss - Include dissipative heating? (0=no, 1=yes)
    idiss: usize = 1,
    // efall - Include energy fallout term? (0=no, 1=yes)
    efall: usize = 0,
    // rterm - Include simple relaxation term that mimics atmospheric radiation? (0=no, 1=yes) (Note: this is a very simple approach, and is only recommended for highly idealized model simulations. See Rotunno and Emanuel 1987, JAS, p. 546 for a description of this term.)
    rterm: usize = 0,
    // wbc - West lateral boundary condition.
    wbc: usize = 2,
    // ebc - East lateral boundary condition.
    ebc: usize = 2,

    // sbc - South lateral boundary condition.
    sbc: usize = 2,

    // nbc - North lateral boundary condition.
    //   where:  1 = periodic
    //                 2 = open-radiative
    //                 3 = rigid walls, free slip
    //                 4 = rigid walls, no slip
    nbc: usize = 2,
    // bbc - bottom boundary condition for winds

    //                     where:  1 = free slip
    //                             2 = no slip
    //                             3 = semi-slip (i.e., partial slip)
    // (NOTE: for bbc=3, user must also set some options in param12 section below) [see variables that mention "bbc=3" below]
    bbc: usize = 1,
    // tbc - top boundary condition for winds

    //                     where:  1 = free slip
    //                             2 = no slip
    //                             3 = semi-slip (i.e., partial slip)
    //           (note: tbc=3 requires sfcmodel=1, and uses cnst_znt or cnst_ust)
    tbc: usize = 1,
    // irbc - For bc=2, this is the type of radiative scheme to use: 1 = Klemp-Wilhelmson (1978) on large steps 2 = Klemp-Wilhelmson (1978) on small steps 4 = Durran-Klemp (1983) formulation
    irbc: usize = 4,
    // roflux - Restrict outward flux? (0=no, 1=yes)

    //    When this option is activated, the total outward mass flux at open
    //    boundary conditions is not allowed to exceed total inward mass flux.
    //    This is a requirement for the anelastic solver.  For the compressible
    //    solvers, this scheme helps prevent runaway outward mass flux that can
    //    cause domain-total mass loss and pressure falls.
    roflux: usize = 0,
    // nudgeobc - Nudge winds at inflow boundaries when using open boundary conditions? (0=no, 1=yes)

    //    When using open-radiative lateral boundary conditions, this option
    //    nudges the horizontal winds toward the base-state fields where there
    //    is inflow.  This option is useful for maintaining an inflowing wind
    //    profile in long simulations.  (User must set the variable alphobc;
    nudgeobc: usize = 0,
    // isnd - Base-state sounding: 1 = Dry adiabatic 2 = Dry isothermal 3 = Dry, constant dT/dz [some variables can be 4 = Saturated neutrally stable (BF02 sounding) set in base.F file] 5 = Weisman-Klemp analytic sounding 7 = External file (named 'input_sounding') (see isnd=7 section of base.F for info) (some soundings are available at http://www2.mmm.ucar.edu/people/bryan/cm1) (Note: wind profile is also obtained from input_sounding file; iwnd is ignored) 8 = Dry, constant d(theta)/dz 9 = Dry, constant Brunt-Vaisala frequency 10 = Saturated, constant Brunt-Vaisala frequency 11 = Saturated, constant equiv. pot. temp. 12 = Dry, adiabatic near surface, constant lapse rate above 13 = Dry, three different layers having constant N^2 (squared Brunt-Vaisala frequency) 14 = Dry, profile for Convective Boundary Layer test case. 15 = Moist, analytic, based on DYCOMS-II, used for stratocumulus test cases. 17 = Same as isnd=7, but wind profiles are neglected. User must set wind profile using the 'iwnd' option. External file named 'input_sounding' is used, although columns 4-5 are ignored. (see isnd=7 section of base.F for more info) (some soundings are available at http://www2.mmm.ucar.edu/people/bryan/cm1) 18 = Dry, sharp inversion in middle of profile, used for sheared boundary layer test case. 19 = Moist analytic profiles based on BOMEX, used for shallow cumulus test case 20 = Moist analytic profiles based on RICO, used for precipitating shallow cumulus test case 22 = Initial sounding for stable boundary-layer test case (testcase=9). 23 = Initial sounding for shallow cumulus test case over land (testcase=1
    isnd: usize = 5,
    // iwnd - Base-state wind profile: (ignored if isnd=7) 0 = zero winds [additional variables 1 = RKW-type profile need to be set in 2 = Weisman-Klemp supercell base.F file] 3 = multicell 4 = Weisman-Klemp multicell 5 = Dornbrack etal analytic profile 6 = constant wind 8 = constant or linearly decreasing wind profile, used for simple hurricane boundary layer case (see base.F for more details) 9 = linear wind profiles used for shallow cumulus test case 10 = linear wind profiles used for drizzling stratocumulus test case 11 = wind profiles used for RICO precipitating shallow cumulus case
    iwnd: usize = 2,
    // itern - Initial topography specifications. User must also set zs array in init_terrain.F: 0 = no terrain (zs=0) 1 = bell-shaped hill 2 = Schaer test case 3 = (case from T. Lane and J. Doyle) 4 = specified in external GrADS file
    itern: usize = 0,
    // iinit - 3D initialization option: 0 = no perturbation 1 = warm bubble 2 = cold pool [additional variables 3 = line of warm bubbles need to be set in 4 = initialization for moist benchmark init3d.F file] 5 = cold blob 7 = tropical cyclone (modified Rankine by default) See relevant code in 8 = line thermal with random perturbations init3d.F file for 9 = forced convergence (Loftus et al 2008) more details. 10 = momentum forcing (Morrison et al 2015) 11 = Skamarock-Klemp IG wave perturbation 12 = updraft nudging (Naylor and Gilmore 2012)
    iinit: usize = 1,
    // irandp - Include random potential temperature perturbations in the initial conditions? (0=no, 1=yes) (set magnitude of perturbations in init3d.F)
    irandp: usize = 0,
    // ibalance - Specified balance assumption for initial 3D pressure field (ignored if iinit=7)

    //       0 = no balance (initial pressure perturbation is zero everywhere,
    //                       except for iinit=7)
    //       1 = hydrostatic balance (appropriate for small aspect ratios)
    //       2 = anelastic balance (initial pressure perturbation is the
    //           buoyancy pressure perturbation field for an anelastic
    //           atmosphere).  (Does not currently work with MPI setup.)
    ibalance: usize = 0,
    // iorigin - Specifies location of the origin in horizontal space

    //       1 = At the bottom-left corner of the domain
    //           (x goes from 0 km to nx*dx km)
    //           (y goes from 0 km to ny*dy km)
    //       2 = At the center of the domain
    //           (x goes from -nx*dx/2 km to +nx*dx/2 km)
    //           (y goes from -ny*dy/2 km to +ny*dy/2 km)
    iorigin: usize = 2,
    // axisymm - Run axisymmetric version of model (0=no, 1=yes)

    //     (for axisymm=1, ny must be 1, wbc must be 3, and sbc,nbc must be 1)

    //     (see README.axisymm for more information)
    axisymm: usize = 0,
    // imove - Move domain at constant speed (0=no, 1=yes)

    //        For imove=1, user must set umove and vmove.
    imove: usize = 1,
    // iptra - Integrate passive fluid tracer? (0=no, 1=yes)

    //        User must initialize "pta" array in init3d.F.
    iptra: usize = 0,
    // npt - Total number of passive fluid tracers.
    npt: usize = 1,
    // pdtra - Ensure positive-definiteness for tracers? (0=no, 1=yes)
    pdtra: usize = 1,
    // iprcl - Integrate passive parcels? (0=no, 1=yes)

    //        User must initialize "pdata" array in init3d.F.
    iprcl: usize = 0,
    // nparcels - Total number of parcels.
    nparcels: usize = 1,
};

pub const Param3 = struct {
    //   kdiff2 - Diffusion coefficient for difforder=2. Specified in m^2/s.
    kdiff2: f32 = 75.0,
    // kdiff6 - Diffusion coefficient for difforder=6. Specified as a fraction of one-dimensional stability. A value between 0.02-0.24 is recommended.
    kdiff6: f32 = 0.040,

    // fcor - Coriolis parameter (1/s).
    fcor: f32 = 0.00005,

    // kdiv - Coefficient for divergence damper. Value of ~0.1 is recommended.
    kdiv: f32 = 0.10,

    //     This is only used when psolver=2,3.  (The divergence damper is
    //     an artificial term designed to damp acoustic waves.)

    // alph - Off-centering coefficient for vertically implicit acoustic solver. A value of 0.5 is centered-in-time. Slight forward-in-time bias is recommended. Default value is 0.60. (only used for psolver=3)
    alph: f32 = 0.60,

    // rdalpha - Inverse e-folding time for upper-level Rayleigh damping layer (1/s). Value of about 1/300 is recommended.
    rdalpha: f32 = 3.3333333333e-3,

    // zd - Height above which Rayleigh damping is applied (m). (when irdamp = 1)
    zd: f32 = 15000.0,

    // xhd - Distance from lateral boundaries where Rayleigh damping is applied (m). (when hrdamp = 1)
    xhd: f32 = 100000.0,

    // alphobc - Time scale (s) of nudging tendency when using the nudgeobc option.
    alphobc: f32 = 60.0,

    // umove - Constant speed for domain translation in x-direction (m/s) (for imove = 1) (NOTE: for imove=1 and umove not equal to 0.0, ground-relative winds are umove+ua, umove+u3d, etc)
    umove: f32 = 12.5,

    // vmove - Constant speed for domain translation in y-direction (m/s) (for imove = 1) (NOTE: for imove=1 and vmove not equal to 0.0, ground-relative winds are vmove+va, vmove+v3d, etc)
    vmove: f32 = 3.0,

    // v_t - Constant terminal fall velocity of liquid water (m/s) when ptype=6
    //      When v_t is negative, all liquid water above a small threshold is

    //      removed from the domain, ie, pseudoadiabatic thermodynamics are
    //      used, following Bryan and Rotunno (2009, JAS, pg 3042).
    v_t: f32 = 7.0,

    // l_h - Horizontal turbulence length scale (m) used when horizturb=1 (ie, 2D Smagorinsky) Since cm1r18, this is used OVER LAND ONLY (see lhref1,lhref2 for settings OVER OCEAN)
    l_h: f32 = 100.0,

    // lhref1 - a reference value of l_h (m): value for surface pressure of 1015 mb lhref2 - a reference value of l_h (m): value for surface pressure of 900 mb

    // notes:  - Since cm1r18, the horizontal turbulence length scale for
    //           horizturb=1 is a function of surface pressure
    //           (over the OCEAN ONLY).
    //         - This is based on studies of hurricanes (eg, Bryan 2012, MWR).
    //         - lhref1 and lhref2 define a linear formulation for horizontal
    //           turbulence length over the ocean for horizturb=1.
    //         - For gridpoints over land, l_h (above) is used for horizturb=1.
    //         - For water points above sea level (e.g., lakes) l_h is used.
    lhref1: f32 = 100.0,
    lhref2: f32 = 1000.0,

    // l_inf - Asymptotic vertical turbulence length scale (m) (i.e., vertical length scale at z = infinity) used for ipbl=2 (simple parameterized turbulence / boundary layer scheme)
    l_inf: f32 = 75.0,

    // ndcnst - specified cloud droplet concentration for default version of Morrison microphysics scheme (units of cm-3)
    ndcnst: f32 = 250.0,

    //     Note: typical value of ndcnst (nt_c) for maritime environments:  100 cm-3
    //           typical value of ndcnst (nt_c) for continental environments:  300 cm-3

    // --- NEW --- nt_c - same as ndcnst, but for Thompson microphysics scheme
    nt_c: f32 = 250.0,

    //  (NOTE: for other microphysics schemes, you will have
    //         to change this value manually in the code)

    // --- NEW --- csound - speed of sound (m/s) for psolver=6,7 (Note: should be roughly 5-10 times larger than maximum flow velocity)
    csound: f32 = 300.0,

    // --- NEW --- cstar - propagation speed (m/s) of outward-propagating waves at open boundaries (for irbc=1,2 only)
    cstar: f32 = 30.0,
};

pub const Param11 = struct {
    // param11 section - atmospheric radiation
    // NOTE: The parameters in this section ONLY apply to atmospheric radation. You do not need to set anything here unless radopt >= 1.

    // radopt - Use atmospheric radiation code?

    //            0 = no
    //            1 = yes, use the NASA-Goddard scheme
    //            2 = yes, use the RRTMG scheme

    //    Note:  the NASA-Goddard longwave and shortwave radiation codes
    //    were adapted from the ARPS model, courtesy of the ARPS/CAPS group
    //    at the University of Oklahoma.

    //    Note:  the RRTMG code was adapted from the WRF model.

    //    (Note:  TIPA option is not implemented in this version of CM1)

    //     -----
    //     Note:  for the NASA-Goddard code, the interaction of radiation with
    //     clouds is configured consistently for only two microphysics
    //     schemes:  the NASA-Goddard LFO scheme (ptype=2) and the Morrison
    //     microphysics scheme (ptype=5).  A future version of CM1 might pass the
    //     proper variables from all microphysics schemes into the radiation
    //     code so that consistent calculations are performed.

    //     That said, the radiative tendencies should still be reasonable for all
    //     ice microphysics schemes, and there is no issue for clear-sky
    //     conditions.  (The inconsistency arises only when radiation interacts
    //     with water and ice particles, and the radiation scheme needs to be
    //     sent information about hydrometeor size and distribution for
    //     accurate calculations.)
    //     -----

    //     -----
    //     Note:  for the RRTMG code, only the Thompson (ptype=3), Morrison
    //     (ptype=5), NSSL (ptype=26/27), P3 (50-53), and Jensen ISHMAEL (55) schemes are
    //     accurately coupled with the radiation calculations.
    //     -----
    radopt: f32 = 0,

    // If radopt >= 1, set the following parameters:

    // dtrad - Time increment (seconds) between calculation of radiation tendency. (Radiative tendencies are held fixed in-between calls to the atmospheric radiation subroutine.)
    dtrad: f32 = 300.0,

    // ctrlat - Latitude (applies to entire domain, for now)
    ctrlat: f32 = 36.68,

    // ctrlon - Longitude (applies to entire domain, for now)
    ctrlon: f32 = -98.35,

    //  NOTE:  because ctrlat and ctrlon are fixed (for now) the radiation
    //         scheme is only appropriate for domains having horizontal
    //         extent of order 100--1000 km or less

    //  (FAQ:  Why are lat and lon fixed across the entire domain?
    //   It's because George doesn't have time, at the moment, to deal with
    //   map projections in CM1.)

    // year - Year (integer) at start of simulation
    year: u32 = 2009,

    // month - Month (integer) at start of simulation
    month: u32 = 5,

    // day - Day (integer) at start of simulation
    day: u32 = 15,

    // hour - Hour (integer) at start of simulation
    hour: u32 = 21,

    // minute - Minute (integer) at start of simulation
    minute: u32 = 38,

    // second - Second (integer) at start of simulation
    second: u32 = 0,

    //     Yet Another Note:  the radiation schemes uses three important
    //     pieces of information from the surface section (param12) below:
    //     surface temperature, land/water flag, and land-use type.
    //     Make sure you have the desired settings for your simulation below
    //     (even if you are not using surface fluxes!).

};

pub const Param12 = struct {
    //     param12 section: surface model, ocean model, boundary layer:

    //   NOTE:  By default, surface conditions are the same everywhere at the
    //   initial time.  But, users can define spatially varying initial surface
    //   conditions in init_surface.F
    // isfcflx - Include surface fluxes of heat and moisture (0=no, 1=yes)
    isfcflx: f32 = 0,

    // sfcmodel - Surface model: (Specifically, method to calculate surface fluxes and surface stress over land and water) (NOTE: bbc=3 requires sfcmodel >= 1 ) (NOTE: set_znt=1, or set_ust=1, or set_flx=1 requires sfcmodel = 1)

    //   List (see more info below):

    //         1 = original CM1 formulation

    //         2 = surface-layer scheme from WRF model (details below)

    //         3 = 'revised' surface-layer scheme from WRF model (details below)

    //         4 = GFDL surface layer  (as configured in HWRF_v4.0a)

    //         5 = Monin-Obukhov Similarity Theory (MOST) for LES

    //         6 = MYNN surface layer

    //         7 = MYJ surface layer

    //   Further information:

    //     - sfcmodel=1 : Uses simple formulations wherein surface exchange
    //     coefficients are specified:  see "Options for sfcmodel = 1" section
    //     below.  For diagnostic surface layer calculations (such as 10-m winds),
    //     a neutrally stratified surface layer is assumed.
    //     Notes:  - surface temperature remains fixed over time
    //             - surface moisture availability remains fixed over time
    //             - sfcmodel=1 requires oceanmodel=1

    //     - sfcmodel=2 : Uses the MM5/WRF similarity theory code for the surface
    //     layer:  based on Monin-Obukhov with Carslon-Boland viscous sub-layer
    //     and standard similarity functions from look-up tables.
    //     ("sf_sfclay_physics = 1" in WRF)
    //     See also "Options for sfcmodel = 2" section below.
    //     The soil model is the "Thermal diffusion" model from MM5/WRF:  it
    //     updates soil temperature only ... soil moisture availability is held
    //     fixed over time.  (Same as "sf_surface_physics = 1" in WRF)
    //     Notes:  - sfcmodel=2 can be used with either oceanmodel=1,2

    //     - sfcmodel=3 : A revised version of sfcmodel=2.  See Jimenez et al
    //     (2012, MWR, pg 898) for more details.
    //     Notes:  - sfcmodel=3 can be used with either oceanmodel=1,2

    //     - sfcmodel=4 : GFDL surface layer, as configured in HWRF_v4.0a

    //     - sfcmodel=5 : Monin-Obukhov Similarity Theory (MOST).

    //     - sfcmodel=6 : MYNN surface layer (from WRFV4.2)

    //     - sfcmodel=7 : MYJ surface layer (from WRFV4.2)
    sfcmodel: f32 = 0,

    // oceanmodel - Model for ocean/water surface:

    //         1 = fixed sea-surface temperature
    //         2 = ocean mixed layer model
    //             (Same as "omlcall = 1" in WRF)
    //             (Note:  oceanmodel=2 requires sfcmodel=2,3)
    //             Ref:  Pollard et al, 1973, Geophys. Fluid Dyn., 3, 381-404.

    // Options for initialization of surface conditions:
    oceanmodel: f32 = 0,

    // initsfc - initial surface conditions: 1 = constant values (set tsk0,tmn0,xland0,lu0 below) 2 = sea breeze test case from WRF 3 = rough surface to west; smoother surface to east 4 = coastline (land to west, ocean to east)

    //           for any other value:  you must initialize the surface conditions
    //           yourself in the "init_surface.F" file.

    initsfc: f32 = 1,
    // tsk0 - default initial value for "skin temperature" (K) of soil/water
    // (~1 cm deep) NOTE: this replaces sea surface temperature (tsurf) in cm1r15

    tsk0: f32 = 299.28,
    // tmn0 - default initial value for deep-layer temperature (K) of soil (Note: remains fixed throughout simulation) (only used if sfcmodel=2) (only used over land ... ignored over water)
    tmn0: f32 = 297.28,

    // xland0 - default initial value for land/water flag: 1 for land, 2 for water
    xland0: f32 = 2.0,

    // lu0 - default initial value for land-use index (see LANDUSE.TBL file) (NOTE: for water/ocean, use lu0 = 16)
    lu0: f32 = 16,

    // season - which set of land-use conditions to use from LANDUSE.TBL file: 1 = summer values 2 = winter values
    season: f32 = 1,

    // c-------------------------------------------------------------c
    //  To reiterate:  if you want to use spatially varying values of
    //  tsk,tmn,xland,lu then you must code it up yourself in the
    //  "init_surface.F" file.
    // c-------------------------------------------------------------c

    // Options for sfcmodel = 1:

    // cecd - When bbc=3 and/or isfcflx=1, this allows the user to choose the formulation for the surface exchange coefficients for enthalphy (Ce) and momentum (Cd). Options are: 1 = constant value: user must set cnstce and/or cnstcd below (applies to land and water) 2 = Deacon's formula [eg, Rotunno and Emanuel (1987, JAS)] (over water only) (WRF LANDUSE.TBL used over land) default: 3 = Cd based roughly on Fairall et al (2003) at low wind speeds and Donelan (2004, GRL) at high wind speeds Ce constant, based on Drennan et al. (2007, JAS) (over water only) (WRF LANDUSE.TBL used over land)
    cecd: f32 = 3,

    // pertflx - Use only perturbation winds for calculation of surface fluxes? (0=NO, 1=yes) (Only available with sfcmodel=1)
    pertflx: f32 = 0,

    // cnstce - Constant value of Ce (surface exchange coefficient for enthalpy) if isfcflx=1 and cecd=1
    cnstce: f32 = 0.001,

    // cnstcd - Constant value of Cd (surface exchange coefficient for momentum) if bbc=3 and cecd=1
    cnstcd: f32 = 0.001,

    // Options for sfcmodel = 2,3,6:

    // isftcflx - Use alternative Ck and Cd for tropical storm applications: (0=off) (For Cd: 1,2 = Donelan) (For Ce: 1=constant Z0q, 2=Garratt) MYNN has other options: see module_sf_mynn.F for details (Cannot be used with sfcmodel=1,4,5)
    isftcflx: f32 = 0,

    // iz0tlnd - When using sfcmodel=2, option for thermal roughness length: 0 = Carlson-Boland (original mm5/wrf version) 1 = Czil_new (depends on vegetation height)
    iz0tlnd: f32 = 0,

    // Options for oceanmodel = 2:

    // oml_hml0 - default ocean mixed layer depth (m) at initial time
    oml_hml0: f32 = 50.0,

    // oml_gamma - default deep water lapse rate (K m-1)
    oml_gamma: f32 = 0.14,

    // Further options for sfcmodel = 1 only:

    // set_flx - impose constant surface heat fluxes (0=no, 1=yes)
    set_flx: f32 = 0,

    // cnst_shflx - value for surface sensible heat flux (K m/s) if set_flx=1
    cnst_shflx: f32 = 0.24,

    // cnst_lhflx - value for surface latent heat flux (g/g m/s) if set_flx=1
    cnst_lhflx: f32 = 5.2e-5,

    // set_znt - impose constant surface roughness length (0=no, 1=yes)
    set_znt: f32 = 0,

    // cnst_znt - value of surface roughness length (z0, meters) if set_znt=1
    cnst_znt: f32 = 0.16,

    // set_ust - impose constant surface friction velocity (0=no, 1=yes)
    set_ust: f32 = 0,

    // cnst_ust - value of surface friction velocity (u-star, m/s) if set_ust=1
    cnst_ust: f32 = 0.25,

    // --- NEW --- ramp_sgs - gradually turn on (ie, "ramp up") the subgrid-scale model for LES (0=no, 1=yes) (for sgsmodel >=1 only)
    ramp_sgs: f32 = 1,

    // --- NEW --- ramp_time - for ramp_sgs=1 only: this is the time over which the LES subgrid-scale model is linearly ramped up.
    ramp_time: f32 = 1800.0,

    // --- NEW --- t2p_avg - for two-part models (sgsmodel=3,4) use either: 1 - spatial average (over entire domain at each model level) 2 - time average (each grid point has a different time-avg)
    t2p_avg: f32 = 1,
};
