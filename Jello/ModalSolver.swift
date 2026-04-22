//
//  ModalSolver.swift
//  Jello
//
//  Exact analytic integrator for the linear mass-spring system.
//  K·Φ = Ω²·M·Φ via Accelerate LAPACK dsygvd_; modes evolve as
//  damped harmonic oscillators. Cartesian state (Particle.position /
//  .velocity) is authoritative — each step reads Cartesian, projects
//  to modal space, advances analytically, and unprojects. No modal
//  state persists across frames.
//
//  Fallback: on LAPACK failure, NaN, or runaway force, delegates to
//  a stashed VelocityVerlet.
//

import AppKit
import Accelerate

class ModalSolver: Solver {
  // MARK: - Geometry constants

  private let nFull: Int = GRID_WIDTH * GRID_HEIGHT + 1   // 49 (grid + mouse)
  private let nGrid: Int = GRID_WIDTH * GRID_HEIGHT       // 48
  private let mouseIdx: Int = GRID_WIDTH * GRID_HEIGHT    // 48 (last)

  // MARK: - Solver state

  private enum SystemMode { case uninitialized, drag, free }
  private var sysMode: SystemMode = .uninitialized

  private var nModes: Int = 0                 // 48 drag, 49 free
  private var phi: [Double] = []              // column-major n×n eigenvectors
  private var omega: [Double] = []            // n eigenfrequencies (sqrt of eigenvalues)
  private var modalDamp: [Double] = []        // per-mode damping coef cᵢ (Caughey)
  private var massVec: [Double] = []          // per-DOF mass (n values)
  private var xRestX: [Double] = []           // rest positions, x component (n values)
  private var xRestY: [Double] = []           // rest positions, y component (n values)

  // Drag-case extras (static condensation)
  private var yCoupling: [Double] = []        // -K_ff⁻¹·K_fc (nGrid), scalar since x/y share topology
  private var uRestX: Double = 0              // mouse rest x
  private var uRestY: Double = 0              // mouse rest y

  // MARK: - Fallback

  private let fallback: VelocityVerlet
  private var useFallback: Bool = false
  private var fallbackLogged: Bool = false

  override var preferredIterations: Int { useFallback ? 15 : 1 }

  override init(warp: Warp) {
    self.fallback = VelocityVerlet(warp: warp)
    super.init(warp: warp)
  }

  // MARK: - Public lifecycle

  func rebuildForDrag() {
    if useFallback { return }
    do {
      try buildDragSystem()
      sysMode = .drag
    } catch {
      triggerFallback("rebuildForDrag failed: \(error)")
    }
  }

  func rebuildForFree() {
    if useFallback { return }
    do {
      try buildFreeSystem()
      sysMode = .free
    } catch {
      triggerFallback("rebuildForFree failed: \(error)")
    }
  }

  func updateRestPositions() {
    // Called on window resize — K is unchanged, just re-snapshot rest positions.
    if useFallback || sysMode == .uninitialized { return }
    snapshotRestPositions(includeMouse: sysMode == .free)
  }

  // MARK: - Per-frame step

  override func step(particles: inout [Particle], stepSize: CGFloat) {
    if useFallback {
      // preferredIterations returned 15 this frame, so Warp already scaled
      // stepSize down appropriately (7·delta each). Delegate per-call.
      fallback.step(particles: &particles, stepSize: stepSize)
      self.force = fallback.force
      self.velocity = fallback.velocity
      return
    }
    if sysMode == .uninitialized { return }

    let dt = Double(stepSize)

    stepDimension(particles: &particles, axis: .x, dt: dt)
    if useFallback { return } // mid-step fallback: leave state to next frame
    stepDimension(particles: &particles, axis: .y, dt: dt)
    if useFallback { return }

    // Detect NaN / runaway; flip to fallback if so
    for i in 0..<particles.count {
      let p = particles[i]
      if !p.position.x.isFinite || !p.position.y.isFinite
          || !p.velocity.dx.isFinite || !p.velocity.dy.isFinite {
        triggerFallback("NaN/inf detected in particle state")
        return
      }
    }

    // Populate self.force and self.velocity for stop detection.
    // derivEval sums spring + friction forces into particles[i].force and sets self.force.
    _ = self.derivEval(particles: particles)
  }

