package main

import "core:fmt"
import "core:slice"
import rl "vendor:raylib"

FONTFILE :: #load("./assets/DMSerifText-Regular.ttf")
FONTSIZE :: 40
SMALLFONTSIZE :: FONTSIZE - 10
VERTEX_RADIUS :: FONTSIZE * 0.45

COLOR_BACKGROUND :: rl.RAYWHITE
COLOR_SUBTITLE :: rl.BLACK
COLOR_VERTEX_TEXT :: COLOR_BACKGROUND
COLOR_START_VERTEX :: rl.Color{219, 50, 46, 255}
COLOR_END_VERTEX :: rl.Color{46, 219, 141, 255}
COLOR_IN_PATH :: rl.Color{38, 138, 210, 255}
COLOR_NOT_IN_PATH :: rl.DARKGRAY
COLOR_WEIGHT_TEXT :: rl.DARKBLUE
COLOR_WEIGHT_NOT_IN_PATH_TEXT :: COLOR_NOT_IN_PATH

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
    rl.InitWindow(800, 600, "Algoritmo de Floyd-Warshall aplicado a Redes de Transporte")
    rl.SetTargetFPS(60)

    font := load_baked_font(FONTFILE, FONTSIZE)
    smallfont := load_baked_font(FONTFILE, SMALLFONTSIZE)

    Cities := [?]cstring{"Quito", "St. Domingo", "Riobamba", "Azoguez", "Cuenca", "Machala", "Guayaquil"}
    V := [?]cstring{"Q", "S", "R", "A", "C", "M", "G"}
    E := map[[2]uint]f32{}
    add_edge(V[:], &E, "Q", "S", 0.60)
    add_edge(V[:], &E, "S", "G", 1.00)
    add_edge(V[:], &E, "S", "R", 0.75)
    add_edge(V[:], &E, "S", "M", 0.00)
    add_edge(V[:], &E, "G", "M", 0.70)
    add_edge(V[:], &E, "G", "R", 0.00)
    add_edge(V[:], &E, "R", "A", 1.25)
    add_edge(V[:], &E, "M", "A", 1.25)
    add_edge(V[:], &E, "M", "C", 0.00)
    add_edge(V[:], &E, "C", "A", 0.75)

    m := floyd_warshall_graph(len(V), E, directed=false)
    solver := floyd_warshall_make(len(V), m)

    start, end: int = 0, 0
    edge_points := map[[2]uint][2]rl.Vector2{}

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
            {sw * (.5 + .25), sh * (.5 - .45)}, // Q
            {sw * (.5 + .15), sh * (.5 - .29)}, // S
            {sw * (.5 + .25), sh * (.5 - .14)}, // R
            {sw * (.5 + .20), sh * (.5 + .08)}, // A
            {sw * (.5 + .15), sh * (.5 + .30)}, // C
            {sw * (.5 - .25), sh * (.5 + .00)}, // M
            {sw * (.5 - .15), sh * (.5 - .25)}, // G
        }

        for edge, weight in E {
            edge_points[edge] = {vertices[edge.x], vertices[edge.y]}
        }

        rl.BeginDrawing()
        rl.ClearBackground(COLOR_BACKGROUND)

        /* Subtitle */ {
            text := rl.TextFormat("Desde %s hasta %s: $%v", Cities[start], Cities[end], solver.dist[start][end])
            measure := rl.MeasureTextEx(font, text, FONTSIZE, 0)
            draw_text_centered(font, text, {sw/2, sh - measure.y}, FONTSIZE, COLOR_SUBTITLE)
        }

        for edge, points in edge_points {
            is_in_path := false
            for i in 0..<len(solver.paths[start][end])-1 {
                e := [2]uint{
                    solver.paths[start][end][i:i+2][0],
                    solver.paths[start][end][i:i+2][1],
                }
                if e == edge || e == edge.yx {
                    is_in_path = true
                }
            }
            a, b := points[0], points[1]
            rl.DrawLineEx(a, b, 4 if is_in_path else 2, COLOR_IN_PATH if is_in_path else COLOR_NOT_IN_PATH)
            {
                f := font if is_in_path else smallfont
                s: f32 = FONTSIZE if is_in_path else SMALLFONTSIZE
                draw_weight(f, (a + b)/2, E[edge], s, is_in_path)
            }
        }

        for pos, i in vertices {
            _, found := slice.linear_search(solver.paths[start][end][:], uint(i))
            color: rl.Color = ---
            if i == start do color = COLOR_START_VERTEX
            else if i == end do color = COLOR_END_VERTEX
            else if found do color = COLOR_IN_PATH
            else do color = COLOR_NOT_IN_PATH
            check_clicked_vertex(i, pos, &start, &end)
            draw_vertex(font, pos, V[i], color)
        }
        rl.EndDrawing()
    }

    rl.CloseWindow()
}


// Helper Functions

load_baked_font :: proc(filedata: []u8, fontsize: i32) -> rl.Font {
    return rl.LoadFontFromMemory(".ttf", raw_data(filedata), cast(i32)len(filedata), fontsize, nil, 0)
}

add_edge :: proc(V: []cstring, E: ^map[[2]uint]f32, v1, v2: cstring, weight: f32) {
    v1_pos, found_v1 := slice.linear_search(V, v1)
    assert(found_v1)
    v2_pos, found_v2 := slice.linear_search(V, v2)
    assert(found_v2)
    edge := [2]uint{uint(v1_pos), uint(v2_pos)}
    E^[edge] = weight
}

draw_text_centered :: proc(font: rl.Font, text: cstring, pos: rl.Vector2, fontsize: f32, color: rl.Color) {
    measure := rl.MeasureTextEx(font, text, fontsize, 0)
    rl.DrawTextEx(font, text, pos - measure/2, fontsize, 0, color)
}

draw_vertex :: proc(font: rl.Font, pos: rl.Vector2, name: cstring, color: rl.Color) {
    rl.DrawCircleV(pos, VERTEX_RADIUS, color)
    draw_text_centered(font, name, pos, FONTSIZE, COLOR_VERTEX_TEXT)
}

draw_weight :: proc(font: rl.Font, pos: rl.Vector2, value, fontsize: f32, is_in_path: bool) {
    text := rl.TextFormat("$%v", value) if value != 0.70 else "$0.7"
    draw_text_centered(font, text, pos, fontsize, COLOR_WEIGHT_TEXT if is_in_path else COLOR_WEIGHT_NOT_IN_PATH_TEXT)
}

check_clicked_vertex :: proc(vertex_index: int, vertex_pos: rl.Vector2, start, end: ^int) {
    if rl.IsMouseButtonDown(.LEFT) && rl.CheckCollisionPointCircle(rl.GetMousePosition(), vertex_pos, VERTEX_RADIUS*2) {
        start^ = vertex_index
    }
    if rl.IsMouseButtonDown(.RIGHT) && rl.CheckCollisionPointCircle(rl.GetMousePosition(), vertex_pos, VERTEX_RADIUS*2) {
        end^ = vertex_index
    }
}
