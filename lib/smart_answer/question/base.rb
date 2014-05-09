module SmartAnswer
  module Question
    class Base < Node

      def initialize(name, options = {}, &block)
        @save_input_as = nil
        @next_node_function ||= lambda {|_|}
        @permitted_next_nodes = []
        super
      end

      def next_node(*args, &block)
        if block_given?
          @next_node_function = block
        elsif args.count == 1
          @next_node_function = lambda { |_input| args.first }
          @permitted_next_nodes << args.first
        else
          raise ArgumentError
        end
      end

      def permitted_next_nodes(*args)
        @permitted_next_nodes += args
      end

      def next_node_for(current_state, input)
        current_state.instance_exec(input, &@next_node_function) \
          or raise "Next node undefined (#{current_state.current_node}(#{input}))"
      end

      def save_input_as(variable_name)
        @save_input_as = variable_name
      end

      def transition(current_state, raw_input)
        input = parse_input(raw_input)
        next_node = next_node_for(current_state, input)
        raise "Illegal next node '#{next_node}'. All next nodes must be explicitly declared." unless permitted_next_node?(next_node)
        new_state = current_state.transition_to(next_node, input) do |state|
          state.save_input_as @save_input_as if @save_input_as
        end
        @calculations.each do |calculation|
          new_state = calculation.evaluate(new_state)
        end
        new_state
      end

      def parse_input(raw_input)
        raw_input
      end

      def to_response(input)
        input
      end

      def question?
        true
      end

    private
      def permitted_next_node?(next_node)
        @permitted_next_nodes.include?(next_node)
      end
    end
  end
end
