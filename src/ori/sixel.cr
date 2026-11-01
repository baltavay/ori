require "digest/sha1"
require "file_utils"
require "process"

# Sixel payloads for terminals that implement sixel but not the kitty protocol —
# foot is the one that matters here. The encoder is ImageMagick (`magick` or
# `convert`), the only program that writes sixel; it runs on worker threads because
# a ~25 ms process per image must not block a frame. Payloads are cached by source
# file, mtime and the exact pixel box.
module Ori
  class Sixel
    WORKERS = 2

    @@binary : String? = nil

    def self.binary : String?
      @@binary ||= begin
        %w[magick convert].find do |candidate|
          Process.run(candidate, ["-version"], output: Process::Redirect::Close,
            error: Process::Redirect::Close).success?
        rescue
          false
        end
      end
    end

    def self.available? : Bool
      !binary.nil?
    end

    # `cell` is the terminal cell in pixels: the payload is encoded at exactly the
    # pixels its cell box covers, so the terminal never has to scale it.
    def initialize(@cache_dir : String, @cell : {Int32, Int32})
      FileUtils.mkdir_p(@cache_dir)
      @queue = Channel(Tuple(String, String, Int32, Int32)).new(64)
      @pending = Set(String).new
      @failed = Set(String).new
      @memory = {} of String => String
      @mutex = Mutex.new
      WORKERS.times do |index|
        name = index.zero? ? "ori-sixel" : "ori-sixel#{index + 1}"
        Fiber::ExecutionContext::Isolated.new(name) do
          Thread.name = name
          work
        end
      end
    end

    # The payload for `png` in a `cols`x`rows` cell box, or nil while it is being made.
    def fetch(png : String, cols : Int32, rows : Int32) : String?
      return nil unless File.exists?(png)
      width = (cols * @cell[0]).clamp(1, 4096)
      height = (rows * @cell[1]).clamp(1, 4096)
      target = target_for(png, width, height)
      if cached = @mutex.synchronize { @memory[target]? }
        return cached
      end
      unless File.exists?(target)
        schedule(png, target, width, height)
        return nil
      end
      data = File.read(target)
      @mutex.synchronize { @memory[target] = data }
      data
    rescue
      nil
    end

    private def target_for(png : String, width : Int32, height : Int32) : String
      stamp = File.info?(png).try { |info| "#{info.size}:#{info.modification_time.to_unix}" } || "0"
      key = Digest::SHA1.hexdigest("#{png}:#{stamp}:#{width}x#{height}")[0, 24]
      File.join(@cache_dir, "#{key}.six")
    end

    private def schedule(png : String, target : String, width : Int32, height : Int32) : Nil
      @mutex.synchronize do
        return if @pending.includes?(target) || @failed.includes?(target)
        @pending << target
      end
      select
      when @queue.send({png, target, width, height})
      else
      end
    rescue Channel::ClosedError
    end

    private def work : Nil
      binary = Sixel.binary
      return unless binary
      loop do
        png, target, width, height = @queue.receive
        temp = "#{target}.#{Process.pid}.tmp"
        begin
          FileUtils.mkdir_p(File.dirname(target))
          args = [png, "-resize", "#{width}x#{height}!", "-strip", "-depth", "8", "sixel:#{temp}"]
          okay = Process.run(binary, args, output: Process::Redirect::Close,
            error: Process::Redirect::Close).success?
          if okay && File.exists?(temp)
            File.rename(temp, target)
          else
            @mutex.synchronize { @failed << target }
          end
        rescue
          @mutex.synchronize { @failed << target }
        ensure
          @mutex.synchronize { @pending.delete(target) }
          File.delete(temp) if File.exists?(temp)
        end
      end
    rescue Channel::ClosedError
    end
  end
end
