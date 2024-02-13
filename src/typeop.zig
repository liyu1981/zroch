const std = @import("std");
const builtin = std.builtin;
const testing = std.testing;

pub const NewStructField = struct {
    name: [:0]const u8,
    type: type,
    default_value: ?*const anyopaque = null,
    is_comptime: bool = false,
    alignment: comptime_int = 0,
};

pub fn insertFieldToStruct(comptime orig_struct_type: type, comptime new_field: NewStructField, comptime index: usize) type {
    const orig_ti = @typeInfo(orig_struct_type);
    switch (orig_ti) {
        .Struct => {},
        else => {
            @compileError("orig_struct_type must be struct type, but got:" ++ @typeName(orig_struct_type));
        },
    }

    if (index > orig_ti.Struct.fields.len) {
        @compileLog("index should be less than:", orig_ti.Struct.fields.len, ", got: ", index);
        @compileError("index out of bound.");
    }

    var new_fields: [orig_ti.Struct.fields.len + 1]builtin.Type.StructField = undefined;
    comptime var j: usize = 0;
    comptime for (0..orig_ti.Struct.fields.len + 1) |i| {
        if (i == index) {
            new_fields[i] = .{
                .name = new_field.name,
                .type = new_field.type,
                .default_value = new_field.default_value,
                .is_comptime = new_field.is_comptime,
                .alignment = new_field.alignment,
            };
        } else {
            new_fields[i] = orig_ti.Struct.fields[j];
            j += 1;
        }
    };

    const new_struct_info: builtin.Type.Struct = .{
        .layout = .Auto,
        .fields = &new_fields,
        .decls = &[_]builtin.Type.Declaration{},
        .is_tuple = false,
    };

    return @Type(.{ .Struct = new_struct_info });
}

pub const DeleteFieldE = enum {
    name,
    index,
    type,
};

pub const DeleteFieldU = union(DeleteFieldE) {
    name: []const u8,
    index: usize,
    type: type,
};

pub fn deleteFieldFromStruct(comptime orig_struct_type: type, comptime by: DeleteFieldU) type {
    const orig_ti = @typeInfo(orig_struct_type);
    switch (orig_ti) {
        .Struct => {},
        else => {
            @compileError("orig_struct_type must be struct type, but got:" ++ @typeName(orig_struct_type));
        },
    }

    switch (by) {
        .name => |name| {
            if (orig_ti.Struct.fields.len == 0) {
                @compileError("orig_struct_type is empty.");
            }

            const found: usize = brk: {
                comptime for (0..orig_ti.Struct.fields.len) |i| {
                    if (std.mem.eql(u8, orig_ti.Struct.fields[i].name, name)) {
                        break :brk i;
                    }
                };
                @compileError(name ++ " is not a field in orig_struct_type.");
            };
            return deleteFieldFromStruct(orig_struct_type, .{ .index = found });
        },
        .index => |index| {
            if (orig_ti.Struct.fields.len == 0) {
                @compileError("orig_struct_type is empty.");
            }

            if (index > orig_ti.Struct.fields.len) {
                @compileLog("index should be less than:", orig_ti.Struct.fields.len, ", got: ", index);
                @compileError("index out of bound.");
            }

            var new_fields: [orig_ti.Struct.fields.len - 1]builtin.Type.StructField = undefined;
            comptime var j: usize = 0;
            comptime for (0..orig_ti.Struct.fields.len) |i| {
                if (i == index) {
                    continue;
                } else {
                    new_fields[j] = orig_ti.Struct.fields[i];
                    j += 1;
                }
            };

            const new_struct_info: builtin.Type.Struct = .{
                .layout = .Auto,
                .fields = &new_fields,
                .decls = &[_]builtin.Type.Declaration{},
                .is_tuple = false,
            };

            return @Type(.{ .Struct = new_struct_info });
        },
        .type => |unwanted_type| {
            const found: usize = brk: {
                comptime for (0..orig_ti.Struct.fields.len) |i| {
                    if (orig_ti.Struct.fields[i].type == unwanted_type) {
                        break :brk i;
                    }
                };
                return @Type(orig_ti);
            };
            const delete_once_type_result = deleteFieldFromStruct(orig_struct_type, .{ .index = found });
            return deleteFieldFromStruct(delete_once_type_result, .{ .type = unwanted_type });
        },
    }
}