  // MARK: - Drag system assembly

  private enum ModalError: Error {
    case lapackInfo(String, Int32)
  }

  private func buildDragSystem() throws {
    nModes = nGrid
    massVec = warp.particles.prefix(nGrid).map { Double($0.mass) }

    // Assemble K_ff (nGrid × nGrid) and K_fc (nGrid) from springs.
    // Grid-grid (both mobile) contributes k/2 per-endpoint stiffness.
    // Grid-mouse (mouse immobile) contributes full k on grid diagonal; -k to K_fc.
    var Kff = [Double](repeating: 0, count: nGrid * nGrid)
    var Kfc = [Double](repeating: 0, count: nGrid)
    for spring in warp.springs {
      let a = spring.a, b = spring.b
      let mouseInvolved = (a == mouseIdx) || (b == mouseIdx)
      if mouseInvolved {
        let grid = (a == mouseIdx) ? b : a
        if grid == mouseIdx { continue } // should not happen
        let k = Double(spring.springK)   // full stiffness (Spring.apply doubles when one end immobile)
        Kff[grid * nGrid + grid] += k
        Kfc[grid] -= k
      } else {
        let k = Double(spring.springK) / 2.0
        Kff[a * nGrid + a] += k
        Kff[a * nGrid + b] -= k
        Kff[b * nGrid + a] -= k
        Kff[b * nGrid + b] += k
      }
    }

    // Solve y = -K_ff⁻¹·K_fc (i.e. K_ff · y = -K_fc) via Cholesky (dposv_).
    var KffCholesky = Kff // copy; dposv_ destroys A
    var negKfc = Kfc.map { -$0 }
    var uplo: Int8 = Int8(UnicodeScalar("U").value)
    var nA = Int32(nGrid)    // n
    var nLda = Int32(nGrid)  // lda — separate to satisfy Swift exclusive-access
    var nLdb = Int32(nGrid)  // ldb — ditto
    var nrhs: Int32 = 1
    var info: Int32 = 0
    dposv_(&uplo, &nA, &nrhs, &KffCholesky, &nLda, &negKfc, &nLdb, &info)
    if info != 0 { throw ModalError.lapackInfo("dposv_", info) }
    yCoupling = negKfc

    // Eigendecompose K_ff·Φ = Ω²·M·Φ via dsygvd_.
    // Build M as a diagonal dense matrix (required by dsygvd).
    var Mmat = [Double](repeating: 0, count: nGrid * nGrid)
    for i in 0..<nGrid { Mmat[i * nGrid + i] = massVec[i] }
    // dsygvd overwrites A with eigenvectors (if jobz='V'). Use Kff directly.
    var w = [Double](repeating: 0, count: nGrid)
    try runDsygvd(n: nGrid, a: &Kff, b: &Mmat, w: &w)
    phi = Kff
    omega = w.map { sqrt(max($0, 0)) }
    modalDamp = computeModalDamping(n: nGrid)

    snapshotRestPositions(includeMouse: false)
    uRestX = Double(warp.particles[mouseIdx].position.x)
    uRestY = Double(warp.particles[mouseIdx].position.y)
  }

  // MARK: - Free system assembly

  private func buildFreeSystem() throws {
    nModes = nFull
    massVec = warp.particles.map { Double($0.mass) }

    // Assemble K (n × n) for all-mobile system. Every spring contributes k/2.
    var Kmat = [Double](repeating: 0, count: nFull * nFull)
    for spring in warp.springs {
      let a = spring.a, b = spring.b
      let k = Double(spring.springK) / 2.0
      Kmat[a * nFull + a] += k
      Kmat[a * nFull + b] -= k
      Kmat[b * nFull + a] -= k
      Kmat[b * nFull + b] += k
    }
    var Mmat = [Double](repeating: 0, count: nFull * nFull)
    for i in 0..<nFull { Mmat[i * nFull + i] = massVec[i] }

    var w = [Double](repeating: 0, count: nFull)
    try runDsygvd(n: nFull, a: &Kmat, b: &Mmat, w: &w)
    phi = Kmat
    omega = w.map { sqrt(max($0, 0)) }
    modalDamp = computeModalDamping(n: nFull)

    snapshotRestPositions(includeMouse: true)
  }

