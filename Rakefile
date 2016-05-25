# encoding: utf-8
require 'rake'
require 'rake/testtask'
require 'rake/packagetask'
require 'rubygems/package_task'
require 'rspec/core/rake_task'
require 'spree/testing_support/common_rake'

RSpec::Core::RakeTask.new

task :default => [:spec]

spec = eval(File.read('spree_google_base.gemspec'))

Gem::PackageTask.new(spec) do |p|
  p.gem_spec = spec
end

desc "Release to gemcutter"
task :release => :package do
  require 'rake/gemcutter'
  Rake::Gemcutter::Tasks.new(spec).define
  Rake::Task['gem:push'].invoke
end

desc "Generates a dummy app for testing"
task :test_app do
  ENV['LIB_NAME'] = 'spree_google_base'

  #puts 'Installing spree-multi-domain migrations [required for testing]'
  #dep_path = `bundle show spree_multi_domain`.chomp
  #migration_path = File.join(dep_path,'db','migrate')
  dummy_path = File.join(FileUtils.pwd, 'spec', 'dummy', 'db')

  FileUtils.mkdir_p(dummy_path)
  #FileUtils.cp_r(migration_path, dummy_path)

  Rake::Task['common:test_app'].invoke
end
