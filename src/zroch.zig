const std = @import("std");
const zroutine = @import("zroutine.zig");
const zchan = @import("zchan.zig");
const testing = std.testing;
const builtin = std.builtin;
const typeop = @import("typeop.zig");

fn defineZorch(comptime ChanDataType: type, comptime RoutineArgsType: type) type {
    const StubRoutineFnType = @typeInfo(*const fn () anyerror!void).Pointer.child;

    const ChanType = zchan.Chan(ChanDataType);
    const RFnArgsStruct = typeop.insertFieldToStruct(RoutineArgsType, .{ .name = "chan", .type = *ChanType }, 0);
    const RFnType = typeop.insertParamToFn(StubRoutineFnType, .{ .type = RFnArgsStruct }, 0);

    return struct {
        const Self = @This();
        pub const RoutineFnArgs = RFnArgsStruct;
        pub const RoutineFn = RFnType;
        pub const Chan = ChanType;
        pub const RoutineMgr = zroutine.defineRoutineMgr(*const RoutineFn);

        allocator: std.mem.Allocator,
        ch: Chan = undefined,
        rmgr: RoutineMgr = undefined,

        pub fn init(allocator: std.mem.Allocator) !Self {
            var ret = Self{ .allocator = allocator };
            ret.rmgr = RoutineMgr.init(allocator, null);
            ret.ch = try Chan.init(allocator);
            return ret;
        }

        pub fn deinit(this: *Self) void {
            this.ch.deinit();
            this.rmgr.deinit();
        }

        pub fn join(this: *Self) void {
            this.rmgr.join();
        }
    };
}

// all tests

const SumZorch = defineZorch(i32, struct {});

fn sumIntZorch(args: SumZorch.RoutineFnArgs) anyerror!void {
    var sum: i32 = 0;
    while (true) {
        const i = try args.chan.read();
        // std.debug.print("got {d}\n", .{i});
        if (i < 0) break;
        sum += i;
    }
    std.debug.print("\nnow write sum:{d}\n", .{sum});
    try args.chan.write(&sum);
}

test "sum_zroch" {
    var z = try SumZorch.init(testing.allocator);
    defer z.deinit();
    _ = try z.rmgr.spawn(sumIntZorch, .{ .chan = &z.ch });
    for (0..500) |i| {
        // std.debug.print("write: {d}\n", .{i});
        try z.ch.write(&@as(i32, @intCast(i)));
    }
    // std.debug.print("\nwrite: -1\n", .{});
    try z.ch.write(&(-1));
    std.debug.print("\nnow read\n", .{});
    const sum = try z.ch.read();
    std.debug.print("\nsum={d}\n", .{sum});
    z.join();
}

const HttpReqZorch = defineZorch([]const u8, struct { url: []const u8 });

fn httpReqZorch(args: HttpReqZorch.RoutineFnArgs) anyerror!void {
    const allocator = testing.allocator;
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    const headers = .{ .allocator = allocator };
    const uri = try std.Uri.parse(args.url);
    var req = try client.open(.GET, uri, headers, .{});
    defer req.deinit();
    try req.send(.{});
    try req.wait();
    const body = try req.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(body);
    try args.chan.write(&body);
}

test "http_zroch" {
    var z = try HttpReqZorch.init(testing.allocator);
    defer z.deinit();
    _ = try z.rmgr.spawn(httpReqZorch, .{ .chan = &z.ch, .url = "https://ziglang.org/" });
    const body = try z.ch.read();
    std.debug.print("\nGot: {s} ... ({d}) bytes\n", .{ body[0..32], body.len });
    defer z.ch.allocator.free(body);
    z.join();
}

// below are some manual integrations without zroch

const IntCh = zchan.Chan(i32);

const SumIntArgs = struct { chan: *IntCh };

fn sumInt(args: SumIntArgs) anyerror!void {
    var sum: i32 = 0;
    while (true) {
        const i = try args.chan.read();
        // std.debug.print("got {d}\n", .{i});
        if (i < 0) break;
        sum += i;
    }
    std.debug.print("\nnow write sum:{d}\n", .{sum});
    try args.chan.write(&sum);
}

test "sum" {
    const RoutineMgr = zroutine.defineRoutineMgr(*const fn (args: SumIntArgs) anyerror!void);
    var rmgr = RoutineMgr.init(testing.allocator, null);
    defer rmgr.deinit();
    var ch = try IntCh.init(testing.allocator);
    defer ch.deinit();
    _ = try rmgr.spawn(sumInt, .{ .chan = &ch });
    for (0..500) |i| {
        // std.debug.print("write: {d}\n", .{i});
        try ch.write(&@as(i32, @intCast(i)));
    }
    // std.debug.print("\nwrite: -1\n", .{});
    try ch.write(&(-1));
    std.debug.print("\nnow read\n", .{});
    const sum = try ch.read();
    std.debug.print("\nsum={d}\n", .{sum});
    rmgr.join();
}

const SliceCh = zchan.Chan([]const u8);

const HttpReqArgs = struct { chan: *SliceCh, url: []const u8 };

fn httpReq(args: HttpReqArgs) anyerror!void {
    const allocator = testing.allocator;
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    const headers = .{ .allocator = allocator };
    const uri = try std.Uri.parse(args.url);
    var req = try client.open(.GET, uri, headers, .{});
    defer req.deinit();
    try req.send(.{});
    try req.wait();
    const body = try req.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(body);
    try args.chan.write(&body);
}

test "http" {
    const RoutineMgr = zroutine.defineRoutineMgr(*const fn (args: HttpReqArgs) anyerror!void);
    var rmgr = RoutineMgr.init(testing.allocator, null);
    defer rmgr.deinit();
    var ch = try SliceCh.init(testing.allocator);
    defer ch.deinit();
    _ = try rmgr.spawn(httpReq, .{ .chan = &ch, .url = "https://ziglang.org/" });
    const body = try ch.read();
    std.debug.print("\nGot: {s} ... ({d}) bytes\n", .{ body[0..32], body.len });
    defer ch.allocator.free(body);
    rmgr.join();
}
