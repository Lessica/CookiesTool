require_relative 'patch_static_framework'
project 'CookiesTool.xcodeproj'

def all_pods
	pod 'BinaryCodable', :git => 'git@github.com:jverkoey/BinaryCodable.git'
end

target 'CookiesTool' do
	platform :osx, '10.13'
	all_pods
end

target 'CookiesTool-iOS' do
	platform :ios, '12.0'
	all_pods
end
