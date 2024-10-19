# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new do |task|
  task.requires << "rubocop-minitest"
  task.requires << "rubocop-rake"
end

task default: %i[test rubocop]
