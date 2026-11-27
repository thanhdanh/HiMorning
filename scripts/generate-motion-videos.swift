#!/usr/bin/env swift
import Foundation
import AppKit
import CoreGraphics
import AVFoundation

// ============================================================================
// HiMorning 16:9 Studio Biomechanical Motion Video Generator (go-tall standard)
// - Renders 960x540 30fps H.264 seamless 2-phase MP4 clips + studio posters
// - Uses exact Apple Vision landmarks (never guessed, zero dots on eyes/nose)
// - Pure C2-continuous guarded micro-articulation + editorial #11161F dip cuts
//   between Step 1 (Start) and Step 2 (Peak) -> zero ghosting, zero neck shear
// ============================================================================

struct JointPt {
    let x: Double // 0..100 (left to right)
    let y: Double // 0..100 (top to bottom)
    let active: Bool
}

enum RegionMaskMode {
    case ellipse(cx: Double, cy: Double, rx: Double, ry: Double, feather: Double)
    case halfPlane(px: Double, py: Double, nx: Double, ny: Double, feather: Double)
}

struct ArchGuard {
    var minX: (edge0: Double, edge1: Double)? = nil
    var maxX: (edge0: Double, edge1: Double)? = nil
    var minY: (edge0: Double, edge1: Double)? = nil
    var maxY: (edge0: Double, edge1: Double)? = nil
}

struct BoneRigOp {
    let pivotX: Double
    let pivotY: Double
    let dThetaDeg: Double
    let dxPct: Double
    let dyPct: Double
    let phaseOffset: Double
    let region: RegionMaskMode
}

struct PhaseSpec {
    let imageFile: String
    let guardBounds: ArchGuard
    let ops: [BoneRigOp]
    let joints: [String: JointPt]
    let bones: [(String, String, Bool)]
}

struct ChallengeMotionSpec {
    let key: String
    let phase1: PhaseSpec
    let phase2: PhaseSpec
}

let W = 960
let H = 540
let FPS: Int32 = 30
let PHASE_FRAMES = 66     // 2.2s per phase
let DIP_FRAMES = 6        // 0.2s studio #11161F dip transition
let TOTAL_FRAMES = (PHASE_FRAMES + DIP_FRAMES) * 2 // 144 frames = 4.8s seamless loop

let STUDIO_R: Double = 17.0 // #11161F
let STUDIO_G: Double = 22.0
let STUDIO_B: Double = 31.0

