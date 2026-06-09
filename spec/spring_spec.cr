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

  it "starts moving toward target" do
    pos, vel = Ori::Spring.update(0.0, 0.0, 100.0, 6.0, 1.0, 0.1)
    pos.should be > 0.0
  end
end

