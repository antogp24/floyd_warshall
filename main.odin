package main

import "core:fmt"
import "core:slice"
import rl "vendor:raylib"

V := [?]cstring{"A", "B", "C", "D", "E"}
E := map[[2]uint]f32{
    {/*A*/0, /*B*/1} =  4,
    {/*A*/0, /*D*/3} =  5,
    {/*B*/1, /*C*/2} =  1,
    {/*B*/1, /*E*/4} =  6,
    {/*C*/2, /*A*/0} =  2,
    {/*C*/2, /*D*/3} =  3,
    {/*D*/3, /*C*/2} =  1,
    {/*D*/3, /*E*/4} =  2,
    {/*E*/4, /*A*/0} =  1,
    {/*E*/4, /*D*/3} =  4,
}

FONTSIZE :: 50

draw_text_centered :: proc(font: rl.Font, text: cstring, pos: rl.Vector2, fontsize: f32, color: rl.Color) {
    measure := rl.MeasureTextEx(font, text, fontsize, 0)
    rl.DrawTextEx(font, text, pos - measure/2, fontsize, 0, color)
}

draw_vertex :: proc(font: rl.Font, pos: rl.Vector2, name: cstring, color: rl.Color) {
    RADIUS :: 25
    rl.DrawCircleV(pos, RADIUS, color)
    draw_text_centered(font, name, pos, FONTSIZE, rl.WHITE)
}

draw_weight :: proc(font: rl.Font, pos: rl.Vector2, value, fontsize: f32, color: rl.Color) {
    text := rl.TextFormat("%v", value)
    draw_text_centered(font, text, pos, fontsize, color)
}

parametric_line :: #force_inline proc(A, B: rl.Vector2, $t: f32) -> rl.Vector2 where t >= 0 && t <=1 {
    return rl.Vector2{
        A.x + (B.x - A.x) * t,
        A.y + (B.y - A.y) * t,
    }
}

// Gives a point in the line perpendicular to the line formed by A and B, it passes through the midpoint between A and B.
middlep :: proc(A, B: rl.Vector2, $t: f32) -> rl.Vector2 {
    mid := (A + B) / 2
    if B.y == A.y do return mid + {0, t}
    mp := - (B.x - A.x) / (B.y - A.y)
    return rl.Vector2{ mid.x + t, mid.y + mp * t }
}

main :: proc() {
    rl.InitWindow(800, 600, "Algoritmo de Floyd-Warshall")
    rl.SetTargetFPS(60)

    font := rl.LoadFontEx("./assets/DMSerifText-Regular.ttf", FONTSIZE, nil, 0)
    m := floyd_warshall_graph(len(V), E)
    solver := floyd_warshall_make(len(V), m)

    start, end: int = 0, 0

    for !rl.WindowShouldClose() {
        time := rl.GetTime()
        sw, sh := cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()

        if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressedRepeat(.LEFT) {
            start = (start - 1) %% len(solver.dist)
        }
        else if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressedRepeat(.RIGHT) {
            start = (start + 1) %% len(solver.dist)
        }
        else if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressedRepeat(.DOWN) {
            end = (end - 1) %% len(solver.dist)
        }
        else if rl.IsKeyPressed(.UP) || rl.IsKeyPressedRepeat(.UP) {
            end = (end + 1) %% len(solver.dist)
        }

        vertices := [?]rl.Vector2{
            {sw * (.5 - .15), sh * (.5 - .25)}, // A
            {sw * (.5 + .15), sh * (.5 - .25)}, // B
            {sw * (.5 - .30), sh * (.5      )}, // C
            {sw * (.5      ), sh * (.5 + .25)}, // D
            {sw * (.5 + .30), sh * (.5      )}, // E
        }
        edge_points := map[[2]uint][]rl.Vector2{
            {/*A*/0, /*B*/1} =  {vertices[0], vertices[1]},
            {/*A*/0, /*D*/3} =  {vertices[0], vertices[3]},
            {/*B*/1, /*C*/2} =  {vertices[1], vertices[2]},
            {/*B*/1, /*E*/4} =  {vertices[1], vertices[4]},
            {/*C*/2, /*A*/0} =  {vertices[2], vertices[0]},
            {/*C*/2, /*D*/3} =  {vertices[2], vertices[3]},
            {/*D*/3, /*C*/2} =  {vertices[3], vertices[3], middlep(vertices[3], vertices[2], -30), vertices[2] + {5, 30}, vertices[2] + {5, 30}},
            {/*D*/3, /*E*/4} =  {vertices[3], vertices[4]},
            {/*E*/4, /*A*/0} =  {vertices[4], vertices[0]},
            {/*E*/4, /*D*/3} =  {vertices[4], vertices[4], middlep(vertices[4], vertices[3], 30), vertices[3] + {30, 0}, vertices[3] + {30, 0}},
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)

        /* Top Header */ {
            text := rl.TextFormat("Desde (%s) hasta (%s) el peso es %v", V[start], V[end], solver.dist[start][end])
            draw_text_centered(font, text, {sw/2, sh*.10}, FONTSIZE, rl.BLACK)
        }

        for edge, points in edge_points {
            _, found0 := slice.linear_search(solver.paths[start][end][:], edge[0])
            _, found1 := slice.linear_search(solver.paths[start][end][:], edge[1])
            is_in_path := found0 && found1 && edge[1] != uint(start) && edge[0] != uint(end)
            color := rl.BLUE if is_in_path else rl.DARKGRAY
            assert(len(points) == 2 || len(points) == 5)
            if len(points) == 2 {
                a, b := points[0], parametric_line(points[0], points[1], 0.85)
                rl.DrawLineEx(a, b, 4 if is_in_path else 2, color)
                rl.DrawCircleV(b, 8 if is_in_path else 4, color)
                draw_weight(font, (a + b)/2, E[edge], FONTSIZE - (-10 if is_in_path else 15), color)
            }
            else if len(points) == 5 {
                rl.DrawSplineCatmullRom(raw_data(points), cast(i32)len(points), 4 if is_in_path else 2, color)
                rl.DrawCircleV(points[4], 8 if is_in_path else 4, color)
                draw_weight(font, points[2], E[edge], FONTSIZE - (-10 if is_in_path else 15), color)
            }
        }
        for pos, i in vertices {
            _, found := slice.linear_search(solver.paths[start][end][:], uint(i))
            color: rl.Color = ---
            if i == start do color = rl.RED
            else if found do color = rl.BLUE
            else do color = rl.DARKGRAY
            draw_vertex(font, pos, V[i], color)
        }
        rl.EndDrawing()
    }

    rl.CloseWindow()
}