pub const NewFnParam = struct {
    is_generic: bool = false,
    is_noalias: bool = false,
    type: ?type,
};

pub fn insertParamToFn(comptime orig_fn_type: type, comptime new_param: NewFnParam, comptime index: usize) type {
    const orig_ti = @typeInfo(orig_fn_type);
    switch (orig_ti) {
        .Fn => {},
        else => {
            @compileError("orig_struct_type must be struct type, but got:" ++ @typeName(orig_fn_type));
        },
    }

    if (index > orig_ti.Fn.params.len) {
        @compileLog("index should be less than:", orig_ti.Fn.params.len, ", got: ", index);
        @compileError("index out of bound.");
    }

    var new_params: [orig_ti.Fn.params.len + 1]builtin.Type.Fn.Param = undefined;
    comptime var j: usize = 0;
    comptime for (0..orig_ti.Fn.params.len + 1) |i| {
        if (i == index) {
            new_params[i] = .{
                .is_generic = new_param.is_generic,
                .is_noalias = new_param.is_noalias,
                .type = new_param.type,
            };
        } else {
            new_params[i] = orig_ti.Fn.params[j];
            j += 1;
        }
    };

    const new_fn: builtin.Type.Fn = .{
        .calling_convention = orig_ti.Fn.calling_convention,
        .alignment = orig_ti.Fn.alignment,
        .is_generic = orig_ti.Fn.is_generic,
        .is_var_args = orig_ti.Fn.is_var_args,
        .return_type = orig_ti.Fn.return_type,
        .params = &new_params,
    };

    return @Type(.{ .Fn = new_fn });
}

pub const DeleteParamE = enum {
    index,
    type,
};

pub const DeleteParamU = union(DeleteParamE) {
    index: usize,
    type: type,
};

pub fn deleteParamFromFn(comptime orig_fn_type: type, comptime by: DeleteParamU) type {
    const orig_ti = @typeInfo(orig_fn_type);
    switch (orig_ti) {
        .Fn => {},
        else => {
            @compileError("orig_fn_type must be Fn type, but got:" ++ @typeName(orig_fn_type));
        },
    }

    switch (by) {
        .index => |index| {
            if (orig_ti.Fn.params.len == 0) {
                @compileError("orig_fn_type has no params.");
            }

            if (index > orig_ti.Fn.params.len) {
                @compileLog("index should be less than:", orig_ti.Fn.params.len, ", got: ", index);
                @compileError("index out of bound.");
            }

            var new_params: [orig_ti.Fn.params.len - 1]builtin.Type.Fn.Param = undefined;
            comptime var j: usize = 0;
            comptime for (0..orig_ti.Fn.params.len) |i| {
                if (i == index) {
                    continue;
                } else {
                    new_params[j] = orig_ti.Fn.params[i];
                    j += 1;
                }
            };

            const new_fn: builtin.Type.Fn = .{
                .calling_convention = orig_ti.Fn.calling_convention,
                .alignment = orig_ti.Fn.alignment,
                .is_generic = orig_ti.Fn.is_generic,
                .is_var_args = orig_ti.Fn.is_var_args,
                .return_type = orig_ti.Fn.return_type,
                .params = &new_params,
            };

            return @Type(.{ .Fn = new_fn });
        },
        .type => |unwanted_type| {
            const found: usize = brk: {
                comptime for (0..orig_ti.Fn.params.len) |i| {
                    if (orig_ti.Fn.params[i].type == unwanted_type) {
                        break :brk i;
                    }
                };
                return @Type(orig_ti);
            };
            const delete_once_type_result = deleteParamFromFn(orig_fn_type, .{ .index = found });
            return deleteParamFromFn(delete_once_type_result, .{ .type = unwanted_type });
        },
    }
}

