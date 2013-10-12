Pod::Spec.new do |s|

  s.name         = "SPAsync"
  s.version      = "0.0.1"
  s.summary      = "Tools for abstracting asynchrony in Objective-C."

  s.description  = <<-DESC
SPAsync
=======
by Joachim Bengtsson <joachimb@gmail.com>

Tools for abstracting asynchrony in Objective-C. Read [the introductory blog entry](http://overooped.com/post/41803252527/methods-of-concurrency) for much more detail.
DESC

  s.homepage     = "https://github.com/nevyn/SPAsync"

  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "Joachim Bengtsson" => "joachimb@gmail.com" }

  s.source       = { :git => "https://github.com/nevyn/SPAsync.git", :commit => "bd5730018a606f4ff91c964679eb1b7baba06f7d" }

  s.source_files  = 'Sources', 'Sources/**/*.{h,m}', 'include/**/*.h'
  s.public_header_files = 'include/SPAsync/**/*.h'

  s.ios.deployment_target = '5.0'

  s.requires_arc = true

end
