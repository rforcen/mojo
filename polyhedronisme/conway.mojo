# conway transformations
from polyhedron import Polyhedron
from vertex import Vertex
from common import Vertexes, Face, Faces, u32, f32, EdgeKey, EdgeFaces, EdgeVertices, MAX_UINT

#kis
def kis(mut p : Polyhedron, height : Float32 = 0.1) -> Polyhedron:    

    var new_faces = Faces(capacity=p.calc_total_vertexes())
    var new_vertexes = p.vertexes.copy()
    
    # gen new vertex (apex) and new faces   
    p.calc_centers()
    p.calc_normals()    
    
    for f_idx, face in enumerate(p.faces):
        # new vertex (apex) index
        var apex_idx = u32(len(p.vertexes) + f_idx)
        
        # apex extrusion        
        new_vertexes.append(p.centers[f_idx] + p.normals[f_idx] * height)

        # create triangular face
        for i in range(len(face)-1):
            new_faces.append([face[i], face[i+1], apex_idx])
        # close the polygon
        new_faces.append([face[len(face)-1], face[0], apex_idx])
    
    return Polyhedron("k"+p.name, new_vertexes^, new_faces^)

# ambo
def ambo(mut p : Polyhedron) -> Polyhedron:
    # unique edges
    var edge_map = Dict[EdgeKey, u32]()    

    for face in p.faces:
        for i in range(len(face)):
            var key = EdgeKey.init_sorted(face[i], face[(i + 1)] if i < len(face)-1 else face[0])

            if not key in edge_map: # new?
                edge_map[key] = u32(len(edge_map))
            
    # mid points
    var new_vertices = Vertexes(capacity=len(edge_map))
    for key in edge_map.keys():
        var v1 = p.vertexes[key.v1]
        var v2 = p.vertexes[key.v2]
        new_vertices.append((v1 + v2) / 2.0)

    # For each edge, register the IDs of the two faces that form it	
    var edge_faces = List[EdgeFaces](length=len(edge_map), fill=EdgeFaces(MAX_UINT, MAX_UINT))

    # List of edges that converge at each original vertex
    var vertex_edges = Faces(length=len(p.vertexes), fill=Face())
    var new_faces = Faces(capacity=len(p.faces)+len(p.vertexes))    

    # Populate original faces and map dual adjacencies
    for f_idx, face in enumerate(p.faces):
        var uint_f_idx = u32(f_idx)

        var face_edge_ids = Face(capacity=len(face))

        for i in range(len(face)):
            var v1 = face[i]
            var v2 = face[(i + 1) % len(face)]

            var key = EdgeKey.init_sorted(v1, v2)
            var edge_id = edge_map.find(key).value()

            face_edge_ids.append(edge_id)

            # Register which faces share this edge
            if edge_faces[edge_id].f1 == MAX_UINT:    edge_faces[edge_id].f1 = uint_f_idx
            elif edge_faces[edge_id].f2 == MAX_UINT:  edge_faces[edge_id].f2 = uint_f_idx

            # Add edge to vertex umbrella without duplication            
            try:    _ = vertex_edges[v1].index(edge_id)                            
            except: vertex_edges[v1].append(edge_id)

            try:    _ = vertex_edges[v2].index(edge_id)                            
            except: vertex_edges[v2].append(edge_id)

        new_faces.append(face_edge_ids^)

    #  reconstruct vertex caps in true cyclic order
    for edges_list in vertex_edges:
        var degree = len(edges_list)
        if degree < 3: continue

        var vert_face_ids = Face(length=degree, fill=0)
        var visited = List[Bool](length=degree, fill=False)
        
        var current_edge = edges_list[0]
        vert_face_ids[0] = current_edge
        visited[0] = True

        # We will look for the first valid face that uses this edge
        var current_face = edge_faces[current_edge].f1

        for i in range(1, degree):
            var next_edge_id = current_edge

            # We look for which of the other edges of the vertex belongs to 'current_face'
            for e_idx, edge in enumerate(edges_list):
                if visited[e_idx]: continue
                if edge_faces[edge].f1 == current_face or edge_faces[edge].f2 == current_face:
                    next_edge_id = edge
                    visited[e_idx] = True
                    break

            vert_face_ids[i] = next_edge_id

            # Jump to the OTHER face that shares the new edge to continue the umbrella
            current_face = edge_faces[next_edge_id].f2 if edge_faces[next_edge_id].f1 == current_face else edge_faces[next_edge_id].f1
            current_edge = next_edge_id
            
        new_faces.append(vert_face_ids^)

    return Polyhedron("a"+p.name, new_vertices, new_faces)

