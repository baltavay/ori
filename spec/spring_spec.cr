require "spec"
require "../src/ori"

describe Ori::Spring do
  it "reaches target when critically damped" do
    pos = 0.0
    vel = 0.0
    100.times do
      pos, vel = Ori::Spring.update(pos, vel, 100.0, 6.0, 1.0, 0.016)
    end
    (pos - 100.0).abs.should be < 1.0
    vel.abs.should be < 1.0
  end

  it "reaches target when underdamped (bouncy)" do
    pos = 0.0
    vel = 0.0
    400.times do
      pos, vel = Ori::Spring.update(pos, vel, 100.0, 3.0, 0.3, 0.016)
    end
    (pos - 100.0).abs.should be < 0.5
  end

  it "stays at target when already there" do
    pos, vel = Ori::Spring.update(50.0, 0.0, 50.0, 6.0, 1.0, 0.016)
    (pos - 50.0).abs.should be < 0.001
    vel.abs.should be < 0.001
  end

describe "Ori::Spring::Clock" do
  it "runs the same steps however a span of wall-clock time is divided" do
    run = ->(elapsed : Float64, frames : Int32) do
      clock = Ori::Spring::Clock.new(step: 0.25)
      pos = 0.0
      vel = 0.0
      frames.times do
        pos, vel = Ori::Spring.apply(clock.take(elapsed / frames), pos, vel, 100.0, 3.0, 0.3)
      end
      {pos, vel}
    end
    whole = run.call(4.0, 1)
    whole.should eq(run.call(4.0, 16))
    whole.should eq(run.call(4.0, 4))
  end

  it "runs one step per step's worth of elapsed time" do
    clock = Ori::Spring::Clock.new
    clock.take(Ori::Spring::STEP_SECONDS * 4).steps.should eq(4)
  end

  it "carries the left-over time into the next frame" do
    clock = Ori::Spring::Clock.new(step: 0.25)
    clock.take(0.3125).steps.should eq(1) # 1.25 steps, 0.0625 left over
    clock.take(0.1875).steps.should eq(1) # 0.25 of backlog, nothing left
    clock.take(0.0625).steps.should eq(0) # less than one step
  end

  it "caps a long stall and snaps onto the target" do
    clock = Ori::Spring::Clock.new(step: 0.25)
    schedule = clock.take(2_500.0) # 10 000 steps of backlog
    schedule.steps.should eq(Ori::Spring::MAX_STEPS)
    schedule.snap.should be_true
    pos, vel = Ori::Spring.apply(schedule, 0.0, 0.0, 100.0, 3.0, 0.3)
    pos.should eq(100.0)
    vel.should eq(0.0)
  end

  it "does not carry a snap's backlog into the next frame" do
    clock = Ori::Spring::Clock.new(step: 0.25)
    clock.take(2_500.0)
    clock.take(0.0).steps.should eq(0)
    clock.take(0.25).steps.should eq(1)
  end
end
end

