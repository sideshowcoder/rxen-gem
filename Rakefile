#!/usr/bin/env ruby

require 'rubygems' unless ENV['NO_RUBYGEMS']
require 'rake/gempackagetask'
require 'rubygems/specification'

 
spec = Gem::Specification.new do |s|
  s.name = "rxen"
  s.version = "0.1.2"
  s.authors = ['Philipp Fehre']
  s.email = "philipp.fehre@googlemail.com"
  s.homepage = "https://github.com/sideshowcoder/rxen-gem"
  s.description = "Ruby wrapper to acces the Xen XML-RPC API via simple ruby methods" 
  s.summary = "Handles login, and after that all other Xen API methods exposed via XML-RPC by XenServer"
  
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc"]
  
  s.require_path = 'lib'
  s.autorequire = 'rxen'
  s.files = %w(README.rdoc Rakefile) + Dir.glob("{lib,tests,bin}/*")
  
  s.bindir = 'bin'
  s.executables = ['rxen']
  s.test_files = Dir.glob('tests/*.rb')  
  s.add_dependency('json')
end

Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar = true
end

task :default => "pkg/#{spec.name}-#{spec.version}.gem" do
    puts "generated latest version"
end