  // MARK: - Rest-position snapshot

  // x_rest must be a configuration where ALL springs sit at rest length — i.e.
  // the undeformed lattice, not the current (deformed) particle positions.
  // Otherwise "modal equilibrium" (q = 0) does NOT correspond to zero spring
  // force, and the post-drag stop-condition (self.force < 20) never trips.
  // We anchor on particles[0] and reconstruct the lattice from the current
  // window size and spring offsets — both of which were set so that the
  // original particle positions are a valid rest configuration.
  private func snapshotRestPositions(includeMouse: Bool) {
    let count = includeMouse ? nFull : nGrid
    xRestX = [Double](repeating: 0, count: count)
    xRestY = [Double](repeating: 0, count: count)

    let anchor = warp.particles[0].position
    let size = warp.window.frame.size
    for i in 0..<nGrid {
      let (gx, gy) = convert(toPosition: i)
      let dx = CGFloat(gx) / CGFloat(GRID_WIDTH - 1) * size.width
      let dy = CGFloat(gy) / CGFloat(GRID_HEIGHT - 1) * size.height
      xRestX[i] = Double(anchor.x + dx)
      xRestY[i] = Double(anchor.y + dy)
    }

    if includeMouse {
      // Derive mouse_rest from any mouse-grid spring's offset, which encodes
      // mouse_rest − grid_rest at initialization time.
      for spring in warp.springs {
        if spring.a == mouseIdx || spring.b == mouseIdx {
          let gridIdx = (spring.a == mouseIdx) ? spring.b : spring.a
          if spring.a == mouseIdx {
            // offset = b − a = grid_rest − mouse_rest → mouse_rest = grid_rest − offset
            xRestX[mouseIdx] = xRestX[gridIdx] - Double(spring.offset.dx)
            xRestY[mouseIdx] = xRestY[gridIdx] - Double(spring.offset.dy)
          } else {
            // offset = b − a = mouse_rest − grid_rest → mouse_rest = grid_rest + offset
            xRestX[mouseIdx] = xRestX[gridIdx] + Double(spring.offset.dx)
            xRestY[mouseIdx] = xRestY[gridIdx] + Double(spring.offset.dy)
          }
          return
        }
      }
      // Fallback: mouse at current position (no coupling springs)
      xRestX[mouseIdx] = Double(warp.particles[mouseIdx].position.x)
      xRestY[mouseIdx] = Double(warp.particles[mouseIdx].position.y)
    }
  }

  // MARK: - Modal damping (Caughey diagonal)

  private func computeModalDamping(n: Int) -> [Double] {
    // cᵢ = friction · Σⱼ Φⱼᵢ²  (diagonal of Φᵀ·C·Φ with C = friction·I)
    var damp = [Double](repeating: 0, count: n)
    let f = Double(friction)
    for i in 0..<n {
      var sq: Double = 0
      for j in 0..<n {
        let v = phi[i * n + j] // column-major: column i, row j
        sq += v * v
      }
      damp[i] = f * sq
    }
    return damp
  }

  // MARK: - LAPACK wrapper

