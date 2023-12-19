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

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_untyped_expr = b.addTest(.{
        .name = "expr tests",
        .root_source_file = .{ .path = "src/untyped/expr.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_untyped_expr_test = b.addRunArtifact(test_untyped_expr);

    const test_typed_expr = b.addTest(.{
        .name = "expr tests",
        .root_source_file = .{ .path = "src/typed/expr.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_typed_expr_test = b.addRunArtifact(test_typed_expr);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_untyped_expr_test.step);
    test_step.dependOn(&run_typed_expr_test.step);
}
