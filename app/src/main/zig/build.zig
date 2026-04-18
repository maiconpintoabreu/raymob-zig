const std = @import("std");

pub fn build(b: *std.Build) void {
    const native_lib_name = b.option([]const u8, "native_lib_name", "Name of the output library") orelse "raymobzig";
    const gl_version = b.option([]const u8, "gl_version", "OpenGL ES version (ES20, ES30)") orelse "ES20";
    const ndk_home = b.graph.environ_map.get("ANDROID_NDK_HOME") orelse "/home/maicon/Android/Sdk/ndk/28.0.13004108";

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = if (target.result.abi.isAndroid()) b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
        .platform = .android,
        .android_ndk = ndk_home,
        .android_api_version = 28,
    }) else b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib_artifact = raylib_dep.artifact("raylib");
    raylib_artifact.root_module.pic = true;

    const exe_mod = b.createModule(.{
        .root_source_file = if (target.result.abi.isAndroid()) b.path("src/main_android.zig") else b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.linkLibrary(raylib_artifact);
    exe_mod.linkLibrary(raylib_artifact);

    const run_step = b.step("run", "Run the app");

    if (target.result.abi.isAndroid()) {
        const lib = b.addLibrary(.{
            .name = native_lib_name,
            .linkage = .dynamic,
            .root_module = exe_mod,
        });
        const mod = lib.root_module;
        mod.addCMacro("PLATFORM", "Android");
        mod.addCMacro("APP_LIB_NAME", native_lib_name);
        mod.addCMacro("GL_VERSION", gl_version);
        mod.pic = true;

        const toolchain_path = b.fmt("{s}/toolchains/llvm/prebuilt/linux-x86_64", .{ndk_home});
        const sysroot_path = b.fmt("{s}/sysroot", .{toolchain_path});

        const cpu_arch = @tagName(target.result.cpu.arch);
        const suffix = if (target.result.cpu.arch == .arm) "-linux-androideabi" else "-linux-android";
        const arch_dir = b.fmt("{s}{s}", .{ cpu_arch, suffix });

        const libc_content = b.fmt(
            \\include_dir={0s}/usr/include
            \\sys_include_dir={0s}/usr/include/{1s}
            \\crt_dir={0s}/usr/lib/{1s}/{2d}
            \\static_lib_dir={0s}/usr/lib/{1s}/{2d}
            \\msvc_lib_dir=
            \\kernel32_lib_dir=
            \\gcc_dir=
        , .{ sysroot_path, arch_dir, 28 });

        const write_step = b.addWriteFiles();
        const libc_file = write_step.add("android-libc.txt", libc_content);

        const glue_dir = b.pathJoin(&.{ ndk_home, "sources/android/native_app_glue" });
        const glue_src = b.pathJoin(&.{ glue_dir, "android_native_app_glue.c" });

        // 3. Add the include path to the module
        lib.root_module.addIncludePath(.{ .cwd_relative = glue_dir });

        // 4. Add the C source file to the module
        lib.root_module.addCSourceFile(.{
            .file = .{ .cwd_relative = glue_src },
            .flags = &.{ "-std=c99", "-DANDROID" },
        });

        lib.setLibCFile(libc_file);
        lib.root_module.link_libc = true;

        const lib_dir = b.fmt("{s}/usr/lib/{s}/{d}", .{ sysroot_path, arch_dir, 28 });
        lib.root_module.addLibraryPath(.{ .cwd_relative = lib_dir });

        lib.root_module.export_symbol_names = &.{"main"};
        lib.root_module.linkSystemLibrary("android", .{});
        lib.root_module.linkSystemLibrary("log", .{});
        lib.root_module.linkSystemLibrary("EGL", .{});
        lib.root_module.linkSystemLibrary("GLESv2", .{});

        lib.root_module.linkLibrary(raylib_artifact);
        b.installArtifact(lib);
    } else {
        const exe = b.addExecutable(.{
            .name = native_lib_name,
            .root_module = exe_mod,
            .use_llvm = if (optimize == .Debug) true else null,
            .use_lld = if (optimize == .Debug) true else null,
        });
        const content_path = "resources/";
        const install_content_step = b.addInstallDirectory(.{
            .source_dir = b.path(content_path),
            .install_dir = .prefix,
            .install_subdir = "resources/",
        });
        exe.step.dependOn(&install_content_step.step);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        run_step.dependOn(&run_cmd.step);
    }
}