  private func runDsygvd(n: Int, a: inout [Double], b: inout [Double], w: inout [Double]) throws {
    var itype: Int32 = 1
    var jobz: Int8 = Int8(UnicodeScalar("V").value)
    var uplo: Int8 = Int8(UnicodeScalar("U").value)
    var nn = Int32(n)
    var lda = nn
    var ldb = nn
    var info: Int32 = 0

    // Workspace query
    var workQuery = [Double](repeating: 0, count: 1)
    var iworkQuery = [Int32](repeating: 0, count: 1)
    var lwork: Int32 = -1
    var liwork: Int32 = -1
    dsygvd_(&itype, &jobz, &uplo, &nn, &a, &lda, &b, &ldb, &w,
            &workQuery, &lwork, &iworkQuery, &liwork, &info)
    if info != 0 { throw ModalError.lapackInfo("dsygvd_ query", info) }

    lwork = Int32(workQuery[0])
    liwork = iworkQuery[0]
    var work = [Double](repeating: 0, count: Int(lwork))
    var iwork = [Int32](repeating: 0, count: Int(liwork))

    dsygvd_(&itype, &jobz, &uplo, &nn, &a, &lda, &b, &ldb, &w,
            &work, &lwork, &iwork, &liwork, &info)
    if info != 0 { throw ModalError.lapackInfo("dsygvd_", info) }
  }

  // MARK: - Per-axis step

  private enum Axis { case x, y }

