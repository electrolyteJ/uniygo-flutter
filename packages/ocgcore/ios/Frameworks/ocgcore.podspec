Pod::Spec.new do |s|
  s.name             = 'ocgcore'
  s.version          = '1.0.0'
  s.summary          = 'YGOPRO ocgcore duel engine'
  s.homepage         = 'https://github.com/electrolyteJ/ygopro-core'
  s.license          = { :type => 'MIT' }
  s.author           = { 'electrolyteJ' => '' }
  s.platform         = :ios, '12.0'
  s.source           = { :path => '.' }
  s.vendored_frameworks = 'libocgcore.xcframework'
  s.static_framework = true
end
