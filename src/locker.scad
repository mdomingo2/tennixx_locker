// ============================================================================
//  Tennis-ball-machine locker  -  parametric, 3D-printable, sliding-dovetail
// ----------------------------------------------------------------------------
//  Open-front cabinet sized to hold a 39.2 x 27.1 x 44.8 cm machine with >=1"
//  clearance all round. ~1" (25.4 mm) walls. Every panel is auto-split into
//  tiles that fit a Bambu Lab P2S (256^3) bed and re-joined with full-length
//  SLIDING DOVETAILS. The 5 panels meet at the corners with sliding-dovetail
//  housing joints + locking pins.
//
//  Axes:  X = width,  Y = depth (FRONT is open, at +Y),  Z = height (up).
// ============================================================================

$fn = 48;

/* [What to show] */
// "assembled" | "exploded" | "panel" | "tile"
mode = "assembled";
// which panel for mode=="panel"/"tile":  bottom top back left right
which = "left";
// tile indices for mode=="tile" (column ti, row tj)
ti = 0;
tj = 0;
// debug: disable corner (panel-to-panel) joints to test tile bodies alone
corner_joints = 2;   // 0=none, 1=tongues only, 2=tongues+grooves+pins

/* ===================== PARAMETERS (mm) ===================== */
object      = [392, 271, 448];   // machine [Depth(X-in), Width, Height]
clearance   = 25.4;              // >= 1" free space on every interior side
wall        = 25.4;              // ~1" panel thickness

print_env   = [256, 256, 256];   // Bambu Lab P2S build volume
print_margin= 10;                // keep parts this far from bed edges

// tile-to-tile sliding dovetail (cross-section flares through the wall)
dt_depth = 18;   // how far the tongue reaches into the neighbour
dt_root  = 11;   // neck width (at the seam face)
dt_tip   = 18;   // widest width (locks against in-plane separation)
dt_fit   = 0.35; // slide clearance added to every socket face

// main panel-to-panel sliding-dovetail housing joint
mj_depth = 12;   // groove depth into the receiving panel face
mj_root  = 11;   // groove neck width
mj_tip   = 17;   // groove base width (undercut) -> leaves ~4mm walls in a 1" panel
mj_fit   = 0.40; // slide clearance
mj_weld  = 1.2;  // embed tenons this far into their panel (robust CSG merge)

// locking pins (printed or 8 mm dowel) that pin every slid joint home
pin_d    = 8;
pin_clr  = 0.30;

explode  = 90;   // gap used by mode=="exploded"

/* ===================== DERIVED ===================== */
inW = object[1] + 2*clearance;        // interior width   (X)
inD = object[0] + 2*clearance;        // interior depth   (Y)
inH = object[2] + 2*clearance;        // interior height  (Z)

outW = inW + 2*wall;                  // overall width
outD = inD + wall;                    // overall depth (back wall only)
outH = inH + 2*wall;                  // overall height

usable  = min(print_env[0], print_env[1]) - 2*print_margin;  // bed area limit
usableZ = print_env[2] - print_margin;                       // bed height limit
cellmax = usable - dt_depth;          // leave room for the protruding tongue

// tile count for a given panel edge length
function ntiles(L) = max(1, ceil(L / cellmax));

/* ===================== DOVETAIL PRIMITIVE ===================== */
// Canonical sliding-dovetail prism:
//   length `len` runs along +Y, grows from `root` to `tip` (in X) as it goes
//   0 -> `depth` along +Z.  i.e. run=Y, depth=+Z, flare=X.
module dt_canon(len, depth, root, tip) {
    hull() {
        translate([-root/2, 0, 0      ]) cube([root, len, 0.02]);
        translate([-tip/2,  0, depth-0.02]) cube([tip,  len, 0.02]);
    }
}

/* ===================== GENERIC TILED PANEL =====================
   Built in a LOCAL frame: the panel lies in the (u,v) plane, thickness `t`
   along +n(=local Z). Split into nu x nv tiles. Tile carries a male dovetail
   on its +u and +v edges and a female socket on its -u and -v edges, so
   neighbours interlock. `cell` returns one tile; `whole` returns the slab. */

