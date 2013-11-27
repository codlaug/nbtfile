# Encoding: UTF-8

Gem::Specification.new do |s|
  s.platform          = Gem::Platform::RUBY
  s.name              = 'nbtfile'
  s.version           = '0.3.0'
  s.author            = 'Glenn Hoppe'
  s.description       = 'Gem for parsing NBT file format (Minecraft)'
  s.date              = '2013-11-27'
  s.summary           = 'Gem for parsing NBT file format (Minecraft)'
  s.require_paths     = %w(lib)
  s.files             = Dir["{app,config,db,lib}/**/*"] + ["readme.rdoc"]
end