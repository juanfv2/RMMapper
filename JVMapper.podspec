Pod::Spec.new do |s|
  s.name     = 'JVMapper'
  s.version  = '2.0.0'
  s.license  = 'MIT'
  s.summary  = 'Convert NSDictionary/NSArray into objects with predefined class.'
  s.homepage = 'https://github.com/juanfv2/JVMapper'
  s.authors  = { 'Juan Villalta' => 'juanfv2@gmail.com' }
  s.source   = { :git => 'https://github.com/juanfv2/JVMapper.git', :tag => '2.0.0' }
  s.source_files = 'JVMapper'
  s.requires_arc = true
  s.ios.deployment_target = '5.0'
end