@inline(__always)
func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let t = max(0.0, min(1.0, (x - edge0) / max(1e-6, edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)
}

@inline(__always)
func evalGuard(_ xPct: Double, _ yPct: Double, _ g: ArchGuard) -> Double {
    var w = 1.0
    if let mx = g.minX {
        w *= smoothstep(mx.edge0, mx.edge1, xPct)
        if w <= 0.0001 { return 0.0 }
    }
    if let xx = g.maxX {
        w *= (1.0 - smoothstep(xx.edge0, xx.edge1, xPct))
        if w <= 0.0001 { return 0.0 }
    }
    if let my = g.minY {
        w *= smoothstep(my.edge0, my.edge1, yPct)
        if w <= 0.0001 { return 0.0 }
    }
    if let xy = g.maxY {
        w *= (1.0 - smoothstep(xy.edge0, xy.edge1, yPct))
        if w <= 0.0001 { return 0.0 }
    }
    return w
}

@inline(__always)
func regionWeight(xPct: Double, yPct: Double, mode: RegionMaskMode, guardBounds: ArchGuard) -> Double {
    let gw = evalGuard(xPct, yPct, guardBounds)
    if gw <= 0.0001 { return 0.0 }
    switch mode {
    case let .ellipse(cx, cy, rx, ry, feather):
        let dx = (xPct - cx) / rx
        let dy = (yPct - cy) / ry
        let dist = sqrt(dx * dx + dy * dy)
        return gw * (1.0 - smoothstep(1.0 - feather, 1.0 + feather, dist))
    case let .halfPlane(px, py, nx, ny, feather):
        let signedDist = (xPct - px) * nx + (yPct - py) * ny
        return gw * smoothstep(-feather, feather, signedDist)
    }
}

func forwardMapPoint(xPct: Double, yPct: Double, ops: [BoneRigOp], guardBounds: ArchGuard, baseAngle: Double) -> (Double, Double) {
    var px = xPct / 100.0 * Double(W)
    var py = yPct / 100.0 * Double(H)
    for op in ops {
        let s = 0.5 - 0.5 * cos(baseAngle + op.phaseOffset)
        let w = regionWeight(xPct: xPct, yPct: yPct, mode: op.region, guardBounds: guardBounds)
        if w <= 0.0005 { continue }
        let pivX = op.pivotX / 100.0 * Double(W)
        let pivY = op.pivotY / 100.0 * Double(H)
        let rad = (op.dThetaDeg * Double.pi / 180.0) * w * s
        let tx = (op.dxPct / 100.0 * Double(W)) * w * s
        let ty = (op.dyPct / 100.0 * Double(H)) * w * s
        let cosA = cos(rad)
        let sinA = sin(rad)
        let rx = px - pivX
        let ry = py - pivY
        px = pivX + (rx * cosA - ry * sinA) + tx
        py = pivY + (rx * sinA + ry * cosA) + ty
    }
    return (px / Double(W) * 100.0, py / Double(H) * 100.0)
}

@inline(__always)
func inverseMapPixel(outX: Double, outY: Double, ops: [BoneRigOp], guardBounds: ArchGuard, sValues: [Double]) -> (Double, Double) {
    var px = outX
    var py = outY
    let xPct = outX / Double(W) * 100.0
    let yPct = outY / Double(H) * 100.0
    if evalGuard(xPct, yPct, guardBounds) <= 0.0001 { return (px, py) }
    for i in stride(from: ops.count - 1, through: 0, by: -1) {
        let op = ops[i]
        let s = sValues[i]
        if s <= 0.0005 { continue }
        let w = regionWeight(xPct: xPct, yPct: yPct, mode: op.region, guardBounds: guardBounds)
        if w <= 0.0005 { continue }
        let pivX = op.pivotX / 100.0 * Double(W)
        let pivY = op.pivotY / 100.0 * Double(H)
        let rad = -(op.dThetaDeg * Double.pi / 180.0) * w * s
        let tx = (op.dxPct / 100.0 * Double(W)) * w * s
        let ty = (op.dyPct / 100.0 * Double(H)) * w * s
        let ux = px - tx - pivX
        let uy = py - ty - pivY
        let cosA = cos(rad)
        let sinA = sin(rad)
        px = pivX + (ux * cosA - uy * sinA)
        py = pivY + (ux * sinA + uy * cosA)
    }
    return (px, py)
}

@inline(__always)
func sampleBilinearRGB(buf: [UInt8], width: Int, height: Int, fx: Double, fy: Double) -> (UInt8, UInt8, UInt8) {
    let cx = max(0.0, min(Double(width - 1), fx))
    let cy = max(0.0, min(Double(height - 1), fy))
    let x0 = Int(floor(cx))
    let y0 = Int(floor(cy))
    let x1 = min(width - 1, x0 + 1)
    let y1 = min(height - 1, y0 + 1)
    let tx = cx - Double(x0)
    let ty = cy - Double(y0)

    let i00 = (y0 * width + x0) * 4
    let i10 = (y0 * width + x1) * 4
    let i01 = (y1 * width + x0) * 4
    let i11 = (y1 * width + x1) * 4

    let w00 = (1.0 - tx) * (1.0 - ty)
    let w10 = tx * (1.0 - ty)
    let w01 = (1.0 - tx) * ty
    let w11 = tx * ty

    let r = Double(buf[i00]) * w00 + Double(buf[i10]) * w10 + Double(buf[i01]) * w01 + Double(buf[i11]) * w11
    let g = Double(buf[i00 + 1]) * w00 + Double(buf[i10 + 1]) * w10 + Double(buf[i01 + 1]) * w01 + Double(buf[i11 + 1]) * w11
    let b = Double(buf[i00 + 2]) * w00 + Double(buf[i10 + 2]) * w10 + Double(buf[i01 + 2]) * w01 + Double(buf[i11 + 2]) * w11
    return (UInt8(max(0, min(255, Int(r.rounded())))),
            UInt8(max(0, min(255, Int(g.rounded())))),
            UInt8(max(0, min(255, Int(b.rounded())))))
}

func loadScaledRGBA(url: URL) throws -> [UInt8] {
    guard let nsImg = NSImage(contentsOf: url),
          let cgImg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "LoadImg", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load \(url.path)"])
    }
    var rgba = [UInt8](repeating: 0, count: W * H * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    rgba.withUnsafeMutableBytes { raw in
        if let ctx = CGContext(
            data: raw.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) {
            ctx.interpolationQuality = .high
            ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: W, height: H))
        }
    }
    return rgba
}

let MAT_GUARD      = ArchGuard(minX: (6.0, 12.0), maxX: (86.0, 92.0), minY: (5.0, 10.0), maxY: (66.0, 73.0))
let STANDING_GUARD = ArchGuard(minX: (12.0, 18.0), maxX: (82.0, 88.0), minY: (3.0, 7.0), maxY: (84.0, 90.0))
let PORTRAIT_GUARD = ArchGuard(minX: (10.0, 16.0), maxX: (84.0, 90.0), minY: (4.0, 8.0), maxY: (92.0, 98.0))
let SEATED_GUARD   = ArchGuard(minX: (18.0, 24.0), maxX: (76.0, 82.0), minY: (4.0, 8.0), maxY: (62.0, 70.0))

