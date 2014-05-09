module SmartAnswer
  module Question
    class Base < Node

      def initialize(name, options = {}, &block)
        @save_input_as = nil
        @validations ||= []
        @next_node_function_chain ||= []
        @default_next_node_function ||= lambda {|_|}
        @permitted_next_nodes = []
        super
      end

      def next_node(next_node = nil, &block)
        if block_given?
          @default_next_node_function = block
        elsif next_node
          @next_node_function_chain << [next_node, lambda { |_| true }]
          @permitted_next_nodes << next_node
        else
          raise ArgumentError
        end
      end

      def next_node_if(next_node, &block)
        @next_node_function_chain << [next_node, block]
        @permitted_next_nodes << next_node
      end

      def validate(message = nil, &block)
        @validations << [message, block]
      end

      def permitted_next_nodes(*args)
        @permitted_next_nodes += args
      end

      def next_node_for(current_state, input)
        validate!(current_state, input)
        next_node = next_node_from_function_chain(current_state, input) || next_node_from_default_function(current_state, input)
        raise "Next node undefined (#{current_state.current_node}(#{input}))" unless next_node
        raise "Illegal next node '#{next_node}'. All next nodes must be explicitly declared." unless permitted_next_node?(next_node)
        next_node
      end

      def save_input_as(variable_name)
        @save_input_as = variable_name
      end

      def transition(current_state, raw_input)
        input = parse_input(raw_input)
        next_node = next_node_for(current_state, input)
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

      def validate!(current_state, input)
        @validations.each do |message, predicate|
          if !current_state.instance_exec(input, &predicate)
            if message
              raise InvalidResponse, message
            else
              raise InvalidResponse
            end
          end
        end
      end

      def next_node_from_function_chain(current_state, input)
        found = @next_node_function_chain.find do |(_, predicate)|
          current_state.instance_exec(input, &predicate)
        end
        found && found.first
      end

      def next_node_from_default_function(current_state, input)
        current_state.instance_exec(input, &@default_next_node_function)
      end

    end
  end
end
