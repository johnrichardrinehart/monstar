//! OpenSSH wrapper that installs Monstar's terminfo entry before login.

const std = @import("std");

const terminfo = @embedFile("monstar-terminfo-source");
const bootstrap_command =
    \\if infocmp monstar >/dev/null 2>&1; then
    \\  cat >/dev/null
    \\elif command -v tic >/dev/null 2>&1; then
    \\  mkdir -p "$HOME/.terminfo" && tic -x -o "$HOME/.terminfo" -
    \\else
    \\  cat >/dev/null
    \\  echo 'monstar ssh: remote host does not provide tic' >&2
    \\  exit 127
    \\fi
;

pub fn run(init: std.process.Init, args: []const [:0]const u8) !void {
    const arena = init.arena.allocator();
    const parsed = parseArgs(args) catch return error.InvalidCli;

    const bootstrap_argv = try buildBootstrapArgs(arena, args, parsed);

    var bootstrap = try std.process.spawn(init.io, .{
        .argv = bootstrap_argv,
        .stdin = .pipe,
    });

    bootstrap.stdin.?.writeStreamingAll(init.io, terminfo) catch |err| {
        bootstrap.kill(init.io);
        return err;
    };
    bootstrap.stdin.?.close(init.io);
    bootstrap.stdin = null;
    const bootstrap_term = try bootstrap.wait(init.io);
    if (exitCode(bootstrap_term) != 0) return error.TerminfoBootstrapFailed;

    var ssh_argv: std.ArrayList([]const u8) = .empty;
    try ssh_argv.append(arena, "ssh");
    for (args) |arg| try ssh_argv.append(arena, arg);
    var ssh = try std.process.spawn(init.io, .{ .argv = ssh_argv.items });
    const ssh_term = try ssh.wait(init.io);
    std.process.exit(exitCode(ssh_term));
}

fn buildBootstrapArgs(
    arena: std.mem.Allocator,
    args: []const [:0]const u8,
    parsed: ParsedArgs,
) ![]const []const u8 {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.append(arena, "ssh");
    try argv.append(arena, "-oRemoteCommand=none");
    try argv.append(arena, "-oRequestTTY=no");
    try argv.append(arena, "-oSessionType=default");
    try argv.append(arena, "-oStdinNull=no");
    for (args[0..parsed.destination_index], 0..) |arg, index| {
        if (!parsed.omit_from_bootstrap[index]) try argv.append(arena, arg);
    }
    try argv.append(arena, args[parsed.destination_index]);
    try argv.append(arena, bootstrap_command);
    return argv.toOwnedSlice(arena);
}

const ParsedArgs = struct {
    destination_index: usize,
    omit_from_bootstrap: [256]bool = @splat(false),
};

fn parseArgs(args: []const [:0]const u8) !ParsedArgs {
    if (args.len == 0 or args.len > 256) return error.InvalidCli;

    var parsed: ParsedArgs = .{ .destination_index = undefined };
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--")) {
            index += 1;
            if (index >= args.len) return error.InvalidCli;
            parsed.destination_index = index;
            break;
        }
        if (arg.len == 0 or arg[0] != '-' or std.mem.eql(u8, arg, "-")) {
            parsed.destination_index = index;
            break;
        }
        if (arg.len < 2 or arg[1] == '-') return error.InvalidCli;

        var omit_from_bootstrap = false;
        var takes_value = false;
        var short_index: usize = 1;
        while (short_index < arg.len) : (short_index += 1) {
            const option = arg[short_index];
            if (std.mem.indexOfScalar(u8, "fGNsVQ", option) != null) return error.InvalidCli;
            if (std.mem.indexOfScalar(u8, "nTt", option) != null) omit_from_bootstrap = true;
            if (std.mem.indexOfScalar(u8, "BbCcDEeFIiJLlmOoPpRSwW", option) != null) {
                takes_value = true;
                if (short_index + 1 == arg.len) {
                    index += 1;
                    if (index >= args.len) return error.InvalidCli;
                }
                break;
            }
        }
        if (omit_from_bootstrap and takes_value) return error.InvalidCli;
        parsed.omit_from_bootstrap[index] = omit_from_bootstrap;
    }

    if (index >= args.len or index + 1 != args.len) return error.InvalidCli;
    return parsed;
}

fn exitCode(term: std.process.Child.Term) u8 {
    return switch (term) {
        .exited => |code| code,
        .signal => |signal| 128 +% @as(u8, @truncate(@intFromEnum(signal))),
        .stopped, .unknown => 1,
    };
}

test "SSH arguments find destination after options" {
    const args = [_][:0]const u8{ "-p", "2222", "-vv", "user@example.com" };
    const parsed = try parseArgs(&args);
    try std.testing.expectEqual(3, parsed.destination_index);
}

test "SSH bootstrap omits terminal and stdin options" {
    const args = [_][:0]const u8{ "-tn", "example.com" };
    const parsed = try parseArgs(&args);
    try std.testing.expect(parsed.omit_from_bootstrap[0]);
}

test "SSH bootstrap preserves connection options" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();

    const args = [_][:0]const u8{ "-t", "-p", "2222", "user@example.com" };
    const parsed = try parseArgs(&args);
    const argv = try buildBootstrapArgs(arena_state.allocator(), &args, parsed);

    try std.testing.expectEqualStrings("ssh", argv[0]);
    try std.testing.expectEqualStrings("-oRemoteCommand=none", argv[1]);
    try std.testing.expectEqualStrings("-p", argv[5]);
    try std.testing.expectEqualStrings("2222", argv[6]);
    try std.testing.expectEqualStrings("user@example.com", argv[7]);
    try std.testing.expectEqualStrings(bootstrap_command, argv[8]);
}

test "SSH arguments reject remote commands" {
    const args = [_][:0]const u8{ "example.com", "uptime" };
    try std.testing.expectError(error.InvalidCli, parseArgs(&args));
}

test "SSH arguments reject forwarding-only sessions" {
    const args = [_][:0]const u8{ "-N", "example.com" };
    try std.testing.expectError(error.InvalidCli, parseArgs(&args));
}
