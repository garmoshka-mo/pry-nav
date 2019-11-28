require 'fileutils'

class PryMoves::Backtrace

  class << self
    def lines_count; @lines_count || 5; end
    def lines_count=(f); @lines_count = f; end

    def filter
      @filter || /(\/gems\/|\/rubygems\/|\/bin\/|\/lib\/ruby\/)/
    end
    def filter=(f); @filter = f; end

    def format(&block)
      @formatter = block
    end

    def formatter
      @formatter || lambda do |line|
        # not used
      end
    end
  end

  def initialize(pry)
     @pry = pry
  end

  def run_command(param, param2)
    if param.is_a?(String) and (match = param.match /^>(.*)/)
      suffix = match[1].size > 0 ? match[1] : param2
      write_to_file build, suffix
    elsif param and param.match /\d+/
      index = param.to_i
      frame_manager.change_frame_to index
    else
      print_backtrace param
    end
  end

  private

  def print_backtrace filter
    @colorize = true
    if filter.is_a? String
      @filter = filter
    else
      @lines_count = PryMoves::Backtrace::lines_count
    end
    @pry.output.puts build
  end

  def build
    result = []
    show_vapid = %w(+ all hidden vapid).include? @filter
    stack = stack_bindings(show_vapid)
              .reverse.reject do |binding|
                binding.eval('__FILE__').match self.class::filter
              end

    if @lines_count and stack.count > @lines_count
      result << "Latest #{@lines_count} lines: (`bt all` for full tracing)"
      stack = stack.last(@lines_count)
    end

    build_result stack, result
  end

  def build_result(stack, result)
    current_object = nil
    stack.each_with_index do |binding|
      obj, debug_snapshot = binding.eval '[self, (debug_snapshot rescue nil)]'
      # Comparison of objects directly may raise exception
      if current_object.object_id != obj.object_id
        result << "#{debug_snapshot || format_obj(obj)}:"
        current_object = obj
      end

      result << build_line(binding)
    end
    result
  end

  def format_obj(obj)
    if @colorize
      PryMoves::Painter.colorize obj
    else
      obj.inspect
    end
  end

  def build_line(binding)
    file = PryMoves::Helpers.shorten_path "#{binding.eval('__FILE__')}"

    signature = PryMoves::Helpers.method_signature binding
    signature = ":#{binding.frame_type}" if !signature or signature.length < 1

    indent = if frame_manager.current_frame == binding
               '==> '
             else
               s = "#{binding.index}:".ljust(4, ' ')
               "\e[2;49;90m#{s}\e[0m"
             end

    line = binding.eval('__LINE__')
    "#{indent}#{file}:#{line} #{signature}"
  end

  def frame_manager
    PryStackExplorer.frame_manager(@pry)
  end

  def stack_bindings(vapid_frames)
    frame_manager.bindings.filter_bindings vapid_frames: vapid_frames
  end

  def write_to_file(lines, file_suffix)
    log_path = log_path file_suffix
    File.write log_path, lines.join("\n")
    puts "Backtrace logged to #{log_path}"
  end

  def log_path(file_suffix)
    root = defined?(Rails) ? Rails.root.to_s : '.'
    root += '/log'
    FileUtils.mkdir_p root
    "#{root}/backtrace_#{file_suffix}.log"
  end

end