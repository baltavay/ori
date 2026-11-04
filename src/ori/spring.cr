module Ori::Spring
  # A frame runs whole steps of a fixed size, and its work has a maximum with a
  # named fallback: past MAX_STEPS the spring snaps onto its target instead of
  # catching up. 300 steps of 4 ms is 1.2 s, so only a real stall reaches it.
  STEP_SECONDS = 0.004
  MAX_STEPS    = 300

  # The whole steps one frame should run, the step size, and whether the spring
  # should give up on the backlog and snap onto its target.
  record Schedule, steps : Int32, snap : Bool, step : Float64

  # Turns wall-clock time into whole `step` slices and keeps the remainder for
  # the next frame, so the state is the same however frames are divided.
  class Clock
    getter backlog : Float64

    def initialize(@step : Float64 = STEP_SECONDS, @max_steps : Int32 = MAX_STEPS)
      @backlog = 0.0
    end

    def take(elapsed : Float64) : Schedule
      @backlog += elapsed if elapsed > 0
      steps = (@backlog / @step).to_i
      if steps <= 0
        Schedule.new(0, false, @step)
      elsif steps > @max_steps
        @backlog = 0.0
        Schedule.new(@max_steps, true, @step)
      else
        @backlog -= steps * @step
        Schedule.new(steps, false, @step)
      end
    end

    def reset : Nil
      @backlog = 0.0
    end
  end

  # Runs a schedule's steps on one spring, or snaps it onto its target.
  def self.apply(schedule : Schedule, pos : Float64, vel : Float64, target : Float64, frequency : Float64, damping : Float64) : {Float64, Float64}
    return {target, 0.0} if schedule.snap
    schedule.steps.times do
      pos, vel = update(pos, vel, target, frequency, damping, schedule.step)
    end
    {pos, vel}
  end

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
