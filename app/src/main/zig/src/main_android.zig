const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const BONE_SOCKETS = 3;
const BONE_SOCKET_HAT = 0;
const BONE_SOCKET_HAND_R = 1;
const BONE_SOCKET_HAND_L = 2;

export fn main() void {
    const screenWidth: i32 = 800;
    const screenHeight: i32 = 450;

    rl.InitWindow(screenWidth, screenHeight, "raylib [models] example - bone socket");
    defer rl.CloseWindow();

    // Define the camera to look into our 3d world
    var camera: rl.Camera3D = .{
        .position = .{ .x = 5.0, .y = 5.0, .z = 5.0 },
        .target = .{ .x = 0.0, .y = 2.0, .z = 0.0 },
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = rl.CAMERA_PERSPECTIVE,
    };

    // Load gltf model
    var characterModel: rl.Model = rl.LoadModel("resources/greenman.glb"); // Load character model
    defer rl.UnloadModel(characterModel);
    const equipModel: [BONE_SOCKETS]rl.Model = .{
        rl.LoadModel("resources/greenman_hat.glb"), // Index for the hat model is the same as BONE_SOCKET_HAT
        rl.LoadModel("resources/greenman_sword.glb"), // Index for the sword model is the same as BONE_SOCKET_HAND_R
        rl.LoadModel("resources/greenman_shield.glb"), // Index for the shield model is the same as BONE_SOCKET_HAND_L
    };
    defer for (equipModel) |model| {
        rl.UnloadModel(model);
    };

    var showEquip: [3]bool = .{ true, true, true }; // Toggle on/off equip

    // Load gltf model animations
    var animsCount: i32 = 0;
    var animIndex: usize = 0;
    var animCurrentFrame: f32 = 0;
    const modelAnimations = rl.LoadModelAnimations("resources/greenman.glb", &animsCount);
    defer rl.UnloadModelAnimations(modelAnimations, animsCount);

    const animsCountU: usize = @intCast(animsCount);

    // indices of bones for sockets
    var boneSocketIndex: [BONE_SOCKETS]usize = undefined;

    // search bones for sockets
    for (0..@as(usize, @intCast(characterModel.skeleton.boneCount))) |i| {
        const boneName: [:0]const u8 = @ptrCast(&characterModel.skeleton.bones[i].name);
        if (rl.TextIsEqual(boneName, "socket_hat")) {
            boneSocketIndex[BONE_SOCKET_HAT] = i;
            continue;
        }

        if (rl.TextIsEqual(boneName, "socket_hand_R")) {
            boneSocketIndex[BONE_SOCKET_HAND_R] = i;
            continue;
        }

        if (rl.TextIsEqual(boneName, "socket_hand_L")) {
            boneSocketIndex[BONE_SOCKET_HAND_L] = i;
            continue;
        }
    }

    const position: rl.Vector3 = .{ .x = 0, .y = 0, .z = 0 }; // Set model position
    var angle: f32 = 0.0; // Set angle for rotate character

    rl.DisableCursor(); // Limit cursor to relative movement inside the window

    rl.SetTargetFPS(60); // Set our game to run at 60 frames-per-second

    while (!rl.WindowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        rl.UpdateCamera(&camera, rl.CAMERA_THIRD_PERSON);

        // Rotate character
        if (rl.IsKeyDown(rl.KEY_F)) {
            angle += 1.0;
            angle = @mod(angle, 360.0);
        } else if (rl.IsKeyDown(rl.KEY_H)) {
            angle -= 1.0;
            angle = @mod(angle, 360.0);
        }

        // Select current animation
        if (rl.IsKeyPressed(rl.KEY_T)) animIndex = (animIndex + 1) % animsCountU else if (rl.IsKeyPressed(rl.KEY_G)) animIndex = (animIndex + animsCountU - 1) % animsCountU;

        // Toggle shown of equip
        if (rl.IsKeyPressed(rl.KEY_ONE)) showEquip[BONE_SOCKET_HAT] = !showEquip[BONE_SOCKET_HAT];
        if (rl.IsKeyPressed(rl.KEY_TWO)) showEquip[BONE_SOCKET_HAND_R] = !showEquip[BONE_SOCKET_HAND_R];
        if (rl.IsKeyPressed(rl.KEY_THREE)) showEquip[BONE_SOCKET_HAND_L] = !showEquip[BONE_SOCKET_HAND_L];

        // Update model animation
        const anim = modelAnimations[animIndex];
        animCurrentFrame = @mod(animCurrentFrame + 1, @as(f32, @floatFromInt(anim.keyframeCount)));
        rl.UpdateModelAnimation(characterModel, anim, animCurrentFrame);
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        {
            rl.BeginDrawing();
            defer rl.EndDrawing();

            rl.ClearBackground(rl.RAYWHITE);
            {
                rl.BeginMode3D(camera);
                defer rl.EndMode3D();
                // Draw character
                const characterRotate: rl.Quaternion = rl.QuaternionFromAxisAngle(.{ .x = 0.0, .y = 1.0, .z = 0.0 }, angle * std.math.rad_per_deg);
                characterModel.transform = rl.MatrixMultiply(rl.QuaternionToMatrix(characterRotate), rl.MatrixTranslate(position.x, position.y, position.z));
                rl.UpdateModelAnimation(characterModel, anim, animCurrentFrame);
                rl.DrawMesh(characterModel.meshes[0], characterModel.materials[1], characterModel.transform);

                // Draw equipments (hat, sword, shield)
                for (0..BONE_SOCKETS) |i| {
                    if (!showEquip[i]) continue;

                    const transform = &anim.keyframePoses[@as(usize, @intFromFloat(animCurrentFrame))][boneSocketIndex[i]];
                    const inRotation = characterModel.skeleton.bindPose[boneSocketIndex[i]].rotation;
                    const outRotation = transform.rotation;

                    // Calculate socket rotation (angle between bone in initial pose and same bone in current animation frame)
                    const rotate = rl.QuaternionMultiply(outRotation, rl.QuaternionInvert(inRotation));
                    var matrixTransform = rl.QuaternionToMatrix(rotate);
                    // Translate socket to its position in the current animation
                    matrixTransform = rl.MatrixMultiply(matrixTransform, rl.MatrixTranslate(transform.translation.x, transform.translation.y, transform.translation.z));
                    // Transform the socket using the transform of the character (angle and translate)
                    matrixTransform = rl.MatrixMultiply(matrixTransform, characterModel.transform);

                    // Draw mesh at socket position with socket angle rotation
                    rl.DrawMesh(equipModel[i].meshes[0], equipModel[i].materials[1], matrixTransform);
                }

                rl.DrawGrid(10, 1.0);
            }

            rl.DrawText("Use the T/G to switch animation", 10, 10, 20, rl.GRAY);
            rl.DrawText("Use the F/H to rotate character left/right", 10, 35, 20, rl.GRAY);
            rl.DrawText("Use the 1,2,3 to toggle shown of hat, sword and shield", 10, 60, 20, rl.GRAY);
            //----------------------------------------------------------------------------------
        }
    }
}

// Define the __wrap_fopen to be implemented inside Raylib
extern "c" fn __wrap_fopen(filename: [*c]const u8, modes: [*c]const u8) callconv(.c) ?*anyopaque;

// Define dlsym and RTLD_NEXT to be able to call system fopen as I am overriding it bellow
// https://pubs.opengroup.org/onlinepubs/009604299/functions/dlsym.html
extern "c" fn dlsym(handle: ?*anyopaque, symbol: [*c]const u8) ?*anyopaque;
const RTLD_NEXT = @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));

// Override fopen to call __wrap_fopen
export fn fopen(filename: [*c]const u8, modes: [*c]const u8) callconv(.c) ?*anyopaque {
    return __wrap_fopen(filename, modes);
}

// Implement __real_fopen as Raylib needs it to open files that are not inside assets folder
export fn __real_fopen(filename: [*c]const u8, modes: [*c]const u8) callconv(.c) ?*anyopaque {
    const real_fopen_ptr = dlsym(RTLD_NEXT, "fopen") orelse return null;
    const real_fopen: *const fn ([*c]const u8, [*c]const u8) callconv(.c) ?*anyopaque = @ptrCast(@alignCast(real_fopen_ptr));

    return real_fopen(filename, modes);
}