// male tongue on the +U seam (runs along V, flares through thickness Z)
module tongueU(x, y0, len, t) {
    translate([x, y0, t/2]) rotate([0,90,0]) dt_canon(len, dt_depth, dt_root, dt_tip);
}
// permutation that maps canon (run=Y,depth=Z,flare=X) -> (run=X,depth=Y,flare=Z)
PV = [[0,1,0,0],[0,0,1,0],[1,0,0,0],[0,0,0,1]];
// male tongue on the +V seam (runs along U, flares through thickness Z)
module tongueV(x0, y, len, t) {
    translate([x0, y, t/2]) multmatrix(PV) dt_canon(len, dt_depth, dt_root, dt_tip);
}
// matching sockets (same shape, grown by fit)
module socketU(x, y0, len, t) {
    translate([x, y0, t/2]) rotate([0,90,0])
        dt_canon(len+2*dt_fit, dt_depth+dt_fit, dt_root+2*dt_fit, dt_tip+2*dt_fit);
}
module socketV(x0, y, len, t) {
    translate([x0, y, t/2]) multmatrix(PV)
        dt_canon(len+2*dt_fit, dt_depth+dt_fit, dt_root+2*dt_fit, dt_tip+2*dt_fit);
}

module tile_local(Lu, Lv, t, nu, nv, i, j) {
    cu = Lu/nu;  cv = Lv/nv;
    difference() {
        union() {
            translate([i*cu, j*cv, 0]) cube([cu, cv, t]);
            if (i < nu-1) tongueU((i+1)*cu, j*cv, cv, t);
            if (j < nv-1) tongueV(i*cu, (j+1)*cv, cu, t);
        }
        if (i > 0) socketU(i*cu, j*cv - dt_fit, cv, t);
        if (j > 0) socketV(i*cu - dt_fit, j*cv, cu, t);
    }
}

module slab_local(Lu, Lv, t) { cube([Lu, Lv, t]); }

/* ===================== PANEL PLACEMENT ===================== */
// Each panel is described by a world origin O and an orthonormal basis
// (U,V = in-plane, N = +thickness).  One engine, five panels.
function pO (n)= n=="bottom"?[0,0,0] : n=="top"?[0,0,outH-wall] :
                 n=="back"?[0,0,wall] : n=="left"?[0,wall,wall] : [outW-wall,wall,wall];
function pU (n)= (n=="bottom"||n=="top"||n=="back")?[1,0,0]:[0,1,0];
function pV (n)= (n=="bottom"||n=="top")?[0,1,0]:[0,0,1];
function pN (n)= (n=="bottom"||n=="top")?[0,0,1]: n=="back"?[0,1,0]:[1,0,0];
function pLu(n)= (n=="bottom"||n=="top"||n=="back")?outW:inD;
function pLv(n)= (n=="bottom"||n=="top")?outD:inH;

module place(n) {
    U=pU(n); V=pV(n); N=pN(n); O=pO(n);
    multmatrix([[U[0],V[0],N[0],O[0]],
                [U[1],V[1],N[1],O[1]],
                [U[2],V[2],N[2],O[2]],
                [0,0,0,1]]) children();
}

/* ===================== MAIN (CORNER) SLIDING-DOVETAIL JOINTS =====================
   - sides drop onto the bottom / under the top via Y-running dovetails
   - the back drops down into vertical dovetails cut in the side rear faces
   - every slid joint is locked with an 8 mm pin                              */
// tenons are extended by mj_weld on the neck side so they embed into (overlap)
// their own panel -> the CSG union is a solid merge, not a coplanar touch.
module groove_bottom(cx){ translate([cx,0,wall])           rotate([0,180,0])  dt_canon(outD, mj_depth+mj_fit, mj_root+2*mj_fit, mj_tip+2*mj_fit); }
module tenon_bottom (cx){ translate([cx,wall,wall+mj_weld]) rotate([0,180,0])  dt_canon(inD,  mj_depth+mj_weld, mj_root,        mj_tip); }
module groove_top   (cx){ translate([cx,0,outH-wall])                          dt_canon(outD, mj_depth+mj_fit, mj_root+2*mj_fit, mj_tip+2*mj_fit); }
module tenon_top    (cx){ translate([cx,wall,outH-wall-mj_weld])               dt_canon(inD,  mj_depth+mj_weld, mj_root,        mj_tip); }
module side_groove  (cx){ translate([cx,wall,outH-wall])    rotate([-90,0,0]) dt_canon(inH,  mj_depth+mj_fit, mj_root+2*mj_fit, mj_tip+2*mj_fit); }
module back_tenon   (cx){ translate([cx,wall-mj_weld,outH-wall]) rotate([-90,0,0]) dt_canon(inH, mj_depth+mj_weld, mj_root,     mj_tip); }

