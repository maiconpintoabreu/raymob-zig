const std = @import("std");

const ray = @cImport({
    @cInclude("raylib.h");
});

export fn main() void {
    const screenWidth = 800;
    const screenHeight = 450;

    ray.InitWindow(screenWidth, screenHeight, "Raylib Android - ZIG");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("Hello from Zig!", 190, 200, 20, ray.LIGHTGRAY);
    }
}

//TODO: implement it some how
export fn __real_fopen(path: [*:0]const u8, mode: [*:0]const u8) callconv(.c) ?*anyopaque {
    _ = path;
    _ = mode;
    return null;
}