  private func stepDimension(particles: inout [Particle], axis: Axis, dt: Double) {
    let dofCount: Int
    let restVec: [Double]
    switch axis {
    case .x: restVec = xRestX
    case .y: restVec = xRestY
    }
    switch sysMode {
    case .drag: dofCount = nGrid
    case .free: dofCount = nFull
    case .uninitialized: return
    }

    // --- Gather Cartesian state into u (displacement) and v (velocity) ---
    var u = [Double](repeating: 0, count: dofCount)
    var v = [Double](repeating: 0, count: dofCount)

    if sysMode == .drag {
      // Equilibrium shifts with mouse: x_eq[i] = x_rest[i] + y[i] · (mouse - mouse_rest)
      let mousePos: Double = (axis == .x)
        ? Double(particles[mouseIdx].position.x)
        : Double(particles[mouseIdx].position.y)
      let mouseRest: Double = (axis == .x) ? uRestX : uRestY
      let du = mousePos - mouseRest
      for i in 0..<nGrid {
        let xeq = restVec[i] + yCoupling[i] * du
        let pos = (axis == .x) ? Double(particles[i].position.x) : Double(particles[i].position.y)
        let vel = (axis == .x) ? Double(particles[i].velocity.dx) : Double(particles[i].velocity.dy)
        u[i] = pos - xeq
        v[i] = vel
      }
    } else {
      for i in 0..<nFull {
        let pos = (axis == .x) ? Double(particles[i].position.x) : Double(particles[i].position.y)
        let vel = (axis == .x) ? Double(particles[i].velocity.dx) : Double(particles[i].velocity.dy)
        u[i] = pos - restVec[i]
        v[i] = vel
      }
    }

    // --- Modal project: q = Φᵀ·M·u, q̇ = Φᵀ·M·v ---
    var Mu = [Double](repeating: 0, count: dofCount)
    var Mv = [Double](repeating: 0, count: dofCount)
    for i in 0..<dofCount {
      Mu[i] = massVec[i] * u[i]
      Mv[i] = massVec[i] * v[i]
    }
    var q = [Double](repeating: 0, count: dofCount)
    var qdot = [Double](repeating: 0, count: dofCount)
    cblas_dgemv(CblasColMajor, CblasTrans,
                Int32(dofCount), Int32(dofCount), 1.0,
                phi, Int32(dofCount), Mu, 1, 0.0, &q, 1)
    cblas_dgemv(CblasColMajor, CblasTrans,
                Int32(dofCount), Int32(dofCount), 1.0,
                phi, Int32(dofCount), Mv, 1, 0.0, &qdot, 1)

    // --- Advance each mode analytically ---
    var qNew = [Double](repeating: 0, count: dofCount)
    var qdotNew = [Double](repeating: 0, count: dofCount)
    let eps = 1e-6
    for i in 0..<dofCount {
      let w = omega[i]
      let c = modalDamp[i]
      if w < eps {
        // Rigid-body (zero-frequency) mode: pure viscous drift.
        // q̈ + c·q̇ = 0  →  q̇(t) = q̇₀·exp(-c·t), q(t) = q₀ + q̇₀·(1-exp(-c·t))/c
        if c < 1e-12 {
          qNew[i] = q[i] + qdot[i] * dt
          qdotNew[i] = qdot[i]
        } else {
          let e = exp(-c * dt)
          qdotNew[i] = qdot[i] * e
          qNew[i] = q[i] + qdot[i] * (1 - e) / c
        }
      } else {
        // Damped oscillator. ζ = c/(2ω). Underdamped branch covers our parameter range
        // (current friction=1.5, mass≥1, so ζ stays well below 1 for realistic modes).
        let zeta = c / (2 * w)
        if zeta >= 1 {
          triggerFallback("overdamped mode ζ=\(zeta) at ω=\(w)")
          return
        }
        let zw = zeta * w
        let wd = w * sqrt(1 - zeta * zeta)
        let e = exp(-zw * dt)
        let cosT = cos(wd * dt)
        let sinT = sin(wd * dt)
        let A = q[i]
        let B = (qdot[i] + zw * q[i]) / wd
        qNew[i] = e * (A * cosT + B * sinT)
        qdotNew[i] = e * ((-zw * A + B * wd) * cosT + (-zw * B - A * wd) * sinT)
      }
    }
    if useFallback { return }

    // --- Unproject: δ = Φ·q, v' = Φ·q̇ ---
    var dx = [Double](repeating: 0, count: dofCount)
    var dv = [Double](repeating: 0, count: dofCount)
    cblas_dgemv(CblasColMajor, CblasNoTrans,
                Int32(dofCount), Int32(dofCount), 1.0,
                phi, Int32(dofCount), qNew, 1, 0.0, &dx, 1)
    cblas_dgemv(CblasColMajor, CblasNoTrans,
                Int32(dofCount), Int32(dofCount), 1.0,
                phi, Int32(dofCount), qdotNew, 1, 0.0, &dv, 1)

    // --- Write back to particles ---
    if sysMode == .drag {
      let mousePos: Double = (axis == .x)
        ? Double(particles[mouseIdx].position.x)
        : Double(particles[mouseIdx].position.y)
      let mouseRest: Double = (axis == .x) ? uRestX : uRestY
      let du = mousePos - mouseRest
      for i in 0..<nGrid {
        if particles[i].immobile { continue }
        let xeq = restVec[i] + yCoupling[i] * du
        let newPos = xeq + dx[i]
        let newVel = dv[i]
        if axis == .x {
          particles[i].position.x = CGFloat(newPos)
          particles[i].velocity.dx = CGFloat(newVel)
        } else {
          particles[i].position.y = CGFloat(newPos)
          particles[i].velocity.dy = CGFloat(newVel)
        }
      }
    } else {
      for i in 0..<nFull {
        if particles[i].immobile { continue }
        let newPos = restVec[i] + dx[i]
        let newVel = dv[i]
        if axis == .x {
          particles[i].position.x = CGFloat(newPos)
          particles[i].velocity.dx = CGFloat(newVel)
        } else {
          particles[i].position.y = CGFloat(newPos)
          particles[i].velocity.dy = CGFloat(newVel)
        }
      }
    }
  }

  // MARK: - derivEval override

  // Mirrors Solver.derivEval but WITHOUT the force>50000 termination. The
  // modal integrator is unconditionally stable by construction (each mode
  // evolves as exp(-ζωt)·bounded trig), so a "forces too large" runtime
  // termination is both unnecessary and miscalibrated — aggressive drags
  // on a 193-DOF grid with springK=28 routinely push |force| over 50000
  // transiently without any instability.
  override func derivEval(particles: [Particle]) -> [Particle] {
    var particles = particles

    for i in 0..<particles.count {
      particles[i].force = CGVector.zero
    }
    warp.springs.apply(particles: &particles)
    for i in 0..<particles.count {
      particles[i].force -= particles[i].velocity * friction
    }
    self.force = particles.reduce(0) { (a, b) in a + abs(b.force.dx) + abs(b.force.dy) }

    return particles
  }

  // MARK: - Fallback handling

  private func triggerFallback(_ reason: String) {
    useFallback = true
    if !fallbackLogged {
      print("ModalSolver: falling back to VelocityVerlet — \(reason)")
      fallbackLogged = true
    }
  }
}