let ALL_CHALLENGES: [ChallengeMotionSpec] = [
    // 1. PUSH-UPS (Side profile on mat: Plank -> 90-deg lowered push-up)
    ChallengeMotionSpec(
        key: "push_ups",
        phase1: PhaseSpec(
            imageFile: "push_ups_step1.jpg",
            guardBounds: MAT_GUARD,
            ops: [
                BoneRigOp(pivotX: 15.3, pivotY: 69.5, dThetaDeg: 1.4, dxPct: 0.0, dyPct: 1.1, phaseOffset: 0,
                          region: .halfPlane(px: 20.0, py: 70.0, nx: 1.0, ny: -0.35, feather: 14.0)),
            ],
            joints: [
                "ear": JointPt(x: 76.0, y: 25.1, active: false),
                "shoulder": JointPt(x: 68.2, y: 35.1, active: true),
                "elbow": JointPt(x: 67.0, y: 59.8, active: true),
                "wrist": JointPt(x: 67.0, y: 80.9, active: true),
                "hip": JointPt(x: 46.4, y: 48.5, active: false),
                "knee": JointPt(x: 32.5, y: 61.2, active: false),
                "ankle": JointPt(x: 15.3, y: 69.5, active: false),
            ],
            bones: [
                ("ear", "shoulder", false), ("shoulder", "elbow", true), ("elbow", "wrist", true),
                ("shoulder", "hip", false), ("hip", "knee", false), ("knee", "ankle", false),
            ]
        ),
        phase2: PhaseSpec(
            imageFile: "push_ups_step2.jpg",
            guardBounds: MAT_GUARD,
            ops: [
                BoneRigOp(pivotX: 16.4, pivotY: 69.0, dThetaDeg: -1.6, dxPct: 0.0, dyPct: -1.2, phaseOffset: 0,
                          region: .halfPlane(px: 22.0, py: 69.0, nx: 1.0, ny: -0.3, feather: 14.0)),
            ],
            joints: [
                "ear": JointPt(x: 82.5, y: 56.1, active: false),
                "shoulder": JointPt(x: 74.2, y: 57.7, active: true),
                "elbow": JointPt(x: 64.0, y: 62.6, active: true),
                "wrist": JointPt(x: 66.8, y: 81.0, active: true),
                "hip": JointPt(x: 50.6, y: 63.9, active: false),
                "knee": JointPt(x: 34.5, y: 68.1, active: false),
                "ankle": JointPt(x: 16.4, y: 69.0, active: false),
            ],
            bones: [
                ("ear", "shoulder", false), ("shoulder", "elbow", true), ("elbow", "wrist", true),
                ("shoulder", "hip", false), ("hip", "knee", false), ("knee", "ankle", false),
            ]
        )
    ),

    // 2. WAVE HAND (Front portrait: open hand left tilt -> right tilt)
    ChallengeMotionSpec(
        key: "wave_hand",
        phase1: PhaseSpec(
            imageFile: "wave_hand_step1.jpg",
            guardBounds: PORTRAIT_GUARD,
            ops: [
                BoneRigOp(pivotX: 26.7, pivotY: 80.3, dThetaDeg: 5.5, dxPct: 0.8, dyPct: 0.0, phaseOffset: 0,
                          region: .ellipse(cx: 24.5, cy: 48.0, rx: 14.0, ry: 32.0, feather: 0.45)),
            ],
            joints: [
                "neck": JointPt(x: 51.7, y: 56.4, active: false),
                "lShoulder": JointPt(x: 64.8, y: 57.0, active: false),
                "rShoulder": JointPt(x: 38.6, y: 55.7, active: true),
                "rElbow": JointPt(x: 26.7, y: 80.3, active: true),
                "rWrist": JointPt(x: 24.4, y: 49.1, active: true),
            ],
            bones: [
                ("lShoulder", "neck", false), ("neck", "rShoulder", false),
                ("rShoulder", "rElbow", true), ("rElbow", "rWrist", true),
            ]
        ),
        phase2: PhaseSpec(
            imageFile: "wave_hand_step2.jpg",
            guardBounds: PORTRAIT_GUARD,
            ops: [
                BoneRigOp(pivotX: 26.6, pivotY: 79.8, dThetaDeg: -5.5, dxPct: -0.8, dyPct: 0.0, phaseOffset: 0,
                          region: .ellipse(cx: 26.0, cy: 47.0, rx: 14.0, ry: 32.0, feather: 0.45)),
            ],
            joints: [
                "neck": JointPt(x: 51.7, y: 56.4, active: false),
                "lShoulder": JointPt(x: 64.9, y: 57.1, active: false),
                "rShoulder": JointPt(x: 38.6, y: 55.6, active: true),
                "rElbow": JointPt(x: 26.6, y: 79.8, active: true),
                "rWrist": JointPt(x: 25.7, y: 47.8, active: true),
            ],
            bones: [
                ("lShoulder", "neck", false), ("neck", "rShoulder", false),
                ("rShoulder", "rElbow", true), ("rElbow", "rWrist", true),
            ]
        )
    ),

    // 3. NECK ROTATION (Front portrait: gentle turn left -> gentle turn right)
    ChallengeMotionSpec(
        key: "neck_rotation",
        phase1: PhaseSpec(
            imageFile: "neck_rotation_step1.jpg",
            guardBounds: PORTRAIT_GUARD,
            ops: [
                BoneRigOp(pivotX: 50.7, pivotY: 50.0, dThetaDeg: -1.6, dxPct: -0.9, dyPct: 0.0, phaseOffset: 0,
                          region: .halfPlane(px: 50.0, py: 44.0, nx: 0.0, ny: -1.0, feather: 10.0)),
            ],
            joints: [
                "ear": JointPt(x: 54.1, y: 25.1, active: true),
                "neck": JointPt(x: 50.7, y: 55.8, active: true),
                "lShoulder": JointPt(x: 63.9, y: 55.8, active: false),
                "rShoulder": JointPt(x: 37.6, y: 55.7, active: false),
            ],
            bones: [
                ("ear", "neck", true), ("rShoulder", "neck", false), ("neck", "lShoulder", false),
            ]
        ),
        phase2: PhaseSpec(
            imageFile: "neck_rotation_step2.jpg",
            guardBounds: PORTRAIT_GUARD,
            ops: [
                BoneRigOp(pivotX: 50.4, pivotY: 50.0, dThetaDeg: 1.6, dxPct: 0.9, dyPct: 0.0, phaseOffset: 0,
                          region: .halfPlane(px: 50.0, py: 44.0, nx: 0.0, ny: -1.0, feather: 10.0)),
            ],
            joints: [
                "ear": JointPt(x: 45.8, y: 25.6, active: true),
                "neck": JointPt(x: 50.4, y: 55.8, active: true),
                "lShoulder": JointPt(x: 63.6, y: 55.4, active: false),
                "rShoulder": JointPt(x: 37.3, y: 56.3, active: false),
            ],
            bones: [
                ("ear", "neck", true), ("rShoulder", "neck", false), ("neck", "lShoulder", false),
            ]
        )
    ),

    // 4. JUMPING JACKS (Front full-body: closed stance -> wide V open stance)
    ChallengeMotionSpec(
        key: "jumping_jacks",
        phase1: PhaseSpec(
            imageFile: "jumping_jacks_step1.jpg",
            guardBounds: STANDING_GUARD,
            ops: [
                BoneRigOp(pivotX: 50.0, pivotY: 85.0, dThetaDeg: 0.0, dxPct: 0.0, dyPct: -1.1, phaseOffset: 0,
                          region: .ellipse(cx: 50.0, cy: 48.0, rx: 16.0, ry: 38.0, feather: 0.45)),
            ],
            joints: [
                "neck": JointPt(x: 50.0, y: 27.6, active: false),
                "rShoulder": JointPt(x: 45.2, y: 27.6, active: true),
                "rElbow": JointPt(x: 43.9, y: 40.1, active: true),
                "rWrist": JointPt(x: 43.8, y: 52.3, active: true),
                "lShoulder": JointPt(x: 54.7, y: 27.6, active: true),
                "lElbow": JointPt(x: 55.8, y: 40.3, active: true),
                "lWrist": JointPt(x: 55.9, y: 52.1, active: true),
                "rHip": JointPt(x: 46.8, y: 51.1, active: false),
                "lHip": JointPt(x: 52.5, y: 51.5, active: false),
                "rKnee": JointPt(x: 47.6, y: 69.4, active: false),
                "lKnee": JointPt(x: 52.5, y: 70.2, active: false),
                "rAnkle": JointPt(x: 47.8, y: 86.8, active: true),
                "lAnkle": JointPt(x: 52.4, y: 87.1, active: true),
            ],
            bones: [
                ("rWrist", "rElbow", true), ("rElbow", "rShoulder", true),
                ("lWrist", "lElbow", true), ("lElbow", "lShoulder", true),
                ("rShoulder", "lShoulder", false), ("rShoulder", "rHip", false), ("lShoulder", "lHip", false),
                ("rHip", "lHip", false), ("rHip", "rKnee", false), ("rKnee", "rAnkle", true),
                ("lHip", "lKnee", false), ("lKnee", "lAnkle", true),
            ]
        ),
        phase2: PhaseSpec(
            imageFile: "jumping_jacks_step2.jpg",
            guardBounds: STANDING_GUARD,
            ops: [
                BoneRigOp(pivotX: 45.5, pivotY: 25.5, dThetaDeg: 3.2, dxPct: 0.0, dyPct: -0.6, phaseOffset: 0,
                          region: .ellipse(cx: 38.0, cy: 17.0, rx: 12.0, ry: 14.0, feather: 0.45)),
                BoneRigOp(pivotX: 54.5, pivotY: 25.5, dThetaDeg: -3.2, dxPct: 0.0, dyPct: -0.6, phaseOffset: 0,
                          region: .ellipse(cx: 62.0, cy: 17.0, rx: 12.0, ry: 14.0, feather: 0.45)),
                BoneRigOp(pivotX: 50.0, pivotY: 85.0, dThetaDeg: 0.0, dxPct: 0.0, dyPct: -1.3, phaseOffset: 0,
                          region: .ellipse(cx: 50.0, cy: 48.0, rx: 24.0, ry: 40.0, feather: 0.45)),
            ],
            joints: [
                "neck": JointPt(x: 50.0, y: 25.5, active: false),
                "rShoulder": JointPt(x: 45.5, y: 25.5, active: true),
                "rElbow": JointPt(x: 38.9, y: 21.3, active: true),
                "rWrist": JointPt(x: 35.2, y: 11.4, active: true),
                "lShoulder": JointPt(x: 54.5, y: 25.5, active: true),
                "lElbow": JointPt(x: 61.3, y: 20.6, active: true),
                "lWrist": JointPt(x: 65.3, y: 11.2, active: true),
                "rHip": JointPt(x: 46.7, y: 52.2, active: false),
                "lHip": JointPt(x: 52.6, y: 52.4, active: false),
                "rKnee": JointPt(x: 43.7, y: 68.9, active: false),
                "lKnee": JointPt(x: 56.4, y: 69.6, active: false),
                "rAnkle": JointPt(x: 40.5, y: 86.4, active: true),
                "lAnkle": JointPt(x: 60.0, y: 86.7, active: true),
            ],
            bones: [
                ("rWrist", "rElbow", true), ("rElbow", "rShoulder", true),
                ("lWrist", "lElbow", true), ("lElbow", "lShoulder", true),
                ("rShoulder", "lShoulder", false), ("rShoulder", "rHip", false), ("lShoulder", "lHip", false),
                ("rHip", "lHip", false), ("rHip", "rKnee", false), ("rKnee", "rAnkle", true),
                ("lHip", "lKnee", false), ("lKnee", "lAnkle", true),
            ]
        )
    ),

    // 5. REACH UP / STRETCHING (Front upper body: arms down -> arms straight overhead)
    ChallengeMotionSpec(
        key: "stretching",
        phase1: PhaseSpec(
            imageFile: "stretching_step1.jpg",
            guardBounds: PORTRAIT_GUARD,
            ops: [
                BoneRigOp(pivotX: 44.5, pivotY: 44.4, dThetaDeg: 2.8, dxPct: 0.0, dyPct: -0.4, phaseOffset: 0,
                          region: .ellipse(cx: 42.5, cy: 64.0, rx: 8.5, ry: 22.0, feather: 0.45)),
                BoneRigOp(pivotX: 55.6, pivotY: 44.2, dThetaDeg: -2.8, dxPct: 0.0, dyPct: -0.4, phaseOffset: 0,
                          region: .ellipse(cx: 57.5, cy: 64.0, rx: 8.5, ry: 22.0, feather: 0.45)),
            ],
            joints: [
                "neck": JointPt(x: 50.0, y: 44.3, active: false),
                "rShoulder": JointPt(x: 44.5, y: 44.4, active: true),
                "rElbow": JointPt(x: 42.7, y: 60.4, active: true),
                "rWrist": JointPt(x: 42.2, y: 74.6, active: true),
                "lShoulder": JointPt(x: 55.6, y: 44.2, active: true),
                "lElbow": JointPt(x: 57.3, y: 59.9, active: true),
                "lWrist": JointPt(x: 57.1, y: 74.4, active: true),
                "rHip": JointPt(x: 46.5, y: 74.4, active: false),
                "lHip": JointPt(x: 53.4, y: 75.0, active: false),
            ],
            bones: [
                ("rWrist", "rElbow", true), ("rElbow", "rShoulder", true),
                ("lWrist", "lElbow", true), ("lElbow", "lShoulder", true),
                ("rShoulder", "lShoulder", true), ("rShoulder", "rHip", false), ("lShoulder", "lHip", false),
            ]
        ),
        phase2: PhaseSpec(
            imageFile: "stretching_step2.jpg",
            guardBounds: PORTRAIT_GUARD,
            ops: [
                BoneRigOp(pivotX: 44.2, pivotY: 41.1, dThetaDeg: 2.2, dxPct: 0.0, dyPct: -1.4, phaseOffset: 0,
                          region: .ellipse(cx: 40.0, cy: 23.0, rx: 9.0, ry: 20.0, feather: 0.45)),
                BoneRigOp(pivotX: 54.9, pivotY: 41.8, dThetaDeg: -2.2, dxPct: 0.0, dyPct: -1.4, phaseOffset: 0,
                          region: .ellipse(cx: 60.0, cy: 23.0, rx: 9.0, ry: 20.0, feather: 0.45)),
            ],
            joints: [
                "neck": JointPt(x: 49.6, y: 41.5, active: false),
                "rShoulder": JointPt(x: 44.2, y: 41.1, active: true),
                "rElbow": JointPt(x: 39.5, y: 30.8, active: true),
                "rWrist": JointPt(x: 40.4, y: 14.7, active: true),
                "lShoulder": JointPt(x: 54.9, y: 41.8, active: true),
                "lElbow": JointPt(x: 60.7, y: 30.7, active: true),
                "lWrist": JointPt(x: 59.8, y: 14.8, active: true),
                "rHip": JointPt(x: 46.5, y: 74.7, active: false),
                "lHip": JointPt(x: 53.3, y: 74.8, active: false),
            ],
            bones: [
                ("rWrist", "rElbow", true), ("rElbow", "rShoulder", true),
                ("lWrist", "lElbow", true), ("lElbow", "lShoulder", true),
                ("rShoulder", "lShoulder", true), ("rShoulder", "rHip", false), ("lShoulder", "lHip", false),
            ]
        )
    ),

    // 6. GUIDED RHYTHM STANDING (Side profile: tall stand -> gentle knee bend)
    ChallengeMotionSpec(
        key: "rhythm_standing",
        phase1: PhaseSpec(
            imageFile: "rhythm_standing_step1.jpg",
            guardBounds: STANDING_GUARD,
            ops: [
                BoneRigOp(pivotX: 48.3, pivotY: 89.6, dThetaDeg: 0.0, dxPct: 0.0, dyPct: 1.0, phaseOffset: 0,
                          region: .halfPlane(px: 50.0, py: 74.0, nx: 0.0, ny: -1.0, feather: 14.0)),
            ],
            joints: [
                "ear": JointPt(x: 49.0, y: 12.7, active: false),
                "shoulder": JointPt(x: 48.6, y: 23.6, active: false),
                "elbow": JointPt(x: 48.1, y: 38.2, active: false),
                "wrist": JointPt(x: 50.5, y: 50.7, active: false),
                "hip": JointPt(x: 50.0, y: 50.8, active: true),
                "knee": JointPt(x: 49.4, y: 69.9, active: true),
                "ankle": JointPt(x: 48.3, y: 89.6, active: true),
            ],
            bones: [
                ("ear", "shoulder", false), ("shoulder", "elbow", false), ("elbow", "wrist", false),
                ("shoulder", "hip", false), ("hip", "knee", true), ("knee", "ankle", true),
            ]
        ),
        phase2: PhaseSpec(
            imageFile: "rhythm_standing_step2.jpg",
            guardBounds: STANDING_GUARD,
            ops: [
                BoneRigOp(pivotX: 48.4, pivotY: 89.2, dThetaDeg: 0.0, dxPct: -0.4, dyPct: 1.8, phaseOffset: 0,
                          region: .halfPlane(px: 50.0, py: 72.0, nx: 0.0, ny: -1.0, feather: 14.0)),
            ],
            joints: [
                "ear": JointPt(x: 49.6, y: 13.1, active: false),
                "shoulder": JointPt(x: 48.6, y: 22.6, active: false),
                "elbow": JointPt(x: 56.4, y: 27.1, active: false),
                "wrist": JointPt(x: 63.8, y: 26.1, active: false),
                "hip": JointPt(x: 46.6, y: 48.8, active: true),
                "knee": JointPt(x: 51.8, y: 69.2, active: true),
                "ankle": JointPt(x: 48.4, y: 89.2, active: true),
            ],
            bones: [
                ("ear", "shoulder", false), ("shoulder", "elbow", false), ("elbow", "wrist", false),
                ("shoulder", "hip", false), ("hip", "knee", true), ("knee", "ankle", true),
            ]
        )
    ),

    // 7. GUIDED RHYTHM SEATED (Front seated on stool: arms down -> arms raised overhead)
    ChallengeMotionSpec(
        key: "rhythm_seated",
        phase1: PhaseSpec(
            imageFile: "rhythm_seated_step1.jpg",
            guardBounds: SEATED_GUARD,
            ops: [
                BoneRigOp(pivotX: 45.0, pivotY: 36.0, dThetaDeg: 2.6, dxPct: 0.0, dyPct: -0.5, phaseOffset: 0,
                          region: .ellipse(cx: 42.0, cy: 52.0, rx: 7.5, ry: 18.0, feather: 0.45)),
                BoneRigOp(pivotX: 55.0, pivotY: 35.7, dThetaDeg: -2.6, dxPct: 0.0, dyPct: -0.5, phaseOffset: 0,
                          region: .ellipse(cx: 58.0, cy: 52.0, rx: 7.5, ry: 18.0, feather: 0.45)),
            ],
            joints: [
                "neck": JointPt(x: 50.0, y: 35.9, active: false),
                "rShoulder": JointPt(x: 45.0, y: 36.0, active: true),
                "rElbow": JointPt(x: 42.8, y: 49.6, active: true),
                "rWrist": JointPt(x: 41.1, y: 62.5, active: true),
                "lShoulder": JointPt(x: 55.0, y: 35.7, active: true),
                "lElbow": JointPt(x: 57.0, y: 48.7, active: true),
                "lWrist": JointPt(x: 58.7, y: 61.5, active: true),
                "rHip": JointPt(x: 46.6, y: 58.0, active: false),
                "lHip": JointPt(x: 52.5, y: 58.1, active: false),
                "rKnee": JointPt(x: 42.7, y: 66.0, active: false),
                "lKnee": JointPt(x: 56.6, y: 64.7, active: false),
                "rAnkle": JointPt(x: 43.0, y: 86.8, active: false),
                "lAnkle": JointPt(x: 56.3, y: 86.1, active: false),
            ],
            bones: [
                ("rWrist", "rElbow", true), ("rElbow", "rShoulder", true),
                ("lWrist", "lElbow", true), ("lElbow", "lShoulder", true),
                ("rShoulder", "lShoulder", false), ("rShoulder", "rHip", false), ("lShoulder", "lHip", false),
                ("rHip", "rKnee", false), ("rKnee", "rAnkle", false),
                ("lHip", "lKnee", false), ("lKnee", "lAnkle", false),
            ]
        ),
        phase2: PhaseSpec(
            imageFile: "rhythm_seated_step2.jpg",
            guardBounds: SEATED_GUARD,
            ops: [
                BoneRigOp(pivotX: 45.1, pivotY: 33.1, dThetaDeg: 2.5, dxPct: 0.0, dyPct: -1.1, phaseOffset: 0,
                          region: .ellipse(cx: 38.5, cy: 21.0, rx: 10.5, ry: 16.0, feather: 0.45)),
                BoneRigOp(pivotX: 54.3, pivotY: 33.1, dThetaDeg: -2.5, dxPct: 0.0, dyPct: -1.1, phaseOffset: 0,
                          region: .ellipse(cx: 61.5, cy: 21.0, rx: 10.5, ry: 16.0, feather: 0.45)),
            ],
            joints: [
                "neck": JointPt(x: 49.7, y: 33.1, active: false),
                "rShoulder": JointPt(x: 45.1, y: 33.1, active: true),
                "rElbow": JointPt(x: 38.7, y: 25.9, active: true),
                "rWrist": JointPt(x: 36.2, y: 13.8, active: true),
                "lShoulder": JointPt(x: 54.3, y: 33.1, active: true),
                "lElbow": JointPt(x: 60.9, y: 26.0, active: true),
                "lWrist": JointPt(x: 64.2, y: 13.8, active: true),
                "rHip": JointPt(x: 46.8, y: 58.7, active: false),
                "lHip": JointPt(x: 52.5, y: 58.5, active: false),
                "rKnee": JointPt(x: 43.1, y: 64.6, active: false),
                "lKnee": JointPt(x: 56.6, y: 65.4, active: false),
                "rAnkle": JointPt(x: 43.0, y: 86.5, active: false),
                "lAnkle": JointPt(x: 56.4, y: 85.9, active: false),
            ],
            bones: [
                ("rWrist", "rElbow", true), ("rElbow", "rShoulder", true),
                ("lWrist", "lElbow", true), ("lElbow", "lShoulder", true),
                ("rShoulder", "lShoulder", false), ("rShoulder", "rHip", false), ("lShoulder", "lHip", false),
                ("rHip", "rKnee", false), ("rKnee", "rAnkle", false),
                ("lHip", "lKnee", false), ("lKnee", "lAnkle", false),
            ]
        )
    ),
]

