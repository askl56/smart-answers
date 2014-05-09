# coding:utf-8

require 'ostruct'
require_relative '../test_helper'

class QuestionBaseTest < ActiveSupport::TestCase
  test "State is carried over on a state transition" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node :done
    }
    initial_state = SmartAnswer::State.new(q.name)
    initial_state.something_else = "Carried over"
    new_state = q.transition(initial_state, :yes)
    assert_equal "Carried over", new_state.something_else
  end

  test "Next node is taken from next_node_for method" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node :done
    }
    initial_state = SmartAnswer::State.new(q.name)
    q.stubs(:next_node_for).returns(:done)
    new_state = q.transition(initial_state, :anything)
    assert_equal :done, new_state.current_node
  end

  test "Can define next_node by passing a value" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node :done
    }
    initial_state = SmartAnswer::State.new(q.name)
    new_state = q.transition(initial_state, :anything)
    assert_equal :done, new_state.current_node
  end

  test "Can define next_node by giving a block, provided that next node is declared" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node { :done_done }
      permitted_next_nodes(:done_done)
    }
    initial_state = SmartAnswer::State.new(q.name)
    new_state = q.transition(initial_state, :anything)
    assert_equal :done_done, new_state.current_node
  end

  test "exception raised if next_node calulated by block has not been declared" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node { :not_declared }
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_raises(RuntimeError) do
      q.transition(initial_state, 'something')
    end
  end

  test "next_node block can refer to state" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node do
        colour == 'red' ? :was_red : :wasnt_red
      end
      permitted_next_nodes(:was_red, :wasnt_red)
    }
    initial_state = SmartAnswer::State.new(q.name)
    initial_state.colour = 'red'
    new_state = q.transition(initial_state, 'anything')
    assert_equal :was_red, new_state.current_node
  end

  test "next_node block is passed input" do
    input_was = nil
    q = SmartAnswer::Question::Base.new(:example) {
      next_node(:done) do |input|
        input_was = input
        :done
      end
      permitted_next_nodes(:done)
    }
    initial_state = SmartAnswer::State.new(q.name)
    new_state = q.transition(initial_state, 'something')
    assert_equal 'something', input_was
  end

  test "Input can be saved into the state" do
    q = SmartAnswer::Question::Base.new(:favourite_colour?) do
      save_input_as :colour_preference
      next_node :done
    end
    initial_state = SmartAnswer::State.new(q.name)
    new_state = q.transition(initial_state, :red)
    assert_equal :red, new_state.colour_preference
  end

  test "Input sequence is saved into responses" do
    q = SmartAnswer::Question::Base.new(:favourite_colour?) {
      next_node :done
    }
    initial_state = SmartAnswer::State.new(q.name)
    new_state = q.transition(initial_state, :red)
    assert_equal [:red], new_state.responses
  end

  test "Node path is saved in state" do
    q = SmartAnswer::Question::Base.new(:favourite_colour?)
    q.next_node :done
    initial_state = SmartAnswer::State.new(q.name)
    initial_state.current_node = q.name
    new_state = q.transition(initial_state, :red)
    assert_equal [:favourite_colour?], new_state.path
  end

  test "Can calculate other variables based on input" do
    q = SmartAnswer::Question::Base.new(:favourite_colour?) do
      save_input_as :colour_preference
      calculate :complementary_colour do
        colour_preference == :red ? :green : :red
      end
      next_node :done
    end
    initial_state = SmartAnswer::State.new(q.name)
    new_state = q.transition(initial_state, :red)
    assert_equal :green, new_state.complementary_colour
    assert new_state.frozen?
  end

  test "Can calculate intermediary values used when computing next node" do
    q = SmartAnswer::Question::Base.new(:favourite_colour?) do
      next_node_calculation :complementary_colour do |response|
        response == :red ? :green : :red
      end
      next_node_calculation :blah do
        "blah"
      end
      next_node_if(:done) {
        complementary_colour == :green
      }
      next_node(:shouldnt_go_here)
    end
    initial_state = SmartAnswer::State.new(q.name)
    new_state = q.transition(initial_state, :red)
    assert_equal :green, new_state.complementary_colour
    assert_equal "blah", new_state.blah
    assert_equal :done, new_state.current_node
  end

  test "conditional next node can be specified using next_node_if passing a block" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:bar) { true }
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_equal :bar, q.next_node_for(initial_state, :red)
  end

  test "conditional next node can be specified using next_node_if passing a predicate" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:bar, ->(_) {true})
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_equal :bar, q.next_node_for(initial_state, :red)
  end

  test "conditional next node can be specified using next_node_if passing a list of predicates all of which must be true" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:bar, ->(_) {true}, ->(_) {false})
      next_node_if(:baz, ->(_) {true})
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_equal :baz, q.next_node_for(initial_state, :red)
  end

  test "conditional next nodes are evaluated in order" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:skipped) { false }
      next_node_if(:first) { true }
      next_node_if(:second) { true }
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_equal :first, q.next_node_for(initial_state, :red)
  end

  test "conditional block is passed input and can refer to state" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:is_red) do |input|
        color == input
      end
    }
    initial_state = SmartAnswer::State.new(q.name)
    initial_state.color = :red
    assert_equal :is_red, q.next_node_for(initial_state, :red)
  end

  test "next_node block used as fallback" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:skipped) { false }
      next_node { :next }
      permitted_next_nodes(:next)
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_equal :next, q.next_node_for(initial_state, :red)
  end

  test "conditional next_node used if triggered ignoring fallback" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:next) { true }
      next_node { :ignored }
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_equal :next, q.next_node_for(initial_state, :red)
  end

  test "next_node value used as fallback" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:skipped) { false }
      next_node(:next)
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_equal :next, q.next_node_for(initial_state, :red)
  end

  test "next_node value ignored if conditional fires" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:next) { true }
      next_node(:ignored)
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_equal :next, q.next_node_for(initial_state, :red)
  end

  test "error if no conditional transitions found and no fallback" do
    q = SmartAnswer::Question::Base.new(:example) {
      next_node_if(:skipped) { false }
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_raises RuntimeError do
      q.next_node_for(initial_state, :red)
    end
  end

  test "can validate response" do
    q = SmartAnswer::Question::Base.new(:example) {
      validate { |response| response == :red }
      next_node(:next)
    }
    initial_state = SmartAnswer::State.new(q.name)
    assert_raises SmartAnswer::InvalidResponse do
      q.next_node_for(initial_state, :blue)
    end
    assert_equal :next, q.next_node_for(initial_state, :red)
  end
end
