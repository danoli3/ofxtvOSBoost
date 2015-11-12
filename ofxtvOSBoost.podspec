Pod::Spec.new do |s|
  s.name         = "ofxtvOSBoost"
  s.version      = "1.59.0"
  s.summary      = "Boost C++ library"
  s.description  = <<-DESC
Boost is the library that can (and should) be used to ease c++ development.
                   DESC
  s.homepage     = "http://www.boost.org"
  s.license      = 'Boost'
  s.author       = { "Danoli3" => "danoli3@gmail.com" }
  s.source       = { :git => "https://github.com/danoli3/ofxtvOSBoost.git", :tag => "#{s.version}" }

  s.platform     = :tvos, '9.0'
  s.tvos.deployment_target = '9.0'
  s.requires_arc = false
  s.tvos.source_files = "libs/boost/include/**/*.{h,hpp,ipp}"
  s.tvos.header_mappings_dir = "libs/boost/include"
  s.tvos.public_header_files = "libs/boost/include/**/*.{h,hpp,ipp}"

  s.tvos.preserve_paths = "libs/boost/include/**/*.{h,hpp,ipp}", "libs/boost/tvos/**/*.a"
  s.tvos.vendored_libraries = "libs/boost/tvos/**/*.a"

end