func drawSkeleton(ctx: CGContext, phase: PhaseSpec, baseAngle: Double, primaryS: Double, alpha: CGFloat) {
    let scale = CGFloat(W) / 800.0
    var movedJoints: [String: (CGPoint, Bool)] = [:]
    for (name, jp) in phase.joints {
        let (mxPct, myPct) = forwardMapPoint(xPct: jp.x, yPct: jp.y, ops: phase.ops, guardBounds: phase.guardBounds, baseAngle: baseAngle)
        let gx = mxPct / 100.0 * Double(W)
        let gy = (1.0 - myPct / 100.0) * Double(H)
        movedJoints[name] = (CGPoint(x: gx, y: gy), jp.active)
    }

    for (a, b, act) in phase.bones {
        guard let (p1, _) = movedJoints[a], let (p2, _) = movedJoints[b] else { continue }
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineWidth((act ? 5.2 : 3.6) * scale)
        ctx.setStrokeColor(act
            ? CGColor(red: 0.16, green: 0.90, blue: 0.58, alpha: 0.24 * alpha)
            : CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.16 * alpha))
        ctx.move(to: p1); ctx.addLine(to: p2); ctx.strokePath()

        ctx.setLineWidth((act ? 2.4 : 1.7) * scale)
        ctx.setStrokeColor(act
            ? CGColor(red: 0.32, green: 0.96, blue: 0.68, alpha: 0.92 * alpha)
            : CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.78 * alpha))
        ctx.move(to: p1); ctx.addLine(to: p2); ctx.strokePath()
        ctx.restoreGState()
    }

    let pulseBoost = CGFloat(1.0 + 0.14 * primaryS)
    for (_, (pt, act)) in movedJoints {
        ctx.saveGState()
        let haloR: CGFloat = (act ? 12.0 * pulseBoost : 9.0) * scale
        ctx.setFillColor(act
            ? CGColor(red: 0.16, green: 0.92, blue: 0.60, alpha: 0.25 * alpha)
            : CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18 * alpha))
        ctx.fillEllipse(in: CGRect(x: pt.x - haloR, y: pt.y - haloR, width: haloR * 2, height: haloR * 2))

        let ringR: CGFloat = (act ? 6.6 : 5.0) * scale
        ctx.setFillColor(act
            ? CGColor(red: 0.16, green: 0.88, blue: 0.56, alpha: 0.94 * alpha)
            : CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.88 * alpha))
        ctx.fillEllipse(in: CGRect(x: pt.x - ringR, y: pt.y - ringR, width: ringR * 2, height: ringR * 2))

        let coreR: CGFloat = (act ? 3.8 : 2.8) * scale
        ctx.setFillColor(act
            ? CGColor(red: 0.95, green: 1.0, blue: 0.95, alpha: alpha)
            : CGColor(red: 0.15, green: 0.20, blue: 0.28, alpha: 0.92 * alpha))
        ctx.fillEllipse(in: CGRect(x: pt.x - coreR, y: pt.y - coreR, width: coreR * 2, height: coreR * 2))
        ctx.restoreGState()
    }
}