# quinto

def quinto(mut p:Polyhedron) -> Polyhedron:
    p.calc_centers()

    var mid_map = Dict[EdgeKey, u32]()

    var new_vertices = p.vertexes.copy()
    var new_faces = Faces(capacity=len(p.faces))

    for f_idx, face in enumerate(p.faces):
        
        if len(face)<3: continue
        var centroid = p.centers[f_idx]

        # Single array for internal points. We avoid double contiguous allocation
        # This array will be permanently saved as the central face, so it does NOT have a local defer free.
        var inner_face_ids = Face(length=len(face), fill=0)

        var v1 = face[len(face) - 2]
        var v2 = face[len(face) - 1]

        # Generate midpoints and internal corners
        for idx, v3 in enumerate(face):
            var p1 = p.vertexes[v1]
            var p2 = p.vertexes[v2]
            var mid_pt = (p1 + p2) * 0.5

            var e_key = EdgeKey.init_sorted(v1, v2)
            if not e_key in mid_map: # not found -> add                
                mid_map[e_key] = u32(len(new_vertices))
                new_vertices.append(mid_pt)
            
            # append vertex for internal face
            inner_face_ids[idx] = u32(len(new_vertices))
            new_vertices.append((mid_pt + centroid) * 0.5)

            v1 = v2
            v2 = v3
        
        # Construction of corner pentagons
        v1 = face[len(face) -2]
        v2 = face[len(face) -1]

        for idx, v3 in enumerate(face):
            var next_idx = (idx + 1) if (idx + 1) < len(face) else 0

            var t12 = mid_map.find(EdgeKey.init_sorted(v1, v2)).value()
            var t23 = mid_map.find(EdgeKey.init_sorted(v2, v3)).value()

            var ti12 = inner_face_ids[idx]
            var ti23 = inner_face_ids[next_idx]

            # make the pentagon
            new_faces.append([ti12, t12, v2, t23, ti23])

            v1 = v2
            v2 = v3
            
        # add central face
        new_faces.append(inner_face_ids^)

    return Polyhedron('q' + p.name, new_vertices^, new_faces^)

# whirl
def whirl(mut p: Polyhedron) -> Polyhedron:
    p.calc_centers()

    # dict for points at 1/3 of edges
    var edge_map = Dict[EdgeKey, u32]()
    
    var new_vertices = p.vertexes.copy()
    var new_faces = Faces(capacity=p.calc_total_vertexes()+len(p.faces))

    for f_idx, face in enumerate(p.faces):
        if len(face) < 3 : continue
        
        var centroid = p.centers[f_idx]
        # Local array to store the IDs of the interior vertices of THIS face
        var inner_ids = Face(length=len(face), fill=0)

        var v1 = face[len(face) - 2]
        var v2 = face[len(face) - 1]
        
        # Generate all new vertices for this face
        for idx, v3 in enumerate(face):
            # We deterministically generate the point at 1/3 from v1 towards v2
            var e_key = EdgeKey(v1, v2)
            if not e_key in edge_map:
                edge_map[e_key] = u32(len(new_vertices))
                new_vertices.append(p.vertexes[v1].one_third(p.vertexes[v2]))
            
            var e_key_21 = EdgeKey(v2, v1)
            if not e_key_21 in edge_map:
                edge_map[e_key_21] = u32(len(new_vertices))
                new_vertices.append(p.vertexes[v2].one_third(p.vertexes[v1]))
            
            var v1_2 = p.vertexes[v1].one_third(p.vertexes[v2])
            var cv1 = centroid.one_third(v1_2).normalize()

            inner_ids[idx] = u32(len(new_vertices))
            new_vertices.append(cv1)
        
            v1 = v2
            v2 = v3

        # Build the perimeter Hexagons
        v1 = face[len(face) - 2]
        v2 = face[len(face) - 1]
        
        for idx, v3 in enumerate(face):
            
            var next_idx = (idx + 1) % len(face)

            # Now we guarantee that they exist independently in the map
            var e_v1_v2 = edge_map.find(EdgeKey(v1, v2)).value()
            var e_v2_v1 = edge_map.find(EdgeKey(v2, v1)).value()
            var e_v2_v3 = edge_map.find(EdgeKey(v2, v3)).value()

            var cv1name = inner_ids[idx]
            var cv2name = inner_ids[next_idx]
            
            new_faces.append([cv1name, e_v1_v2, e_v2_v1, v2, e_v2_v3, cv2name])
            
            v1 = v2
            v2 = v3
        

        # Add the rotated central face (we reuse inner_ids)
        new_faces.append(inner_ids^)
    
    return Polyhedron('w' + p.name, new_vertices^, new_faces^)

