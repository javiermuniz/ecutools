# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name = "ecutools"
  s.version     = "0.0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors = ["Javier Muniz"]
  s.email = "javier@granicus.com"
  s.summary = "Toolkit for disassembling and reverse engineering ECU ROMs"
  s.homepage = "http://github.com/javiermuniz/ecutools"
  s.description = "Toolkit for ECU disassembly and analysis"
  
  s.rubyforge_project = "ecutools"
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  
  s.add_development_dependency('thor', '>= 0.14')

  s.add_dependency('thor', '>= 0.14')
end