func renderChallenge(_ spec: ChallengeMotionSpec, cleanDir: URL, iosDir: URL, androidRawDir: URL, androidDrawableDir: URL) throws {
    let rgba1 = try loadScaledRGBA(url: cleanDir.appendingPathComponent(spec.phase1.imageFile))
    let rgba2 = try loadScaledRGBA(url: cleanDir.appendingPathComponent(spec.phase2.imageFile))

    let mp4Name = "motion_\(spec.key).mp4"
    let posterName = "motion_\(spec.key)_poster.jpg"
    let iosMP4 = iosDir.appendingPathComponent(mp4Name)
    let iosPoster = iosDir.appendingPathComponent(posterName)
    try? FileManager.default.removeItem(at: iosMP4)

    let writer = try AVAssetWriter(outputURL: iosMP4, fileType: .mp4)
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: W,
        AVVideoHeightKey: H,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 850_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
            AVVideoExpectedSourceFrameRateKey: Int(FPS),
            AVVideoMaxKeyFrameIntervalKey: Int(FPS),
        ],
    ]
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    writerInput.expectsMediaDataInRealTime = false
    let pbAttrs: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: W,
        kCVPixelBufferHeightKey as String: H,
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: pbAttrs)
    writer.add(writerInput)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let cs = CGColorSpaceCreateDeviceRGB()
    var frameRGBA = [UInt8](repeating: 0, count: W * H * 4)
    let halfLen = PHASE_FRAMES + DIP_FRAMES
    let posterFrameIdx = halfLen + PHASE_FRAMES / 2

    for frameIdx in 0..<TOTAL_FRAMES {
        let isPhase2 = frameIdx >= halfLen
        let localIdx = frameIdx % halfLen
        let activePhase = isPhase2 ? spec.phase2 : spec.phase1
        let srcRGBA = isPhase2 ? rgba2 : rgba1

        let brightness: Double
        if localIdx < 3 {
            brightness = Double(localIdx + 1) / 4.0
        } else if localIdx >= PHASE_FRAMES {
            let dipStep = localIdx - PHASE_FRAMES
            brightness = max(0.0, 1.0 - Double(dipStep + 1) / Double(DIP_FRAMES))
        } else {
            brightness = 1.0
        }

        let normT = Double(min(localIdx, PHASE_FRAMES)) / Double(PHASE_FRAMES)
        let baseAngle = 2.0 * Double.pi * normT
        let primaryS = 0.5 - 0.5 * cos(baseAngle)
        let sValues = activePhase.ops.map { 0.5 - 0.5 * cos(baseAngle + $0.phaseOffset) }

        frameRGBA.withUnsafeMutableBufferPointer { frameBuf in
            guard let frameBase = frameBuf.baseAddress else { return }
            DispatchQueue.concurrentPerform(iterations: H) { y in
                let fy = Double(y)
                let rowOffset = y * W * 4
                for x in 0..<W {
                    let fx = Double(x)
                    let (srcX, srcY) = inverseMapPixel(outX: fx, outY: fy, ops: activePhase.ops, guardBounds: activePhase.guardBounds, sValues: sValues)
                    let outIdx = rowOffset + x * 4
                    let r: UInt8; let g: UInt8; let b: UInt8
                    if abs(srcX - fx) < 0.03 && abs(srcY - fy) < 0.03 {
                        r = srcRGBA[outIdx]; g = srcRGBA[outIdx + 1]; b = srcRGBA[outIdx + 2]
                    } else {
                        (r, g, b) = sampleBilinearRGB(buf: srcRGBA, width: W, height: H, fx: srcX, fy: srcY)
                    }
                    if brightness < 0.999 {
                        frameBase[outIdx + 0] = UInt8(max(0, min(255, Int((STUDIO_R + (Double(r) - STUDIO_R) * brightness).rounded()))))
                        frameBase[outIdx + 1] = UInt8(max(0, min(255, Int((STUDIO_G + (Double(g) - STUDIO_G) * brightness).rounded()))))
                        frameBase[outIdx + 2] = UInt8(max(0, min(255, Int((STUDIO_B + (Double(b) - STUDIO_B) * brightness).rounded()))))
                    } else {
                        frameBase[outIdx + 0] = r; frameBase[outIdx + 1] = g; frameBase[outIdx + 2] = b
                    }
                    frameBase[outIdx + 3] = 255
                }
            }
        }

        var pbOpt: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pbOpt)
        guard let pb = pbOpt else { continue }
        CVPixelBufferLockBaseAddress(pb, [])
        if let baseAddr = CVPixelBufferGetBaseAddress(pb) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
            let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            if let ctx = CGContext(data: baseAddr, width: W, height: H, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: cs, bitmapInfo: bitmapInfo) {
                ctx.interpolationQuality = .high
                ctx.setShouldAntialias(true)
                ctx.setAllowsAntialiasing(true)
                frameRGBA.withUnsafeMutableBytes { rawPtr in
                    if let srcCtx = CGContext(data: rawPtr.baseAddress, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                       let cgImg = srcCtx.makeImage() {
                        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: W, height: H))
                    }
                }
                if brightness > 0.05 {
                    drawSkeleton(ctx: ctx, phase: activePhase, baseAngle: baseAngle, primaryS: primaryS, alpha: CGFloat(brightness))
                }
                if frameIdx == posterFrameIdx, let posterCG = ctx.makeImage() {
                    let rep = NSBitmapImageRep(cgImage: posterCG)
                    if let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88]) {
                        try jpg.write(to: iosPoster)
                        try jpg.write(to: androidDrawableDir.appendingPathComponent(posterName))
                    }
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pb, [])
        while !writerInput.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frameIdx), timescale: FPS))
    }

    writerInput.markAsFinished()
    let sem = DispatchSemaphore(value: 0)
    writer.finishWriting { sem.signal() }
    sem.wait()
    if writer.status != .completed {
        throw writer.error ?? NSError(domain: "GenVideo", code: 2, userInfo: [NSLocalizedDescriptionKey: "Writer failed"])
    }
    let androidMP4 = androidRawDir.appendingPathComponent(mp4Name)
    try? FileManager.default.removeItem(at: androidMP4)
    try FileManager.default.copyItem(at: iosMP4, to: androidMP4)

    let mp4KB = ((try? FileManager.default.attributesOfItem(atPath: iosMP4.path)[.size] as? Int) ?? 0) / 1024
    let posterKB = ((try? FileManager.default.attributesOfItem(atPath: iosPoster.path)[.size] as? Int) ?? 0) / 1024
    print("[OK] \(mp4Name) (\(TOTAL_FRAMES)f @ \(FPS)fps, \(mp4KB) KB) + \(posterName) (\(posterKB) KB)")
}

let root = URL(fileURLWithPath: "/Users/danhvt0109/Projects/HiMorning")
let cleanDir = root.appendingPathComponent("scripts/motion-assets/keyframes_clean")
let iosDir = root.appendingPathComponent("apps/ios/Resources/Motion")
let androidRawDir = root.appendingPathComponent("apps/android/app/src/main/res/raw")
let androidDrawableDir = root.appendingPathComponent("apps/android/app/src/main/res/drawable-nodpi")

try FileManager.default.createDirectory(at: iosDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: androidRawDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: androidDrawableDir, withIntermediateDirectories: true)

for spec in ALL_CHALLENGES {
    try renderChallenge(spec, cleanDir: cleanDir, iosDir: iosDir, androidRawDir: androidRawDir, androidDrawableDir: androidDrawableDir)
}
print("ALL 7 STUDIO MOTION VIDEOS + POSTERS GENERATED FOR iOS & ANDROID!")