# chamfer
def chamfer(mut p : Polyhedron, dist : f32) -> Polyhedron:
    p.calc_normals()

    # Map to build edge hexagons in a shared way.
    # We store a slice of 6 u32 for each canonical edge (sorted).
    var hex_map = Dict[EdgeKey, Face]()

    var new_vertices = Vertexes(capacity = p.calc_total_vertexes())
    var new_faces = Faces(capacity = len(p.faces))

    # Add modified original vertices (radially stretched)
    for v in p.vertexes: new_vertices.append(v * (1.0 + dist))

    # Process faces to push corners and structure hexagons
    for f_idx, face in enumerate(p.faces):
        if len(face) < 3: continue

        var f_normal = p.normals[f_idx]

        # Array for the new version of the displaced original face
        var orig_face_new = Face(length=len(face), fill=0)

        # Temporary array for the IDs of the new internal vertices of this face
        var face_inner_ids = Face(length=len(face), fill=0)

        # Generate the vertices of the corners displaced by the normal
        for idx, v2 in enumerate(face):
            var v2_pos = p.vertexes[v2]
            var v2new_pos = v2_pos + (f_normal * (dist * 1.5))
            var v2new_id = u32(len(new_vertices))

            new_vertices.append(v2new_pos)

            face_inner_ids[idx] = v2new_id
            orig_face_new[idx] = v2new_id # Fill the central face
        
        # Once the internal points of the face are generated, we stitch the hexagons
        var v1_idx = len(face) - 1
        for v2_idx, v2 in enumerate(face):
            var v1 = face[v1_idx]

            var v1new = face_inner_ids[v1_idx]
            var v2new = face_inner_ids[v2_idx]         

            # Symmetric canonical key for the edge between v1 and v2
            var e_key = EdgeKey.init_sorted(v1, v2)

            try:
                ref hm_ref = hex_map[e_key]
                # We recover the buffer and mandatorily write the neighboring vertices
                if v1 < v2:
                    hm_ref[4] = v1new
                    hm_ref[5] = v2new
                else:
                    hm_ref[4] = v2new
                    hm_ref[5] = v1new
            except:
                # not found -> add it
                # First face that visits the edge: initialize the buffer
                var hex_buffer =    Face([v2, v2new, v1new, v1, MAX_UINT, MAX_UINT]) \
                    if v1 < v2 else Face([v1, v1new, v2new, v2, MAX_UINT, MAX_UINT])
                
                hex_map[e_key] = hex_buffer^
            
            v1_idx = v2_idx        
        
        # Add the displaced original face to the global list
        new_faces.append(orig_face_new^)

    # copy values from hex_map to new_faces
    # Fix hexagons that were not connected to a face
    for _face in hex_map.values():            
        var face = _face.copy()

        if len(face) == 6 and face[4] == MAX_UINT:
            face[4] = face[2]
            face[5] = face[1]
        
        new_faces.append(face^)

    return Polyhedron("c" + p.name, new_vertices^, new_faces^)

