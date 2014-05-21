class GraphPresenter
  def initialize(flow)
    @flow = flow
    @simulation_data = TransitionSimulator.simulate(flow)
  end

  def labels
    Hash[@flow.nodes.map { |node| [node.name, graph_label_text(node)]} ]
  end

  def adjacency_list
    @adjacency_list ||= begin
      adjacency_list = {}
      @flow.questions.each do |node|
        adjacency_list[node.name] = []
        node.next_node_function_chain.each do |(nextnode, predicates)|
          pair = [node.name, nextnode]
          edge_label = ""
          if @simulation_data[pair]
            edge_label << "*#{@simulation_data[pair]}*\n"
          end
          edge_label << predicates.map(&:label).compact.join(" AND\n")
          adjacency_list[node.name] << [nextnode, edge_label]
        end
      end
      @flow.outcomes.each do |node|
        adjacency_list[node.name] = []
      end
      adjacency_list
    end
  end

  def to_hash
    {
      labels: labels,
      adjacencyList: adjacency_list
    }
  end

private
  def graph_label_text(node)
    text = node.class.to_s.split("::").last + "\n-\n"
    case node
    when SmartAnswer::Question::MultipleChoice
      text << word_wrap(node_title(node))
      text << "\n\n"
      text << node.permitted_options.map do |option|
          "( ) #{option}"
        end.join("\n")
    when SmartAnswer::Question::Checkbox
      text << word_wrap(node_title(node))
      text << "\n\n"
      text << node.options.map do |option|
          "[ ] #{option}"
        end.join("\n")
    when SmartAnswer::Question::Base
      text << word_wrap(node_title(node))
    when SmartAnswer::Outcome
      text << word_wrap(node_title(node).empty? ? node.name.to_s : node_title(node))
    else
      text << "Unknown node type"
    end
    text
  end

  def word_wrap(text, line_width=40)
    text.split("\n").collect! do |line|
      line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
    end * "\n"
  end

  def allow_missing_interpolations(&block)
    old = I18n.config.missing_interpolation_argument_handler
    I18n.config.missing_interpolation_argument_handler = ->(key) { "((#{key}))" }
    block.call
  ensure
    I18n.config.missing_interpolation_argument_handler = old
  end

  def i18n_prefix(node)
    "flow.#{@flow.name}.#{node.name}"
  end

  def node_title(node)
    allow_missing_interpolations do
      I18n.translate!("#{i18n_prefix(node)}.title", {})
    end
  rescue I18n::MissingTranslationData
    ""
  end

  def node_body(node)
    allow_missing_interpolations do
      I18n.translate!("#{i18n_prefix(node)}.body", {})
    end
  rescue I18n::MissingTranslationData
    ""
  end

  def translate_option(node, option)
    allow_missing_interpolations do
      begin
        I18n.translate!("flow.#{@flow.name}.options.#{option}")
      rescue I18n::MissingTranslationData
        I18n.translate("#{i18n_prefix(node)}.options.#{option}")
      end
    end
  end

  def presenter
    @presenter ||= FlowRegistrationPresenter.new(@flow)
  end
end
