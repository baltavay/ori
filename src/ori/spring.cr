module Ori::Spring
  # Compute spring position/velocity for one time step.
  # Uses damped harmonic oscillator (Ryan Juckett algorithm).
  #  - pos, vel: current state
  #  - target: equilibrium position
  #  - frequency: angular frequency (rad/s), higher = faster
  #  - damping: damping ratio (0=undamped, 1=critically damped, >1=overdamped)
  #  - dt: time step in seconds
  # Returns {new_pos, new_vel}
  def self.update(pos : Float64, vel : Float64, target : Float64, frequency : Float64, damping : Float64, dt : Float64) : {Float64, Float64}
    return {target, 0.0} if frequency <= 0 || dt <= 0

    x0 = pos - target
    v0 = vel

    x0 = 0.0 if x0.abs < 1e-8
    v0 = 0.0 if v0.abs < 1e-8

    return {target, 0.0} if x0 == 0.0 && v0 == 0.0

    omega = frequency
    zeta = damping
    omega_d = omega * Math.sqrt({1.0 - zeta * zeta, 0.0}.max)
    half_life = {omega * zeta * dt, 100.0}.min
    exp = Math.exp(-half_life)

    if zeta < 1.0
      # Underdamped
      if omega_d > 0
        cos_omega = Math.cos(omega_d * dt)
        sin_omega = Math.sin(omega_d * dt)
        a = cos_omega + (zeta * omega / omega_d) * sin_omega
        b = sin_omega / omega_d
        nx = exp * (x0 * a + v0 * b)
        nv = exp * (-x0 * omega_d * sin_omega + v0 * (cos_omega - omega * zeta * b))
      else
        nx = exp * x0
        nv = exp * (v0 - omega * zeta * x0)
      end
    elsif zeta > 1.0
      # Overdamped
      zeta2 = Math.sqrt(zeta * zeta - 1.0)
      omega1 = omega * (zeta - zeta2)
      omega2 = omega * (zeta + zeta2)
      e1 = Math.exp(-omega1 * dt)
      e2 = Math.exp(-omega2 * dt)
      co1 = x0 * (omega2 / (omega2 - omega1)) - v0 / (omega2 - omega1)
      co2 = x0 - co1
      nx = co1 * e1 + co2 * e2
      nv = -omega1 * co1 * e1 - omega2 * co2 * e2
    else
      # Critically damped
      nx = exp * (x0 + (omega * zeta * x0 + v0) * dt)
      nv = exp * (v0 - (omega * zeta * x0 + v0) * omega * zeta * dt)
    end

    {nx + target, nv}
  end
end