# insetN
def insetN(mut p: Polyhedron, n: Int = 0, inset_dist: f32 = 0.5, popout_dist: f32 = -0.2) -> Polyhedron:
    p.calc_normals()
    p.calc_centers()

    var new_vertices = p.vertexes.copy()
    var new_faces = Faces(capacity = p.calc_total_vertexes())

    var found_any = False

    # process faces
    for f_idx, face in enumerate(p.faces):
        var flen = len(face)
        if flen < 3: continue
        
        # Does this face meet the 'n' sides filter? (If n == 0, all enter)
        if n == 0 or flen == n:
            found_any = True
            var centroid = p.centers[f_idx]
            var f_normal = p.normals[f_idx]

            var inner_face_ids = Face(length = flen, fill=0)

            # Generate the new internal vertices of the cap
            for idx, v in enumerate(face):
                var v_pos = p.vertexes[v]

                # Calculate the base position interpolating towards the center
                var base_tween = v_pos.tween(centroid, inset_dist)
                # Add the three-dimensional displacement of the normal (extrusion)
                # v_new = base_tween + (normal * popout_dist)
                var v_new_pos  = base_tween + (f_normal * popout_dist)

                var new_id = len(new_vertices)
                new_vertices.append(v_new_pos)
                inner_face_ids[idx] = u32(new_id)
            
            # Build the walls (lateral trapezoids)
            var v1_idx = flen - 1
            for v2_idx, v2 in enumerate(face):
                
                var v1 = face[v1_idx]
                var v1_new = inner_face_ids[v1_idx]
                var v2_new = inner_face_ids[v2_idx]

                var iv1 = v1
                var iv2 = v2

                # Build the lateral trapezoid: {iv1, iv2, v2new, v1new}                
                new_faces.append([iv1, iv2, v2_new, v1_new])

                v1_idx = v2_idx

            # Add the reduced internal cap as a new face
            new_faces.append(inner_face_ids^)
        else:
            # If the face does not meet the filter, we clone it exactly like the original            
            new_faces.append(face.copy())

    if not found_any and n!=0:
        print("No faces matched the filter criteria.")
        return p.copy()

    return Polyhedron("n" + p.name, new_vertices^, new_faces^)

# gyro
def gyro(mut p: Polyhedron) -> Polyhedron:
    p.calc_centers()
    
    var edge_map = Dict[EdgeKey, EdgeVertices]()

    var new_vertices = Vertexes()    
    new_vertices.extend(p.vertexes.copy())
    var new_faces = Faces(capacity = p.calc_total_vertexes())

    # Save the ID of the center of each face
    var face_centers_ids = Face(length=len(p.faces), fill=0)

    # Generate face centers and the 2 unified vertices per edge
    for f_idx, face in enumerate(p.faces):
        var flen = len(face)
        if flen < 3:  continue
        
        face_centers_ids[f_idx] = u32(len(new_vertices))
        new_vertices.append(p.centers[f_idx])

        for j in range(flen):
            var v1 = face[(j + flen - 2) % flen]
            var v2 = face[(j + flen - 1) % flen]

            var e_key = EdgeKey.init_sorted(v1, v2)
            if not e_key in edge_map:
                # Since e_key orders internally from lowest to highest, we determine the real order in space
                var v_low  = v1 if v1 < v2 else v2
                var v_high = v2 if v1 < v2 else v1

                var id_low_third = u32(len(new_vertices))
                new_vertices.append(p.vertexes[v_low].one_third(p.vertexes[v_high]))

                var id_high_third = u32(len(new_vertices))
                new_vertices.append(p.vertexes[v_high].one_third(p.vertexes[v_low]))

                edge_map[e_key] = EdgeVertices(id_low_third, id_high_third)

    # Exact stitching of chiral pentagons           
    for f_idx, face in enumerate(p.faces):
        var flen = len(face)
        if flen < 3:  continue
        
        var cntr_id = face_centers_ids[f_idx]

        for j in range(flen):
            var v1 = face[(j + flen - 2) % flen]
            var v2 = face[(j + flen - 1) % flen]
            var v3 = face[j]

            # Recover the vertex pairs of the three involved edges
            var ev_12 = edge_map.find(EdgeKey.init_sorted(v1, v2)).value()
            var ev_23 = edge_map.find(EdgeKey.init_sorted(v2, v3)).value()

            # Solve mathematically which ID corresponds to the real directional sense
            # e_v1_v2: the point at 1/3 of the way from v1 towards v2
            var e_v1_v2 =  ev_12.v1_third if v1 < v2 else ev_12.v2_third
            # e_v2_v1: the point at 1/3 of the way from v2 towards v1 (that is, at 2/3 from v1)
            var e_v2_v1 = ev_12.v2_third if v1 < v2 else ev_12.v1_third
            # e_v2_v3: the point at 1/3 of the way from v2 towards v3
            var e_v2_v3 = ev_23.v1_third if v2 < v3 else ev_23.v2_third

            var iv2 = v2

            # Stitch the chiral pentagon identical to the C++ Winding Order
            new_faces.append(Face([cntr_id, e_v1_v2, e_v2_v1, iv2, e_v2_v3]))
		
    return Polyhedron('g'+p.name, new_vertices^, new_faces^)

