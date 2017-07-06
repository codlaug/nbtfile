# encoding: UTF-8
$:.push File.expand_path("../lib", __FILE__)
Gem::Specification.new do |spec|
  # ============
  # = Defaults =
  # ============
  spec.name        = 'nbtfile'
  spec.version     = '0.3.0'
  spec.summary     = 'NBT file'
  spec.description = 'Library for reading and writing NBT files (as used by Minecraft).'
  spec.authors     = ['MenTaLguY']
  spec.email       = 'gems@bmonkeys.net'
  spec.homepage    = 'https://github.com/2called-chaos/nbtfile'

  # =========
  # = Files =
  # =========
  spec.files      += Dir['lib/nbtfile.rb']
  spec.files      += Dir['lib/nbtfile/*.rb']
end
