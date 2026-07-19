Pod::Spec.new do |s|
  s.name             = 'ocgcore'
  s.version          = '1.0.0'
  s.summary          = 'YGOPRO ocgcore duel engine'
  s.homepage         = 'https://github.com/electrolyteJ/ygopro-core'
  s.license          = { :type => 'MIT' }
  s.author           = { 'electrolyteJ' => '' }
  s.platform         = :osx, '10.15'
  s.source           = { :path => '.' }
  s.vendored_libraries = 'Frameworks/libocgcore.dylib'
  s.static_framework = true
end