# propellor
def propellor(mut p : Polyhedron) -> Polyhedron:
    var edge_map = Dict[EdgeKey, EdgeVertices]()

    var new_vertices = p.vertexes.copy()
    var new_faces = Faces(capacity = p.calc_total_vertexes())

    # Generate the 2 unified vertices per edge
    for face in p.faces:
        var flen = len(face)
        if flen < 3: continue
        
        for j in range(flen):
            var v1 = face[(j + flen - 2) % flen]
            var v2 = face[(j + flen - 1) % flen]

            var e_key = EdgeKey.init_sorted(v1, v2)
            
            if not e_key in edge_map:
                
                var v_low = v1 if v1 < v2 else v2
                var v_high = v2 if v1 < v2 else v1

                var id_low_third = len(new_vertices)
                new_vertices.append(p.vertexes[v_low].one_third(p.vertexes[v_high]))
                
                var id_high_third = len(new_vertices)
                new_vertices.append(p.vertexes[v_high].one_third(p.vertexes[v_low]))
                
                edge_map[e_key] = EdgeVertices(v1_third = u32(id_low_third), v2_third = u32(id_high_third))
            
    # Build the faces central helix + quadrilaterals of union
    for face in p.faces:
        var flen = len(face)
        if flen < 3: continue
        
        # Reserve memory for the new central cap (same number of sides as the original)
        var central_face = Face(length = flen, fill=0)
        
        for j in range(flen):
            var v1 = face[(j + flen - 2) % flen]
            var v2 = face[(j + flen - 1) % flen]
            var v3 = face[j]
            
            # Recover the unified pairs from the hash map
            var ev_12 = edge_map.find(EdgeKey.init_sorted(v1, v2)).value()
            var ev_23 = edge_map.find(EdgeKey.init_sorted(v2, v3)).value()
            
            # Solve the exact geometric directional senses
            var e_v1_v2 = ev_12.v1_third if v1 < v2 else ev_12.v2_third
            var e_v2_v1 = ev_12.v2_third if v1 < v2 else ev_12.v1_third
            var e_v2_v3 = ev_23.v1_third if v2 < v3 else ev_23.v2_third
            
            var iv2 = v2
            
            # fill the corresponding gap of the central helix [e_v1_v2, e_v2_v3, ...]
            central_face[j] = e_v1_v2

            # Stitch the lateral quadrilateral that embraces the original vertex iv2
            new_faces.append([e_v1_v2, e_v2_v1, iv2, e_v2_v3])
        
        # At the end of STEP 2 of propellor, before adding central_face:
        # We invert the slice to correct the Winding Order (counterclockwise direction)
	
        var right = len(central_face) - 1
        var left=0
        while left < right:
            #swap(central_face[left], central_face[right])
            var tmp = central_face[left]
            central_face[left] = central_face[right]
            central_face[right] = tmp

            right -= 1
            left += 1
        
        new_faces.append(central_face^)
    
    return Polyhedron('p'+p.name, new_vertices^, new_faces^)

