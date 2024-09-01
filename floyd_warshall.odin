package main

FloydWarshall :: struct($N: uint) {
    dist:  [N][N]f32,
    next:  [N][N]uint,
    paths: [N][N][dynamic]uint,
}

@(private="file")
INF :: 1e5000

floyd_warshall_make :: proc($N: uint, graph_matrix: [N][N]f32) -> (self: FloydWarshall(N)) {
    // Copy input graph_matrix.
    for i in 0..<N {
        for j in 0..<N {
            if graph_matrix[i][j] < INF do self.next[i][j] = j
            self.dist[i][j] = graph_matrix[i][j]
        }
    }

    // Compute all pairs shortest paths.
    for k in 0..<N {
        for i in 0..<N {
            for j in 0..<N {
                if (self.dist[i][k] + self.dist[k][j] < self.dist[i][j]) {
                    self.dist[i][j] = self.dist[i][k] + self.dist[k][j]
                    self.next[i][j] = self.next[i][k]
                }
            }
        }
    }

    // Reconstruct all paths as lists of vertices.
    for start in 0..<N {
        for end in 0..<N {
            if self.dist[start][end] >= INF do continue

            for at := start; at != end; at = self.next[at][end] {
                append(&self.paths[start][end], at)
            }
            append(&self.paths[start][end], end)
        }
    }

    return
}

get_path :: proc($N: uint, using self: ^FloydWarshall(N), V: []cstring, start: uint, end: uint) -> (path: [dynamic]cstring) {
    int_path := paths[start][end]
    for i in 0..<len(int_path) do append(&path, V[int_path[i]])
    return
}

floyd_warshall_default_graph :: proc($N: uint) -> (m: [N][N]f32) {
    for i in 0..<N {
        for j in 0..<N {
            if i != j do m[i][j] = INF
        }
    }
    return
}

floyd_warshall_graph :: proc($N: uint, E: map[[2]uint]f32, directed := true) -> (m: [N][N]f32) {
    for i in 0..<N {
        for j in 0..<N {
            m[i][j] = INF if i != j else 0
        }
    }
    for edge, weight in E {
        m[edge.x][edge.y] = weight
        if !directed do m[edge.y][edge.x] = weight
    }
    return
}