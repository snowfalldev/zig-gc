const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = blk: {
        const module = b.addModule("gc", .{
            .root_source_file = b.path("src/gc.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        if (target.result.isDarwin()) module.linkFramework("Foundation", .{});
        module.addIncludePath(b.path("vendor/bdwgc/include"));

        // TODO(mitchellh): support more complex features that are usually on
        // with libgc like threading, parallelization, etc.
        const cflags = [_][]const u8{};
        const src_files = [_][]const u8{
            "alloc.c",    "reclaim.c", "allchblk.c", "misc.c",     "mach_dep.c", "os_dep.c",
            "mark_rts.c", "headers.c", "mark.c",     "obj_map.c",  "blacklst.c", "finalize.c",
            "new_hblk.c", "dbg_mlc.c", "malloc.c",   "dyn_load.c", "typd_mlc.c", "ptr_chck.c",
            "mallocx.c",
        };

        inline for (src_files) |src| {
            module.addCSourceFile(.{
                .file = b.path("vendor/bdwgc/" ++ src),
                .flags = &cflags,
            });
        }
        break :blk module;
    };

    {
        const tests = b.addTest(.{
            .root_source_file = b.path("src/gc.zig"),
            .target = target,
            .optimize = optimize,
        });

        tests.root_module = module;

        const run_tests = b.addRunArtifact(tests);

        const test_step = b.step("test", "Run library tests");
        test_step.dependOn(&run_tests.step);
    }

    // example app
    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("example/basic.zig"),
        .target = target,
        .optimize = optimize,
    });
    {
        exe.root_module.addImport("gc", module);
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run_example", "run example");
        run_step.dependOn(&run_cmd.step);
    }
}
