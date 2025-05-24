const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    //web exports are completely separate
    if (target.query.os_tag == .emscripten) {
        const web_assets = b.addInstallDirectory(.{
            .source_dir = b.path("web"),
            .install_dir = .{ .prefix = {} },
            .install_subdir = "htmlout",
            .exclude_extensions = &.{"template.html"},
        });
        b.getInstallStep().dependOn(&web_assets.step);

        const exe_lib = try rlz.emcc.compileForEmscripten(b, "BioMechanics", "src/main.zig", target, optimize);

        exe_lib.linkLibrary(raylib_artifact);
        exe_lib.root_module.addImport("raylib", raylib);
        exe_lib.root_module.addImport("raygui", raygui);

        // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
        const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });
        //this lets your program access files like "resources/my-image.png":
        link_step.addArg("--embed-file");
        link_step.addArg("resources/");
        // asyncify off b/c of animation
        //link_step.addArg("-s");
        //link_step.addArg("ASYNCIFY");
        link_step.addArg("--shell-file");
        link_step.addArg("web/template.html");

        // link_step.addArg("-s");
        // link_step.addArg("ASSERTIONS");
        // link_step.addArg("-sALLOW_MEMORY_GROWTH");

        link_step.addArg("-s");
        link_step.addArg("ALLOW_MEMORY_GROWTH");

        link_step.addArg("-s");
        link_step.addArg("TOTAL_STACK=256mb");
        // link_step.addArg("-s TOTAL_MEMORY=67108864");
        // link_step.addArg("-s TOTAL_MEMORY=67108864");

        // link_step.addArg("-sALLOW_MEMORY_GROWTH");

        // link_step.addArg("-s TOTAL_MEMORY=67108864");
        // link_step.addArg("-s TOTAL_MEMORY=67108864");
        // link_step.addArg("-s TOTAL_MEMORY=67108864");

        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rlz.emcc.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run BioMechanics");
        run_option.dependOn(&run_step.step);
        return;
    }

    const exe = b.addExecutable(.{ .name = "BioMechanics", .root_source_file = b.path("src/main.zig"), .optimize = optimize, .target = target });
    const resources_folder = b.addInstallDirectory(.{
        .source_dir = b.path("resources/"),
        .install_dir = .{ .bin = {} },
        .install_subdir = "resources",
    });
    b.getInstallStep().dependOn(&resources_folder.step);

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run BioMechanics");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
