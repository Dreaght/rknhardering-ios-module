require 'fileutils'
require 'xcodeproj'

root = File.expand_path('..', __dir__)
app_dir = File.join(root, 'RKNHarderingIOSApp')
proj_path = File.join(app_dir, 'RKNHarderingIOSApp.xcodeproj')

FileUtils.rm_rf(proj_path) if Dir.exist?(proj_path)

project = Xcodeproj::Project.new(proj_path)
app_target = project.new_target(:application, 'RKNHarderingIOSApp', :ios, '16.0')

project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
end

app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.rknhardering.ios'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = 'RKNHarderingIOSApp/Info.plist'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end

main_group = project.main_group
app_group = main_group.new_group('RKNHarderingIOSApp', 'RKNHarderingIOSApp')
shared_sources = main_group.new_group('SharedSources', '../Sources/RKNHarderingIOS')
app_sources = app_group.new_group('App', 'RKNHarderingIOSApp')

file_refs = []
Dir.glob(File.join(root, 'Sources', 'RKNHarderingIOS', '*.swift')).sort.each do |path|
  file_refs << shared_sources.new_file(File.basename(path))
end

Dir.glob(File.join(app_dir, 'RKNHarderingIOSApp', '*.swift')).sort.each do |path|
  file_refs << app_sources.new_file(File.basename(path))
end

app_target.add_file_references(file_refs)

project.files.each do |ref|
  next unless ref.display_name == 'Foundation.framework'

  ref.path = 'System/Library/Frameworks/Foundation.framework'
  ref.source_tree = 'SDKROOT'
end

project.save
puts "Generated #{proj_path}"

