const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "lambd",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_cmd = b.addRunArtifact(exe);
    const build_step = b.addInstallArtifact(exe);

    run_cmd.step.dependOn(&build_step.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //const tests_main = b.addTest(.{
    //    .name = "main tests",
    //    .root_source_file = .{ .path = "src/main.zig" },
    //    .target = target,
    //    .optimize = optimize,
    //});
    //const run_main_tests = b.addRunArtifact(tests_main);

    const tests_expr = b.addTest(.{
        .name = "expr tests",
        .root_source_file = .{ .path = "src/expr.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_expr_tests = b.addRunArtifact(tests_expr);

    const test_step = b.step("test", "Run unit tests");
    //test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_expr_tests.step);
}
