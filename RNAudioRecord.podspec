require 'json'

package = JSON.parse(File.read(File.join(__dir__, './package.json')))

Pod::Spec.new do |s|
  s.name           = "RNAudioRecord"
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = "https://github.com/maxckelly/react-native-audio-record"
  s.source         = { :git => 'https://github.com/maxckelly/react-native-audio-record.git' }

  s.requires_arc   = true
  s.platform       = :ios, '11.0'

  s.preserve_paths = './README.md', './package.json', './src/index.ts'
  s.source_files   = './ios/**/*.{h,m,swift}'
  s.dependency 'React'
end
