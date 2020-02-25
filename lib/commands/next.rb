class PryMoves::Next < PryMoves::TraceCommand

  def init(binding_)
    @start_line = binding_.eval('__LINE__')
    @start_digest = frame_digest(binding_)
    if @command[:param] == 'blockless'
      @stay_at_frame = @start_digest
    end
    @events_traced = 0
  end

  def trace(event, file, line, method, binding_)
    @events_traced += 1
    traced_method_exit = (@call_depth < 0 and %w(line call).include? event)
    if traced_method_exit
      # Set new traced method, because we left previous one
      set_traced_method binding_
      throw :skip if event == 'call'
    end

    if @call_depth == 0 and
      within_current_method?(file, line)

      if event == 'line'
        if @stay_at_frame
          return (
            @stay_at_frame == current_frame_digest or
            @c_stack_level < 0
          )
        elsif @start_line != line or (
            @events_traced > 1 and # чтобы не застревало на while (vx = shift)
            @start_digest == current_frame_digest # for correct iterating over one_line_in_block
          )
          return true
        end
      end

      exit_from_method if event == 'return' and
        method == @method[:name] and before_end?(line)
    end
  end

end