# hollow  
def hollow(mut p: Polyhedron, inset_dist: f32 = 0.2, thickness: f32 = 0.1) -> Polyhedron:
    p.calc_centers()
    var normals = p.avg_normals()

    var new_vertices = p.vertexes.copy()
    var new_faces = Faces(capacity = p.calc_total_vertexes())

    for f_idx, face in enumerate(p.faces):
        var flen = len(face)
        if flen < 3: continue

        var centroid = p.centers[f_idx]
        var normal = normals[f_idx]

        # PROTECTION AGAINST TOPOLOGICAL EXPLOSION (For HaaaaD and similar)
		# If the accumulated normal of the face came collapsed or null, we use a safe spherical fallback 
        
        var normal_len_sq = normal.lengthSq()
        if normal_len_sq < 0.9:
            var cent_len = centroid.length()
            if cent_len > 0.0001:
                normal = centroid / cent_len
            else:
                # use a safe spherical fallback
                normal = Vertex(1.0, 0.0, 0.0)

        # DYNAMIC ADAPTATION OF MEASUREMENTS (Prevents microscopic faces from piercing the mesh)
        # We measure the real distance of the first vertex to the centroid to estimate the size of the face
        
        # We measure the real distance of the first vertex to the centroid to estimate the size of the face
        var v0 = p.vertexes[face[0]]
        var dist_to_centroid = v0.distanceSq(centroid)

        # If the face is a tiny "needle", we smooth the inset and proportionally scale the thickness
        var local_inset = 0.05 if (inset_dist * dist_to_centroid < 0.001) else inset_dist
        var local_thickness = dist_to_centroid * 0.2 if thickness > dist_to_centroid else thickness

        # STABLE ORIENTATION CORRECTION
        var invert_winding = False
        if normal.dot(centroid) < 0.0:
            normal = -normal
            invert_winding = True
        
        # 1st step. local ID mappings of this face
        var inset_ids = Face(length=flen, fill=0)
        var down_ids = Face(length=flen, fill=0)

        # 1st step. generate vertices (towards the inside)
        for idx, v in enumerate(face):
            var v_pos = p.vertexes[v]
            
            # Inset Vertex on the exterior plane of the face
            var ins_pt = v_pos.tween(centroid, local_inset)
            inset_ids[idx] = u32(len(new_vertices))
            new_vertices.append(ins_pt)

            # Down Vertex (Sunk perpendicularly subtracting the clean normal)
            var down_pt = ins_pt - (normal * local_thickness)
            down_ids[idx] = u32(len(new_vertices))
            new_vertices.append(down_pt)

        # 2nd step, make final faces
        var idx1 = flen - 1
        for idx2, v2 in enumerate(face):
            var iv1 = face[idx1]
            var iv2 = v2

            var fin1 = inset_ids[idx1]
            var fin2 = inset_ids[idx2]

            var down1 = down_ids[idx1]
            var down2 = down_ids[idx2]

            var frame_face : List[u32] = [ fin1, fin2, iv2, iv1 ]     if invert_winding else [ iv1, iv2, fin2, fin1 ]
            var wall_face  : List[u32] = [ down1, down2, fin2, fin1 ] if invert_winding else [ fin1, fin2, down2, down1 ]

            new_faces.append(frame_face^)
            new_faces.append(wall_face^)

            idx1 = idx2

    return Polyhedron('H' + p.name, new_vertices^, new_faces^)

# test    
from seeds import Dodecahedron
from std.time import perf_counter

def tr():   # failure double free
    var d = materialize[Dodecahedron]()   

    for i in range(10+1):
        print(t"{i} : name : {d.name}, faces: {len(d.faces)}, vertexes: {len(d.vertexes)}", end='')
        var lap = perf_counter()
        d = kis(d)
        print(t" in {Int(1000*(perf_counter() - lap))} ms")

def main():
    tr()