module tongues(n){
    if(n=="left")  { tenon_bottom(wall/2);        tenon_top(wall/2); }
    if(n=="right") { tenon_bottom(outW-wall/2);   tenon_top(outW-wall/2); }
    if(n=="back")  { back_tenon(wall/2);          back_tenon(outW-wall/2); }
}
module grooves(n){
    if(n=="bottom"){ groove_bottom(wall/2);       groove_bottom(outW-wall/2); }
    if(n=="top")   { groove_top(wall/2);          groove_top(outW-wall/2); }
    if(n=="left")  { side_groove(wall/2); }
    if(n=="right") { side_groove(outW-wall/2); }
}

module pins_all(){
    pd = pin_d + 2*pin_clr;
    for(cx=[wall/2, outW-wall/2]){
        translate([cx, outD-35, -1])              cylinder(h=wall+2, d=pd);          // side->bottom
        translate([cx, outD-35, outH-wall-1])     cylinder(h=wall+2, d=pd);          // side->top
    }
    translate([-1,         wall+mj_depth/2, outH/2]) rotate([0,90,0]) cylinder(h=wall+2, d=pd); // back->left
    translate([outW-wall-1, wall+mj_depth/2, outH/2]) rotate([0,90,0]) cylinder(h=wall+2, d=pd); // back->right
}

/* ===================== PANEL / TILE ASSEMBLY ===================== */
module panel_whole(n){
    difference(){
        union(){ place(n) slab_local(pLu(n), pLv(n), wall); tongues(n); }
        grooves(n);
        pins_all();
    }
}

BIG = 1000;
module footprint(n,i,j){
    nu=ntiles(pLu(n)); nv=ntiles(pLv(n));
    cu=pLu(n)/nu; cv=pLv(n)/nv;
    ulo=(i==0)? -BIG : i*cu;        uhi=(i==nu-1)? pLu(n)+BIG : (i+1)*cu;
    vlo=(j==0)? -BIG : j*cv;        vhi=(j==nv-1)? pLv(n)+BIG : (j+1)*cv;
    place(n) translate([ulo,vlo,-BIG]) cube([uhi-ulo, vhi-vlo, 2*BIG]);
}
module panel_tile(n,i,j){
    nu=ntiles(pLu(n)); nv=ntiles(pLv(n));
    difference(){
        union(){
            place(n) tile_local(pLu(n), pLv(n), wall, nu, nv, i, j);
            if(corner_joints>=1) intersection(){ tongues(n); footprint(n,i,j); }
        }
        if(corner_joints>=2){ grooves(n); pins_all(); }
    }
}

/* ===================== VIEW DISPATCH ===================== */
panels = ["bottom","top","back","left","right"];
function outward(n)= n=="bottom"?[0,0,-1]: n=="top"?[0,0,1]: n=="back"?[0,-1,0]:
                     n=="left"?[-1,0,0]:[1,0,0];

module all_tiles(n){
    nu=ntiles(pLu(n)); nv=ntiles(pLv(n));
    for(i=[0:nu-1]) for(j=[0:nv-1]) panel_tile(n,i,j);
}

if (mode=="assembled")      for(n=panels) panel_whole(n);
else if (mode=="exploded")  for(n=panels) translate(outward(n)*explode) panel_whole(n);
else if (mode=="panel")     panel_whole(which);
else if (mode=="tile")      panel_tile(which, ti, tj);
else if (mode=="alltiles")  all_tiles(which);

/* ===================== REPORT ===================== */
echo(str("Interior  WxDxH (mm): ", inW, " x ", inD, " x ", inH));
echo(str("Exterior  WxDxH (mm): ", outW, " x ", outD, " x ", outH));
echo(str("Usable bed cell (mm): ", cellmax));
for(n=panels) echo(str("panel ", n, ": ", ntiles(pLu(n)), " x ", ntiles(pLv(n)),
                       " tiles  (", ntiles(pLu(n))*ntiles(pLv(n)), ")"));