pub fn replaceFnReturn(comptime orig_fn_type: type, comptime new_return_type: type) type {
    const orig_ti = @typeInfo(orig_fn_type);
    switch (orig_ti) {
        .Fn => {},
        else => {
            @compileError("orig_fn_type must be Fn type, but got:" ++ @typeName(orig_fn_type));
        },
    }

    const new_fn: builtin.Type.Fn = .{
        .calling_convention = orig_ti.Fn.calling_convention,
        .alignment = orig_ti.Fn.alignment,
        .is_generic = orig_ti.Fn.is_generic,
        .is_var_args = orig_ti.Fn.is_var_args,
        .return_type = new_return_type,
        .params = orig_ti.Fn.params,
    };

    return @Type(.{ .Fn = new_fn });
}

// all tests. Most tests, if it can compile and run then means passed

test "poc" {
    // credit to https://stackoverflow.com/questions/61466724/generation-of-types-in-zig-zig-language/63858916#63858916
    const A = @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &[_]builtin.Type.StructField{
                .{ .name = "one", .type = i32, .default_value = null, .is_comptime = false, .alignment = 0 },
            },
            .decls = &[_]builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
    const a: A = .{ .one = 25 };
    try testing.expectEqual(a.one, 25);
}

test "addFieldToStruct" {
    const S1 = struct { b: usize };
    const S2 = insertFieldToStruct(S1, .{ .name = "a", .type = usize }, 0);
    const v: S2 = .{ .a = 1, .b = 2 };
    try testing.expectEqual(v.a + v.b, 3);
}

test "deleteFieldFromStruct" {
    {
        const S1 = struct { a: usize, b: usize };
        const S2 = deleteFieldFromStruct(S1, .{ .index = 0 });
        const v: S2 = .{ .b = 2 };
        _ = v;
    }
    {
        const S1 = struct { a: usize, b: usize };
        const S2 = deleteFieldFromStruct(S1, .{ .name = "a" });
        const v: S2 = .{ .b = 2 };
        _ = v;
    }
    {
        const S1 = struct { a: usize, b: usize, c: i32 };
        const S2 = deleteFieldFromStruct(S1, .{ .type = usize });
        const v: S2 = .{ .c = 2 };
        _ = v;
    }
}

fn test_addParamToFn_1() void {
    std.debug.print("\ngreeting!\n", .{});
}

fn test_addParamToFn_2(msg: []const u8) void {
    std.debug.print("\n{s}\n", .{msg});
}

test "addParamToFn" {
    const f2 = insertParamToFn(@TypeOf(test_addParamToFn_1), .{ .type = []const u8 }, 0);
    const fptr: *const f2 = test_addParamToFn_2;
    fptr("hello");
}

test "deleteParamFromFn" {
    {
        const f2 = deleteParamFromFn(@TypeOf(test_addParamToFn_2), .{ .index = 0 });
        const fptr: *const f2 = test_addParamToFn_1;
        fptr();
    }
    {
        const f2 = deleteParamFromFn(@TypeOf(test_addParamToFn_2), .{ .type = []const u8 });
        const fptr: *const f2 = test_addParamToFn_1;
        fptr();
    }
}

fn test_replaceFnReturn_1() void {}

fn test_replaceFnReturn_2() usize {
    return 0;
}

test "replaceFnReturn" {
    const f2 = replaceFnReturn(@TypeOf(test_replaceFnReturn_1), usize);
    const fptr: *const f2 = test_replaceFnReturn_2;
    const ret = fptr();
    try testing.expectEqual(ret, 0);
}
