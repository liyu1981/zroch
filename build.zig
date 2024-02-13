const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    _ = target;
    const optimize = b.standardOptimizeOption(.{});
    _ = optimize;

    _ = b.addModule("zroutine", .{
        .source_file = .{ .path = "src/zroutine.zig" },
    });

    _ = b.addModule("zchan", .{
        .source_file = .{ .path = "src/zchan.zig" },
    });

    _ = b.addModule("zroch", .{
        .source_file = .{ .path = "src/zroch.zig" },
    });

    _ = b.addModule("typeop", .{
        .source_file = .{ .path = "src/typeop.zig" },
    });
}
